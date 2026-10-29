# API fixtures

Real responses captured from the Django backend (`runserver` on a scratch database
migrated and seeded with `seed_demo`), pretty-printed with the key order the API returned.
All requests sent `Accept-Language: fr` and `Accept: application/json`. Base path `/api/v1`.
Timestamps are as returned and are not stable: tests must not assert exact timestamps.

| Fixture | Request |
| --- | --- |
| `flyers_current.json` | `GET /flyers/current` |
| `flyers_list.json` | `GET /flyers` |
| `offers_list.json` | `GET /offers` |
| `categories_list.json` | `GET /categories` |
| `stores_list.json` | `GET /stores` (no coordinates, `distance_km` null) |
| `stores_list_with_distance.json` | `GET /stores?lat=5.3600&lng=-4.0083` |
| `store_detail.json` | `GET /stores/{id}` (first store of `stores_list`) |
| `payment_methods.json` | `GET /payment-methods` |
| `list_detail.json` | `POST /lists` `{"name":"Courses"}`, then `POST /lists/{id}/items` with a product item (`product`, `quantity`) and a free-text item (`text`, `quantity`), then `GET /lists/{id}` as `customer@example.com` (Bearer token) |
| `me.json` | `GET /me` (Bearer token of `customer@example.com`) |
| `me_card.json` | `GET /me/card` (Bearer token) |
| `auth_login.json` | `POST /auth/login` for `customer@example.com`; the tokens are replaced by `access-token-fixture` / `refresh-token-fixture` (never commit real JWTs) |
| `error_validation.json` | `POST /auth/register` with the weak password `123` (HTTP 400) |
| `error_not_found.json` | `GET /stores/99999` (HTTP 404) |

Notes:

- `product.image` is null in the seed data (no images are seeded).
- The seed data fits on one page, so every `next` is null. The paging tests cover a non-null
  `next` with a synthetic envelope.
- Money (`price`, `old_price`) and store coordinates are decimal strings, e.g. `"750.00"`.
