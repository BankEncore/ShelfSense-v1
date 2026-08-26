# Phase 11 — Cash accountability plan

Status: **Proposed**.

## Goal

Complete operational cash custody from store safe through an open POS session and back to the safe, then optionally out as a prepared deposit—without replacing Register, session, X/Z, or Phase 10 gift-card cash-out.

## Exit outcome

> Every non-sale cash movement is authorized, attributable, and reflected in expected cash. Session custody starts as a safe-to-session transfer and ends by moving counted cash to the safe. Gift-card cash-out and cash refunds cannot spend cash the session does not have. The store can reconcile the safe and prepare a deposit without a hard store-day close.

## Scope boundary

| In scope | Out of scope (defer) |
|---|---|
| One operational store safe; one-time initialization | Independent `cash_drawers` table; movable till identity |
| Open `PosSession` as drawer custody on a **Register** | Workstation as a POS synonym ([ADR-021](../../adr/ADR-021-register-and-terminal-identity.md)) |
| Opening float as atomic safe→session transfer | Typed float with no source location |
| Counted close → over/short → transfer counted amount to safe | Redefining `closing_expected_cash_cents` to zero |
| Available-cash checks on cash refunds and gift-card cash-outs | Cashless sales without an open session |
| Paid-in, paid-out, drop, replenishment | Direct session-to-session (drawer-to-drawer) transfer |
| Atomic completed transfers | Multi-stage initiate/release/receive/dispute |
| Safe count and over/short; retain overnight | Allocating safe variance onto sessions |
| Deposit in transit (prepare/release from store custody) | Bank confirmation, matching, returned deposits |
| Store-day cash **report** and status labels | Hard store-day finalization that blocks the next date |
| Manager-assisted close (same count rules; `closed_by_user_id`) | Forced-takeover or investigation case workflow |
| Online Rails Register only | Offline/sync, sealed-drawer close, Terminal (ADR-018) |
| Unified **projection** over tenders, cash-outs, and Phase 11 facts | Copying `pos_tenders` or `gift_card_cash_outs` into movements |
| Phase 12 consumes available-cash | Buyback payout workflow |

## Identity

```text
Store
├── Register          durable checkout; receipt sequence; Z period
│   └── PosSession    cashier custody interval (the till, for MVP)
├── Safe              one operational cash location
└── Deposit in transit   prepared deposit location (no bank confirmation)
```

- The **Register** does not hold a durable cash balance between sessions.
- Cash facts reference the session (and are therefore reportable by register).
- After close, session location balance is zero. The next open is a new safe→session transfer.
- **Terminal** remains deferred. Do not use `workstation`.

## Architectural position

```text
Authoritative commercial facts (do not copy)
  pos_tenders                 cash payments and cash refunds
  gift_card_cash_outs         gift-card cash-out and reversals

Phase 11 operational facts
  cash_operations + cash_entries
    └── source rows on non-reverse ops only: transfers, paid-in/out, reconciliations, safe initialization, deposits

Projections (rebuildable)
  Pos::SessionTotals          expected session cash
  Cash::SafeTotals            expected safe / deposit-in-transit
  store-day cash report       union of facts for a business date
```

Expected session cash (open session):

```text
opening_float_cents                          snapshot of the safe→session transfer
+ completed cash payment tenders             pos_tenders (net in drawer; Phase 5)
- completed cash refund tenders
- gift-card cash-outs + cash-out reversals   gift_card_cash_outs
+ paid-ins + replenishments
- paid-outs - drops
± accepted session over/short                after close snapshot is taken; see lifecycle
```

Closed session: return persisted `closing_expected_cash_cents` (expected **before** over/short and transfer). Never rewrite closed snapshots. Z sums of those snapshots stay custody-interval figures ([phase10-reporting-closeout.md](../phase10-stored-value/phase10-reporting-closeout.md), [phase5-plan.md](../phase4-6-point-of-sale/phase5-cash-register/phase5-plan.md)).

Change given on a cash **sale** is not a $0-float blocker: `amount_cents` is already net in the drawer; presented cash funds change on that tender. Available-cash fails refunds, gift-card cash-outs, paid-outs, and drops when posting would make expected session cash negative.

## Slices

### 11.0 — Contract alignment (this packet)

Vocabulary, ADR-025 no-duplication, existing close/Z, Phase 10 cash-out formula, historical vs new sessions, explicit safe-init cutover, reversal/source-row model, optimistic safe-count concurrency, and authorization (`direct` vs `approval_required`). No application code except what a docs PR needs. This directory is 11.0 complete as implementation authority.

### 11.1 — Safe-backed session lifecycle

One store safe and one-time initialization; `OpenSession` as atomic transfer; extend `Pos::SessionTotals`; close with existing snapshot meaning; over/short then transfer counted cash to safe; prohibit negative expected session cash; available-cash on cash refunds and `GiftCards::CashOut`; manager-assisted close; preserve Z semantics. Detail: [phase11-session-lifecycle.md](phase11-session-lifecycle.md).

### 11.2 — Non-sale cash activity

Paid-in/out, reason catalog, drops, replenishments, atomic transfers, approval thresholds, reversals. Detail: [phase11-non-sale-activity.md](phase11-non-sale-activity.md).

### 11.3 — Safe reconciliation and reporting

Safe count and over/short; retained balance; deposit preparation to deposit in transit; store-day report without hard finalization; concurrency and reporting hardening. Detail: [phase11-safe-and-reporting.md](phase11-safe-and-reporting.md).

There is **no** 11.4 integration slice. Gift-card cash-out belongs in 11.1. Phase 12 consumes the available-cash service.

## Sequencing

```text
11.0 packet
  → 11.1 safe + session lifecycle + available cash + cash-out checks
  → 11.2 paid-in/out, drop, replenish, reverse
  → 11.3 safe recon, deposit, store-day report
```

11.1 must land as one coherent PR (reviewable commits). Open, close, expected-cash rewrite, and cash-out/refund available-cash cannot ship independently.

11.2 may add movement types to the same posting service. 11.3 must not require yesterday’s deposit before today’s open.

## Locked policy

| Decision | Contract |
|---|---|
| Custody | Open `PosSession` is the till. No `cash_drawers` table in MVP |
| Register vs cash | Register is checkout/Z identity; session is custody; safe holds store cash between sessions |
| Commercial facts | `pos_tenders` and `gift_card_cash_outs` stay authoritative; Phase 11 does not copy them |
| Money | Integer cents; organization base currency |
| Negative session cash | Prohibited after 11.1 (intentional migration from today’s $0-float refund/cash-out) |
| Negative location cash | Prohibited on safe and deposit-in-transit |
| Approval | Cannot authorize a negative expected balance. Phase 6 `direct` / `approval_required`; dedicated approve keys; org defaults with store override; never `approved_by = performed_by` |
| Open | Requires initialized safe. Positive float posts a balanced safe→session transfer; zero float keeps snapshot 0 and creates no movement |
| Reverse | New `reverse` operation + inverse entries; original source row unchanged; no fabricated inverse business event |
| Safe recon concurrency | Snapshot expected + `lock_version` at count start; revalidate on submit; activity may continue during the count |
| Denominations | Never required; optional lines must sum to the count total |
| Cutover | Coordinated maintenance window: uninitialized locations from migration; init without a POS session; then enforce OpenSession |
| Close snapshots | `closing_expected_cash_cents` = expected before recon/transfer; variance = counted − that expected |
| Close transfer | Counted amount to safe; session location balance then zero |
| Session lifecycle | `open` / `closed` only; no Terminal sync/`closing` state |
| Completions | Every POS complete still requires an open session |
| Transfers | One atomic completed fact; no acknowledgement workflow |
| Store day | Report and statuses; next business date may open on retained safe cash |
| Historical sessions | Unchanged snapshots; no backfilled transfers |
| Online | Rails Register only |

## UX adoption

- Register stays on the POS shell (Importmap + Turbo + Stimulus). Open/close, drop, replenish, paid-in/out, and cash-out remain Register workflows, not admin chrome.
- New admin safe/deposit/store-day surfaces use current UDS primitives (feature-led).
- Destinations go through `Admin::NavigationCatalog`. No one-off header links.

## ADR and documentation triggers

- [ADR-021](../../adr/ADR-021-register-and-terminal-identity.md) — Register vs Terminal; no workstation.
- [ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md) — cash owns its ledger; do not invent `financial_events`; do not copy POS tenders.
- [ADR-013](../../adr/ADR-013-append-only-facts.md) — completed movements immutable; reverse/replace.
- [ADR-011](../../adr/ADR-011-naming-conventions.md) — `reversal_of_id` only.
- [phase5-plan.md](../phase4-6-point-of-sale/phase5-cash-register/phase5-plan.md) — close snapshots, Z sums, session-scoped custody.
- [phase10-reporting-closeout.md](../phase10-stored-value/phase10-reporting-closeout.md) — expected-cash baseline including gift-card cash-out.

## Acceptance

1. A positive opening float posts a balanced safe→session transfer. A zero-float opening retains a zero snapshot and creates no zero-valued operation or entries.
2. Close records expected (pre-recon), counted, and variance; posts over/short when nonzero; transfers **counted** cash to the safe; closed snapshots are never rewritten.
3. Z `finalized_opening_float_cents_sum` and `finalized_closing_*_sum` remain sums of session custody intervals.
4. Cash refund and gift-card cash-out fail closed when available session cash is insufficient; change on a cash sale does not.
5. Paid-in/out, drop, and replenishment are not tenders and not gift-card cash-outs.
6. Safe recon is independent of session variance and of deposit preparation.
7. Deposit preparation moves cash from the safe to deposit in transit; bank confirmation is absent.
8. Store-day report explains cash for the date; it does not block the next date.
9. No `cash_drawers` table, no duplicated tender rows, no offline close state machine.

## Parallel work

Phase 12 buyback payout consumes available cash. UDS-6/7 stay parked. Do not pull bank reconciliation or Terminal productization into these slices.
