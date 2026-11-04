# Platform Admin and Multi-Retailer Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let several retailers publish into one shared app only while their paid subscription is active, managed from a platform-admin web dashboard.

**Architecture:** A new `retailers` app holds `Retailer`, `Subscription`, `Payment`, `RetailerChange` and the services that change them. Every content model (`Flyer`, `Store`, `Product`, `Category`, `PaymentMethod`) gets a `retailer` FK; the staff API is scoped to the caller's retailer; `offers.services.publish_flyer` enforces the subscription. A server-rendered `platform_admin` app under `/platform/` is the admin UI.

**Tech Stack:** Django 5.2, DRF, drf-spectacular, PostgreSQL (`btree_gist`), pytest + factory_boy, Caddy. Flutter 3.24.2 / Dart 3.5.2 only for regenerating the API client.

**Spec:** `docs/superpowers/specs/2026-11-04-platform-admin-design.md`

## Global Constraints

- Backend commands run from `backend/` with `export DATABASE_URL=postgres://app:app@localhost:5434/app` and the compose `db` up (`docker compose up -d db mailpit` at the repo root). Never touch container `flariane-postgres-1` or any flariane container. Leave `agriTechCMS` alone.
- App is named `platform_admin`, never `platform` (it would shadow the stdlib module). URL prefix is `/platform/`.
- Roles: `customer`, `retailer_staff`, `platform_admin`. Existing `staff` becomes `retailer_staff`.
- Currency XOF, whole amounts (`amount` is a positive integer). Dashboard text is French.
- Error shape is `{"code","detail","fields"}`. The publish gate answers 403, code `subscription_required`.
- Cross-retailer access to an object answers 404, never 403.
- Lapsed subscription blocks new publishing only; `Retailer.status == suspended` hides content immediately.
- `openapi.yaml` must be regenerated and committed in every task that changes an API schema: `python manage.py spectacular --file openapi.yaml --validate --fail-on-warn`.
- Coverage bar 85% on `retailers` and `platform_admin` (`coverage report --include="retailers/*" --fail-under=85`).
- Do not commit `.env*`, `*.egg-info`, `.superpowers/`. Commit messages end with the attribution line from the session's system reminder.
- Work on a new branch from `docs/platform-admin-spec` (e.g. `feat/platform-admin`).

## Review Focus

- A retailer-B user posts an offer whose `flyer` or `product` id belongs to retailer A: expect 400 with no data from A leaked (Task 4).
- A retailer that is `suspended` but whose subscription has not expired: cannot publish, and its published flyers vanish from public endpoints (Tasks 5, 6).
- Recording a payment for a `pending` retailer extends the subscription but does not activate it; activation is a separate explicit action (Task 1).
- The same `(provider, reference)` recorded twice, including when the second insert loses a race at the database constraint: expect the same clean `DuplicatePayment` error, not a 500 (Task 1).
- Wrong-door access: a `platform_admin` on `/api/v1/staff/*` gets 403; a `retailer_staff` or customer on `/platform/` gets 403; anonymous gets a redirect to login; a POST without CSRF token is refused (Tasks 4, 7).

## File Structure

- `retailers/` (new app): `models.py`, `services.py`, `errors.py`, `admin.py`, `apps.py`, migrations. One responsibility: who the retailers are and what they paid.
- `platform_admin/` (new app): `views.py`, `forms.py`, `urls.py`, `mixins.py`, `templates/platform_admin/*.html`. One responsibility: the dashboard UI. No models.
- Modified: `accounts/` (role, FK), `common/permissions.py`, `catalog/`, `stores/`, `offers/`, `payments/`, `staff/` (ownership + scoping), `common/management/commands/seed_demo.py`, `config/settings/base.py`, `config/urls.py`, `deploy/Caddyfile`, `tests/factories.py`, README, NEXT_STEPS.

---

### Task 1: `retailers` app: models, services, errors

**Files:**
- Create: `backend/retailers/{__init__,apps,models,services,errors,admin}.py`, `backend/retailers/migrations/0001_initial.py` (generated)
- Modify: `backend/config/settings/base.py` (add `"retailers"` to `INSTALLED_APPS`, after `"accounts"`)
- Test: `backend/tests/retailers/test_models.py`, `backend/tests/retailers/test_services.py`

**Interfaces:**
- Produces (`retailers.models`):
  - `Retailer(name: str, slug: SlugField unique, status: Status{PENDING,ACTIVE,SUSPENDED}, created_at)`; property `can_publish -> bool` (`status == ACTIVE` and a `Subscription` exists with `ends_at > timezone.now()`); manager `Retailer.objects.expiring(days: int = 7)` and `.lapsed()` returning querysets (active-status retailers whose `ends_at` is within `days` / in the past).
  - `Subscription(retailer: OneToOne, starts_at, ends_at)`.
  - `Payment(retailer, amount: PositiveIntegerField, provider: str, reference: str, source: Source{MANUAL,WEBHOOK}, confirmed_by: FK User null SET_NULL, confirmed_at, period_months: PositiveSmallIntegerField)`; `UniqueConstraint(provider, reference)`; `save()` raises `RuntimeError` when `pk` is set (append-only, same guard as `PaymentMethodChange`).
  - `RetailerChange(retailer, action: Action{ACTIVATED,SUSPENDED,PAYMENT}, changed_by FK null, changed_by_email, changed_at, detail: CharField(255))`; append-only.
- Produces (`retailers.services`):
  - `record_payment(*, retailer: Retailer, amount: int, provider: str, reference: str, period_months: int, confirmed_by: AbstractBaseUser | None, source: str = Payment.Source.MANUAL) -> Payment`
  - `set_status(retailer: Retailer, status: str, *, by: AbstractBaseUser | None) -> Retailer` (only `ACTIVE` or `SUSPENDED` accepted)
- Produces (`retailers.errors`): `class DuplicatePayment(Exception)`, `class SubscriptionRequired(Exception)`.

- [ ] **Step 1: Write failing tests in `test_models.py`** (add a temporary local `make_retailer` helper; factories come in Task 2): `test_can_publish_false_without_subscription`, `test_can_publish_true_when_active_and_unexpired`, `test_can_publish_false_when_lapsed`, `test_can_publish_false_when_suspended_even_if_unexpired`, `test_can_publish_false_when_pending`, `test_payment_is_append_only` (second `save()` raises `RuntimeError`), `test_expiring_and_lapsed_querysets`.
- [ ] **Step 2: Write failing tests in `test_services.py`**: `test_record_payment_creates_subscription_from_now`, `test_record_payment_extends_from_current_end_when_active` (`ends_at` = old end + months), `test_record_payment_restarts_from_now_when_lapsed`, `test_record_payment_does_not_activate_pending_retailer`, `test_record_payment_writes_one_audit_row`, `test_duplicate_provider_reference_raises_duplicate_payment_and_changes_nothing` (subscription `ends_at` unchanged), `test_duplicate_detected_at_db_constraint` (bypass the pre-check by patching it, expect `DuplicatePayment`), `test_set_status_audits_and_rejects_pending`.
- [ ] **Step 3: Run** `pytest tests/retailers -v`. Expected: FAIL (module missing).
- [ ] **Step 4: Implement models** exactly as in Interfaces, then `python manage.py makemigrations retailers`. Months are calendar months (write a small `_add_months(dt, n)` helper clamping the day; no new dependency).
- [ ] **Step 5: Implement `record_payment`**: one `transaction.atomic()`; pre-check `(provider, reference)` exists → `DuplicatePayment`; create `Payment` catching `IntegrityError` → `DuplicatePayment`; `Subscription` via `select_for_update` get-or-create; new `ends_at = _add_months(max(now, current ends_at), months)`; set `starts_at` to `now` only when creating or restarting after a lapse; write the `RetailerChange(action=PAYMENT)` row. Implement `set_status` with its audit row. Register all four models read-only-ish in `admin.py` (Payment and RetailerChange without add/change/delete permission).
- [ ] **Step 6: Run** `pytest tests/retailers -v`. Expected: PASS.
- [ ] **Step 7: Commit** `feat(retailers): retailer, subscription, payment models and services`.

---

### Task 2: Roles, `User.retailer`, permissions, factories

**Files:**
- Modify: `backend/accounts/models.py` (Role, `retailer` FK, check constraint, `create_superuser`), `backend/accounts/admin.py` (add `retailer` to fieldsets/add_fieldsets/list_display), `backend/common/permissions.py`, `backend/staff/views.py` and `backend/uploads/views.py` (permission import), `backend/common/management/commands/seed_demo.py` (`_users`), `backend/tests/factories.py`, `backend/tests/common/test_permissions.py`, `backend/tests/staff/test_permissions.py`, `backend/tests/accounts/*`, `backend/openapi.yaml`
- Create: `backend/accounts/migrations/0003_*.py` (generated + hand edits), `backend/tests/accounts/test_roles.py`
- Test: as listed

**Interfaces:**
- Consumes: `retailers.models.Retailer` (Task 1).
- Produces:
  - `User.Role{CUSTOMER="customer", RETAILER_STAFF="retailer_staff", PLATFORM_ADMIN="platform_admin"}`; `User.retailer: FK(Retailer, null=True, blank=True, on_delete=PROTECT, related_name="users")`; `CheckConstraint user_retailer_matches_role`: `role == retailer_staff` iff `retailer` is not null.
  - `create_superuser` defaults `role=PLATFORM_ADMIN`.
  - `common.permissions.IsRetailerStaff` (replaces `IsStaff`) and `IsPlatformAdmin`, both: authenticated and exact role match.
  - `tests.factories`: `RetailerFactory` (status active, with a `Subscription` ending 30 days ahead via post-generation), `default_retailer() -> Retailer` (get-or-create slug `"test-retailer"`, active, subscription +365 days), `StaffFactory` (role `retailer_staff`, `retailer=LazyFunction(default_retailer)`), `PlatformAdminFactory` (role `platform_admin`, no retailer). `UserFactory._create` passes `retailer` through.
  - `/auth` and `/me` serializers expose the new role values (no field added).

- [ ] **Step 1: Write failing tests** in `test_roles.py`: `test_superuser_is_platform_admin`, `test_deleting_retailer_with_users_is_protected`. (The constraint tests `test_retailer_staff_requires_retailer` and `test_customer_cannot_have_retailer` belong to Task 3, which adds the constraint.) In `test_permissions.py`: `test_is_retailer_staff_rejects_platform_admin_and_customer`, `test_is_platform_admin_accepts_only_platform_admin`.
- [ ] **Step 2: Run** `pytest tests/accounts/test_roles.py tests/common/test_permissions.py -v`. Expected: FAIL.
- [ ] **Step 3: Implement** model changes and permissions. Rename `IsStaff` → `IsRetailerStaff` everywhere (`grep -rn IsStaff backend`). Update `tests/factories.py` as in Interfaces.
- [ ] **Step 4: Migration `accounts/0003`**: operations in order: add nullable `retailer` FK; `RunPython` mapping `role="staff"` → `"retailer_staff"` (reverse maps back) with `retailer` left null for now; alter `role` choices. Do **not** add the check constraint yet (Task 3's data migration assigns the retailer first; the constraint is added in `accounts/0004`, see Task 3 Step 7).
- [ ] **Step 5: seed_demo**: create demo `Retailer` (slug `demo`, active, subscription via `record_payment` source manual 12 months, idempotent) and make `staff@example.com` a `retailer_staff` of it; add `platform@example.com` (`platform_admin`, password from `DEMO_PLATFORM_PASSWORD`, dev default documented in README like the others).
- [ ] **Step 6: Regenerate** `openapi.yaml`; run the full suite `pytest`. Expected: PASS (existing tests keep working because `StaffFactory` defaults to the shared `default_retailer`).
- [ ] **Step 7: Commit** `feat(accounts): retailer_staff and platform_admin roles`.

---

### Task 3: Retailer ownership of content, per-retailer constraints, backfill

**Files:**
- Modify: models of `catalog` (`Category`, `Product`), `stores` (`Store`), `offers` (`Flyer`), `payments` (`PaymentMethod`); `tests/factories.py` (resource factories get `retailer = LazyFunction(default_retailer)`); `common/management/commands/seed_demo.py` (attach every created row to the demo retailer; payment methods created with that retailer); `payments/services.py` (`create_method(*, user, retailer, **fields)`); `backend/openapi.yaml`
- Create: migrations per app (nullable add), `backend/retailers/migrations/0002_backfill_default_retailer.py`, per-app finalize migrations, `backend/accounts/migrations/0004_user_retailer_role_constraint.py`, `backend/tests/retailers/test_backfill_migration.py`, `backend/tests/offers/test_flyer_overlap_per_retailer.py`
- Test: those two plus the existing suite

**Interfaces:**
- Consumes: `Retailer`, `default_retailer()`.
- Produces: non-null `retailer` FK (`on_delete=PROTECT`) on `Category`, `Product`, `Store`, `Flyer`, `PaymentMethod`. Constraints: `category_retailer_slug_unique (retailer, slug)`, `product_retailer_ean_unique (retailer, ean)`, `paymentmethod_retailer_provider_unique (retailer, provider)`; `flyer_published_no_overlap` now `ExclusionConstraint` with expressions `[("retailer", "="), (daterange(valid_from, valid_to, '[]'), "&&")]`, condition `status='published'`, and the migration enables `BtreeGistExtension()` first. Remove the old global `unique=True` on `Category.slug`, `Product.ean`, `PaymentMethod.provider`.

- [ ] **Step 1: Write failing tests**: `test_flyer_overlap_per_retailer.py`: `test_same_retailer_overlapping_published_flyers_rejected` (`IntegrityError`), `test_different_retailers_may_overlap`. Constraint tests in each app's model tests: `test_two_retailers_can_share_category_slug`, `test_two_retailers_can_share_product_ean`, `test_two_retailers_can_share_payment_provider`, and the negative same-retailer cases.
  Also in `tests/accounts/test_roles.py`: `test_retailer_staff_requires_retailer` (`IntegrityError` from `user_retailer_matches_role`) and `test_customer_cannot_have_retailer`.
- [ ] **Step 2: Write the backfill test** (`@pytest.mark.django_db(transaction=True)`, use `django.db.migrations.executor.MigrationExecutor`): migrate to the state before the backfill, create rows with the historical models (a staff-role user, a category, product, store, flyer, payment method), migrate forward, assert: exactly one `Retailer` slug `default`, status active, a `Subscription` ending about 365 days after the migration, every row's `retailer` is it, the user's role is `retailer_staff` with that retailer. Add `test_backfill_creates_nothing_on_empty_database`.
- [ ] **Step 3: Run** the new tests. Expected: FAIL.
- [ ] **Step 4: Change the models** as in Interfaces, then generate migrations so that each app first **adds the FK as nullable** (`null=True`) in one migration.
- [ ] **Step 5: Hand-write `retailers/0002_backfill_default_retailer`** (depends on all the nullable-add migrations and `accounts/0003`): if any `staff`/`retailer_staff` user, category, product, store, flyer or payment method exists, create `Retailer(name="Default retailer", slug="default", status="active")` plus `Subscription` ending 365 days from now, set `retailer` on every existing row, and attach `retailer_staff` users to it; otherwise do nothing. Reverse is a no-op.
- [ ] **Step 6: Finalize migrations** (one per content app): make `retailer` non-null, drop the old unique flags, add the new constraints; for `offers` also `BtreeGistExtension` then replace the exclusion constraint.
- [ ] **Step 7: `accounts/0004`**: add `user_retailer_matches_role`.
- [ ] **Step 8: Update factories and seed_demo**, then run the whole suite: `pytest`. Expected: PASS. Regenerate `openapi.yaml` only if the schema changed (it should not).
- [ ] **Step 9: Commit** `feat: retailer ownership of flyers, stores, products, categories and payment methods`.

---

### Task 4: Staff API scoped to the caller's retailer

**Files:**
- Modify: `backend/staff/views.py`, `backend/staff/serializers.py`, `backend/payments/views.py`, `backend/payments/serializers.py`, `backend/payments/services.py` (callers pass `retailer`), `backend/tests/staff/conftest.py` if fixtures need a second retailer, `backend/openapi.yaml`
- Create: `backend/tests/staff/test_tenant_isolation.py`

**Interfaces:**
- Consumes: `IsRetailerStaff`, factories with explicit `retailer=` override.
- Produces: `StaffViewSet.scope(qs: QuerySet) -> QuerySet` filtering by `request.user.retailer` using the class attribute `retailer_lookup: str = "retailer"` (`OfferViewSet` sets `"flyer__retailer"`); `perform_create` passes `retailer=request.user.retailer` to `serializer.save`; staff serializers receive `request` in context and restrict related-field querysets (`flyer`, `product`, `category`) to the caller's retailer; `OfferSerializer.validate` rejects a product whose retailer differs from the flyer's.

- [ ] **Step 1: Write failing tests** (parametrized over the six resources): `test_list_excludes_other_retailers_rows`, `test_retrieve_patch_delete_other_retailers_row_returns_404`, `test_created_rows_get_callers_retailer`, `test_offer_with_foreign_flyer_is_400`, `test_offer_with_foreign_product_is_400`, `test_product_with_foreign_category_is_400`, `test_publish_foreign_flyer_is_404`, `test_platform_admin_gets_403_on_staff_routes`, `test_payment_method_provider_unique_per_retailer_only`. Foreign rows are built with `retailer=RetailerFactory()`.
- [ ] **Step 2: Run** `pytest tests/staff/test_tenant_isolation.py -v`. Expected: FAIL.
- [ ] **Step 3: Implement** scoping. Every `get_queryset` in `staff/views.py` and `PaymentMethodStaffViewSet` routes through `self.scope(...)`. `_guard_last_offer` target-flyer lookup uses the scoped queryset so moves cannot cross retailers.
- [ ] **Step 4: Regenerate** `openapi.yaml`; run `pytest`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(staff): scope the staff API to the caller's retailer`.

---

### Task 5: Publish gate

**Files:**
- Modify: `backend/offers/services.py`, `backend/staff/views.py` (`_transition`), `backend/offers/admin.py` (`publish_selected`), `backend/openapi.yaml`
- Test: `backend/tests/offers/test_publish_gate.py`, `backend/tests/staff/test_flyers_api.py` (add cases)

**Interfaces:**
- Consumes: `Retailer.can_publish`, `retailers.errors.SubscriptionRequired`.
- Produces: `publish_flyer(flyer)` raises `SubscriptionRequired` before any other check when `not flyer.retailer.can_publish`. `unpublish_flyer` is never gated. The staff `publish` action answers 403 `{"code": "subscription_required"}`; the admin action reports it with `messages.ERROR`.

- [ ] **Step 1: Write failing tests**: `test_publish_allowed_when_active_and_subscribed`, `test_publish_blocked_when_no_subscription`, `test_publish_blocked_when_lapsed`, `test_publish_blocked_when_suspended`, `test_publish_blocked_when_pending`, `test_unpublish_still_allowed_when_lapsed`, `test_already_published_flyer_stays_published_after_lapse`, `test_staff_api_publish_returns_403_subscription_required` (assert full `{"code","detail","fields"}` shape), `test_admin_publish_action_reports_error`.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement** the gate in `publish_flyer`; translate in `_transition` (`SubscriptionRequired` → `rest_framework.exceptions.PermissionDenied` with `default_code="subscription_required"`, detail via `common.messages.msg`, add the French and English texts to `common/messages.py`); update the admin action.
- [ ] **Step 4: Regenerate** `openapi.yaml` (403 response documented on `publish`); run `pytest`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(offers): require an active subscription to publish a flyer`.

---

### Task 6: Customer endpoints show active retailers only

**Files:**
- Modify: `backend/offers/views.py` (`published_flyers`, `OfferListView`), `backend/stores/views.py` (list and detail querysets), `backend/catalog/views.py`, `backend/payments/views.py` (`PaymentMethodListView`)
- Test: `backend/tests/common/test_active_retailers_only.py`

**Interfaces:**
- Consumes: `Retailer.Status.ACTIVE`.
- Produces: every public queryset adds `.filter(retailer__status=Retailer.Status.ACTIVE)` (for offers: `flyer__retailer__status`). A lapsed-but-active retailer is unaffected.

- [ ] **Step 1: Write failing tests** across flyers (list, detail, current), offers, stores (list, detail), categories, payment methods: `test_suspended_retailer_content_is_hidden`, `test_pending_retailer_content_is_hidden`, `test_lapsed_but_active_retailer_content_stays_visible`, `test_two_active_retailers_both_appear`.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement** the filters.
- [ ] **Step 4: Run** `pytest`. Expected: PASS (existing public tests pass because factories use an active default retailer).
- [ ] **Step 5: Commit** `feat: hide content of non-active retailers from public endpoints`.

---

### Task 7: Platform dashboard

**Files:**
- Create: `backend/platform_admin/{__init__,apps,urls,views,forms,mixins}.py`, `backend/platform_admin/templates/platform_admin/{base,login,retailer_list,retailer_detail,retailer_form,payment_form}.html`, `backend/tests/platform_admin/test_access.py`, `test_views.py`
- Modify: `backend/config/settings/base.py` (`"platform_admin"` in `INSTALLED_APPS`), `backend/config/urls.py` (`path("platform/", include("platform_admin.urls"))`)

**Interfaces:**
- Consumes: `IsPlatformAdmin` semantics, `retailers.services.record_payment`/`set_status`, `DuplicatePayment`, `Retailer.objects.expiring/lapsed`.
- Produces: URL names (namespace `platform`): `login`, `logout`, `retailer_list` (`/platform/`, `?filter=active|pending|expiring|lapsed`), `retailer_create` (`/platform/retailers/new/`), `retailer_detail` (`/platform/retailers/<int:pk>/`), `payment_create` (`/platform/retailers/<int:pk>/payments/new/`), `retailer_activate`, `retailer_suspend` (POST only). `PlatformAdminRequiredMixin`: anonymous → redirect to `platform:login`; authenticated non-admin → 403 via `PermissionDenied`. Forms: `RetailerCreateForm(name, staff_email, staff_password)` creating the retailer (status `pending`) and its first `retailer_staff` user in one transaction (password validated by Django validators; the admin shares it out of band); `PaymentForm(amount, provider, reference, period_months)` where `provider` choices are `PaymentMethod.Provider`, mapping `DuplicatePayment` to a field error on `reference`.

- [ ] **Step 1: Write failing tests** in `test_access.py`: `test_anonymous_redirected_to_login`, `test_customer_and_retailer_staff_get_403`, `test_platform_admin_gets_200`, `test_post_without_csrf_token_is_refused` (client with `enforce_csrf_checks=True`), `test_jwt_bearer_token_does_not_authenticate_dashboard`. In `test_views.py`: `test_list_filters_expiring_and_lapsed`, `test_create_retailer_creates_pending_retailer_and_staff_user`, `test_create_retailer_rejects_existing_email`, `test_record_payment_extends_subscription_and_shows_in_history`, `test_record_payment_duplicate_reference_shows_error`, `test_record_payment_pending_retailer_stays_pending`, `test_activate_and_suspend_write_audit_rows`, `test_suspended_retailer_flyers_vanish_from_public_api` (end to end).
- [ ] **Step 2: Run** `pytest tests/platform_admin -v`. Expected: FAIL.
- [ ] **Step 3: Implement** views, forms, mixin and templates (plain HTML with one small inline `<style>` block; French labels; every POST form includes `{% csrf_token %}`; the login view is Django's `LoginView` limited to users with role `platform_admin`).
- [ ] **Step 4: Run** `pytest tests/platform_admin -v` and `coverage report --include="retailers/*,platform_admin/*" --fail-under=85`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(platform-admin): dashboard to manage retailers, payments and publishing rights`.

---

### Task 8: Edge allowlist, contract, client, docs

**Files:**
- Modify: `deploy/Caddyfile` (matcher `path /admin/* /platform/*`), `backend/openapi.yaml`, `app/packages/api_client/**` (generated), `README.md` (Staff users, Securing /admin, Demo data, Language sections), `NEXT_STEPS.md`, `docs/follow-ups.md`
- Test: `backend/tests/test_prod_settings.py` (add a Caddyfile assertion if the file already tests it; otherwise `grep` check below)

- [ ] **Step 1: Update the Caddyfile matcher** and README: rename "Staff users" to describe the three roles, `createsuperuser` → `platform_admin`, how to create the first retailer in the dashboard, `DEMO_PLATFORM_PASSWORD`, `/platform/` under the same `ADMIN_ALLOWED_IPS` rule.
- [ ] **Step 2: Verify** `grep -n "platform" deploy/Caddyfile` shows the new path in the `@admin_blocked` matcher, and `docker run --rm -v "$PWD/deploy:/etc/caddy" caddy:2 caddy validate --config /etc/caddy/Caddyfile` prints `Valid configuration` (set `DOMAIN`/`ACME_EMAIL`/`ADMIN_ALLOWED_IPS` env if the file requires them).
- [ ] **Step 3: Regenerate** `openapi.yaml`, then run `app/tool/gen_api.sh` (needs Docker and Flutter 3.24.2), then `app/tool/check_api_drift.sh`. Expected: no difference.
- [ ] **Step 4: Run** `cd app && dart format --set-exit-if-changed . && flutter analyze && flutter test`. Expected: pass. If a test fixture still uses the role string `staff`, update it to `retailer_staff`.
- [ ] **Step 5: Run** the whole backend suite with coverage: `pytest --cov` then the three existing `coverage report --fail-under=85` checks plus the new one. Expected: PASS.
- [ ] **Step 6: Update `NEXT_STEPS.md`** (sub-projects 2 and 3 pending) and `docs/follow-ups.md` (webhook payment source; per-retailer branding; retailer self-service sign-up; lapse notifications).
- [ ] **Step 7: Commit** `chore: protect /platform with the admin allowlist, regenerate API contract and client, docs`.
