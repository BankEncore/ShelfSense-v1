# Phase 5 — First Operational Cash Register

**Status:** Slice 1 locked (headless cash accountability and Z finalize). Register UI stack is **not** locked.

**Authority**

| Document | Role |
|---|---|
| [Phase 5 schema](phase5-schema.md) | Session cash columns and period Z snapshots |
| [Phase 4 plan](../phase4-point-of-sale/phase4-plan.md) | Completion, receipt allocation, inventory posting |
| [Receipt identity](../phase4-point-of-sale/receipt-identity.md) | Compact reference and print header form ([ADR-006](../../../adr/ADR-006-receipt-numbering.md)) |
| [Phases 4–6 plan](../spec.md) | Broader sequencing; this packet supersedes conflicting §5 cash/Z detail |
| Accepted ADRs | ADR-006, ADR-007, ADR-008, ADR-009, ADR-011, ADR-012, ADR-013, ADR-019, ADR-020, ADR-021 |

Phase 4 is a headless Cash sale. Phase 5 turns that path into a cashier-usable online Rails register. No Terminal table (ADR-021). Offline sales stay out.

```text
derive business date
        ↓
cashier confirms
        ↓
open Z / reporting period
        ↓
lock period
open Session
record opening float
        ↓
SALE_ENTRY / QUANTITY / TENDER   (ephemeral UI modes; slice 2)
        ↓
Phase 4 authoritative completion
        ↓
blind closing count
        ↓
lock Session
require no working transactions
derive expected Cash
derive variance
freeze Session cash snapshots
close Session
        ↓
lock Reporting Period
require no open Sessions
require no working transactions
require every Session closed with complete cash snapshots
derive commercial totals
aggregate closed-Session snapshots
freeze Z
finalize Reporting Period
```

---

## 1. Objective

Deliver the minimum shift lifecycle:

> Can a cashier operate an ordinary Cash register through open → sell → close → Z using the Phase 4 completion path?

Slice 1 answers the cash-accountability half without screens. Slices 2–3 add the register workspace and receipt/Z presentation.

---

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Client | Rails-native online POS only; standalone/offline Terminal deferred (ADR-021) |
| Permission | Reuse `pos.transact`. No new keys |
| Session open/close | Session cashier only (`Pos::Support.require_session_cashier!`) |
| Z finalize | Any actor with `pos.transact` at the store. **Intentionally broad for Phase 5**; reconsider with Phase 6 controlled actions. Do not add `pos.finalize_reporting_period` now |
| Period serialization | `OpenSession` and `FinalizeReportingPeriod` both lock the same `pos_reporting_periods` row |
| Business date | Confirm `BusinessDate.for_store(...)` only. No arbitrary backdate or override |
| Opening float | Required at open; integer cents `>= 0`; zero allowed; not a paid-in or tender |
| Blind close | `CloseSession` accepts only `closing_count_cents` + `expected_lock_version` (plus session/actor). Expected and variance are server-derived. Slice 3 collects the physical count **before** revealing expected or variance |
| Expected Cash | `opening_float_cents + SUM(cash payment amount_cents)` on **completed** session transactions |
| Tender amount | `pos_tenders.amount_cents` is applied (net in drawer). Do not add presented and subtract change separately |
| Variance | `closing_count_cents - closing_expected_cash_cents` (may be negative) |
| Close snapshots | Persist `closing_expected_cash_cents`, `closing_count_cents`, `closing_variance_cents`. Not live counters |
| Snapshot authority | Open session/period: totals may preview from completed facts. Closed session / finalized period: persisted snapshots are authoritative. Calculation produces the snapshot; it does not replace it after close/finalize |
| Closed session | Immutable. Do not reopen; open a new session |
| Close vs Z | Closing a session does not finalize the period |
| Finalize gate | Period open; matching `expected_lock_version`; no open sessions; no working transactions; every session closed with complete closing cash snapshots |
| Empty Z | A period with zero sessions may finalize as an all-zero snapshot |
| Z commercial totals | From completed `pos_transactions` (`transaction_count`, `subtotal_cents`, `tax_cents`, `total_cents`, `cash_payment_cents`) |
| Z cash figures | **Sums of independent session custody intervals**, not one drawer close (`session_count`, `opening_float_cents_sum`, `closing_*_sum`) |
| Multi-session Z | Do not invent a drawer-chain. One session per Z is the intended ordinary Phase 5 path |
| Z finalizer | Persist `finalized_by_user_id` on the period |
| Z number | Deferred (POS-DEC-088) |
| Drawer table | Deferred (POS-DEC-016). Cash custody is session-scoped |
| Paid-in / paid-out / transfer | Out of Phase 5 |
| Outbox | No session-close or Z-finalize outbox events unless a concrete consumer appears. Audit and immutable snapshots are sufficient |
| UI stack | **Not locked.** Slice 2 locks the UI stack **and** its browser-level testing strategy together. Do not install Importmap / Turbo / Stimulus in slice 1 |
| Input modes (slice 2) | `SALE_ENTRY`, `QUANTITY`, `TENDER` are **ephemeral UI modes**, not persisted transaction states |
| Controllers (slices 2–3) | Call Phase 4/5 services only. No receipt allocation or inventory mutation in controllers |
| Print (slice 3) | Render from immutable completed facts. Proposed path: browser print. Printer failure must not undo completion |

---

## 3. Slices

### Slice 1 — Headless cash / Z (locked)

- Session cash columns and period Z snapshot columns
- `OpenSession` locks the reporting period, then creates the session
- `CloseSession` is blind: count in, server-derived expected/variance out
- `FinalizeReportingPeriod` locks the period, enforces the full gate, freezes aggregates
- `SessionTotals` / `PeriodTotals` preview while open; return persisted snapshots after close/finalize
- Audit + immutability + concurrency tests
- No POS screens

### Slice 2 — Register workspace

Lock the UI stack and browser-testing strategy in the same change.

- If the workspace stays conventional server-rendered Rails, request/integration tests plus manual UX acceptance may suffice.
- If it adopts Turbo/Stimulus or other meaningful client-side behavior, revisit “system tests deferred.”
- Confirm the calculated store business date (no free-form date field).
- Persistent scan/input workspace; quantity correction; working-line removal; cancel.
- Cash tender and complete through Phase 4 services.
- Keyboard-first ordinary path using ephemeral `SALE_ENTRY` / `QUANTITY` / `TENDER` modes.

### Slice 3 — Receipt + close / Z screens

- Receipt from completed facts; header form in [receipt-identity.md](../phase4-point-of-sale/receipt-identity.md)
- Print prompt; one supported path; failure does not undo completion
- Session totals: closed sessions show persisted close snapshots
- Blind count first; then reveal expected and variance
- Finalize and show basic immutable Z from persisted snapshots

---

## 4. Expected Cash formula (Phase 5)

```text
expected = opening_float_cents
         + SUM(pos_tenders.amount_cents)
           for completed transactions in this session
           where tender_type = cash and direction = payment
```

Cancelled transactions contribute nothing. Working tenders are not custody facts.

```text
variance = closing_count_cents - closing_expected_cash_cents
```

---

## 5. Snapshot authority

```text
session open     → SessionTotals derives a preview from completed transactions
session closed   → SessionTotals returns persisted closing cash snapshots
period open      → PeriodTotals may calculate a preview
period finalized → persisted Z snapshots are authoritative
```

Commercial line totals on a closed session may still be read from completed transaction facts (those rows are already immutable). Cash close fields and finalized Z fields must not be treated as live recalculations after freeze.

---

## 6. Authorization, audit, and outbox

Service-level `pos.transact` on every command. Direct unauthorized requests must fail.

Finalizing an immutable register reporting period is a stronger act than operating POS. Phase 5 still uses `pos.transact` so the first operational slice stays small. Reconsider a dedicated permission with Phase 6 controlled actions.

Audit in the same database transaction as a successful change:

| Action | After values (minimum) |
|---|---|
| `pos.session.opened` | `opening_float_cents` |
| `pos.session.closed` | `closing_count_cents`, `closing_expected_cash_cents`, `closing_variance_cents` |
| `pos.reporting_period.finalized` | Z snapshot fields and `finalized_by_user_id` |

No passwords, tokens, or indiscriminate row dumps.

Phase 5 does not introduce session-close or Z-finalize outbox events.

---

## 7. Build order

```text
1. Lock cash / Z decisions (this document + schema)
2. Migrate session and period columns
3. SessionTotals / PeriodTotals (preview vs snapshot)
4. OpenSession (period lock) / CloseSession (blind) / FinalizeReportingPeriod
5. Headless and concurrency tests
6. Slice 2 — UI stack + testing strategy + register workspace
7. Slice 3 — receipt print + blind close / Z screens
```

---

## 8. Slice 1 acceptance

A headless scenario can:

1. Open a reporting period with the calculated store business date (omit or confirm; reject any other date).
2. Open a session with an explicit opening float (including zero), serializing on the period row.
3. Complete one Cash sale through Phase 4 services.
4. Close the session with **only** a counted amount; persist server-derived expected and variance.
5. Observe a negative variance when counted is below expected.
6. Reject close while a working transaction exists.
7. Reject close by a second cashier.
8. Reject finalize while a session is open or a working transaction exists.
9. Finalize after close and persist immutable Z snapshots, including `finalized_by_user_id`.
10. Finalize an unused period as an all-zero Z.
11. Reject mutation of a closed session or finalized period.
12. Record the three audit actions above.
13. Race `OpenSession` vs `FinalizeReportingPeriod` and never produce an open session on a finalized period.
14. Closed session totals and finalized Z totals use persisted snapshots, not a later recomputation as authority.
15. `CloseSession` receives only count; expected/variance are server-derived.
16. Multi-session Z aggregates independent session snapshots (`closing_variance_cents_sum == SUM(session.closing_variance_cents)`) without treating them as one drawer.

---

## 9. Phase 5 acceptance (all slices)

A cashier can complete [spec.md §5.16](../spec.md) (business date through finalize Z) on a keyboard-operable ordinary path. Slice 1 does not claim that UI acceptance.

---

## 10. Out of Phase 5

Returns, discounts, approvals, suspend/recall, post-void, card / stored value, paid-ins / paid-outs / transfers, drawers, offline Terminal, customer display, Z numbering, close/Z outbox events, a dedicated finalize permission, Hotwire unless slice 2 accepts it together with a browser-testing strategy.
