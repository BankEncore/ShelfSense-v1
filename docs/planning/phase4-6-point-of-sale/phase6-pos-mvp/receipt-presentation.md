# Phase 6 — POS receipt presentation and printing

**Status:** Implemented. Implementation authority for customer-facing POS receipt rendering, reprints, post-void receipt presentation, receipt header/footer configuration, and 80-mm browser printing. Implemented in slice 6.8 ([mvp-closeout.md](mvp-closeout.md)).

**Authority:** Customer print copy only. Receipt identity remains [receipt-identity.md](../phase4-point-of-sale/receipt-identity.md) / [ADR-006](../../../adr/ADR-006-receipt-numbering.md). Operator lookup, detail, and reprint *mechanics* remain [transaction-history.md](transaction-history.md). Post-void lineage remains [post-void.md](post-void.md). Dual authority with Core remains [mvp-contract.md](mvp-contract.md) / [ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md). Browser print lifecycle remains [close-z-screens.md](../phase5-cash-register/close-z-screens.md) except where this document supersedes the printed *layout*. Workflow remains [pos-workflow.md](pos-workflow.md).

Companions: [phase6-plan.md](phase6-plan.md), [mvp-closeout.md](mvp-closeout.md), [tender-breadth.md](tender-breadth.md), [controlled-actions.md](controlled-actions.md), [returns.md](returns.md), [pos-tax-contract.md](../phase4-point-of-sale/pos-tax-contract.md).

Draft [receipts.md](../../../drafts/specifications/pos/receipts.md) is vocabulary. This document is implementation authority for the MVP customer copy.

This contract does not own keyboard workflow, X Report, or open-price *entry*. Open-price *print grammar* applies when that merchandise exists.

No new ADR.

### Actually locked

```text
customer print ≠ operator history
receipt is presentation, not a financial record
no receipts table
immutable completed commercial facts + current Store presentation
identity from snapshots via Pos::ReceiptIdentity (do not fork spacing)
barcode payload = compact transaction_reference
never recalculate price / discount / tax / return value / settlement
price adjustments and open-price provenance are not customer-facing
true discounts are customer-facing
inherit | custom | none for header and footer independently
no template language / HTML / Markdown in receipt messages
no reprint audit (6.3 stands)
print after commit; print failure does not reopen the transaction
80-mm browser print; no ESC/POS in this slice
omit business_date on customer paper
one-line description clamp; CSS width is authoritative
condition_name on new Used snapshots; old rows fall back to condition_code
legal_name required; admin + Register enter + print fail closed
```

---

## 1. Objective

ShelfSense must produce a customer-usable receipt for every completed POS transaction.

Receipts are browser-rendered HTML formatted for printing on an 80-mm thermal receipt printer.

The receipt must:

* identify the current Store;
* identify the completed transaction with its permanent receipt reference;
* faithfully present immutable completed commercial facts;
* distinguish sales, returns, discounts, taxes, and settlement;
* provide a scannable transaction reference;
* support reprinting without recalculating historical transaction facts;
* identify post-voided transactions and post-void reversal receipts;
* allow organization-wide receipt messages with Store-specific inheritance, override, or suppression;
* use current Store and receipt-message configuration when rendered.

A receipt is a **presentation of a completed transaction**, not a separate financial record.

Customer print and operator history both read the same Core facts. They do not share layout. Operator history may continue to show directional totals, business date, override provenance, unlinked reference vs return price, external tender references, controlled-action approval, and post-void reason. This document does not strip those from the history screen.

---

## 2. Governing principles

### 2.1 Completed transaction facts are immutable

Receipt rendering must use the immutable completed facts of the transaction.

This includes:

```text
receipt identity (from snapshots)
completed_at
cashier_name_snapshot

merchandise identity snapshots
condition / unit identity snapshots
quantity

selling price
discount
tax
return linkage
post-void lineage

tender identity snapshots
applied tender amounts
Cash presented
change
```

Receipt rendering must never recalculate completed:

```text
price
discount
tax
return value
tender settlement
inventory value
```

using current configuration.

Changing a Product’s current price or Tax Class must not change an old receipt.

### 2.2 Receipt presentation uses current configuration

The following are **not** immutable transaction facts:

```text
Store legal name
Store address
Store phone
receipt header message
receipt footer message
receipt visual formatting
```

They are resolved from current configuration whenever the receipt is rendered.

A historical reprint may show a Store’s current address or current receipt footer while still showing the original transaction’s immutable commercial facts.

```text
CURRENT PRESENTATION
        +
IMMUTABLE COMPLETED TRANSACTION
        ↓
RENDERED RECEIPT
```

Do not snapshot Store name/address/header/footer onto the transaction solely for receipt rendering.

Identity numbers are the exception: reconstruct `S…-R…-T…` from `store_number_snapshot`, `register_number_snapshot`, and `receipt_sequence`. Do not use the Store’s current number.

### 2.3 Price provenance is not customer-facing

ShelfSense may internally distinguish catalog/reference price, ordinary selling price, price adjustment / override, and open price. The customer receipt does not.

Once the selling price is established, that amount is the item’s **Price** from the customer’s perspective.

A price adjustment must not appear as `Price Override`, `Adjustment`, `Manager Override`, `Original Price`, or `Reference Price` on the customer receipt.

Only a true **discount** is separately identified as a reduction from the customer’s item price.

### 2.4 Receipt rendering is not a template engine

Receipt configuration controls optional messages, not the receipt structure. Administrators may not redefine transaction layout or inject calculations.

ShelfSense owns Store identity layout, transaction identity, merchandise layout, discount presentation, tax presentation, totals, tenders, barcode, and post-void/reprint banners.

---

## 3. Receipt structure

Customer print renders in this order:

```text
1. Status banners, where applicable
   (REPRINT, POST-VOIDED, POST-VOID — first ink on the paper)

2. Current Store identity

3. Effective receipt header message, if any

4. Immutable transaction identity
   - completion date/time (Store timezone)
   - Store / Register / transaction sequence
   - cashier

5. Merchandise lines
   - sales
   - returns
   - post-void generated lines (on the reversal receipt only)

6. Transaction totals
   - merchandise / discounts / returns when nonzero
   - subtotal
   - tax
   - final total / refund total

7. Tender settlement (omitted when signed_net_cents = 0)

8. Item counts (ordinary customer activity only)

9. You Saved, when applicable

10. Receipt-reference barcode
    + human-readable compact reference

11. Effective receipt footer message, if any
```

Blank sections are suppressed.

Status banners sit at the **top**, not after a long address or header message.

---

## 4. Store identity block

### 4.1 Authority

The Store identity block uses the **current Store record** associated with the transaction (`pos_transactions.store_id`).

The displayed name is `stores.legal_name`.

Do not fall back to `stores.name`, `system_settings.organization_name`, or `system_settings.legal_name`.

`stores.name` remains an operational Store name and is not the customer receipt identity.

### 4.2 Fields

Render, when present:

```text
stores.legal_name
stores.street_address_1
stores.street_address_2
stores.city + region_code + postal_code
stores.phone
```

Example:

```text
             Example Books, LLC
             Some Shopping Center
               1234 Any Street
              Any Town, MI 99999
                 586-555-9999
```

Blank optional address or phone lines are omitted rather than leaving empty vertical space.

Country-specific address-format redesign is outside this contract.

### 4.3 Legal-name requirement

Never fall back to `stores.name` or System Settings names.

After preflight of existing rows (identify blanks; **do not** copy `name` into `legal_name`), require `legal_name` on Store create/update **while the Store is active**, and on activation. Deactivate of a legacy blank `legal_name` is allowed — do not invent a name. Reprints use current Store presentation and still fail closed if blank.

Register enter/open refuses a blank legal name:

> This Store cannot use POS until its legal name is configured.

The receipt renderer fail-closes if `legal_name` is somehow still blank. Never print a substitute name.

See [mvp-closeout.md](mvp-closeout.md) §2.4.

---

## 5. Receipt header and footer messages

Header/footer fields contain **optional presentation messages**. They do not contain the structured Store identity or transaction facts.

Appropriate content includes:

Header:

```text
Proud Member of the ABA
Thank you for shopping local
Annual Book Fair — September 12
```

Footer:

```text
Thank you for shopping with us!
Visit examplebooks.com
Returns accepted according to store policy.
```

Structured information already modeled by ShelfSense should not be hidden in these fields merely because arbitrary text is available.

Print messages as stored. Do not auto-uppercase.

---

## 6. Header/footer inheritance

Header and footer inheritance are independent.

Each Store has a mode for each message:

```text
inherit
custom
none
```

Add:

```text
stores.receipt_header_mode
stores.receipt_footer_mode
```

with `null: false` and `default: "inherit"`. Allowed values are only those three.

Phase 1 left blank Store text meaning “inherit the system default,” with no way to suppress a later org default. `none` is that missing capability. A blank system default and `none` are not the same: `none` stays blank even if the organization later adds a default.

### 6.1 `inherit`

```text
store.receipt_header_mode = inherit
→ system_settings.default_receipt_header

store.receipt_footer_mode = inherit
→ system_settings.default_receipt_footer
```

A later change to the System default immediately changes the effective message for inheriting Stores, including historical reprints.

### 6.2 `custom`

```text
receipt_header_mode = custom
→ stores.receipt_header

receipt_footer_mode = custom
→ stores.receipt_footer
```

Custom mode requires nonblank custom text. Changes to the System default do not affect the Store while its mode is `custom`.

### 6.3 `none`

Print no corresponding configurable message. This is distinct from inheritance.

### 6.4 System-level blank semantics

System Settings is the top of the inheritance chain and therefore requires no mode. Blank default means the organization has no default message. An inheriting Store receives that blank result.

### 6.5 Dormant custom text

Changing a Store from `custom` to `inherit` or `none` does **not** erase its custom text. The stored value is dormant while the mode is not `custom`. Selecting `custom` again restores it.

Do not require the text columns to be NULL in `inherit` or `none` mode.

### 6.6 Migration of existing Store configuration

Because header/footer inheritance semantics were previously undefined:

```text
existing nonblank receipt_header  → receipt_header_mode = custom
existing blank receipt_header     → receipt_header_mode = inherit
existing nonblank receipt_footer  → receipt_footer_mode = custom
existing blank receipt_footer     → receipt_footer_mode = inherit
```

Do not copy System defaults into Store fields during migration.

---

## 7. Header/footer message format

Receipt messages support plain Unicode text, preserved internal line breaks, and automatic wrapping.

They do not support HTML, Markdown, CSS, template variables, liquid-style expressions, embedded calculations, or images.

```text
Thank you for shopping at {store.name}
```

is printed literally. ShelfSense does not interpolate `{store.name}`.

All configured text is HTML-escaped before rendering (Rails ERB default; do not use `html_safe` / `raw` on these fields).

### 7.1 Whitespace

Normalize leading and trailing whitespace. Preserve intentional internal blank lines.

The receipt layout itself provides spacing before and after the configured message.

### 7.2 Length

Initial maximum: **500 characters** per header/footer field, applied to the trimmed value of:

```text
system_settings.default_receipt_header
system_settings.default_receipt_footer
stores.receipt_header
stores.receipt_footer
```

The purpose is to prevent accidentally producing excessive thermal-paper output, not to enforce a fixed line count. There is no characters-per-line validation.

### 7.3 Alignment

Header and footer messages are centered. Custom alignment is out of scope.

---

## 8. Header placement

The header message appears **after** the structured Store identity and **before** transaction metadata. Status banners are already above the Store identity.

The configurable header never appears above the Store legal name.

Example (no banners):

```text
             Example Books, LLC
               1234 Any Street
              Any Town, MI 99999
                 586-555-9999

            Proud Member of the ABA
          Thank you for shopping local

18 Aug 2026 7:12 PM
Store: 003   Reg: 02   Trans: 0018427
Cashier: John D.
```

---

## 9. Permanent receipt identity

Every completed POS transaction retains one permanent customer-facing receipt identity. This contract does not invent a second format.

Compact (barcode payload, human-readable under the barcode, lookup/scan input):

```text
S{store_number}-R{register_number}-T{receipt_sequence}
```

Header form — **exactly** `Pos::ReceiptIdentity.header` ([receipt-identity.md](../phase4-point-of-sale/receipt-identity.md); three spaces after `Store:` / `Reg:`):

```text
Store: 003   Reg: 02   Trans: 0018427
```

Minimum display widths: Store 3 digits, Register 2, Sequence 7. Padding is a minimum, not a maximum. Larger numbers are never truncated.

Reconstruct from immutable completed receipt facts. Do not use the Store’s current number.

---

## 10. Transaction metadata

Print:

```text
completed_at          # Store IANA timezone (ADR-007)
receipt identity      # header form
cashier_name_snapshot # "Not captured" if null (6.3)
```

**Do not** print `business_date` on the customer copy. Operator history, Session/X/Z, and reporting continue to show it.

The customer receipt does not normally print technical UUIDs, operation IDs, audit IDs, Session IDs, or reporting-period IDs.

---

## 11. Merchandise line layout

A receipt line is a compact multi-line group. Avoid page breaks inside one group.

```text
{identifier} {condition}      {net merchandise amount} {tax indicators}
  {description}
  {pricing details when needed}
  {return linkage when needed}
```

Example:

```text
9999999999999 Used Very Good            15.00 A
  The title or name of the product
```

### 11.1 Identifier

From the completed `merchandise_snapshot` only:

* individually tracked: `unit_identifier`
* otherwise: `sku`

Do not look up the current Product / Variant / InventoryUnit.

### 11.2 Condition

For individually tracked / Used merchandise, print a compact condition when captured.

For individually tracked / Used merchandise, print a compact condition when captured.

```text
condition_name present     → Used {condition_name}     # e.g. Used Very Good
older row, code only       → Used {condition_code}
```

Never live-lookup `merchandise_conditions`. Standard merchandise does not print `New`. New completions snapshot `condition_name` at freeze ([mvp-closeout.md](mvp-closeout.md) §2.3).

### 11.3 Description

Print the completed merchandise description snapshot. Do not use the current Product name.

Description occupies a separate indented line. Clamp to one printed line and truncate with an ellipsis rather than letting arbitrarily long titles dominate the receipt. Do not lock a character-per-line count; CSS width is authoritative.

If the snapshot is missing or the description is blank, print `Description unavailable`. Never substitute live catalog data.

---

## 12. Primary merchandise amount

The amount aligned at the right edge of the merchandise line is **`net_merchandise_amount_cents` before tax**, signed by line direction:

```text
sale    → + net_merchandise_amount_cents
return  → - net_merchandise_amount_cents
```

That amount already reflects any customer discount. Do not print `extended_selling_amount_cents` as the primary amount.

Tax remains in the tax summary rather than being embedded into the item amount.

---

## 13. Customer-facing price presentation

### 13.1 No discount, quantity 1

Print no additional price detail. Whether the selling price came from normal price, authorized price adjustment, or open-price entry is not shown.

### 13.2 Quantity greater than one

```text
9999999999999                      24.00 A
  Product Name
  2 @ $12.00
```

The unit price is the effective customer-facing selling unit price (`selling_unit_price_cents`).

---

## 14. Discounts

Discounts are customer-facing. Price adjustments are not discounts.

Use `manual_discount_cents` / `manual_discount_basis_points` from the completed line. The amount shown is the **total discount for the line**, signed as a reduction.

When `manual_discount_basis_points` is present and meaningful, label `Discount {percent}%`. Otherwise `Discount:`.

### 14.1 Quantity 1

```text
9999999999999                      10.80 A
  Product Name
  Price:                            12.00
  Discount 10%:                    -1.20
```

### 14.2 Quantity greater than one

```text
9999999999999                      21.60 A
  Product Name
  2 @ $12.00
  Discount 10%:                    -2.40
```

### 14.3 Adjusted price plus discount

Internal facts might be reference $15.00, selling $12.00, discount $1.20, net $10.80. Customer receipt shows Price $12.00 and Discount, never the $15.00 reference.

---

## 15. Open-price merchandise

Open-price merchandise uses the same receipt grammar as any other item. Do not print `OPEN PRICE`, `Price entered manually`, `Override`, or `Reference price`.

If an actual discount is subsequently applied, use the normal discount grammar from the cashier-authorized selling price.

---

## 16. Returns

Return lines are visually identified. The primary line amount is negative.

### 16.1 Linked return

```text
RETURN
9999999999999 Used Very Good           -20.00 AC
  Product Name
  Original: S001-R02-T0012345
```

The original receipt reference comes from the immutable original transaction identity (`store_number_snapshot` / `register_number_snapshot` / `receipt_sequence` of the original completed transaction). Each linked return line carries its own original reference. A single transaction may print different originals. There is no transaction-wide assumption that all return lines share a source.

Do not print `Return from`.

### 16.2 Discounted linked return

If the original customer-facing price was $12.00 with a $1.20 discount:

```text
RETURN
9999999999999 Used Very Good           -10.80 A
  Product Name
  Price:                            12.00
  Discount 10%:                    -1.20
  Original: S001-R02-T0012345
```

Do not print `Discount reversal`. The customer sees the same pricing relationship that applied to the returned merchandise.

### 16.3 Unlinked return

```text
UNLINKED RETURN
9999999999999 Used Very Good           -20.00 A
  Product Name
  Original receipt: Not provided
```

Do not print `Original: Unknown` — that implies ShelfSense lost known historical information.

Do not print unlinked reference vs return unit prices on the customer copy. The reference regular price used internally for an unlinked-return controlled action is not customer-facing. The cashier-authorized return selling price is simply the customer-facing return price. Operator history may still show reference vs return.

---

## 17. Tax indicators

Receipt lines use compact receipt-local tax indicators: `A`, `B`, `C`, `AB`, `AC`, `ABC`, …

These letters are **receipt-local display labels**, not permanent tax identifiers. Assign them during rendering. Do not persist `A` / `B` / `C` onto the transaction.

### 17.1 Grouping key

Group applied completed components. Do not group solely by the current Store Tax row.

```text
group key = [store_tax_id, rate_percent]
```

`rate_percent` is the frozen component rate. A later change to the live Store Tax rate must not merge with historical components that used a different rate.

Sort groups by:

1. minimum `calculation_order` among members
2. `store_tax_code_snapshot`
3. `rate_percent`

Then assign `A`, `B`, `C`, … in that order. Use the first member’s `store_tax_name_snapshot` as the summary label.

### 17.2 Applicable components

Attach an indicator for completed tax components where `applies = true`. Components where `applies = false` receive no indicator and are omitted from the customer tax summary.

Applied zero-rate components may be rendered as `0.000%` when present in completed tax facts.

### 17.3 Tax summary

Aggregate from completed component facts. Line direction supplies sign (component `tax_cents` / `taxable_basis_cents` stay nonnegative in Core):

```text
signed_basis = sale ? +taxable_basis_cents : -taxable_basis_cents
signed_tax   = sale ? +tax_cents           : -tax_cents
```

Example:

```text
Tax A ($25.00 @ 6.000%)             1.50
Tax B ($15.00 @ 1.250%)             0.19
Tax C ($5.00 @ 0.500%)              0.03
Total Tax                            1.72
```

Returns contribute negative economic amounts. Do not rerun `Tax::Calculate` during receipt rendering.

When only one tax group exists, the compact `Tax A` amount line is enough; omit `Total Tax`. When multiple groups exist, print each group plus `Total Tax`.

---

## 18. Transaction totals

The receipt totals section is direction-aware. Use persisted Core columns. Do not invent a parallel calculator.

Customer-facing merchandise subtotal before tax:

```text
Merchandise  = subtotal_cents                         # sale-direction extended selling
Discounts    = -discount_cents                        # sale-direction customer discounts
Returns      = -(return_subtotal_cents - return_discount_cents)
Subtotal     = Merchandise + Discounts + Returns
             = subtotal_cents - discount_cents
               - (return_subtotal_cents - return_discount_cents)
```

Return-side historical discount is incorporated into Returns rather than reported as new savings.

Tax lines plus `Total Tax` (when shown) must equal:

```text
tax_cents - return_tax_cents
```

Final amount must equal persisted `signed_net_cents`:

```text
signed_net_cents
  = (subtotal_cents - discount_cents + tax_cents)
    - (return_subtotal_cents - return_discount_cents + return_tax_cents)
```

`total_cents = abs(signed_net_cents)` remains the settlement magnitude.

### 18.1 Detailed mixed transaction

When discounts and/or returns exist (nonzero rows only):

```text
Merchandise                         80.00
Discounts                          -15.00
Returns                            -40.00
Subtotal                            25.00
Tax A ($25.00 @ 6.000%)             1.50
Tax B ($15.00 @ 1.250%)             0.19
Tax C ($5.00 @ 0.500%)              0.03
Total Tax                            1.72
TOTAL                               26.72
```

Do not use operator labels (`Sales subtotal`, `Discount reversal`, `Net`) on the customer copy. History may keep `_directional_totals`.

### 18.2 Simple sale

Suppress unnecessary zero/detail rows:

```text
Subtotal                            25.00
Tax A                                1.50
TOTAL                               26.50
```

### 18.3 Refund transaction

When `signed_net_cents < 0`:

```text
REFUND TOTAL                        26.72
```

Print the magnitude, not `TOTAL -26.72`. Line and subtotal calculations may remain signed.

### 18.4 Zero-net transaction

When `signed_net_cents = 0`:

```text
TOTAL                                0.00
```

No tender section.

---

## 19. Tender presentation

Tender lines represent **applied settlement**. Print in `tender_number` order using the completed `tender_name` snapshot, never the live tender-type name.

Example:

```text
External Card                       10.00
Check                               10.00
Cash                                 6.72
Cash presented                      10.00
Change                               3.28
```

Do not print `Total Payment` when the applied tender rows already reconcile to `total_cents`.

Use **Cash presented**, not `Cash Tendered`. That is the existing Core / workspace / Phase 5 print vocabulary (`amount_presented_cents`).

### 19.1 Cash payment

Always print the applied Cash amount (`tender_name` snapshot, typically `Cash`). When the Cash payment captured presented/change, also print `Cash presented` and `Change`.

`Cash` is the settlement amount. `Cash presented` is physical currency presented.

### 19.2 Refund tender

```text
Cash Refund                         10.00
External Card Refund                16.72
```

Customer copies do not need internal refund-operation identifiers. How the refund suffix is formed from `tender_name` + direction is presentation; do not invent a second tender name column.

### 19.3 External references

Customer receipts omit Card authorization/reference, Check reference, and Other tender reference unless a later tender-specific contract requires customer presentation. Operator history may show them.

---

## 20. Item counts

After settlement, print quantity totals when nonzero:

```text
Items Sold: 6
Items Returned: 2
```

```text
Items Sold     = SUM(quantity) for sale-direction lines that are not post_void_generated
Items Returned = SUM(quantity) for return-direction lines that are not post_void_generated
```

These are quantity counts, not line counts. Suppress zeros.

Post-void generated lines do not contribute. A post-void reversal receipt therefore does not report those generated quantities as ordinary customer `Items Sold` / `Items Returned`.

---

## 21. You Saved

`You Saved` is customer-facing sale-direction discount information.

```text
You Saved = discount_cents     # persisted sale-direction customer discounts
```

It excludes price adjustments / overrides, reference-vs-selling difference, open-price determination, return-side historical discount, and post-void reversal amounts.

Print only when positive:

```text
             You Saved: $15.00
```

A pure return or post-void receipt does not create new customer savings.

---

## 22. Receipt barcode

Every completed receipt prints a scannable barcode containing **exactly** the compact permanent transaction reference:

```text
S003-R02-T0018427
```

Do not encode the transaction UUID, a database URL, JSON, or customer information.

Beneath the barcode, print the same value as human-readable text.

Initial linear symbology is Code 128 or an equivalently compact symbology capable of representing the canonical reference exactly, including hyphens.

The barcode must be usable as typed/scanned input to transaction lookup (6.3 already exact-matches `transaction_reference` after trim/uppercase). Linked-return-by-scan is a workflow concern, not a second payload.

---

## 23. Footer placement

The effective footer message appears **after** the receipt barcode/reference.

The permanent receipt reference therefore remains visually associated with the transaction, while the final customer-facing content is the Store’s closing message.

---

## 24. Reprints

A reprint:

* uses the same permanent receipt identity;
* uses the same immutable completed transaction facts;
* does not allocate another sequence;
* does not create another financial transaction;
* uses current Store identity/header/footer configuration;
* is visibly marked.

Print at the top:

```text
              *** REPRINT ***
```

Immediate completion Print is the original copy (`reprint: false`). History Print is `REPRINT` (`reprint: true`). Same print partial ([transaction-history.md](transaction-history.md) §9).

A reprint may differ from the original physical paper in Store legal name, address, phone, header message, footer message, and CSS/layout — not in completed transaction facts.

No reprint table. **No reprint audit** — 6.3 stands (`window.print` stays client-side). This contract does not add print-attempt persistence.

---

## 25. Post-voided original receipts

A source transaction that has subsequently been post-voided remains historically unchanged. Its detail and later reprints are layered with a prominent status banner.

Print at the top (and above `*** REPRINT ***` when both apply, so the void status is the first line):

```text
           *** POST-VOIDED ***
This transaction has been post-voided
and is no longer valid.

Post-voided by: S003-R02-T0018500
```

Customer print **does** show the compact reversing receipt reference. That is a change from the current print-only stamp, which omits “Post-voided by.” Operator history may still hyperlink the reversal.

The original receipt barcode continues to encode the **original** receipt reference. The original receipt body remains the original completed transaction.

---

## 26. Post-void reversal receipt

The compensating post-void transaction receives its own permanent receipt identity. Its receipt must identify itself as a post-void rather than a customer return.

```text
             *** POST-VOID ***
Original: S003-R02-T0018427
```

Generated return-direction lines are not labeled `RETURN` or `UNLINKED RETURN`. They are part of the post-void correction. Do not print per-line `Post-void of {ref}` once the transaction banner already names the original.

The post-void receipt’s barcode encodes the **new post-void transaction’s** receipt reference.

Customer-facing price-adjustment provenance remains hidden. Completed discounts may be shown according to the normal discount presentation grammar where useful to explain the reversed commercial amount.

Do not print `You Saved` or ordinary `Items Sold` / `Items Returned` for generated activity.

A post-void of a sale typically settles as a refund; use `REFUND TOTAL` when `signed_net_cents < 0`.

---

## 27. Printing lifecycle

Receipt identity and transaction completion occur before printing.

```text
complete transaction
allocate permanent receipt identity
commit immutable facts
        ↓
render/print receipt
```

Never print then commit. Printer or browser printing failure does not reopen, cancel, or reverse the transaction, release the receipt identity, or rerun tax or settlement.

The cashier can print again from completed transaction history.

Print trigger remains an explicit **Print receipt** action; never automatic on GET ([close-z-screens.md](../phase5-cash-register/close-z-screens.md)).

---

## 28. Browser rendering and 80-mm printing

The initial implementation uses browser-rendered HTML/CSS. No printer driver, ESC/POS protocol, or direct device integration is required.

### 28.1 Print target

Optimize for 80-mm thermal roll paper. Do not assume the entire physical 80 mm is printable. Use a receipt content area compatible with normal thermal-printer margins (current CSS `72mm` content width is an acceptable starting point). Do not use a fixed receipt height.

### 28.2 Print stylesheet

The dedicated print stylesheet must:

* hide application navigation;
* hide buttons and interactive controls;
* hide screen-only metadata;
* use black-on-white output;
* use tabular numerals for monetary amounts;
* right-align monetary columns;
* preserve hierarchy without depending on background colors;
* avoid page breaks inside one merchandise line group;
* avoid splitting the totals/tender block unnecessarily;
* remove unnecessary browser-page margins where supported;
* allow the printer driver to determine final roll cut/length.

The 40-character visual ruler used during design may be retained as a regression/design aid but is not a fixed-width rendering contract. HTML/CSS layout is authoritative.

---

## 29. Screen versus print representation

Completed transaction detail may expose additional operational information on screen.

The **customer print representation** omits:

```text
controlled-action approval information
price-adjustment provenance
unlinked reference vs return unit price
manager identity
internal reason codes
internal transaction UUID
operation UUID
audit IDs
inventory valuation
GL classification
unnecessary external tender references
operator directional-total labels
```

The print receipt is customer presentation, not an audit report.

Both screen and print must derive commercial numbers from the same immutable completed transaction facts.

---

## 30. Header/footer administration UI

### 30.1 System Settings

Expose Default Receipt Header Message and Default Receipt Footer Message.

Help text: used by Stores configured to inherit. Receipt messages are plain text and automatically wrap to receipt width. A blank System value means there is no organization default message.

### 30.2 Store configuration

For Header and independently for Footer:

```text
( ) Use organization default
    Effective default:
    "{current system text, or an explicit empty-state}"

( ) Use custom …
    [ custom text area ]

( ) Do not print a … message
```

The current effective inherited text should be visible without requiring navigation to System Settings.

Selecting `custom` enables the Store textarea. Selecting `inherit` or `none` leaves any saved custom value dormant.

---

## 31. Header/footer validation

Validate:

```text
receipt_header_mode ∈ inherit | custom | none
receipt_footer_mode ∈ inherit | custom | none

custom header mode → receipt_header contains non-whitespace text
custom footer mode → receipt_footer contains non-whitespace text

all four configurable message fields → maximum 500 trimmed characters
```

Add database CHECK constraints for the mode enums. Where practical, add database checks ensuring a `custom` mode has nonblank text. Do not require the text fields to be NULL in `inherit` or `none` mode.

---

## 32. Auditing configuration changes

Receipt configuration remains ordinary mutable administrative configuration.

Changes to Store legal name/address/phone, Store receipt mode, Store receipt custom text, and System default receipt header/footer should use the existing configuration audit conventions.

Rendering or reprinting a receipt does not modify completed commercial facts and does not create a reprint audit event.

---

## 33. Historical rendering failure policy

Do not silently substitute live Product, price, tax, or tender data when a required historical snapshot is absent.

For pre-existing historical data where a presentation snapshot genuinely does not exist, use an explicit neutral fallback such as `Description unavailable` rather than presenting current catalog information as though it were historical truth.

Current Store identity/header/footer are the deliberate exception defined by this contract.

---

## 34. No receipt table required

This contract does not require a separate `receipts` table.

```text
Completed PosTransaction
        +
ReceiptIdentity
        +
Current Presentation Configuration
        ↓
Rendered Receipt
```

The completed POS transaction remains the commercial source of truth.

---

## 35. Example receipt

Exact spacing is illustrative. HTML/CSS layout, not fixed-width ASCII, is authoritative. Identity header spacing follows `Pos::ReceiptIdentity.header`.

```text
             Example Books, LLC
             Some Shopping Center
               1234 Any Street
              Any Town, MI 99999
                 586-555-9999

             Proud Member of the ABA

18 Aug 2026 7:12 PM
Store: 003   Reg: 02   Trans: 0018427
Cashier: John D.

9999999999999 Used Very Good            15.00 A
  The title or name of the product

9999999999999 Used Very Good            10.00 AB
  The title or name of the product
  Price:                            15.00
  Discount:                         -5.00

9999999999999                      20.00 C
  The title or name of the product
  2 @ $10.00

9999999999999                      20.00 B
  The title or name of the product
  2 @ $15.00
  Discount:                        -10.00

RETURN
9999999999999 Used Very Good           -20.00 AC
  The title or name of the product
  Original: S003-R01-T0000042

UNLINKED RETURN
9999999999999 Used Very Good           -20.00
  The title or name of the product
  Original receipt: Not provided

Merchandise                         80.00
Discounts                          -15.00
Returns                            -40.00
Subtotal                            25.00
Tax A ($25.00 @ 6.000%)             1.50
Tax B ($15.00 @ 1.250%)             0.19
Tax C ($5.00 @ 0.500%)              0.03
Total Tax                            1.72
TOTAL                               26.72

External Card                       10.00
Check                               10.00
Cash                                 6.72
Cash presented                      10.00
Change                               3.28

Items Sold: 6
Items Returned: 2

             You Saved: $15.00

               [BARCODE]
          S003-R02-T0018427

       Thank you for shopping with us!
```

---

## 36. Acceptance criteria

The receipt work is complete when all of the following are true.

### Identity and presentation

1. A completed transaction prints with `Pos::ReceiptIdentity.header` and the compact `transaction_reference`.
2. The printed barcode encodes exactly that compact reference.
3. A reprint retains the same receipt identity and does not allocate a sequence.
4. A reprint uses the current Store legal name, address, phone, effective header, and effective footer.
5. Changing current Store presentation configuration never changes completed transaction facts.

### Header/footer inheritance

6. Header and footer independently support `inherit`, `custom`, and `none`.
7. `inherit` dynamically resolves the current System default.
8. `custom` uses Store text and requires nonblank text.
9. `none` deliberately suppresses that message even if the org default is later filled.
10. Switching away from `custom` preserves dormant custom text.
11. Existing nonblank Store receipt text migrates to `custom`; blank text migrates to `inherit`.
12. System default blank means no inherited message.
13. Receipt messages render as escaped plain text with preserved internal line breaks.

### Merchandise

14. Quantity-one merchandise renders identifier, condition where applicable, description, `net_merchandise_amount_cents`, and tax indicators.
15. Quantity greater than one shows `quantity @ selling_unit_price`.
16. Price adjustments/overrides are not customer-facing.
17. Open-price items are indistinguishable from ordinarily priced merchandise after price establishment.
18. Customer discounts are explicitly displayed from completed discount facts.
19. `You Saved` equals persisted `discount_cents` when positive.

### Returns

20. Linked returns are labeled `RETURN`.
21. Linked returns print their original permanent receipt reference.
22. Multiple return lines may reference different original receipts.
23. Unlinked returns are labeled `UNLINKED RETURN`.
24. Unlinked returns say `Original receipt: Not provided` and do not print reference vs return price.
25. Historical discounts on returned merchandise use the same Price/Discount grammar, not `Discount reversal`.

### Tax

26. Tax indicators are receipt-local letters assigned from `[store_tax_id, rate_percent]`.
27. Tax summary values derive solely from completed component facts.
28. Historical linked-return tax is never recalculated using current tax rules.
29. Non-applicable components are omitted.

### Totals and settlement

30. Mixed sale/return totals equal persisted `signed_net_cents`.
31. Refund transactions use `REFUND TOTAL` with magnitude `abs(signed_net_cents)`.
32. Applied tender amounts reconcile to `total_cents`.
33. Cash distinguishes applied amount from `Cash presented` / `Change`.
34. Customer copies omit unnecessary external tender references.

### Reprint/post-void

35. Reprints are visibly marked `REPRINT` at the top.
36. A post-voided source reprint is marked `POST-VOIDED` at the top and prints `Post-voided by: {compact ref}`.
37. A post-void reversal receipt is marked `POST-VOID` and identifies the original receipt.
38. Post-void generated lines are not presented as customer returns and do not feed `Items Sold` / `Items Returned` / `You Saved`.

### Print behavior

39. The receipt prints cleanly on an 80-mm thermal-paper target using browser print.
40. Application navigation and interactive controls are absent from printed output.
41. Merchandise line groups and totals avoid inappropriate page breaks.
42. Print failure does not alter or reopen the completed transaction.
43. Printing never recalculates price, tax, discount, return value, or settlement.
44. Operator history still exposes operational detail this copy hides.

---

## 37. Out of scope

```text
direct ESC/POS printer drivers
printer discovery
cash-drawer hardware integration
electronic/email receipts
SMS receipts
customer receipt preferences
receipt logos/images
QR-code payloads beyond the receipt reference
arbitrary receipt templates
HTML/Markdown receipt messages
template variables
custom fonts/alignment per Store
custom tax-indicator configuration
jurisdiction-specific statutory receipt rules
receipt archival as rendered PDF/image
historical versioning of Store address/header/footer
customer-specific receipt messages
reprint audit / printed_at
rewriting operator history to match customer layout
keyboard / linked-return-by-scan workflow (payload only)
```

These may be added later without changing the invariant that completed commercial facts remain authoritative and immutable.

---

## 38. Final contract summary

```text
CURRENT STORE CONFIGURATION
  legal name
  address
  phone
  header message
  footer message

          +

IMMUTABLE COMPLETED POS FACTS
  permanent receipt reference
  completed time
  cashier
  merchandise
  selling price
  discounts
  returns
  tax
  tenders
  correction lineage

          ↓

CUSTOMER RECEIPT

          ↓

80-mm browser print
```

The customer receipt presents **what the customer paid or received**, not the internal pricing or approval mechanics ShelfSense used to establish those amounts.
