# Backend Design: Supermarket Mobile App (Sub-project 1 of 3)

Date: 2026-10-29
Status: Draft, awaiting review

## 1. Context and goals

A real product for a retail client (not Lidl). The client's own brand and an original design are used. Only general supermarket-app structure is borrowed: offers and flyer, shopping list, store finder, loyalty card. No third-party logos, assets or private APIs.

The project is split into three sub-projects, each with its own spec, plan and build cycle:

1. **Backend** (this document): Django, Django REST Framework, PostgreSQL.
2. **Customer app**: Flutter for Android and iOS (offers/flyer, shopping list, stores, loyalty card).
3. **Staff mode**: the same Flutter app with a role-based management area for offers, flyers and stores.

Build order: backend, customer app, staff mode.

### Agreed constraints
- Single country, single language (Flutter localization is still wired up from day one).
- Data enters the system through the staff mobile mode; Django admin remains as a desktop fallback for bulk edits and CSV import.
- One Flutter codebase and one store listing; staff accounts see an extra management area.
- REST with an OpenAPI contract; the Dart client is generated from the schema.

### Out of scope for backend v1
Push notifications, payments, online ordering, coupon redemption at the till, social login, PostGIS, offline conflict resolution beyond last-write-wins.

## 2. Data model

### `accounts`
- `User`: custom model, email as login, `role` (`customer` | `staff`), name, created_at.
- `LoyaltyCard`: one per customer, unique member number (generated on sign-up), rendered by the app as barcode or QR code.

### `catalog`
- `Category`: name, slug, sort order.
- `Product`: name, description, image, category, unit (e.g. "500 g"), optional EAN (nullable).

### `offers`
- `Flyer`: title, `valid_from`, `valid_to`, status (`draft` | `published`), cover image. Customers see only published flyers.
- `Offer`: flyer, product, price, optional old price, optional badge text, sort order, optional per-offer validity override.

### `stores`
- `Store`: name, address, city, postcode, latitude, longitude, phone, active flag.
- `OpeningHours`: store, weekday, open and close time. A closed day has no row.

### `shopping`
- `ShoppingList`: user, name, timestamps.
- `ListItem`: list, optional product link, optional free text, quantity, checked flag. At least one of product or free text is required.

### Rules
- Prices are `DecimalField`; one currency, configured in settings.
- Customers see only published flyers and active stores; staff see everything.
- Shopping lists are private to the owner.
- Store distance is computed on the device. The server sorts by simple nearest-distance when coordinates are given (no PostGIS).
- A flyer can be published only if it has at least one offer and its dates do not overlap another published flyer.

## 3. API

Base path `/api/v1/`, JSON over HTTPS. OpenAPI schema at `/api/schema/` (via `drf-spectacular`); this is the contract for the generated Dart client.

### Auth
| Endpoint | Purpose |
|---|---|
| `POST /auth/register` | Email and password sign-up; creates a `customer` and their loyalty card |
| `POST /auth/login` | Access token (15 min) and refresh token (30 days) |
| `POST /auth/refresh` | Rotates the refresh token |
| `POST /auth/logout` | Blacklists the refresh token |
| `GET/PATCH /me` | Profile; includes `role` so the app can enable staff mode |
| `GET /me/card` | Card number and the value to encode |
| `DELETE /me` | Account deletion (required by Apple) |

### Public, read-only (no login)
- `GET /flyers/current`, `GET /flyers`, `GET /flyers/{id}`
- `GET /offers?category=&q=`
- `GET /categories`
- `GET /stores?lat=&lng=&q=`, `GET /stores/{id}` (includes opening hours)

### Shopping lists (customer, owner only)
- `GET/POST /lists`, `GET/PATCH/DELETE /lists/{id}`
- `POST /lists/{id}/items`, `PATCH/DELETE /lists/{id}/items/{item_id}`
- `updated_since` filter; sync is last-write-wins by `updated_at`.

### Staff (`role=staff`, under `/api/v1/staff/`)
- CRUD for `flyers`, `offers`, `products`, `categories`, `stores` (including opening hours).
- `POST /staff/flyers/{id}/publish` and `/unpublish`.
- `POST /staff/uploads/image`: multipart; JPEG, PNG or WebP, max 5 MB; resized; returns a URL.

### Permissions and cross-cutting rules
- DRF permission classes: `IsStaff`, `IsOwner`, anonymous read-only on public endpoints.
- Staff accounts are created or promoted only in Django admin, never via the API.
- Stricter rate limiting on `/auth/*`.
- Error shape: `{"code": "...", "detail": "...", "fields": {...}}`.
- Cursor pagination on list endpoints.
- Images: S3-compatible storage in production, local disk in development.

## 4. Infrastructure

### Layout
```
backend/    Django project (apps: accounts, catalog, offers, stores, shopping)
app/        Flutter app (sub-project 2)
docs/       specs and plans
```

### Local development
- `docker compose up`: Django, Postgres, local mail catcher.
- Settings split into `base`, `dev`, `prod`; secrets from environment variables; committed `.env.example`.
- `seed_demo` management command loads sample categories, products, a flyer with offers and stores.

### Production
- Django behind gunicorn and a reverse proxy (Caddy or nginx) with HTTPS.
- Managed Postgres with daily backups; S3-compatible object storage.
- Static files via WhiteNoise or the proxy; migrations run as a release step.
- Hosting is to be confirmed with the client (single VPS with Docker Compose is sufficient for launch; the containers move to a managed platform without code changes).
- Sentry for errors; `/healthz` for uptime checks.

### Security
- Argon2 password hashing and password validators.
- `DEBUG=False` in production; CORS locked down; login throttling.
- Account deletion and a privacy policy URL, as both stores require.

## 5. Testing and CI

- `pytest`, `pytest-django`, `factory_boy`.
- Model tests: constraints (no overlapping published flyers, unique card numbers, list-item validation).
- API tests for every endpoint across anonymous, customer and staff, including: a customer cannot read another user's list; a customer gets 403 on `/staff/*`; a draft flyer is invisible to customers.
- OpenAPI drift check: CI regenerates the schema and fails if it differs from the committed `openapi.yaml`.
- Coverage target: about 85% on `accounts`, `offers`, `shopping`.
- GitHub Actions on every PR: `ruff` lint and format, `mypy` (lenient initially), `pytest` against a Postgres service container, OpenAPI drift check, Docker build. Deployment is a manual or tag-triggered job for v1.

## 6. Open items
- Production hosting choice (confirm with the client).
- Retailer name and brand (needed for the customer app design, not for the backend).
- Privacy policy and terms content (client to provide).
