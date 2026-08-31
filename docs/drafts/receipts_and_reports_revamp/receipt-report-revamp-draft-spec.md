# Receipt and report revamp — draft specification

Status: **Draft for review**  
Program: Follow-on Register refinement  
Scope: Customer receipts, gift-card vouchers, cash-operation slips, session tapes, X/Z reports, and their shared thermal presentation system

## 1. Authority and intent

This specification defines a presentation and projection revamp over existing ShelfSense transaction, tender, Store Tax, stored-value, cash, session, and reporting-period authority.

The supplied HTML mockups establish visual direction for:

- information density;
- hierarchy;
- thermal typography;
- dividers and section labels;
- total and status emphasis;
- description-first merchandise lines;
- grouped tenders and stored-value activity;
- receipt/report chrome.

They are not independently authoritative for keyboard mappings, routes, permissions, lifecycle rules, financial formulas, or terminology. Mock values are illustrative and must not be copied into calculation contracts.

Repository domain authority continues to govern:

- completed transaction facts;
- receipt identity;
- tender direction and settlement;
- Store Tax components;
- stored-value entries and `balance_after_cents`;
- cash custody entries;
- session close snapshots;
- reporting-period finalization;
- authorization and audit.

## 2. Goals

1. Make customer receipts understandable without exposing internal operational detail.
2. Make cash and reporting documents independently reconcilable.
3. Give all thermal documents a coherent ShelfSense visual system.
4. Render from persisted authority without repricing or reconstructing completed facts.
5. Support original print, retry, reprint, post-void, reversal, and recovery states explicitly.
6. Separate customer documents, custody evidence, and management reports rather than forcing them into one template.
7. Preserve keyboard access and predictable focus on every screen surface used to preview or print a document.
8. Build a scenario fixture suite that exercises mutually exclusive receipt/report states.

## 3. Non-goals

This program does not:

- remap Register keyboard shortcuts;
- redesign transaction, tender, stored-value, cash, session, or Z domain semantics;
- create a new generic Receipt aggregate without a demonstrated lifecycle need;
- store raw printer bytes or image snapshots merely for reprint;
- require pixel-identical historical reprints;
- expose full gift-card numbers on ordinary customer receipts;
- expose Tax Class names as customer Store Tax labels;
- print expected drawer cash where authorization or blind-count policy prohibits it;
- print manager credentials, internal operation IDs, GL classifications, or other audit-only detail on customer receipts.

## 4. Document families

| Family | Documents | Audience | Authority |
| --- | --- | --- | --- |
| D1. Customer transaction | Original receipt, reprint, return/refund receipt, exchange receipt, post-void documents | Customer and store | Completed transaction, lines, tax components, tenders, stored-value operations |
| D2. Stored-value credential | Gift-card voucher, recovered/replacement print copy | Customer; management-authorized generation | Protected credential-delivery/recovery authority |
| D3. Customer cash-out | Gift-card cash-out receipt | Customer and store | Stored-value cash-out operation plus cash entries |
| D4. Cash custody | Paid In, Paid Out, Cash Drop, Cash Replenishment, reversal slip | Cashier and management | Immutable cash operation and entries |
| D5. Session | Session close tape, closed-session summary print | Cashier and management | Frozen session close facts |
| D6. Interim report | X Report | Authorized cashier/management | Current open-session facts as of print time |
| D7. Final report | Z Report | Management/accounting | Finalized reporting-period facts |

## 5. Core invariants

### 5.1 Printing is presentation, not posting

Printing, retrying a failed print, and reprinting:

- do not create or modify financial activity;
- do not alter inventory;
- do not allocate a new receipt identity;
- do not update tender or stored-value balances;
- do not open, close, or finalize sessions or reporting periods.

### 5.2 Completed facts remain authoritative

A document must consume persisted facts. A renderer may group, label, format, and omit inapplicable rows, but it must not:

- look up current product prices;
- reapply current discount rules;
- recalculate tax using current Store Tax configuration;
- rename completed tenders from current configuration where a tender snapshot governs;
- display a live stored-value balance as though it were the balance produced by a historical transaction;
- reconstruct a closed-session or finalized-Z total from mutable current state.

### 5.3 Factual reproduction, not pixel identity

Reprints retain the original receipt identity and historical commercial facts. The current approved renderer may present those facts differently from the original print where existing policy allows current descriptive or presentation configuration.

This program does not require raw print-byte retention or an image of the original receipt.

### 5.4 Direction remains visible

Sales, returns, payments, refunds, stored-value issuance, stored-value redemption, and cash custody movements must preserve direction. A zero or net total must not hide gross activity.

### 5.5 Unlike reconciliations remain separate

Reports must not combine merchandise activity, stored-value liability activity, tender settlement, and physical cash custody into an ambiguous single Net Total.

## 6. Data-authority map

| Presented fact | Required authority |
| --- | --- |
| Store/Register/receipt identity | Completed transaction receipt identity snapshots/sequence |
| Completion date/time | Completed transaction occurrence/completion time |
| Business date | Completed transaction/session/reporting-period fact where document requires it |
| Cashier | Completed cashier snapshot or session authority as appropriate |
| Merchandise description, SKU/unit identifier, condition | Completed line merchandise snapshot |
| Quantity, selling price, discount, direction | Completed transaction line facts |
| Linked-return original reference | Original completed transaction/line link |
| Store Tax letter/name/rate/basis/amount | Completed line Store Tax components and their snapshots |
| Tender name/direction/applied amount | Completed tender facts/snapshots |
| Cash tendered and change | Completed Cash tender facts |
| Printable tender reference | Explicit receipt-safe policy and completed safe value; never arbitrary exposure by accident |
| Stored-value type/program/masked reference | Completed issuance/tender detail and permitted descriptive presentation |
| Stored-value post-operation balance | Applicable persisted stored-value entry `balance_after_cents` |
| Full gift-card number | Protected voucher first-print or recovery credential only |
| Cash operation effects | Immutable cash entries for the operation |
| Session expected/count/variance | Frozen close facts after count/close; live expected only where authorized |
| X totals | Current open-session report presenter as of print time |
| Z totals | Finalized reporting-period snapshots/facts |

## 7. Shared thermal design system

All document families should reuse shared print primitives while retaining distinct semantics.

### 7.1 Primitives

- Store header.
- Document title and status banner.
- Metadata label/value rows.
- Section title.
- Solid and dashed divider.
- Description-first item block.
- Signed money row.
- Source/destination transfer row.
- Tax-group row.
- Tender/payment row.
- Total banner.
- Original/reversal reference block.
- Performer/approver block.
- Signature block.
- Barcode and human-readable reference.
- Footer/policy message.
- Reprint/recovery designation.

### 7.2 Width and print behavior

- Primary target: 80 mm thermal roll.
- Printable content must remain safe at the narrower effective driver width already used by ShelfSense.
- Screen controls never appear in print.
- Long content wraps without overlapping monetary columns.
- Print typography uses local/fallback-safe fonts; printing waits for requested fonts when supported.
- Barcodes are generated by the approved Code 128 encoder, not decorative hand-built bars.
- Long X/Z/session tapes flow continuously and do not create misleading repeated totals at page breaks.
- Black-and-white output remains legible; meaning never depends on color.

### 7.3 Status vocabulary

Use explicit document states:

- `REPRINT`
- `POST-VOIDED`
- `POST-VOID`
- `INTERIM — SESSION REMAINS OPEN`
- `CLOSED`
- `FINALIZED`
- `REPLACEMENT PRINT COPY` or the final approved recovery term
- `REVERSAL`

Automatic retry of an initial failed print and an intentional later reprint are distinct operational events. Final customer-facing labeling remains a policy decision where not already locked.

## 8. Customer transaction receipt

### 8.1 Default order

1. Store identity and address.
2. Optional configured header message.
3. Reprint/post-void designation.
4. Completion time, Store/Register/Transaction, cashier, and optional customer.
5. Merchandise sales and returns.
6. Stored-value activations/reloads.
7. Merchandise/discount/return/stored-value summary.
8. Store Tax breakdown.
9. Total Due, Refund Total, or Net Total.
10. Payments or refunds applied.
11. Stored-value post-operation balance notes.
12. Sold/returned counts and savings when applicable.
13. Receipt identity barcode.
14. Optional footer/return-policy message.

### 8.2 Store and transaction identity

Print:

- customer-facing Store identity required by receipt policy;
- address and phone where configured;
- actual completion date/time;
- compact Store/Register/Transaction identity;
- cashier name;
- customer name only when attached and permitted.

Do not print a blank Customer row when none is attached.

### 8.3 Merchandise lines

Use description-first hierarchy:

```text
Product description                       $10.99 [A]
SKU: 2210000000063
```

Conditional detail may include:

- quantity and unit price for quantity greater than one;
- actual completed regular/selling price and meaningful discount;
- used-unit identifier and condition;
- linked-return original receipt reference;
- explicit `UNLINKED RETURN` designation;
- tax indicator letters.

Customer receipt lines should not expose:

- internal reference-price variance merely because a price was overridden;
- manager username;
- approval reason or note;
- internal Tax Class name;
- internal operation identifiers.

### 8.4 Discounts

Where a line discount exists, show enough information for the customer to understand the charged price:

```text
Regular Price:                              $9.99
Discount (15%):                            -$1.50
```

Use completed selling and discount facts. Do not calculate against the current catalog price.

### 8.5 Returns

#### Linked return

Show:

- return direction;
- returned item and quantity;
- signed return amount;
- original receipt reference.

Whether the customer-facing return reason prints remains a policy decision.

#### Unlinked return

Show an explicit no-original-receipt designation. Do not imply linkage that does not exist.

#### Refund-total receipt

Use `REFUND TOTAL`, not a negative `TOTAL DUE`. Refund tenders use directional labels such as `Cash Refund` or `Refund to Store Credit`.

#### Even exchange

Show both gross sale and return activity and a `$0.00` Net Total. Do not create a fictitious zero-dollar tender.

### 8.6 Stored-value issuance and reload

Do not mix issuance lines into ordinary merchandise presentation. Use a distinct section:

```text
GIFT CARDS ACTIVATED

Store Gift Card · #801....5940             $15.00
```

Use distinct labels for:

- activation;
- reload;
- post-void/reversal where applicable.

For activation/reload, the balance note may use `New Balance`. Activation amount and balance may be equal; reload amount and resulting balance often are not.

### 8.7 Summary and Store Tax

Applicable rows may include:

- Merchandise Subtotal.
- Item Discounts.
- Returns Subtotal.
- Gift Cards Activated/Reloaded or customer-facing stored-value issuance label.
- Net Merchandise Subtotal.
- Total Store Tax.

Avoid a universal `TAXABLE SUBTOTAL` row unless the value is semantically valid. Different Store Taxes can have different taxable bases.

Each Store Tax row uses the persisted Store Tax name:

```text
[A] Michigan Sales Tax
    6.000% on $29.99                        $1.80
[B] Local Prepared Food Tax
    1.250% on $5.50                         $0.07
Total Tax                                   $1.87
```

Tax Class controls applicability and belongs in operational review/provenance. It is not substituted for the Store Tax name on the customer receipt.

Single-tax, multiple-tax, no-tax, exempt/zero-rated, and return-tax-reversal scenarios require explicit fixtures.

### 8.8 Payments and refunds applied

Use a dedicated section:

```text
PAYMENTS APPLIED
Check                                      $10.00
External Card                             $40.00
```

For Cash payment, preserve all three facts:

```text
Cash Tendered                              $20.00
Cash Applied                               $11.86
Change                                      $8.14
```

For Cash refund:

```text
Cash Refund                                $12.00
```

Stored-value tender examples:

```text
Gift Card · #801....5940                   $20.00
Remaining Balance                           $3.75
```

```text
Refund to Store Credit                     $12.00
New Store Credit Balance                   $34.25
```

Receipt-safe references are category/policy driven. ShelfSense must not print arbitrary `external_reference` content by default.

### 8.9 Stored-value balances

Balance presentation must use the applicable persisted stored-value entry attached to the completed issuance/tender operation:

```text
operation
→ entry for the represented account/instrument
→ balance_after_cents
```

Do not use the account or gift card's current live balance on historical receipts.

Terminology:

- Redemption: `Remaining Balance`.
- Activation/reload/refund: `New Balance`.

For an operation with multiple entries, select the entry for the receipt line's account/instrument rather than taking an arbitrary last entry.

### 8.10 Counts, savings, barcode, and footer

Print when applicable:

- items sold/returned;
- customer savings from completed discounts;
- Code 128 transaction reference;
- configured header/footer/return-policy content.

These sections collapse cleanly when inapplicable.

## 9. Customer receipt state variants

### 9.1 Original receipt

No `REPRINT` designation.

### 9.2 Reprint

- Same receipt identity.
- Same completed commercial facts.
- Clear `REPRINT` designation according to final policy.
- No financial or inventory mutation.

### 9.3 Post-voided original

```text
*** POST-VOIDED ***
This transaction is no longer valid.
Post-voided by: S001-R01-T0000062
```

### 9.4 Post-void reversal

```text
*** POST-VOID ***
Original: S001-R01-T0000056
```

The reversal receipt preserves reversed merchandise, tax, tenders, and stored-value direction.

### 9.5 Pure stored-value transaction

Omit empty merchandise and Store Tax sections. Show issuance/reload, total, payments, balance, and voucher availability.

### 9.6 Pure return

Omit empty sales/issuance sections. Show returns, tax reversal, Refund Total, and refund tenders.

## 10. Gift-card voucher

The voucher is a separate protected print artifact.

Print:

- Store identity;
- issued time;
- amount;
- customer-facing program/type;
- full normalized gift-card number;
- Code 128 barcode of the full number;
- configured voucher footer.

The ordinary receipt remains masked.

### 10.1 First print

- Credential disclosure follows the existing first-print authority.
- A printer failure does not create another gift card or funding operation.
- Retry behavior must not accidentally consume or duplicate credential delivery outside the established lifecycle.

### 10.2 Recovery/replacement print

- Requires established management authorization and reason/audit behavior.
- Customer voucher carries an approved recovery designation, such as `REPLACEMENT PRINT COPY`.
- Internal recovery reason, manager identity, and audit reference belong in management evidence, not necessarily on the customer copy.

## 11. Gift-card cash-out receipt

This is a customer/store receipt distinct from a sales receipt.

Print:

- Store/Register and cashier;
- stable cash-out reference;
- masked gift-card number;
- persisted balance before where available/required;
- Cash paid;
- persisted balance after;
- customer-facing cash-out reason/policy where appropriate;
- acknowledgment/signature line if Store policy requires it;
- barcode/reference.

It must not print the full gift-card number or a live later balance.

## 12. Cash-custody slips

### 12.1 Shared content

- Document type and direction.
- Date/time and business date.
- Store/Register/session context where applicable.
- Stable operation reference.
- Amount.
- Customer-facing/internal reason name as appropriate.
- From and To cash locations for transfers.
- Signed entry effects.
- Performer and approver where recorded.
- Custody signature lines where Store policy requires them.

Do not print expected cash merely to decorate a custody slip.

### 12.2 Paid In

Show drawer effect as positive and the persisted source/reason/note fields that policy permits.

### 12.3 Paid Out

Show drawer effect as negative. Print payee only if an authoritative payee field exists; do not overload a note and relabel it as payee.

### 12.4 Cash Drop

Show drawer-to-safe direction and both immutable entry effects from the same atomic operation.

### 12.5 Cash Replenishment

Show safe-to-drawer direction and both immutable entry effects from the same atomic operation.

### 12.6 Reversal

The reversal is a separate document with:

- original operation reference/type/amount;
- reversal reference;
- compensating effects;
- reversal reason;
- performer/approver;
- explicit statement that the original remains on record.

## 13. Session close tape

The close tape is produced after the count and uses frozen close facts.

Print:

- Store/Register/session/cashier;
- business date and open/close times;
- opening float;
- Cash payments and refunds;
- gift-card cash-outs;
- Paid In/Out;
- Drops and Replenishments;
- relevant cash-operation reversals;
- frozen Expected Cash;
- Counted Cash;
- variance;
- variance reason/approval where applicable;
- counted-cash transfer to safe;
- drawer balance/status after close;
- `CLOSED` designation.

The tape must not be generated from a new live calculation after close.

## 14. X Report

### 14.1 Semantics

An X Report is:

- scoped to an open session;
- interim as of a specific print time;
- non-closing and non-mutating;
- visibly labeled `INTERIM — SESSION REMAINS OPEN`;
- permission-controlled.

Between sessions has no current X Report. Historical totals belong to session/Z reporting.

### 14.2 Sections

#### Identity

- Store/Register.
- business date.
- session/cashier.
- printed-at timestamp.

#### Merchandise activity

- Gross merchandise sales.
- discounts.
- net merchandise sales.
- returns.
- discount reversals.
- net returns.
- net merchandise activity.

#### Stored-value liability activity

- Gift cards activated.
- Gift cards reloaded.
- Other stored-value issuance/refund categories in scope.

Do not treat issuance as merchandise revenue.

#### Store Tax

Use persisted Store Tax names and amounts. Include bases/rates only if the report content contract requires that density.

#### Tenders

Show payment, refund, and net by tender category, with permitted child tender types. Tender totals reconcile to transaction settlement.

#### Cash custody

- Opening float.
- net Cash tender.
- gift-card cash-outs.
- Paid In/Out.
- Drops/Replenishments.
- reversals.

Expected Cash is omitted unless the viewer has the approved before-count permission. Known operation effects may still print without revealing expected balance.

## 15. Z Report

### 15.1 Semantics

A Z Report is:

- scoped to one finalized reporting period/store business date;
- based on finalized/frozen facts;
- visibly labeled `FINALIZED`;
- non-mutating on view or reprint.

### 15.2 Sections

- Store/business date/Z identity and finalizer.
- Merchandise sales, discounts, returns, and net activity.
- Stored-value liability activity.
- Store Tax summary.
- Tender payments/refunds/net.
- Session count and reconciliation summary.
- Cash transferred to safe.
- Safe/deposit/reconciliation status only to the extent already in the reporting-period contract.
- Finalized status and time.

Do not combine unlike merchandise, liability, tender, and custody facts into one ambiguous Net Total.

## 16. Screen preview and keyboard behavior

### 16.1 Host surfaces

The following screen surfaces may host or launch document printing:

- Transaction Complete.
- Transaction Review.
- gift-card recovery.
- cash-operation detail.
- Session Details/Closed Session.
- X Report.
- Z Report.
- report print surface.

### 16.2 Requirements

- Print/Reprint controls are reachable by keyboard.
- F10 behavior remains governed by Register shell authority where the surface is Register-owned.
- Initial focus is appropriate to the task, not silently trapped on hidden print markup.
- Enter does not trigger an unrelated print or navigation action.
- Print errors are announced accessibly and provide a keyboard recovery action.
- Authorized iframe printing does not strand focus permanently in the iframe.
- Printing a voucher does not also print the customer receipt, and vice versa.
- Screen preview communicates document status and scope even when it is not pixel-identical to the thermal output.

## 17. Component architecture

### 17.1 Current components to preserve or refactor

- `Pos::CustomerReceipt` completed-fact projection.
- `Pos::ReceiptIdentity`.
- `Pos::ReceiptMessages`.
- approved Code 128 encoder/helper.
- protected first-print/recovery services.
- receipt/voucher print controller.
- existing report presenters and finalized snapshots.

### 17.2 Customer-receipt projection direction

Prefer explicit collections/sections over one mixed line collection:

```text
CustomerReceipt
├── identity
├── merchandise_lines
├── stored_value_issuances
├── summary_rows
├── store_tax_groups
├── payment_or_refund_lines
├── stored_value_balance_notes
├── counts_and_savings
└── messages_and_barcode
```

Exact Ruby structures are implementation detail, but each section must expose persisted facts without view-level domain reconstruction.

### 17.3 Print partial direction

Decompose the current monolithic customer receipt into reusable, semantically named print partials/components where doing so eliminates duplication:

- receipt header/identity;
- document status;
- merchandise lines;
- stored-value issuance lines;
- summary and Store Tax groups;
- payments/refunds;
- balance notes;
- counts/savings;
- barcode/footer.

Do not create abstraction merely to share markup between semantically different documents. Cash slips and reports should reuse primitives, not pretend to be transaction receipts.

### 17.4 Screen versus print projections

Transaction Complete, Transaction Review, and the thermal receipt may have different density, but they should consume a coherent completed-transaction projection or clearly mapped projections. Avoid three independent sets of labels/formulas that can drift.

## 18. Scenario fixture suite

The supplied receipt mockup remains the complex mixed-sale fixture. Add focused fixtures for mutually exclusive branches.

### 18.1 Customer receipt fixtures

1. Ordinary single-tender sale.
2. Complex mixed sale with quantity, discount, unlinked return, two Store Taxes, issuance, and Cash/Card/Check.
3. Linked return with partial quantity and original reference.
4. Return-only Cash refund.
5. Mixed even exchange with no tender.
6. Post-voided original reprint.
7. Post-void reversal.
8. Gift-card activation only.
9. Gift-card reload with a preexisting balance.
10. Gift-card redemption plus Cash.
11. Store Credit refund.
12. Trade Credit redemption/refund where supported.
13. Used individual item with condition and unit identifier.
14. Open-price item showing only appropriate customer facts.
15. One Store Tax.
16. Multiple Store Taxes with different bases.
17. No-tax/exempt scenario.
18. Customerless sale.
19. Long-content stress receipt.
20. Missing historical description fail-closed/presentation fallback.

### 18.2 Other document fixtures

- First-print gift-card voucher.
- Recovered/replacement voucher.
- Gift-card cash-out receipt.
- Paid In.
- Paid Out.
- Cash Drop.
- Cash Replenishment.
- Cash-operation reversal.
- Zero-variance session close.
- Over/short session close.
- X Report with expected cash hidden.
- X Report with authorized expected cash.
- Finalized Z Report.
- Long thermal X/Z tape.

## 19. Automated acceptance requirements

### 19.1 Reconciliation

- Printed customer receipt rows reconcile to completed `signed_net_cents` under sale, return, mixed, issuance, and post-void scenarios.
- Store Tax group sum equals persisted transaction tax direction.
- Tender/payment/refund rows reconcile to completed settlement.
- Cash tendered equals Cash applied plus change.
- Cash-operation slip effects equal persisted entries.
- Session tape uses frozen close totals.
- Z report uses finalized period facts.

### 19.2 Historical integrity

- Reprint after current catalog price/name change preserves completed line facts.
- Reprint after current Store Tax configuration changes preserves completed Store Tax facts.
- Reprint after tender configuration changes preserves completed tender facts.
- Reprint after later stored-value activity prints the original operation's applicable `balance_after_cents`.
- Print/reprint creates no commercial rows or new receipt sequence.

### 19.3 Protection and authorization

- Ordinary receipt never contains a full gift-card number.
- Voucher contains the authorized full number and valid barcode.
- Prefix/last-four administrative inquiry cannot become possession authority for redemption, reload, cash-out, or voucher recovery.
- Expected Cash remains absent without the required permission.
- Arbitrary tender external references do not print without receipt-safe policy.

### 19.4 Print behavior

- Receipt-only, voucher-only, and tape-only modes select the correct artifact.
- Print controls do not appear in output.
- Print failure/retry does not duplicate posting.
- Long content remains readable at thermal width.
- Barcode payloads match their printed human-readable references.

## 20. Manual verification

For every fixture, inspect:

- 80 mm screen preview;
- actual browser print preview at effective driver width;
- black-and-white legibility;
- long-name wrapping;
- column alignment;
- barcode scannability;
- original versus reprint status;
- keyboard-only Print/Reprint flow;
- focus after print cancellation and print error;
- 200% zoom on host screen surfaces.

## 21. Recommended implementation sequence

### Slice R1 — Content and authority lock

- Lock document-family boundaries.
- Lock customer receipt ordering and conditional rows.
- Lock Store Tax naming.
- Lock stored-value `balance_after_cents` selection.
- Resolve receipt-safe tender-reference policy.
- Resolve remaining customer-facing labels.

### Slice R2 — Shared thermal primitives

- Establish print tokens, width, typography, dividers, status, money rows, totals, barcode, and footer primitives.
- Add stress fixtures and render verification.

### Slice R3 — Customer receipt projection and template

- Separate merchandise and stored-value sections.
- Implement Store Tax names/bases/rates.
- Implement payment/refund and Cash tendered/applied/change hierarchy.
- Implement receipt state variants and scenario tests.

### Slice R4 — Voucher and cash-out documents

- Revise first-print/recovery voucher presentation.
- Add cash-out receipt.
- Verify protected-number and audit boundaries.

### Slice R5 — Cash-custody slips

- Paid In/Out, Drop, Replenishment, and reversal print projections/templates.
- Add custody/signature policy hooks only where supported.

### Slice R6 — Session close tape

- Render frozen close and transfer facts.
- Verify blind-count boundaries and post-count visibility.

### Slice R7 — X/Z report revamp

- Apply report content contract.
- Separate merchandise, liability, tender, and custody sections.
- Enforce X interim and Z finalized semantics.
- Verify long thermal output.

### Slice R8 — Host-surface and closeout

- Align Transaction Complete, Transaction Review, report preview, and print actions with Register chrome.
- Complete keyboard/focus and printer-failure recovery.
- Remove superseded presentation paths and obsolete tests.
- Run the full fixture/manual matrix.

## 22. Pending decisions

1. Exact customer-facing label for net pretax merchandise activity; avoid universally assuming one taxable subtotal.
2. Whether and when a linked/unlinked return reason appears on the customer receipt.
3. Receipt-safe tender reference fields and formatting by tender category.
4. Exact original-print retry versus intentional-reprint designation.
5. Exact voucher recovery designation.
6. Which Store identity fields are legally required versus current presentation configuration.
7. Whether exempt/zero-rated treatment prints explicitly or through absence of a tax indicator.
8. Whether custody signature lines are always printed, configurable, or omitted for selected operation types.
9. X Report Store Tax detail density: amounts only versus name/rate/basis/amount.
10. Final Z safe/deposit section based on the accepted reporting-period scope.

## 23. Exit criteria

The revamp is complete when:

- every thermal artifact belongs to one document family;
- every document consumes named persisted authority;
- customer receipt fixtures cover sale, return, exchange, post-void, stored value, used merchandise, and tax variants;
- receipt tax rows use Store Tax names;
- historical stored-value balance notes use the applicable persisted `balance_after_cents`;
- X and Z retain distinct interim/final semantics;
- reports separate merchandise, stored-value liability, tender, and cash custody reconciliations;
- full gift-card numbers appear only on authorized vouchers;
- print, retry, reprint, and recovery are non-commercial and tested;
- all host print controls are keyboard reachable with reliable focus recovery;
- thermal print output passes the documented visual, stress, and barcode checks;
- superseded receipt/report markup and duplicate calculation paths are removed.
