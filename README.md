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
