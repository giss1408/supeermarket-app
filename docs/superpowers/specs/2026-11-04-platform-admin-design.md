# Platform admin and multi-retailer publishing: design

Date: 2026-11-04. Status: draft, awaiting review.

## Goal

The platform owner runs one shared customer app. Several retailers each pay the platform to publish
flyers, offers and stores into it. A web dashboard lets the platform admin record those payments and
decide which retailers may publish.

Decisions taken during brainstorming:

- Business model: many retailers, one shared app (not a single retailer, not white-label).
- Payment confirmation: manual in v1 (admin records a mobile-money payment). The payment record is
  built so a provider webhook can replace the admin click later.
- Entitlement: a time-based subscription. While active, a retailer can publish any number of flyers.
- Admin UI: a server-rendered Django dashboard in the existing backend (no SPA, no new JS toolchain).

## Scope

This spec covers sub-project 1 only. The other two get their own spec, plan and build.

1. **Multi-retailer backend plus platform dashboard** (this spec).
2. Customer app multi-retailer browsing (Offers and Stores tabs assume one retailer today).
3. Retailer publishing UI (the "staff mode" listed in `NEXT_STEPS.md`). Until it exists, retailer
   staff publish through the staff API or Django admin.

Out of scope: any Flutter screen change, automated payment-provider integration, tiered plans,
per-flyer credits, retailer self-service sign-up.

The shipped mobile app must keep working: existing customer endpoints keep their shape and return
published content of active retailers.

## Data model

- `Retailer`: `name`, `slug`, `status` (`pending`, `active`, `suspended`), `created_at`.
- `User.role` becomes `customer`, `retailer_staff`, `platform_admin`. Existing `staff` rows migrate to
  `retailer_staff`.
- `User.retailer`: nullable FK. Required for `retailer_staff`; null for customers and platform admins
  (enforced by a check constraint).
- Retailer ownership (non-null FK `retailer`) on `Flyer`, `Store`, `Product`, `Category` and
  `PaymentMethod`. `Offer` is owned through its flyer. Products and categories are per retailer
  because SKUs and prices differ. `PaymentMethod.provider` is unique per retailer instead of global.
- `Payment`: `retailer`, `amount` (whole XOF), `provider`, `reference`, `source` (`manual` or
  `webhook`), `confirmed_by`, `confirmed_at`, `period_months`. Append-only (same guard as
  `PaymentMethodChange`). Unique `(provider, reference)` so one mobile-money transaction cannot be
  recorded twice.
- `Subscription`: `retailer`, `starts_at`, `ends_at`. Recording a payment extends `ends_at`: from the
  current end if still active, otherwise from now.
- `Retailer.can_publish` is derived, never stored: `status == active` and `now < subscription.ends_at`.
- `RetailerChange`: append-only audit log of activate, suspend and payment recording (who, what,
  when), modelled on `PaymentMethodChange`.
- `flyer_published_no_overlap` gains `retailer` as an equality expression (`btree_gist`), so overlap is
  checked per retailer.
- Migration: create one default `Retailer`, backfill every existing row to it, migrate `staff` to
  `retailer_staff` attached to it. Forward-only, like the repo's other migrations; take a database
  backup first.

## Permissions

- `/api/v1/staff/*` stays but is scoped to the caller's retailer. A queryset mixin filters every
  viewset by `request.user.retailer` and sets it on create. Access to another retailer's object
  returns 404, not 403, so ids do not leak.
- `platform_admin` has no retailer and no access to the staff API; it only reaches the dashboard.
- Customer endpoints return content from active retailers only, so a suspended retailer's flyers
  disappear from the shipped app.

## Publish gate

- Moving a flyer to `published` goes through one service function, `offers.services.publish_flyer`.
  It requires `retailer.can_publish`; otherwise the API answers 403 with the standard error shape and
  code `subscription_required`.
- The staff API and Django admin both call this function, so the rule lives in one place.
- A lapsed subscription blocks new publishing only. Flyers already published stay visible until
  their `valid_to`. Suspending a retailer hides its content immediately, as an explicit admin action.

## Dashboard

A new `platform` Django app, server-rendered, French, under `/platform/`.

| Page | Purpose |
| --- | --- |
| Retailers list | Name, status, subscription end date; filters: active, expiring in 7 days, lapsed, pending |
| Retailer detail | Subscription, payment history, staff users, activate or suspend |
| Record payment | Retailer, amount, provider, reference, months; rejects a duplicate reference |
| Create retailer | Name plus first staff user |

- Access: login required with `role == platform_admin`. Django session auth with CSRF, separate from
  the mobile JWT flow. `/platform/` is added to the same Caddy IP allowlist as `/admin/`
  (`ADMIN_ALLOWED_IPS`).
- Recording a payment runs in one transaction: payment row, subscription extension and audit entry
  commit together or not at all.

## Contract and client

`backend/openapi.yaml` is regenerated because the staff and customer schemas change. The Dart client
drift check fails until `app/tool/gen_api.sh` is re-run; regenerating the client is part of the plan.
No Flutter screen changes.

## Testing

Pytest, same style as the repo, keeping the 85% line-coverage bar on the new `platform` app.

- Tenant isolation: a retailer A user cannot read, edit or publish with retailer B ids.
- Publish gate in four states: active, lapsed, suspended, pending.
- Subscription extension when active versus lapsed.
- Duplicate `(provider, reference)` rejection.
- Per-retailer flyer overlap constraint.
- Migration backfill of existing rows and the `staff` to `retailer_staff` role change.
- Dashboard access: non-admins and anonymous users are refused.
