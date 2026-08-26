# Phase 10 — Account transfers and adjustments

Status: **Proposed**. Administrative same-type movement and manual ledger corrections. POS refund destinations remain [phase10-refund-post-void.md](phase10-refund-post-void.md). Schema: [phase10-schema.md](phase10-schema.md). Authorization: [phase10-authorization.md](phase10-authorization.md).

### Actually locked

```text
transfer is never debit-plus-credit adjustments
refund is never a manual adjustment
erroneous operations are reversed, not offset
same type and currency only
cross-type conversion prohibited
merge and consolidation move the full balance and close source
partial administrative transfer leaves source active
all manual debits require second user
credits at/above organization threshold require second user
performer cannot self-approve
merge uses merge authority, not stored_value.transfer
```

## 1. Transfer

`stored_value_transfers` plus one `transfer` operation with paired entries that net to zero.

| `transfer_type` | Amount | Source after post | Authority |
|---|---|---|---|
| `customer_merge` | Full remaining | Closed | `Customers::MergeCustomers` |
| `account_consolidation` | Full remaining | Closed | `stored_value.transfer` + second user |
| `administrative` | Full or partial | Closed only if amount equals remaining; otherwise active | `stored_value.transfer` + second user |

Rules:

- Source and destination differ.
- Same `account_type` and `currency_code`.
- Amount > 0 and ≤ source `balance_cents`.
- Inter-customer and administrative transfers (including consolidation) require second-user approval. Performer ≠ approver.
- Customer-merge transfer follows merge authority, not `stored_value.transfer`.
- Reversal of a transfer is blocked after the destination has downstream spend that would overdraw.

**Zero-balance merge:** close the merged source customer’s zero-balance store/trade accounts. Do not create a survivor account for a zero balance. No transfer operation when amount is 0.

Ordinary uniqueness remains one non-closed store-credit and one non-closed trade-credit account per customer. Consolidation typically moves a source customer’s full balance into the destination customer’s existing same-type account (or creates that account when the transferred amount is positive).

Gift-card replacement is **not** this table; it is `gift_card_replacements`.

## 2. Manual adjustment

`stored_value_adjustments` plus one `adjust` operation. Signed entry amount is derived from `adjustment_direction` and positive `amount_cents`. Never expose a balance-edit field.

Eligible accounts: store credit, trade credit, and gift-card accounts that pass lifecycle checks.

| Instrument / account | Adjustment |
|---|---|
| Active gift card | Allowed |
| Suspended gift card | Elevated administrative adjustment only |
| Replaced gift card | Block; use the replacement account |
| Closed gift card | Block ordinary adjustment |
| Positive adjustment | Must respect program `maximum_balance_cents`. `StoredValue::Post` rechecks under the account lock for every non-reversal gift-card credit. |
| Negative adjustment | Cannot overdraw |

Reasons come from `stored_value_adjustment_reasons`. Do not seed `opening_balance` as an ordinary reason. Snapshot `reason_code` / `reason_name_snapshot` on the posted adjustment.

## 3. Separation from other workflows

| Workflow | Mechanism |
|---|---|
| POS refund | `refund` operation via tenders and tender details |
| Paid gift-card sale | `activate` / `reload` issuance |
| Accommodation not tied to a POS refund | `adjust` with a catalog reason |
| Known bad posted operation | `reverse` |
| Move value between same-type accounts | `transfer` |

## 4. Account activity (read model)

Staff with `stored_value.view_activity` see per-account history on customer show for store credit and trade credit, including closed accounts. Staff with `gift_cards.view` see the same table on gift-card show for that instrument’s account.

Columns: store, business date, operation type, signed amount, balance-after, actor and reason snapshot when present, and a POS transaction reference when the operation is attributable to a completed POS issuance, tender, or related source row. Gift-card identity stays masked. This is UI over `stored_value_entries`; it is not a second ledger.

## 5. Outbox

- `stored_value.transferred`
- `stored_value.adjusted`
- `stored_value.reversed` when an adjust or transfer is reversed
