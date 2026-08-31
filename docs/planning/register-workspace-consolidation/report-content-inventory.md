# Report content inventory (Slice 6C gate)

Status: **Complete — dispositions assigned.** Snapshot-envelope extensions for 6C: **none.** Packet may move to fully locked for implementation. P13 may render only rows whose disposition permits the surface.

Authority: [slice6c-reporting-period-plan.md](slice6c-reporting-period-plan.md), [report-content-contract.md](report-content-contract.md). Verified against `Pos::OperatorReport`, `Pos::SessionTotals`, `Pos::PeriodTotals`, session close columns, and `PeriodTotals#snapshot` (2026-08-30).

## Disposition key

| Disposition | Meaning |
|---|---|
| Required now — existing authority | Domain totals/snapshots already authoritative |
| Required now — presenter grouping | Existing facts; P13 only regroups/labels |
| Prospective snapshot extension | Live yes; finalized needs approved freeze |
| Omit when unavailable | Hide; never `$0.00` for “not captured” |
| Deferred | Known gap; out of 6C UI |
| Future domain | Domain not product-ready (buyback; trade-credit as P13 category) |

Surface columns: **Yes** / **No** / **Gated** (expected-cash permission) / **N/A**.

Closed-session commercial/tender rows use `SessionTotals` over **immutable completed** transactions and cash facts (not a live “reprice”). Finalized Z may use **only** `finalized_*` snapshot columns.

## Inventory table

| Proposed row | Semantic definition | Current source | Existing service | Live X | Closed session | Current Z | Finalized Z | Disposition |
|---|---|---|---|---|---|---|---|---|
| Completed transactions | Count of completed txs in scope | `pos_transactions` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes (`finalized_transaction_count`) | Required now — existing authority |
| Sales subtotal | Pre-discount sale merchandise aggregate | tx `subtotal_cents` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Gross merchandise sales | Contract commercial headline | Same as sales subtotal | Presenter label over `subtotal_cents` | Yes | Yes | Yes | Yes | Required now — presenter grouping |
| Sales discount | Discount aggregate | tx `discount_cents` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Price adjustments | ± price-override effects as own line | No separate aggregate | Controlled actions only | No | No | No | No | Deferred |
| Sales tax | Tax aggregate | tx `tax_cents` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Sales total | Subtotal − discount + tax | derived | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Return subtotal | Returned merchandise | `return_subtotal_cents` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Return discount reversal | Return discount component | `return_discount_cents` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Return tax reversal | Return tax component | `return_tax_cents` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Returns total | Return total | `return_total_cents` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Net | Signed net | `signed_net_cents` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Post-void adjustments (net) | Post-void signed net | post-void txs | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Post-void count | Post-void transaction count | post-void txs | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Post-void merchandise / discount / tax | Fine post-void breakdown | post-void txs | PeriodTotals snapshot + SessionTotals methods | Yes | Yes | Yes | Yes (period snapshot) | Required now — existing authority |
| Cash payments | Cash tender received | tenders `behavioral_category=cash` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Cash refunds | Cash tender refunded | tenders | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Card payments / refunds | Card tender | tenders | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Check payments / refunds | Check tender | tenders | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Other payments / refunds | Other configured tenders | tenders | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Tender Received / Refunded / Net columns | Contract tender matrix | payment + refund per category | Presenter over totals | Yes | Yes | Yes | Yes | Required now — presenter grouping |
| Gift-card issuance (coarse) | Activation/reload issuance cents | tx `stored_value_issuance_cents` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Gift cards activated vs reloaded | Fine issuance split | Not separated in totals | — | No | No | No | No | Deferred |
| Stored-value payments (coarse) | All SV tender payments | `behavioral_category=stored_value` | PeriodTotals snapshot + SessionTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Stored-value refunds (coarse) | All SV tender refunds | category refund | PeriodTotals snapshot + SessionTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Store-credit payments | SV type tender | `tender_type=store_credit` | SessionTotals / PeriodTotals **live only** | Yes | Yes | Yes | **No** (not in snapshot) | Required now — existing authority on live/current Z/closed; **Omit when unavailable** on finalized Z |
| Gift-card payments (type) | SV type tender | `tender_type=gift_card` | SessionTotals / PeriodTotals live only | Yes | Yes | Yes | **No** | Required now — existing authority on live/current Z/closed; **Omit when unavailable** on finalized Z |
| Trade-credit payments | SV type / future category | `tender_type=trade_credit` | SessionTotals live | Yes (code) | Yes (code) | Yes (code) | **No** | Future domain — do not render as P13 tender category until product domain is ready |
| Refund to original gift card | Refund destination | `pos_stored_value_tender_details` | SessionTotals / PeriodTotals live only | Yes | Yes | Yes | **No** | Required now — existing authority on live/current Z/closed; **Omit when unavailable** on finalized Z |
| Refund to new gift card | Refund destination | details | SessionTotals / PeriodTotals live only | Yes | Yes | Yes | **No** | Required now — existing authority on live/current Z/closed; **Omit when unavailable** on finalized Z |
| Refund to store credit | Refund destination | details | SessionTotals / PeriodTotals live only | Yes | Yes | Yes | **No** | Required now — existing authority on live/current Z/closed; **Omit when unavailable** on finalized Z |
| Gift-card cash-outs (amount) | Cash-out custody | `GiftCardCashOut` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Gift-card cash-out count | Count of originals | `GiftCardCashOut` | SessionTotals; PeriodTotals **always live** (not snapshotted) | Yes | Yes | Yes | **No** (must not live-query after finalize) | Required now — existing authority on live/current Z/closed; **Omit when unavailable** on finalized Z |
| Gift-card cash-out reversals | Reversal amounts | `GiftCardCashOut` | SessionTotals / PeriodTotals | Yes | Yes | Yes | Yes | Required now — existing authority |
| Opening float | Session opening cash | `pos_sessions.opening_float_cents` | session / period sum | Yes | Yes | Aggregate | Sum in snapshot | Required now — existing authority |
| Non-sale cash (aggregate) | Net paid-in/out/drop/replenish/reverse | cash entries | SessionTotals `cash_movement_cents` | Yes | Yes | **No** (PeriodTotals has no aggregate) | **No** | Required now — existing authority on X/closed; **Omit when unavailable** on Z |
| Paid-in | Posted paid-in session effect | `CashOperation` / entries | CashEntry query (immutable ops) | Yes | Yes | Yes (project from ops) | **No** | Required now — existing authority on live/closed/current Z; **Omit when unavailable** on finalized Z |
| Paid-out | Posted paid-out session effect | `CashOperation` / entries | CashEntry query | Yes | Yes | Yes | **No** | Required now — existing authority on live/closed/current Z; **Omit when unavailable** on finalized Z |
| Drops | Session→safe | `CashTransfer` drop | CashEntry query | Yes | Yes | Yes | **No** | Required now — existing authority on live/closed/current Z; **Omit when unavailable** on finalized Z |
| Replenishments | Safe→session | `CashTransfer` replenishment | CashEntry query | Yes | Yes | Yes | **No** | Required now — existing authority on live/closed/current Z; **Omit when unavailable** on finalized Z |
| Cash-operation reversals | Reverse ops session effect | `operation_type=reverse` | CashEntry query | Yes | Yes | Yes | **No** | Required now — existing authority on live/closed/current Z; **Omit when unavailable** on finalized Z |
| Expected closing cash | Blind-count expected | SessionTotals / `closing_expected_cash_cents` | SessionTotals; after close frozen | Gated | Yes (frozen) | Sum | Sum in snapshot | Required now — existing authority (gated on open X) |
| Counted closing cash | Closing count | `closing_count_cents` | session close | N/A | Yes | Sum | Sum in snapshot | Required now — existing authority |
| Variance | Counted − expected | `closing_variance_cents` | session close | N/A | Yes (gate if reveals expected) | Sum | Sum in snapshot | Required now — existing authority |
| Sessions included (Z) | Closed session count in period | sessions | PeriodTotals | N/A | N/A | Yes | Yes | Required now — existing authority |
| Used buyback cash | Future buyback payout | None | None | No | No | No | No | Future domain |
| Cash buyback payouts | Future operational cash | None | None | No | No | No | No | Future domain |

## Snapshot-extension candidates

| Candidate | Live source | Why freeze | Approval for 6C |
|---|---|---|---|
| Fine SV type payments (store credit / gift card) | `type_tender_cents` | Finalized Z currently cannot show type split without live query | **None** — omit on finalized Z |
| SV refund destinations | refund destination queries | Same | **None** — omit on finalized Z |
| Gift-card cash-out count | `GiftCardCashOut` count | OperatorReport would otherwise live-query after finalize | **None** — omit on finalized Z; fix presenter to stop calling live count when finalized |
| Operational cash components (paid-in/out/drop/replenish/reverse) | CashEntry sums | P13 operational section on finalized Z | **None** — omit component lines on finalized Z; custody already reflected in closing expected sums |

No prospective snapshot-envelope migration in 6C. Revisit only if product requires fine finalized Z rows later.

## Implementation notes for P13

1. Evolve/replace `Pos::OperatorReport` so **finalized** period reports never call live-only methods (`store_credit_payment_cents`, `gift_card_cash_out_count`, refund destinations, etc.).
2. Map wireframe “Gross sales” → `subtotal_cents` (presenter grouping).
3. Operational cash **component** rows: implement for X, closed session, and **current** (open) Z via CashEntry projections; omit on finalized Z.
4. Trade credit: keep out of P13 tender UI (Future domain) even if live type totals can be nonzero in DB.
5. Never render `$0.00` for Deferred / Future / Omit rows.

## Sign-off

- Inventory completed on: 2026-08-30
- Reviewed against: `session_totals.rb`, `period_totals.rb`, `operator_report.rb`, session close columns, `PeriodTotals#snapshot`
- Snapshot extensions approved: **none**
- Packet status after completion: **fully locked** for 6C.1–6C.3 implementation (subject to dispositions above)
