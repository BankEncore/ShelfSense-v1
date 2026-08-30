# Report content contract (P13 semantic target)

Status: **Semantic target** for Slice 6C. This document defines desired report vocabulary and formulas. It does **not** claim every row is presently implementable. Rendering authority is [report-content-inventory.md](report-content-inventory.md) dispositions plus [slice6c-reporting-period-plan.md](slice6c-reporting-period-plan.md) source precedence.

Companion wireframe: [textual-wireframes.md](textual-wireframes.md) §P13.

## P13 groups

1. Report identity
2. Commercial activity
3. Tender settlement
4. Stored-value activity
5. Operational cash activity
6. Cash reconciliation
7. Transaction metrics
8. Controls and exceptions
9. Session rollup for Z

## Commercial activity target

```text
Gross merchandise sales
− Discounts
± Price adjustments
− Returned merchandise
= Net merchandise revenue

+ Gift cards issued
+ Net tax
= Signed transaction total
```

P13 may only show a component when the inventory identifies an authoritative source.

## Tender settlement target

Show nonzero tender types using:

```text
Tender          Received          Refunded          Net
```

Categories:

- Cash
- Card
- Check
- Gift card
- Store credit
- Trade credit — **future** until supported
- Configured other tenders

Gift-card **issuance** must never be combined with gift-card **tender** use.

## Stored-value activity target

Semantic rows (when supported):

- Gift cards activated / issued
- Gift cards reloaded
- Gift-card tender redeemed
- Store-credit tender redeemed
- Refunds to original gift card / new gift card / store credit
- Gift-card cash-outs and cash-out reversals

Fine type breakdowns render only when inventory marks them supported for that surface (live vs finalized).

## Operational cash activity target

```text
Paid-in
− Paid-out
+ Replenishments
− Drops
− Gift-card cash-outs
− Cash buyback payouts         [future]
± Cash-operation reversals
= Net operational cash effect
```

Operational cash does not change revenue or tender settlement.

## Cash reconciliation target

```text
Expected closing cash
  = Opening float
  + Cash payments
  − Cash refunds
  + Paid-in
  − Paid-out
  + Replenishments
  − Drops
  − Gift-card cash-outs
  − Cash buyback payouts       [future]
  ± Cash reversals

Variance
  = Counted closing cash
  − Expected closing cash
```

Future rows stay in this semantic contract but must not render until supported. Expected cash and variance obey [slice6c-reporting-period-plan.md](slice6c-reporting-period-plan.md) expected-cash gates.

## Transaction metrics target

- Completed transaction count
- Optional averages (screen only; generally omitted on shift-end tape)
- Post-void counts / nets when supported

## Controls and exceptions target

Nonzero summary of controlled actions / post-void / other exception metrics when inventory supports them.

## Session rollup for Z

- Session count
- Opening floats sum
- Closing expected / counted / variance sums (permission-gated as applicable)
- Links to included sessions when authorized

## Screen report vs shift-end tape

P13 exposes semantic facts; two presenters select from them (see packet). Tape is **42-character** monospaced; no separate financial calculator.
