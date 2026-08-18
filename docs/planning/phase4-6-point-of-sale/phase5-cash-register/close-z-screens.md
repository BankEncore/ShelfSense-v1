# Phase 5 Slice 3 — Receipt print + blind close / Z

**Status:** Implemented. HTTP/domain contract for Slice 3 print, blind close, and Z screens.

**Authority:** Cashier-facing print, blind Session close, and immutable Z screens. Domain close and finalize remain in Slice 1 (`Pos::CloseSession`, `Pos::FinalizeReportingPeriod`, `Pos::SessionTotals`, `Pos::PeriodTotals`). Selling workspace and on-screen completion remain in [register-workspace.md](register-workspace.md). Receipt identity remains in [receipt-identity.md](../phase4-point-of-sale/receipt-identity.md).

Companions: [phase5-plan.md](phase5-plan.md), [close-z-screens-ux.md](close-z-screens-ux.md).

**Governing principle:** presentation and workflow only. Transaction completion is already authoritative, Session close already owns Cash accountability, and Reporting Period finalization already owns Z snapshots. Slice 3 exposes those boundaries without duplicating their business logic.

No new cash-accountability model, permission, printer abstraction, Z number, or drawer is introduced.

---

## 1. Objective

> Can a cashier complete a Cash sale, optionally print its receipt, close the Register with a genuinely blind Cash count, review the frozen Session close result, and finalize an immutable Z?

```text
completed sale
    ↓
receipt confirmation
    ├── Print receipt
    ├── New sale
    └── Close register
             ↓
       blind cash count
             ↓
       close Session
             ↓
       reveal expected / count / variance
             ↓
       Finalize Z
             ↓
       immutable Z
```

Invariants:

* Cash count is entered before expected Cash or variance is exposed.
* `CloseSession` remains authoritative for expected Cash and variance.
* Session close and Reporting Period finalization remain separate actions.
* Closed Session Cash figures are persisted snapshots.
* Finalized Z figures are persisted snapshots.
* Receipt printing happens only after commercial completion and cannot affect completion.
* No GET may cancel a transaction, close a Session, or finalize a Reporting Period.

---

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Printing | Browser print is the only supported Phase 5 path |
| Print trigger | Explicit **Print receipt** action; never automatic on receipt GET |
| Print authority | Completed immutable transaction facts and receipt snapshots |
| Print lifecycle | No `printed_at`, print status, print job, printer record, or acknowledgement |
| Print failure | Cannot undo or alter a completed transaction |
| Receipt identity | Printed header uses `store_number_snapshot`, `register_number_snapshot`, and `receipt_sequence` |
| Close initiation | Separate POST before blind count; `session_id` is the Session represented by the page |
| Working transaction cleanup | Empty working transaction may be explicitly cancelled during close initiation |
| Nonempty sale | Must be completed or cancelled before close begins |
| GET behavior | No GET may cancel a transaction, close a Session, or finalize a Reporting Period |
| Blind close | Count screen contains no expected Cash, variance, opening float, Cash sales, or equivalent derivable values |
| Closing count | Nonnegative integer cents; `$0.00` is valid |
| Session close | Existing `Pos::CloseSession`; count in, expected/variance server-derived |
| Close snapshots | `closing_expected_cash_cents`, `closing_count_cents`, `closing_variance_cents` are authoritative after close |
| Close vs Z | Closing a Session does not automatically finalize the Reporting Period |
| Z finalization | Explicit POST through `Pos::FinalizeReportingPeriod` |
| Z snapshots | Render persisted `finalized_*` fields after finalization |
| Period with no Session | If an open period has no open Session, the enter gate offers **Finalize Z** or **Open session** |
| Unused period Z | A period with zero Sessions may be finalized as an all-zero Z (Slice 1 empty-Z rule) |
| Leave period open | Returns to the enter gate for that Register |
| Authorization | Close flow: Session cashier + `pos.transact`; Z: `pos.transact` at current Store |
| Permissions | No new permission key |
| Period lock on enter Finalize Z | Hidden `expected_lock_version` is the period's `lock_version` |
| Stale period while still open | Re-render the page they posted from; do not finalize; do not show `finalized_*` |
| Open session vs Finalize Z | HTTP loser is a re-rendered enter/error, not a 500 |
| Display timezone | Printed completion time and Z finalized-at use the Store IANA zone (ADR-007) |
| Z header numbers | Period's Store/Register identity (`store_number` / `register_number`), not editable names |
| Z number | Deferred |
| Drawer model | Deferred |
| Denomination counting | Deferred |
| Direct printer integration | Deferred |

---

## 3. Routes

```text
POST /pos/register/close
GET  /pos/sessions/:id/close
POST /pos/sessions/:id/close
POST /pos/sessions/:id/resume_sales
GET  /pos/sessions/:id/closed
POST /pos/reporting_periods/:id/finalize
GET  /pos/reporting_periods/:id/z
```

Every ID is resolved against `current_store`, following the Slice 2 completed-receipt pattern.

---

## 4. Receipt printing

The Slice 2 completed receipt gains three ordinary actions:

```text
[ Print receipt ]   [ New sale ]   [ Close register ]
```

Reached only by explicit completed transaction identity:

```text
GET /pos/transactions/:id/completed
```

No printing occurs automatically when this page loads. Document Enter remains a no-op. Scanner input must not print, start a new sale, or close the Register.

**Print receipt** invokes `window.print()` from a small Stimulus action. The browser's native print dialog is the entire Phase 5 print transport.

Do not add `printer_id`, `printed_at`, `print_status`, print jobs, or ESC/POS integration.

### Printed identity and contents

Printed header follows [receipt-identity.md](../phase4-point-of-sale/receipt-identity.md):

```text
Store: 003   Reg: 02   Trans: 0018427
```

Values come from the completed transaction snapshots, not current Store/Register configuration. The compact reference may also appear.

Render from completed facts: Store / Reg / Trans, transaction reference, business date, completed timestamp (Store IANA zone), line snapshots, subtotal, tax, total, Cash presented, change. Printed line descriptions use the completed merchandise snapshot only. If that snapshot is missing, render `Description unavailable` — do not substitute current Product metadata.

The ordinary on-screen completion screen does not have to adopt the printed header format.

`@media print` hides POS chrome and the three actions, uses a narrow monochrome receipt format, and avoids reliance on background colors.

---

## 5. Close-register entry and initiation

Close Register is available from:

1. The completed receipt (no working transaction).
2. Empty `SALE_ENTRY` only: working status, zero lines, no working tender, UI mode `SALE_ENTRY`.

Do not expose it in `QUANTITY`, `TENDER`, completion-pending, completion-failed, or a merchandised basket. Scanner Enter must never activate Close Register.

```text
POST /pos/register/close
  session_id = <Session represented by this page>
```

The POST is bound to that Session. Do not resolve “whatever open Session this cashier currently has on the Register.” A stale receipt or workspace for Session A must not cancel or close Session B.

Load:

```text
id + current_store + selected Register + Session cashier
```

| Condition | Result |
|---|---|
| Missing / wrong Store / wrong cashier / wrong Register | Not found |
| Named Session is closed | Redirect that Session's closed summary; never fall forward to a newer Session |
| Working transaction with merchandise or tender | Reject, return workspace, "Complete or cancel the current sale before closing." |
| Empty working transaction | `CancelTransaction`, then redirect blind-count GET |
| No working transaction | Redirect blind-count GET |

The empty working ticket is disposed of **before** `CloseSession`. Do not weaken `CloseSession`; it continues to reject any working transaction.

Repeat initiate after empty-ticket cancellation is workflow-idempotent: no working transaction remains, so the POST redirects to the same blind-count GET.

---

## 6. Blind count

```text
GET /pos/sessions/:id/close
```

is read-only. Require current Store, `pos.transact`, and Session cashier.

| Lifecycle | Result |
|---|---|
| Session open + no working transaction | Render blind count |
| Session open + working transaction | Redirect workspace; do not cancel |
| Session already closed | Redirect closed Session summary |
| Wrong Store / wrong cashier / unauthorized | Not found / deny |

GET must never dispose of a working transaction.

The page may display Store, Register, business date, cashier, the count field, **Close session**, and **Return to sales**.

Before the count is submitted, the response must **not contain** expected Cash, variance, opening float, Cash sales, tender totals, transaction totals, or period totals — including visible text, hidden inputs, `data-*` attributes, JavaScript variables, and Turbo metadata.

Closing count: `inputmode="decimal"`, autofocus, parse through `Money::ParseCents`, submit integer cents. `$0.00` is valid; blank, negative, and malformed decimals are invalid. Enter submits the count. Hidden `expected_lock_version` is the **Session** `lock_version`. Do not send expected Cash or variance.

```text
POST /pos/sessions/:id/close
```

parses the count and calls `Pos::CloseSession`. No Cash calculation belongs in the controller.

Every blind-count error recovery reloads the Session first:

| Authoritative state | Result |
|---|---|
| Session already closed | Redirect closed summary; do not call `CloseSession` again |
| Working transaction exists | Redirect workspace, "Complete or cancel the current sale before closing." |
| Still open, no working transaction, invalid count | Re-render blind count; preserve entered value; reveal no expected/variance |
| Still open, no working transaction, stale `lock_version` | Re-render blind count; preserve typed count; stay blind |

```text
POST /pos/sessions/:id/resume_sales
```

invokes `Pos::ResumeOrStartTransaction` and redirects to `GET /pos/register`. No `closing` Session status is needed.

---

## 7. Closed Session summary

```text
GET /pos/sessions/:id/closed
```

Session must be closed. Authorization remains current Store, `pos.transact`, and Session cashier.

Only now expose opening float, Cash payments, expected closing Cash, counted Cash, and variance. Cash-close fields are read from persisted `closing_*` columns. Do not recompute expected Cash after close.

Commercial totals may be exposed through `Pos::SessionTotals` (optional `total_cents` helper). Do not calculate business totals in the controller.

Actions:

```text
period open
→ Finalize Z
→ Leave period open

period finalized
→ View Z
```

Leave period open redirects to `GET /pos/register/enter?register_id=...` (Reporting Period open, Session none). View Z is `GET` of the existing finalized Z.

---

## 8. Enter gate with an open period and no Session

Required for same-day leftover Sessions and leftover periods:

```text
Register has open Reporting Period
Register has no open Session
```

The enter gate presents **Finalize Z** and **Open session**. If the period's business date differs from the Store's current calculated business date, the leftover banner remains conspicuous. Do not limit Z access only to prior-day periods. A period with zero Sessions may be finalized as an all-zero Z.

**Open session** uses the existing Reporting Period, collects a new opening float, opens a Session, and resumes/starts a working transaction. Do not ask the cashier to confirm a new business date.

**Finalize Z** from enter POSTs the period's `expected_lock_version`. Authorization is Store + `pos.transact` (not Session cashier).

| Finalize outcome | Result |
|---|---|
| Period open, versions match | `FinalizeReportingPeriod`, redirect Z |
| Period already finalized | Authorize; redirect existing Z; no second audit |
| Stale `lock_version` and period still open | Re-render the page they posted from (enter or closed summary); do not show `finalized_*` |
| Open session vs finalize race | HTTP loser is a re-rendered enter/error, not a 500 |

---

## 9. Finalized Z

```text
GET /pos/reporting_periods/:id/z
```

Authorization: current Store + `pos.transact`. Period must be finalized. This screen is immutable.

Phase 5 has no Z sequence number. Identity:

```text
Z Report
Store 003
Register 02
Business date 2026-08-17
Finalized 2026-08-17 18:42
Finalized by Alex Rivera
```

Store and Register numbers come from the period's Store/Register identity. Finalized-at uses the Store IANA zone.

Render persisted `finalized_*` commercial and Session-custody snapshots only. After finalization, the Z page must not re-query live transaction/session facts as its reporting authority.

Session-custody wording reflects independent Session custody intervals (sums), not one drawer's values.

---

## 10. Authorization matrix

| Action | Store scope | `pos.transact` | Session cashier |
|---|---:|---:|---:|
| Print completed receipt | yes | yes | transaction cashier |
| Initiate close | yes | yes | yes |
| Blind-count GET | yes | yes | yes |
| Blind-count POST | yes | yes | yes |
| Closed Session summary | yes | yes | yes |
| Return to sales | yes | yes | yes |
| Finalize Z | yes | yes | no |
| Finalized Z GET | yes | yes | no |

---

## 11. UI / keyboard

Slice 3 does not need another complex client-side state machine.

| Screen | Enter | Notes |
|---|---|---|
| Completed receipt | no-op | Print / New sale / Close register are explicit buttons |
| Blind count | submit count | Autofocus the count field; do not reuse scanner-key handling |
| Closed Session / Z | ordinary submit | Turbo/Stimulus optional except the print action |

---

## 12. Acceptance

Slice 3 is complete when:

1. A completed Cash transaction can be printed through one explicit browser-print path.
2. Printed receipt identity uses completed transaction number snapshots and the accepted `Store / Reg / Trans` format.
3. Printing cannot alter or reverse a completed transaction.
4. A cashier can initiate close from a completed receipt or an empty `SALE_ENTRY`.
5. Close initiation explicitly disposes of an empty working transaction but refuses a nonempty sale.
6. Refreshing any GET in the close flow performs no commercial mutation.
7. The closing-count page reveals no value from which expected Cash or variance can be learned.
8. `$0.00` is accepted as a valid closing count.
9. `CloseSession` alone derives and persists expected Cash and variance.
10. Closed Session UI displays persisted `closing_*` values.
11. Closing a Session does not automatically finalize its Reporting Period.
12. Leaving the period open returns to the Register enter gate.
13. An open Reporting Period with no Session can be finalized or resumed with a new Session from that gate, including an unused (zero-session) period.
14. Finalization uses only `FinalizeReportingPeriod`.
15. Finalized Z UI renders persisted `finalized_*` fields.
16. Multi-Session Z language represents sums of independent Session custody intervals rather than a single drawer.
17. Close/finalize lost-response retries resolve to the already-closed/finalized immutable result.
18. Authorization follows the locked Session-cashier vs Store-level Z boundary.
19. Stale still-open period finalize stays on enter/closed-summary and reveals no `finalized_*`.
20. Display timestamps use the Store IANA zone.
21. No new persistence model, permission, printer abstraction, Z number, or drawer model is introduced.
22. All Phase 4/5 unit, integration, concurrency, and required browser tests pass.

---

## 13. Out of this contract

```text
direct printer / ESC-POS integration
printer configuration
print acknowledgement/history
receipt email/SMS
receipt search UI
denomination counting
cash drawer hardware
drawer/till entities
paid-in / paid-out
cash transfers
manager approval workflow
dedicated Z-finalize permission
Z numbering
Z printing
X reports
reopen Session
reopen/fix finalized Z
offline POS
returns / discounts / post-void
```
