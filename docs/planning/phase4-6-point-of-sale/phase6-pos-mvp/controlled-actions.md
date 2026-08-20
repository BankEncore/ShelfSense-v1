# Phase 6 Slice 6.4 — Controlled actions and pricing

**Status:** Implemented (6.4A/B–D).

**Authority:** Permission-tier controlled actions on a working sale line: price override, percentage line discount, and Tax Class override. Dual authority with Core remains [mvp-contract.md](mvp-contract.md) / [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md). Tax remains [pos-tax-contract.md](../phase4-point-of-sale/pos-tax-contract.md). Settlement remains [tender-breadth.md](tender-breadth.md) as amended here for zero-net.

Companions: [phase6-plan.md](phase6-plan.md), [register-workspace.md](../phase5-cash-register/register-workspace.md), [phase4-schema.md](../phase4-point-of-sale/phase4-schema.md), [transaction-history.md](transaction-history.md), [returns.md](returns.md).

Draft [approvals.md](../../../drafts/specifications/pos/approvals.md), [pricing.md](../../../drafts/specifications/pos/pricing.md), [discounts.md](../../../drafts/specifications/pos/discounts.md), and [tax.md](../../../drafts/specifications/pos/tax.md) are vocabulary. This document is implementation authority for the MVP subset.

### Actually locked

```text
permission-tier policy: phase6_permission_tier_v1 (no pos_action_policies)
direct | approval_required | prohibited
no persisted pending approval requests
performer is the transaction cashier
approver needs .approve at this Store, not pos.transact, not a Session
manager-as-cashier is direct (approved_by omitted)
pos_controlled_actions is currently effective state; audit_events is the activity log
reason always required; reason_code is material to the fingerprint
net merchandise is always present; tax uses net
zero-cent rounded discounts are rejected
signed net = 0 → no tenders; completion allowed
signed net < 0 is 6.5B refund settlement ([returns.md](returns.md))
F8/F9 are not controlled actions
history/receipt read Core + effective rows; envelope is provenance
Phase 5 ordinary Cash sale unchanged when unused
```

---

## 1. Objective

A cashier can modify the commercial treatment of a **working sale line** through:

```text
price override
line discount
Tax Class override
```

while ShelfSense preserves who requested, what changed, why, who approved if required, which policy authorized it, and what completed. The ordinary scan → tender → complete path stays unchanged when none of these actions is used.

---

## 2. Policy

No `pos_action_policies` table. Evaluator is code-defined `phase6_permission_tier_v1`.

For each action:

```text
performer lacks .perform at this Store     → prohibited
performer has .perform but not .approve    → approval_required
performer has .perform and .approve        → direct
```

Numeric thresholds are deferred. Store B assignments do not authorize Store A. Global assignments contribute in the active store.

**Remove** of an effective action (override / discount / Tax Class) requires `.perform` and is always `direct`. No second actor. Audit it.

**No-op apply is rejected:** requested selling == reference; requested Tax Class == applied; rounded discount cents == 0 or selling basis == 0.

---

## 3. Permissions

Add only:

```text
pos.price_override.perform
pos.price_override.approve
pos.line_discount.perform
pos.line_discount.approve
pos.tax_class_override.perform
pos.tax_class_override.approve
```

`scope_type: either`. Do **not** seed `unlinked_return` / `return_price_adjustment` / `post_void` in 6.4 (identifiers remain reserved in [mvp-contract.md](mvp-contract.md) §11). 6.5C seeds only `unlinked_return`; `return_price_adjustment` stays reserved. 6.6 seeds `post_void` ([post-void.md](post-void.md)). 6.4 completion integrity stays **sale-direction**; those three actions are prohibited on return lines ([returns.md](returns.md) §16 / §19).

| Role | Perform | Approve |
|---|---|---|
| Associate | Yes | No |
| Store manager | Yes | Yes |
| System administrator | Yes (full catalog) | Yes |

Z finalize stays on `pos.transact`.

Existing databases need `shelfsense:seed_permissions` after migrate.

---

## 4. Actors

Working apply/change/remove requires `pos.transact` **and** `require_transaction_cashier!`.

Second-actor approval:

```text
approver exists and active
approver != performer
approver is not the system actor
approver has matching .approve at this Store
credentials authenticate (has_secure_password)
transaction still working
lock_version still matches
fingerprint of the submitted request still matches
```

The approver does **not** become `current_user`, Session cashier, or transaction cashier. Do not create a manager session cookie. Discard the password after the request. Do **not** require `pos.transact` on the approver.

`direct` → `approved_by_*` omitted/NULL. Never `approved_by = performed_by`.

---

## 5. No pending approvals

```text
Cashier requests
  → evaluate policy
  → direct: execute
  → approval_required: overlay; no durable row
  → second actor authenticates
  → reload + lock; recompute exact request; validate approver
  → execute
```

Stale `expected_lock_version` or a fingerprint mismatch → reject; cashier requests again.

No `approval_requests`, queue, inbox, or manager mode.

---

## 6. `pos_controlled_actions`

Currently **effective** executed fact on a working/completed/cancelled transaction. Not the activity log.

| Column | Notes |
|---|---|
| `id` | UUIDv7 |
| `pos_transaction_id` | FK, required |
| `pos_transaction_line_id` | FK; **NOT NULL** through 6.5 (line-scoped, including unlinked return). 6.6 drops that CHECK for transaction-scoped `post_void` ([post-void.md](post-void.md)). |
| `action_type` | `price_override` \| `line_discount` \| `tax_class_override` |
| `performed_by_user_id` / `performed_by_name_snapshot` | required |
| `approved_by_user_id` / `approved_by_name_snapshot` | required iff `approval_required`; else NULL |
| `reason_code` / `reason_name_snapshot` | required |
| `reason_note` | required when `reason_code = other`; else optional/NULL |
| `policy_result` | `direct` \| `approval_required` only |
| `policy_version` | `phase6_permission_tier_v1` |
| `fingerprint_schema_version` | `v1` |
| `action_fingerprint` | SHA-256 of canonical JSON |
| `material_values` | jsonb; commercial fields used in the fingerprint |
| `executed_at` | timestamptz |
| `created_at` / `updated_at` | timestamptz |

Unique `(pos_transaction_line_id, action_type)` where `pos_transaction_line_id IS NOT NULL`.

Change replaces the row (same uniqueness). Remove deletes the effective row. Child changes increment transaction `lock_version`. No child `lock_version`.

Lifecycle:

```text
working parent     → mutable / replaceable / removable
cancelled parent   → immutable
completed parent   → immutable
```

`prohibited` is never stored.

Constraints (model + DB where practical):

```text
approved_by present  IFF  policy_result == approval_required
approved_by != performed_by
direct → approver columns NULL
```

---

## 7. Fingerprint

Reuse [Idempotency::CanonicalJson](../../../../app/services/idempotency/canonical_json.rb). Actor IDs are **not** in the hash.

```text
fingerprint(
  action type
  + subject (transaction_id, line_id)
  + commercial material values
  + reason_code
  + reason_note if reason_code == other
  + fingerprint_schema_version
)
```

### Price override material

```text
reference_unit_price_cents
requested_selling_unit_price_cents
quantity
```

### Line discount material

```text
selling_unit_price_cents
quantity
line_selling_basis_cents
discount_basis_points
```

### Tax Class override material

```text
default_tax_class_id
requested_tax_class_id
```

Quantity and price are **not** in the Tax Class fingerprint.

Changing `reason_code` (or the `other` note) after approval is a different request.

---

## 8. Completion integrity

Refuse completion unless Core and effective facts agree, **then** require stored `material_values` to equal the commercial fields reconstructed from Core, **then** recompute each fingerprint from actual Core + stored material reason and compare to `action_fingerprint`. This pairing is **sale-direction**:

```text
selling != reference  ↔  effective price_override
manual_discount_basis_points present  ↔  effective line_discount
tax_class_id != default_tax_class_id  ↔  effective tax_class_override
```

6.5 direction-aware integrity ([returns.md](returns.md) §19): linked returns have no 6.4 sale controlled-action rows; unlinked requires `unlinked_return` only. A differing unlinked return price is not a sale override or discount. `price_overridden?` / `manually_discounted?` stay sale-direction helpers. Services reject `price_override` / `line_discount` / `tax_class_override` on return lines.

Old v2 envelopes without `controlled_actions` / `override` / `discount` / default Tax Class keys remain valid. If those keys are present, they must be well-formed. A present `controlled_actions[]` entry requires subject line identity, reason, policy result and version, material values, executed time, performer name, fingerprint, and approver name when `approval_required`. Do not bump `schema_version`.

---

## 9. Reasons

Code-defined catalogs. Snapshot `reason_code` and `reason_name_snapshot`. `other` requires a short note (max 200 characters). Labels may be adjusted later; codes are stable.

**Price override:** `shelf_price_mismatch`, `damaged`, `price_match`, `customer_service`, `manager_discretion`, `other`

**Line discount:** `damaged`, `customer_service`, `manager_discretion`, `other`

**Tax Class override:** `classification_correction`, `tax_configuration_exception`, `manager_discretion`, `other`

---

## 10. Price override (6.4A/B)

No new financial price column. Apply sets `selling_unit_price_cents` to the requested unit price. Reference never changes. Recalculate extended, discount if any, tax, totals. Price `>= 0`. Upward and downward are both allowed.

Cannot change or remove a price override while a manual line discount exists. Remove the discount first.

Remove restores `selling_unit_price_cents = reference_unit_price_cents`.

---

## 11. Line discount (6.4C)

One manual percentage discount per line. No stacking, fixed amount, transaction discount, coupon, or promotion.

```text
manual_discount_basis_points     nullable   # null = no manual discount
manual_discount_cents            NOT NULL DEFAULT 0
net_merchandise_amount_cents     NOT NULL
```

```text
selling_basis = selling_unit_price_cents × quantity
discount_cents = round_half_up(selling_basis × bp / 10_000)
net = selling_basis − discount_cents
```

Range `1..10_000` bp. 100% is valid. Reject apply when `discount_cents == 0` or selling basis is 0. Net ≥ 0.

Backfill existing lines: `manual_discount_cents = 0`, `net = extended`.

Transaction `discount_cents NOT NULL DEFAULT 0`. `subtotal` remains Σ `extended_selling_amount_cents`.

```text
total = subtotal − discount + tax
line_total = net + line_tax
```

Tax basis is always `net_merchandise_amount_cents` (equals extended when undiscounted). Existing [tax_cases.json](../../../../test/fixtures/files/pos/tax_cases.json) stay pre-discount; add new golden cases.

---

## 12. Zero-net settlement (6.4C)

Amend [tender-breadth.md](tender-breadth.md):

```text
signed net > 0  → payment tenders required; exact settlement
signed net = 0  → no tenders permitted; completion allowed
signed net < 0  → unsupported until 6.5 ([returns.md](returns.md))
```

No fake `Cash $0.00`. Positive-total Phase 5/6.2 path unchanged.

---

## 13. Quantity and merge

Sale lines only ([returns.md](returns.md) §10):

```text
sale line has price override  → ChangeQuantity rejected
sale line has manual discount → ChangeQuantity rejected
```

Message: `Remove the price override or discount before changing quantity.`

Tax Class override does **not** block quantity. Linked return lines may `ChangeQuantity` (re-run historical allocation). Unlinked return quantity is fingerprint-bound and cannot be edited ([returns.md](returns.md) §10 / §17).

Compatible rescan (`AddMerchandise`) requires **all** of:

```text
no inventory unit
same variant, sale
no effective controlled-action row on that line
selling == stored reference
applied Tax Class == stored default (after 6.4D)
selling == current catalog regular
applied Tax Class == current variant Tax Class
```

Scanning after a control creates or finds an **uncontrolled** line.

F8 / `RemoveWorkingLine` deletes that line’s effective `pos_controlled_actions` in the same transaction (no approval). Apply/change/remove activity remains in `audit_events`.

---

## 14. Tax Class override (6.4D)

Keep `tax_class_id` / `tax_class_code_snapshot` as **applied**. Add:

```text
default_tax_class_id
default_tax_class_code_snapshot
default_tax_class_name_snapshot
tax_class_name_snapshot
```

**Default is the ProductVariant Tax Class at add time.** Later live variant Tax Class changes do not rewrite the working line’s default.

Backfill historically reliable applied identity onto default: `default_tax_class_id = tax_class_id` and `default_tax_class_code_snapshot = tax_class_code_snapshot`. Leave `default_tax_class_name_snapshot` and `tax_class_name_snapshot` NULL on already-completed or cancelled lines — Tax Class names are mutable and were never snapshotted. Working lines may copy the current Tax Class name because they have not completed. New completions snapshot names normally. Do **not** add these columns to `pos_transactions_status_null_rules`.

Apply: cashier selects another **active** Tax Class for which every **active** Store Tax has a resolved rule (existing `UnresolvedApplicability`). Recalculate every Store Tax determination. No cashier-entered rates, component toggles, exemption checkboxes, or synthetic nontaxable class.

Remove restores `tax_class_id = default_tax_class_id` and recalculates.

---

## 15. Calculation pipeline

```text
reference unit price
        ↓
selling unit price
        ↓
extended selling amount
        ↓
manual line discount
        ↓
net merchandise amount
        ↓
Store Tax on net using applied Tax Class
        ↓
line total = net + line tax
```

Every pricing/tax mutation clears working tenders and advances `lock_version`.

---

## 16. Envelope (additive v2)

Omit unused keys. For `direct`, omit `approved_by_*`.

Override block only when overridden:

```json
{
  "override": {
    "reference_unit_price_cents": 2000,
    "selling_unit_price_cents": 1800,
    "unit_variance_cents": -200,
    "line_variance_cents": -400
  }
}
```

Discount block only when `manual_discount_basis_points` is present:

```json
{
  "discount": {
    "source": "manual",
    "method": "percentage",
    "basis_points": 1000,
    "discount_cents": 360,
    "net_merchandise_amount_cents": 3240
  }
}
```

Tax: existing `tax_class_id` / `tax_class_code` remain applied. New completions add `default_tax_class_id`, `default_tax_class_code`, `default_tax_class_name`, `tax_class_name`.

`controlled_actions[]` mirrors the effective rows (executed facts only). History **does not** parse the envelope.

---

## 17. Audit

```text
pos.price_override.applied | changed | removed
pos.line_discount.applied | changed | removed
pos.tax_class_override.applied | changed | removed
pos.controlled_action.approved
pos.controlled_action.denied
```

Executed audit: transaction, line, performer, approver, reason, before, requested, after, policy result/version, fingerprint. Never passwords.

Second-actor success: approval event with the **approver** as audit actor, plus execution event with the **cashier** as performer. Denied attempts record independently with no business mutation.

---

## 18. Workspace

Architectural lock: each 6.4 action has a **visible, keyboard-accessible control** and applies to the **selected line**. Disabled with no selection, empty basket, or completion in flight.

Current bindings (wireframe-validatable, not domain invariants) live in [register-workspace.md](../phase5-cash-register/register-workspace.md): F5 override, F6 discount, F7 Tax Class.

Approval overlay is a **second** overlay besides cancel:

- Selling chrome `inert`; Tab trapped.
- F9 does not approve.
- Enter in the **username** field does not Approve (scanner wedge).
- Enter in a non-blank **password** field may submit.
- Selected-line chrome shows when a control is in effect.
- Quantity blocked message: `Remove the price override or discount before changing quantity.`

No fake Return / Post-void controls.

---

## 19. History and receipt

History (6.3 fact-driven): render override / discount / Tax Class sections **only when facts exist**. Snapshots only — never live User, reason catalog, Tax Class, or Product names.

Receipt: print the selling price (no “MANAGER PRICE OVERRIDE” banner). Print discount when present. Print completed tax without a Tax Class override label.

---

## 20. Session / Z

Live and new finalize:

```text
Subtotal
Discount
Tax
Total
```

Additive `finalized_discount_cents` (NULL on already-finalized pre-6.4 periods = not captured). Do not add it to `closed_at_matches_status`. New finalize writes `0` when there was no discount. `total_cents` remains customer settlement.

---

## 21. Delivery

- **PR 6.4A/B** — foundation + price override. Merge gate: ordinary scan → tender → complete when unused.
- **PR 6.4C** — discount, tax-after-discount, zero-net, Session/Z Discount.
- **PR 6.4D** — Tax Class override.

Do not land a foundation-only PR. Rollout: `db:migrate` plus `shelfsense:seed_permissions`. Rollback of 6.4 schema is supported before relying on completed controlled facts; do not delete completed facts to roll back.

---

## 22. Out of 6.4

```text
numeric approval thresholds
admin-managed policy / reason catalogs
Store policy overrides
fixed-amount / stacked / transaction discounts
promotions, coupons, member/employee discounts
customer tax exemptions, cashier-entered rates, component toggles
line_void as controlled action
transaction cancellation approval
return / post-void controls
offline approval credentials
```

---

## 23. Acceptance

1. An associate can request a price override and a manager can approve it without taking over the Session.
2. A manager cashier performs the same action as `direct`.
3. Approval binds to the exact line, commercial values, `reason_code`, and `other` note.
4. Scanner Enter in the username field cannot approve; the approver gets no session.
5. Price override preserves reference vs selling; upward, downward, and $0 are allowed.
6. A percentage line discount reduces net without rewriting selling price; rounded $0.00 effect is rejected.
7. Tax is calculated on net merchandise.
8. Tax Class override selects only a valid configured class.
9. Override + discount + Tax Class override coexist in the defined order.
10. Pricing/tax mutations clear working tenders.
11. Quantity change is blocked on override/discount lines; Tax Class override is not.
12. Discount-only lines do not merge on rescan; live catalog merge checks remain.
13. Completion refuses Core ↔ fact mismatches and fingerprint mismatches.
14. History explains performer, approver, reason, and commercial before/after from snapshots.
15. Receipt shows customer-relevant discount and final amounts.
16. Session/Z shows Discount; pre-6.4 finalized periods stay immutable.
17. Zero-value sale completes with no tender; positive-total sales still require exact payment.
18. Existing 6.1/6.2/6.3 v2 envelopes remain valid.
19. Phase 5 ordinary Cash sale remains unchanged when unused.
