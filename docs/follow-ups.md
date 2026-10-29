# Backend follow-ups

Items raised during task and whole-branch reviews of `feat/backend` that were judged non-blocking and were
**not** fixed on that branch. None affects correctness of the shipped endpoints in normal use; they are
hardening, test gaps, contract polish and documentation. Grouped by area, roughly by priority within each group.

## Security and robustness
- **Admin-created users keep their original email case** (`accounts/admin.py`): the stock admin forms bypass
  `create_user`. Login (`iexact`) and the `Lower(email)` unique constraint still protect, but add `clean_email`
  or lowercase in `User.save()` so the "stored lowercase" invariant holds everywhere.
- **Admin-created customers get no `LoyaltyCard`**, and changing `role` in admin does not add or remove one, so
  `GET /me/card` returns 404 for them. Create the card in `User.save()`/a signal or an admin hook.
- **`validate_password` is called without the user** (`accounts/serializers.py`): the similarity validator cannot
  compare the password to email/name. Validate against an unsaved `User(email=..., name=...)`.
- **Field-only offer PATCH racing a delete** (`staff/views.py`): `save(update_fields=...)` raises `DatabaseError`
  (500) if the offer vanished. Map to 404.
- **Invalid `NUM_PROXIES`** (empty or non-integer) fails at startup with a bare `ValueError`; raise
  `ImproperlyConfigured` with a clear message.
- **`warnings.catch_warnings` around `Image.open`** (`uploads/validators.py`) is process-global; rely on the manual
  40 MP size check plus `DecompressionBombError` instead.
- **PNG ICC profile is carried over on re-encode** and there is no EXIF-strip test for PNG/WebP (not PII; test gap).
- **Card-number `IntegrityError` is reported as an email error** and the `atomic()` around the retry loop adds
  nothing (practically unreachable).
- **Staff offer/flyer `IntegrityError` mapping** in `publish_flyer` is not tied to the exclusion constraint name.
- **Public input bounds**: add `max_length` to `q`/`category` params; add a regression test that a huge `flyer=`
  integer yields an empty page/404, not a 500.

## Data model and domain rules
- No `unique(flyer, product)` on `Offer`; offer validity dates are not checked against the flyer's dates.
- Deleting all offers of a *published* flyer through the **Django admin inline** can still break the
  "published implies at least one offer" rule (the staff API blocks it).
- Deleting a catalog product cascades to users' shopping-list items (ruling for v1); consider an `is_active`
  archive instead.
- Staff error keys differ slightly: "unpublish first" uses `flyer` in the last-offer guard but `status` for
  deleting a published flyer.

## API contract and client
- Response schemas under-require always-present fields (`ListItem` text/quantity/checked, `Product`
  unit/description, `Offer` sort_order, pagination `next`/`previous`), so the generated Dart models make them
  nullable. Cursor examples in the schema are spectacular's defaults.
- `PatchedStaffFlyerRequest` still lists `offers` although PATCH rejects it; the upload's 400 response has no body.
- Validate **error responses** (not just success) against the schema in `tests/test_contract_runtime.py`; simplify
  the `allOf`/`nullable` branch there.
- Pagination over mutable keys (shopping lists by `-updated_at`) can skip/repeat rows between page requests;
  documented in the README, clients should use `updated_since`. A `+` in a hand-built `updated_since` URL decodes
  to a space; send `Z` or percent-encode.

## Admin and imports
- CSV import: catch `csv.Error`, cache category lookups per import, drop the redundant BOM `lstrip`.
- Flyer admin "Unpublish" action always says "Unpublished."; `publish_flyer` raises `DoesNotExist` for an unsaved flyer.
- `common/admin.py` has an `__all__` workaround, a function-local import and heavy `type: ignore`.
- `seed_demo` re-run resets only the password of existing users, not role/card.

## Tests and tooling
- Permission tests use `mock.Mock` users; add real `User`/`AnonymousUser` cases. Add a "follow `next`, no overlap"
  cursor test, a test for `product: null` item PATCH, `is_active=true` store filter, "latest `valid_from` wins" for
  `/flyers/current`, absolute image URL positive test, and a prod S3-branch live check.
- Test nits: misnamed/hard-coded throttle test (breaks if `AUTH_THROTTLE_RATE` is set), redundant `cache.clear()`,
  bad-token public test accepts 200 or 404, public-route security test checks GET only, hash-seed test depends on cwd.
- CI runs on both `push` and `pull_request` for all branches (PR branches run twice); consider `push: [main]`.
- Add `caddy validate` (CI or on the server) for `deploy/Caddyfile`; it could not be run locally.
- Docs: if Caddy is ever placed behind a CDN/load balancer, `remote_ip` (admin allowlist) and `NUM_PROXIES` both
  change; the privacy-policy URL is a client-content item (not a backend deliverable).
