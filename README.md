# Supermarket app

Monorepo. The Django + DRF + PostgreSQL backend lives in `backend/`.

## Backend quickstart

```bash
cp .env.example .env
docker compose up -d db mailpit
cd backend
python3.13 -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
export DATABASE_URL=postgres://app:app@localhost:5434/app
python manage.py migrate
pytest
```

Or run everything in containers: `docker compose up -d db && docker compose run --rm web pytest`.

Health check: `GET /healthz` returns `{"status": "ok"}`. Mailpit UI: http://localhost:8025.

## API contract

The OpenAPI 3 contract is committed at `backend/openapi.yaml` and served live (public, no auth) at
`GET /api/schema/` (YAML; add `?format=json` for JSON). It is the source for the Flutter client.

Regenerate it after changing any endpoint, serializer or `@extend_schema`:

```bash
cd backend
python manage.py spectacular --file openapi.yaml --validate --fail-on-warn
```

Drift is caught twice: `tests/test_openapi.py::test_committed_openapi_matches_generated` and a CI
step that regenerates the file and runs `git diff --exit-code`. Both fail if you forget to commit
the regenerated file. Every operation documents the standard error shape (`Error`: `code`,
`detail`, `fields`) as its `default` response.

Generate a Dart client (not part of this repo), for example:

```bash
openapi-generator-cli generate -i backend/openapi.yaml -g dart-dio -o client
```

## Tests and coverage

```bash
cd backend
pytest --cov
coverage report --include="accounts/*" --fail-under=85   # likewise offers/*, shopping/*
```

CI enforces at least 85% line coverage on `accounts`, `offers` and `shopping`.

## Demo data

`python manage.py seed_demo` fills a development database (it refuses to run unless `DEBUG` is
true, which is the case with `config.settings.dev`). It is idempotent: re-running it keeps the same
rows and re-publishes the "Demo weekly flyer" for the current week if its dates have passed.

It creates 6 categories, 24 products, one published flyer with 12 offers, 5 stores with opening
hours (Mon-Sat; Sunday closed except for the Express store), a staff user `staff@example.com` and a
customer `customer@example.com` (with loyalty card). No images are created.

Passwords come from `DEMO_STAFF_PASSWORD` and `DEMO_CUSTOMER_PASSWORD`. If unset, these dev-only
defaults apply (never use them anywhere real): staff `demo-staff-pass-123`, customer
`demo-customer-pass-123`.

## Staff users

Staff are never created through the API. A superuser (created with `createsuperuser`, below) gets
the role `staff` automatically and can promote other users to staff in the Django admin
(`/admin/`, Users, set the role). Locally, `seed_demo` already creates `staff@example.com`.

## Deployment

The hosting provider is still to be confirmed with the client. A single VPS running
`docker-compose.prod.yml` is sufficient for launch, and the same containers move unchanged to a
managed container platform later.

### What runs

| Service | Purpose |
| --- | --- |
| `migrate` | One-shot: `migrate --noinput` then `createcachetable`; `web` starts only after it succeeds. |
| `web` | The `backend/` image: gunicorn as non-root user `app`, `config.settings.prod`, health check on `/healthz`. |
| `caddy` | Automatic HTTPS (Let's Encrypt), reverse proxy to `web:8000`, request body capped at 6 MB. |
| `maintenance` | Runs `manage.py flushexpiredtokens` once a day (purges expired JWT blacklist rows). |
| `db` | Optional Postgres 16 with a named volume, only with `--profile with-db`. |

### Prerequisites

- A server with Docker and Docker Compose v2, ports 80 and 443 open.
- A DNS record for your domain pointing at the server (Caddy needs it to obtain the certificate).
- A Postgres database: a managed instance (recommended, give its URL in `DATABASE_URL`) or the
  bundled `with-db` profile.
- Optional: an S3-compatible bucket for images; Sentry DSN for error reporting.

### Environment variables

Set these in `.env.prod` (template with comments: `.env.prod.example`).

| Variable | Required | Default | Notes |
| --- | --- | --- | --- |
| `SECRET_KEY` | yes | none | At least 32 characters; the dev default is rejected. |
| `DATABASE_URL` | yes | none | Production never falls back to the dev database. |
| `ALLOWED_HOSTS` | yes | none | Comma-separated, no `*`. First entry is used by the health check. |
| `CSRF_TRUSTED_ORIGINS` | no | empty | Comma-separated origins with scheme. |
| `DOMAIN`, `ACME_EMAIL` | yes (Caddy) | none | Public host name and Let's Encrypt contact. |
| `CURRENCY` | no | `EUR` | |
| `SECURE_SSL_REDIRECT` | no | `1` | `/healthz` is always exempt. |
| `SECURE_HSTS_SECONDS` | no | `31536000` | |
| `SECURE_HSTS_INCLUDE_SUBDOMAINS` | no | off | Set `1` only if all subdomains are HTTPS-only. |
| `AUTH_THROTTLE_RATE` | no | `10/min` | |
| `WEB_CONCURRENCY` | no | `3` | gunicorn workers. |
| `LOG_LEVEL` | no | `INFO` | Logs go to stdout/stderr. |
| `SENTRY_DSN` | no | empty | Sentry is initialized only if set. |
| `SENTRY_ENVIRONMENT`, `SENTRY_TRACES_SAMPLE_RATE` | no | `production`, `0.0` | |
| `AWS_STORAGE_BUCKET_NAME` | no | empty | Set to use S3 for uploads; otherwise the `media` volume. |
| `AWS_S3_ENDPOINT_URL`, `AWS_S3_REGION_NAME`, `AWS_S3_CUSTOM_DOMAIN` | no | empty | S3 options. |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | with S3 | empty | |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | `with-db` only | `app` / none / `app` | |

### First deploy

All commands run from the repository root. `--env-file .env.prod` feeds the Caddy and Postgres
values; the app containers also read `.env.prod` directly.

```bash
cp .env.prod.example .env.prod          # then edit every value; generate SECRET_KEY as the file says
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
# with the bundled database: add `--profile with-db` (and set DATABASE_URL to the db service)
curl https://api.example.com/healthz     # {"status": "ok"}
```

Create the first staff user (a superuser; it gets the role `staff`):

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod run --rm web python manage.py createsuperuser
```

Then sign in at `https://<domain>/admin/` to promote further staff.

### Media storage

- With S3 (`AWS_STORAGE_BUCKET_NAME` set), uploads go to `uploads/*` in the bucket. Because the
  storage uses `querystring_auth=False` and `default_acl=None`, the returned image URLs are plain
  URLs, so the bucket (or CDN in front of it) must allow public read of `uploads/*`. Minimal
  bucket policy (replace `BUCKET`):

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET/uploads/*"
    }]
  }
  ```

  Also turn on bucket versioning so overwritten or deleted images can be recovered.
- Without S3, files live in the `media` volume. Enable the commented `/media/*` block in
  `deploy/Caddyfile` so Caddy serves them, and include the volume in backups.

### Notes on behavior

- The auth throttle counts requests in the database cache table (`django_cache_table`, created by
  `createcachetable` in the `migrate` service), so the limit holds across gunicorn workers.
- Caddy rejects request bodies over 6 MB before Django sees them; the application limit for an
  image file itself stays 5 MB.
- Expired refresh tokens are purged daily by the `maintenance` service. Alternative: remove that
  service and use host cron:
  `0 3 * * * cd /srv/app && docker compose -f docker-compose.prod.yml --env-file .env.prod run --rm web python manage.py flushexpiredtokens`.
- Admin static files are collected into the image at build time and served by WhiteNoise.

### Backups

- Managed Postgres: enable daily automated snapshots and point-in-time recovery.
- `with-db` profile: nightly dump from cron, copied off the server, for example:
  `0 2 * * * cd /srv/app && docker compose -f docker-compose.prod.yml --env-file .env.prod exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > /backups/app-$(date +\%F).sql.gz`
- Media: S3 bucket versioning, or a copy of the `media` volume.

### Upgrades and rollback

Upgrade: `git pull`, then re-run `docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build`.
The `migrate` service applies new migrations before `web` restarts. Migrations are forward-only,
so take a database backup first. To roll back code, check out the previous revision and re-run
the same command; if a release included a migration that is not backward compatible, restore the
backup instead.
