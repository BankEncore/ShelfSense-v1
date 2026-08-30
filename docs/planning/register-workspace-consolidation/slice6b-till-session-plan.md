# Slice 6B — Till and session detail

Status: **Packet locked** on `91-till-session-detail` → `register-workspace-consolidation` ([#91](https://github.com/BankEncore/ShelfSense-v1/issues/91)). Delivery: three PRs (6B.1 / 6B.2 / 6B.3).

Authority: [plan.md](plan.md), [implementation-plan.md](implementation-plan.md), [routing-and-authority.md](routing-and-authority.md), [slice6a-customer-service-plan.md](slice6a-customer-service-plan.md) (shared `RegisterShellContext`, expected-cash law), [textual-wireframes.md](textual-wireframes.md) S17–S19 / S21–S23 / **O19**, [user-stories.md](user-stories.md).

Issue: [#91](https://github.com/BankEncore/ShelfSense-v1/issues/91). Branch: `91-till-session-detail`. PR target: `register-workspace-consolidation`.

## Outcome

Compose Till Activity, Session Details, Active Sessions enhancements, and cash operation detail into the Register shell. Shell-wrap existing paid-in/out, drop, replenish, and gift-card cash-out forms (S21/S22). Enable reverse-from-original on cash activity detail; delete the generic reverse launcher in the same PR as reverse-from-original.

## Boundary statement

> Slice 6B composes authoritative till/session inquiry, existing session-cash forms, and original-operation detail inside the shared Register shell. Inquiry access, expected-cash visibility, mutation eligibility, and reversal authority are evaluated independently. The slice introduces no cash types or financial calculations. Reversal is initiated only from a supported original operation and remains governed atomically by the existing reversal service.

## Locked decisions

| Decision | Choice |
|---|---|
| Delivery | **Three PRs** (6B.1 / 6B.2 / 6B.3) under [#91](https://github.com/BankEncore/ShelfSense-v1/issues/91) |
| Reverse confirm | Wireframe **O19** + DOM `#pos_cash_reversal_overlay` / `data-overlay="cash-reversal-confirmation"` (S23 “O10” prose superseded) |
| Reverse packaging | Nested `POST /pos/cash_operations/:id/reversal`; delete generic launcher in **6B.3** |
| Surfaces | `:inquiry` for S17/S18/S19/detail; `:cash_operation` for S21/S22 forms |
| Assisted Close | Out |
| Basket + cash forms | **Retain**: cash forms allowed alongside a working basket; Return resumes same workspace/basket; F10/GET must not discard the working transaction |
| S17 rows | Custody movements only (`CashOperation` + transfers, `GiftCardCashOut`) — **not** per-transaction cash tenders |

### PR split

| PR | Scope |
|---|---|
| **6B.1** | Till Activity (S17), Session Details (S18), Active Sessions shell (S19); menu; session selection; expected-cash gating |
| **6B.2** | Shell-wrap S21/S22 existing cash forms (`:cash_operation`); custody redirects |
| **6B.3** | Cash activity detail (S23) + reverse-from-original via `Cash::Reverse` + O19; nested reversal route; delete `cash_reversals` launcher |

## Session selection

| Entry state | Till Activity / Session Details default |
|---|---|
| Own session | Current owned session |
| Occupied Register | Occupying session, requires `pos.sessions.view` |
| Between sessions | Most recently closed session on the selected **open** reporting period for that Register |
| Closed Register | No implicit session: recent-session chooser (bounded list) for that Register |
| Selector / no Register | Redirect to Register selection — no detail |
| Explicit `session_id` | Use after store + Register agreement + authorization |

Validation:

- `session_id` must belong to `current_store`
- When both `register_id` and `session_id` are supplied, the session’s register must match
- Stale, cross-store, or inaccessible IDs → not-found/denied **without** leaking session facts
- Never silently substitute another cashier’s session when the requested one is inaccessible
- GET never creates a period, session, transaction, or cash record

## Authorization (additive)

| Capability | Required authority |
|---|---|
| View own current session/till | `pos.transact` and ownership |
| View another cashier’s current session | `pos.sessions.view` |
| View historical session | Actor’s own historical session **or** `pos.sessions.view` |
| View expected/running cash | Session visibility **and** `cash.view_expected_before_count` |
| Open mutation form | Existing operation-specific permission plus own active-session custody |
| Reverse operation | `cash.reverse` plus visibility and `Cash::Reverse` eligibility at commit |

```text
Can view expected cash
  = can view this session
  AND cash.view_expected_before_count
```

`RegisterShellContext#can_view_expected_cash` must not make an otherwise inaccessible session visible.

## Surfaces

- `:inquiry` — Till Activity, Session Details, Active Sessions, cash-operation **detail**
- `:cash_operation` — paid-in/out, drop, replenishment, gift-card cash-out **forms**

Cash-operation surface: require owned active session; suppress Open/Finalize/Close proxies; F10-only shell lock; Escape/Return uses `RegisterShellContext` return path; direct GET without custody redirects to Register state (does not render an unusable form).

## S17 Till Activity projection

Presenter over authoritative facts only:

- `CashOperation` for the session (`pos_session_id`), including transfers (`opening_float`, `drop`, `replenishment`) and `paid_in` / `paid_out` / `reverse`
- `GiftCardCashOut` for that session (originals and reversals)

**Exclude** per-transaction cash tender lines (sale/refund). Those remain on Transactions / X (P13 in 6C).

Row contract: chronological `occurred_at`/`posted_at` with deterministic id tie-breaker; signed **session** effect; original/reversal relationship; performer (approver when present); status; bounded page size. Without expected-cash permission: show signed operation effect; **never** resulting till balance or running expected cash. Expected cash header uses `Pos::SessionTotals` only when authorized.

## S19 Active Sessions (exact)

Read-only: Register, cashier, business date, opened time, session status; optional transaction count from existing session totals; links to permitted Session Details, Till Activity, and X Report. **No** Assisted Close, expected cash, or mutation controls.

## Reverse-from-original (6B.3)

- The existing `Cash::Reverse` service remains authoritative. Presentation must not duplicate eligibility rules; detail `can_reverse` uses the same policy as commit (`Cash::Reverse.reversible?` + permission)
- Confirmation shows **Original effect** and **Reversal effect** (signed session amounts), reason/note per existing service
- Lock/revalidate operation and session together; stale detail cannot bypass changed eligibility; concurrent attempts produce exactly one reversal; failure leaves original unchanged
- Gift-card reverse remains on existing `cash_outs#reverse`
- Delete generic launcher UI/controller; replace with nested `POST /pos/cash_operations/:id/reversal`; reject ineligible originals

## Basket and navigation

- Navigating to a 6B surface must not mutate or discard the working transaction
- Return to Register resumes the same workspace and basket
- Cash mutation forms remain available alongside a working basket (current behavior retained)

## Scope

| In | Out |
|---|---|
| S17 Till Activity | Reporting / X / Z / P13 (6C) |
| S18 Session Details | Assisted Close |
| S19 Active Sessions enhancements (bounded above) | New cash types |
| S21/S22 shell wrap of existing cash forms | Redesigning cash mutation services |
| S23 cash activity detail + reverse-from-original | Suppressing cash forms while basket nonempty |
| Expected-cash gating | Slice 7 |
| O19 reverse confirmation | Using O10 for reverse confirm |

## Manual verification

[slice6b-manual-verification.md](slice6b-manual-verification.md)
