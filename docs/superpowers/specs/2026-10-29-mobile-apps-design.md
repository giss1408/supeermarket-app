# Mobile Apps Design: Customer App and Payment Backend Additions

Date: 2026-10-29
Status: Draft, awaiting review

## 1. Context and goals

The backend (Django, DRF, PostgreSQL) is merged on `main`; see `2026-10-29-backend-design.md`. This document
designs the **customer mobile app** (Flutter, Android and iOS) and the **small backend additions** it needs for
mobile money payments. The market is **Côte d'Ivoire**: prices in CFA francs (XOF), French only, payments through
Wave, Orange Money and MTN MoMo.

The work splits into sub-projects, each with its own plan and build cycle:

1. **Backend additions** (this spec, section 3): payment methods, French language, audit trail. Built first.
2. **Customer app v1** (this spec, sections 4 to 10): offers and flyer, shopping lists, stores, loyalty card,
   account, and the Pay screen.
3. **Staff mode** (separate spec later): the role-gated management area in the same app, including editing the
   payment numbers. The backend endpoints it needs are built here (section 3).

The app uses an original, white-label design. No third-party retailer's logo, assets, palette or private APIs are
used. The client's real brand is applied later by editing one theme file.

### Agreed constraints
- Flutter, one codebase, Android and iOS. The app lives in `app/` in this repository.
- Riverpod for state, `go_router` for navigation, feature-first folders, Drift (SQLite) for local data.
- The API client is generated from `backend/openapi.yaml`.
- Guests can browse offers, flyers, stores and payment numbers. Lists and the loyalty card need an account.
- Offline: cached browsing; shopping lists editable offline and synced later; loyalty card and payment numbers
  available offline.
- Single country (Côte d'Ivoire), single language (French), currency XOF.
- Payment is manual: the customer transfers to the retailer's mobile money number and shows the confirmation to
  the cashier. No orders, no provider API integration.
- The retailer has one set of payment numbers for the whole retailer (not per store).

### Out of scope for v1
Orders, delivery, provider APIs and automatic payment confirmation, push notifications, deep links, an embedded
map, per-store payment numbers, additional languages, tablet layouts, the staff-mode screens (separate spec).

## 2. Open items to confirm (do not block the plan)
- **Barcode symbology.** The card value is a 13-digit number. The app renders Code 128 and offers a QR view; the
  retailer's POS team must confirm what the tills scan. It is a one-line change.
- **Brand and identity.** App name, logo, colors, provider logos (trademarks the retailer must license), and the
  application id (placeholder `com.example.supermarket`).
- **Privacy policy URL and store disclosures** (client content).
- **Provider shortcuts.** Opening a provider's app or USSD menu is not included until the exact, current
  schemes and codes are verified with each provider.
- **Backend follow-ups** raised here: an idempotency key for creating lists, and deletion tombstones for list
  sync (see `docs/follow-ups.md`).

## 3. Backend additions

### 3.1 `payments` app
`PaymentMethod`: `provider` (`wave` | `orange_money` | `mtn_momo`, unique), `phone_number`, `display_name`
(blank), `instructions` (short text, blank, max 500 characters), `is_active`, `updated_at`.
- `phone_number` is validated as an Ivorian number: `+225` followed by 10 digits. It is stored in that normalised
  form; input with spaces or a leading `00225` is normalised before validation.
- At most one row per provider. Inactive rows are not shown to customers.

`PaymentMethodChange` (audit trail): payment method, `changed_by` (user, kept as an email snapshot if the user is
later deleted), `changed_at`, `old_phone_number` and `new_phone_number`, `old_is_active` and `new_is_active`
(the `old_*` values are null on create, the `new_*` values null on a hard delete in admin). A row is written on
every create, update and delete, from the API and from Django admin. It is append-only and visible in Django
admin (read-only).

### 3.2 API
- `GET /api/v1/payment-methods`: public, only active methods, fields `provider`, `phone_number`, `display_name`,
  `instructions`, `updated_at`. At most three rows, but it is cursor-paginated like every other list endpoint
  (page size 100), so the generated Dart client stays uniform.
- `/api/v1/staff/payment-methods` (IsStaff): list, create, retrieve, update (PATCH, no PUT). There is no DELETE
  in the staff API: a method is switched off with PATCH `is_active=false`; hard delete exists only in Django
  admin.
- **Password step-up.** Create and update require the field `current_password` in the JSON body. A missing or
  wrong password returns 400 with `fields.current_password` and writes nothing. Step-up attempts share a stricter
  throttle scope (`staff_sensitive`, default `5/min`) keyed per user.
- Responses use the standard error shape; the committed OpenAPI file and its drift and contract-vs-runtime tests
  cover the new endpoints.

### 3.3 Language and currency
- `LANGUAGE_CODE = "fr"` with `LocaleMiddleware`, so Django and DRF validation messages arrive in French when
  the client sends `Accept-Language: fr`.
- The `CURRENCY` setting default becomes `XOF` (documentation only: prices are still decimal strings such as
  `"1500.00"`). `TIME_ZONE` stays `UTC` (Abidjan is UTC+0).
- `seed_demo` data uses Ivorian places, CFA prices and one demo payment number per provider.

### 3.4 Tests
Models and validators (valid and invalid numbers, uniqueness per provider), audit rows on every change, the
step-up rule (missing, wrong, correct password), the throttle, public listing hides inactive methods, permissions
for every staff route, contract-vs-runtime schema tests, and the French error messages for a sample of
validators.

## 4. App architecture

Layers flow one way: screens → Riverpod controllers → repositories → (Drift database + generated API client).
Screens never call the API; for cached data they only watch database streams.

`app/lib/core/`
- `api/`: generated client wrapped in a Dio instance. Base URL from `--dart-define-from-file`.
- `db/`: Drift tables for categories, products, flyers, offers, stores, opening hours, payment methods, shopping
  lists, list items, the loyalty card, the outbox and sync metadata.
- `auth/`: access token in memory, refresh token in secure storage. On a 401, one shared refresh runs and the
  request is retried once; if refresh fails the user becomes a guest and public caches remain.
- `sync/`: `SyncService` (see section 6).
- `theme/`, `l10n/`, `money/` (XOF formatting), `errors/` (API error to `AppError` mapping).

`app/lib/features/`: `offers`, `lists`, `stores`, `card`, `account`, `payment`. Staff mode will add `staff/`.

Privacy: on sign-out or account switch, user-scoped data (lists, items, outbox, loyalty card) is wiped from the
device. Public caches stay. The Pay screen data is public and stays.

Errors: the API shape `{code, detail, fields}` is parsed into one `AppError`. User-facing text comes from French
ARB strings keyed by `code`; the server's `detail` is never shown to users. Field errors are mapped to form
fields.

## 5. Screens and navigation

`go_router` with four bottom tabs; each tab keeps its own stack and scroll position. Sign-in and register are a
modal flow that returns the user to where they were.

1. **Offers (home).** Current flyer header with validity dates, category chips, search, offer grid (price,
   optional old price, badge), offer detail sheet with "Add to list" (guests are asked to sign in), flyer archive.
2. **Lists.** Guest: sign-in prompt. Signed in: all lists; list detail with tick-off, quantity, swipe to delete,
   add by free text or from offers; a sync indicator ("offline", "N pending").
3. **Stores.** Distance-sorted when location is allowed, otherwise alphabetical with search. Store detail:
   address, tap-to-call, today's hours highlighted, full week, "Open in Maps" hand-off (no embedded map), and a
   link to the Pay screen.
4. **Card / Account.** Guest: sign-in or register. Signed in: full-screen loyalty card (brightness raised, screen
   kept awake while shown), a "Pay by mobile money" entry, edit name, sign out, delete account (confirmation).

Everywhere: pull-to-refresh, offline banner, skeleton loading, empty states, errors with retry, dark mode,
large-text and screen-reader support.

## 6. Data and sync

**Public data** (flyer, offers, categories, stores): show the cache immediately, refresh in the background (flyer
at most every 15 minutes, stores at most daily, both also on pull-to-refresh). Each flyer refresh replaces its
offers in one transaction. Cursor pages are followed to the end with a safety cap.

**Payment methods are the exception.** A stale number sends a customer's money to the wrong place, so they are
refreshed **every time the Pay screen opens** (and on pull-to-refresh) whenever the device is online; the cache is
only a fallback for offline use. The time of the last successful refresh is stored with them.

**Lists.** Lists and items have a local UUID and a nullable server id.
- Every change writes the row and appends an outbox operation in one transaction. Operations run in order, one at
  a time; operations on a list without a server id wait for its create. Repeated edits to one item are merged; a
  create followed by a delete before syncing cancels out.
- Failures: network error or 5xx stop the queue and retry with backoff when connectivity returns; 400 drops the
  operation, reverts that row from the server on the next pull and shows a message; 404 drops the operation and
  removes the local row; 401 triggers a token refresh, then sign-out if that fails.
- Conflicts: last write wins; a pull never overwrites a row with pending operations; only server timestamps are
  used for `updated_since`.
- Pull: `GET /lists?updated_since=<last pull, UTC with Z>` through all cursor pages, fetch each changed list's
  detail, replace its clean rows. Then reconcile: fetch all list ids and remove local lists the server no longer
  has, unless they have pending operations.
- Triggers: app start, resume, sign-in, connectivity regained, pull-to-refresh.
- Sign-out with unsynced changes: warn with the count and offer "sync first" or "discard".
- Known gap: no server idempotency key. If a list create times out, the app pulls first and adopts a list with
  the same name created since the operation was queued instead of creating a duplicate.

**Loyalty card.** Fetched after sign-in, stored locally, refreshed on app start when online.

## 7. Payment feature

The **Pay** screen shows one card per active payment method: provider name, number in large type, a copy button,
the admin's instructions, and the "last updated" date. If no method is active it shows an empty state telling the
customer to ask at the till. A short note explains the flow: send the money in the provider's app, then show the
confirmation message to the cashier. Provider names are plain text; logo slots exist in the theme for licensed
logos. The screen works offline from the cache.

**Stale-number safeguards.** The screen always shows when the numbers were last confirmed with the server
("Checked today 14:32"). When the device is offline, or the refresh failed, it shows a prominent warning: "These
numbers may be out of date. Confirm the number at the till before paying." A copy button copies the number only;
it never launches a payment.

**Fraud guard** (backend, section 3.2): number changes need a password re-entry and are audit-logged. The app also
shows each method's "last updated" date so customers can notice a very recent change.

## 8. Design system

Original and white-label. `core/theme/brand.dart` holds the app name, seed color, typography, logo slot and
provider logo slots. Material 3, light and dark schemes from one seed color (default: a fresh green).
Components: `OfferCard`, `PriceText` (formats `"1500.00"` as "1 500 F CFA" with no decimals, old price struck
through), category chips, store tile, list-item tile, payment-provider card, empty state, error view, offline
banner. Fonts are bundled (open licence), not downloaded at runtime. Accessibility: 48 dp touch targets, AA
contrast, layouts that survive 200% text scale.

## 9. Project setup and tooling

- `app/` Flutter project; Flutter stable pinned in the README.
- Packages: `flutter_riverpod`, `go_router`, `drift` (+ sqlite3 native libs), `dio`, `flutter_secure_storage`,
  `connectivity_plus`, `geolocator`, `url_launcher`, a brightness and wakelock pair, a barcode widget, `intl`.
- `tool/gen_api.sh` generates the Dart client from `backend/openapi.yaml`; the generated code is committed and
  CI regenerates it and fails on drift.
- Environments: dev, staging, prod through `--dart-define-from-file=env/<name>.json`. The dev file points at
  `http://10.0.2.2:8000` (Android emulator) or `http://localhost:8000` (iOS simulator). Cleartext HTTP is
  allowed in debug builds only.
- Minimum OS: Android 7.0 (API 24), iOS 14.
- The default Java here is JDK 24, which Gradle may reject; Gradle is pinned to JDK 17 or 21 when scaffolding.
- Placeholder application id `com.example.supermarket` until the client's identity is known.

## 10. Testing, CI and release

- **Unit:** the sync outbox on an in-memory Drift database (ordering, merge, cancel, each failure class,
  reconcile, no-overwrite of dirty rows, UUID-to-server-id mapping), single-flight token refresh, XOF
  formatting, error-code mapping, phone-number display.
- **Widget:** each tab in guest and signed-in states, the Pay screen with and without active methods, offline
  banners, empty and error states.
- **End to end (`integration_test`, local first):** against the real backend with `seed_demo`: sign in, add a
  list item offline, reconnect, verify it synced; open the Pay screen.
- **CI:** `flutter analyze`, format check, unit and widget tests, the generated-client drift check, an Android
  debug build.
- **Release checklist (README, not automated):** signing keys, Play Console and App Store Connect listings,
  privacy policy URL, data-safety and privacy forms, the account-deletion disclosure (the feature exists).
