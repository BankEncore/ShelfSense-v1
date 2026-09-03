# Receipt and voucher content contract (D1 + D2)

Status: **Accepted** for slices R1–R4.

Authority for completed facts: [ADR-020](../../adr/ADR-020-pos-operation-envelope-and-core-facts.md), [receipt-identity.md](../phase4-6-point-of-sale/phase4-point-of-sale/receipt-identity.md), [ADR-006](../../adr/ADR-006-receipt-numbering.md), [ADR-019](../../adr/ADR-019-pos-sales-tax-model.md), [ADR-026](../../adr/ADR-026-gift-card-number-protection.md).

## Core invariants

1. **Printing is presentation, not posting.** Print, retry, and reprint do not create or modify financial activity.
2. **Completed facts remain authoritative.** No repricing, no current-catalog lookup, no live stored-value balance on historical receipts.
3. **Factual reproduction, not pixel identity.** Reprints may use the current approved renderer.
4. **Direction remains visible.** Sales, returns, payments, refunds, and stored-value activity preserve direction.
5. **Full gift-card numbers** appear only on authorized D2 vouchers.

## D1 — Customer transaction receipt

### Default order

1. Store identity and address
2. Optional configured header message
3. Reprint / post-void designation
4. Completion time, Store/Register/Transaction, cashier, optional customer
5. Merchandise sales and returns (description-first)
6. Stored-value activations/reloads (distinct section)
7. Merchandise/discount/return/stored-value summary
8. Store Tax breakdown (named Store Taxes)
9. `TOTAL DUE`, `REFUND TOTAL`, or `NET TOTAL`
10. Payments or refunds applied
11. Stored-value post-operation balance notes
12. Items sold/returned and savings when applicable
13. Receipt identity barcode
14. Optional footer message

Blank sections collapse.

### Merchandise lines

Description-first:

```text
Product description                       $10.99 [A]
SKU: 2210000000063
```

Conditional detail:

- Quantity and unit price when quantity > 1
- Regular price and discount when `manual_discount_cents` > 0
- Merchandise detail from frozen `variant_detail` when present (composed at sale from type, condition, and attribute values; omit for unattributed Standard)
- Historical lines without `variant_detail`: Used unit identifier with exact legacy `Used {condition_name|code}` when `unit_identifier` is present
- Linked-return original reference
- `[UNLINKED RETURN]` badge for unlinked returns
- Tax indicator letters (receipt-local, not persisted)

Do **not** print: internal reference-price variance, manager username, approval reason, Tax Class name, internal operation IDs. Live `product_variants.name` is never consulted after the sale.

### Stored-value issuance

Distinct section (`GIFT CARDS ACTIVATED` or `GIFT CARDS RELOADED`):

```text
Store Gift Card · #801....5940             $15.00
```

### Summary and Store Tax

When applicable:

- Merchandise Subtotal
- Item Discounts
- Returns Subtotal
- Gift Cards Activated / Gift Cards Reloaded

Each Store Tax row:

```text
[A] Michigan Sales Tax
    6.000% on $29.99                        $1.80
```

When multiple groups: `Total Tax` row. Do not print a universal `TAXABLE SUBTOTAL`.

### Payments

Dedicated `PAYMENTS APPLIED` section. Cash payment:

```text
Cash Tendered                              $20.00
  Cash Applied:                            $11.86
  Change:                                   $8.14
```

Stored-value tender with balance note uses persisted `balance_after_cents` and `Remaining Balance` or `New Balance` as appropriate.

Customer receipts omit arbitrary tender `external_reference` unless a future receipt-safe policy adds it.

### Receipt state variants

| State | Banner |
|---|---|
| Reprint | `*** REPRINT ***` |
| Post-voided original | `*** POST-VOIDED ***` + invalid note + reversing reference |
| Post-void reversal | `*** POST-VOID ***` + original reference |
| Pure stored-value | Omit empty merchandise and tax sections |
| Pure return | Omit empty sales/issuance sections; use `REFUND TOTAL` |
| Even exchange | Show gross activity; `NET TOTAL $0.00`; no fictitious tender |

## D2 — Gift-card voucher

Separate protected print artifact. Print:

- Store identity
- Issued time
- Amount
- `Gift Card` title
- Full normalized presented number
- Code 128 barcode of normalized digits
- Configured voucher footer
- `*** REPLACEMENT PRINT COPY ***` when recovery/replacement authorized

Ordinary receipt stays masked. Voucher content order follows [phase10-gift-card-numbering.md](../phase10-stored-value/phase10-gift-card-numbering.md) §5 with updated chrome from [visual-system.md](visual-system.md).

## Superseded presentation (Phase 6)

The following Phase 6 receipt-presentation rules are **superseded** by this contract:

- Identifier-first merchandise layout (§11)
- One-line description ellipsis clamp (§11.3)
- Generic `Tax A` summary without Store Tax name (§17.3 compact form may remain for single-tax simple sales at implementer discretion — prefer named tax when any detail row is shown)
- Mixed issuance into merchandise lines
- `Cash presented` label (now `Cash Tendered` on customer copy)
- `Subtotal` without merchandise context label (now `Merchandise Subtotal` when detail totals shown)

Identity strings, barcode payload, legal-name requirement, and header/footer inheritance remain from Phase 6.
