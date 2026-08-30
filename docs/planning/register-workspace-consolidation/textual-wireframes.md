# ShelfSense Register Workspace

## Textual wireframes

**Companion to:** [Register workspace consolidation packet](README.md)  
**Status:** Proposed composition (not 6.7 implementation authority)  
**Purpose:** Define the visible structure, actions, variants, and transitions for each shared partial, primary/full surface, and reusable overlay.

**Authority:** These wireframes do not supersede Phase 6.7. See [routing-and-authority.md](routing-and-authority.md). Composition-MVP shortcut legends follow 6.7 except F10 after Slice 3 (Transactions → Register Menu). A mode-scoped SALE/TENDER map appears only as a labeled target concept and is not implementation authority until Slice 7C.

## How to read these wireframes

These are composition contracts, not pixel specifications. They describe information hierarchy, placement, action priority, and contextual variation. Bracketed text identifies an interactive control or conditional region.

```text
[Primary action]       solid commit or workflow-advance action
[Secondary action]     outline or neutral action
[Text action]          low-emphasis or inline action
<value>                authoritative or derived runtime value
{conditional}          rendered only when applicable
! message              warning, blocker, or error
```

Desktop wireframes show the intended Register composition. At constrained width or 200% zoom, secondary rails and drawers stack below the main region in logical DOM order. No action may depend on the visual column position.

Show actions and implemented shortcuts separately until Slice 6 accepts a replacement keyboard contract. Do not treat a future-target key as the composition-MVP binding.

# Part I — Shared shell and partials

## P1. Register workspace shell

Used by all four Register states and most Register-supporting surfaces.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ <Store> · Register <number>                          [Return to ShelfSense] │
│ <Business-date status> · Opened… (if any)                      {cashier}   │
├─────────────────────────────────────────────────────────────────────────────┤
│ {STATUS / PRIOR-DATE / BLOCKER STRIP}                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ {PAGE-LEVEL FEEDBACK / LIVE ANNOUNCEMENT}                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                         STATE-SPECIFIC CONTENT                              │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ {CONTEXTUAL FOOTER OR SHORTCUT LEGEND}                                     │
└─────────────────────────────────────────────────────────────────────────────┘

                              {OVERLAY HOST}
```

Behavior:

- F10 opens the Register Menu and returns focus to its launcher when closed.
- While a blocking overlay or approval dialog is open, F10 does not open another layer. The user must complete or leave the current layer first.
- **Return to ShelfSense** leaves the Register workspace in the **same tab**; it does not close a session.
- If leaving while the user owns an open session, the confirmation explicitly states that custody remains open.
- The shell never substitutes the calculated current date for an established reporting-period business date.

## P2. Register context header

One partial with state-dependent facts—not separate headers per page.

### Selector

```text
001 Main Street Books                                      [Return to ShelfSense]
Business date not selected  ·  {cashier}
```

### Closed

```text
001 Main Street Books  |  02 Front                         [Return to ShelfSense]
Business date not open  ·  Proposed date: Thu 27 Aug 26  ·  {cashier}
```

### Between sessions

```text
001 Main Street Books  |  02 Front                         [Return to ShelfSense]
Business Date Thu 27 Aug 26  |  Opened: … (omitted)  ·  {cashier}
```

### Own session

```text
001 Main Street Books  |  02 Front                         [Return to ShelfSense]
Business Date Thu 27 Aug 26  |  Opened: 27 Aug 26 09:04 am  ·  Jane Smith
```

### Occupied

```text
001 Main Street Books  |  02 Front                         [Return to ShelfSense]
Business Date Thu 27 Aug 26  |  Opened: 27 Aug 26 08:51 am  ·  {viewer}
```

Occupier identity stays in the status strip (**IN USE**), not as a substitute for the viewer cashier label.

### Supporting historical surface

```text
001 Main Street Books  |  02 Front                         [Return to ShelfSense]
Viewing: Session closed Aug 27, 2026 6:12 PM
```

## P3. State/status strip

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ REGISTER CLOSED                                                            │
│ Opening will establish the business date and begin cashier custody.         │
└─────────────────────────────────────────────────────────────────────────────┘
```

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ BETWEEN SESSIONS                                                           │
│ Business date Aug 27 remains open. Open another session or finalize Z.      │
└─────────────────────────────────────────────────────────────────────────────┘
```

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ ! PRIOR BUSINESS DATE STILL OPEN                                           │
│ Register 02 remains on Aug 26. Opening a session will continue Aug 26.      │
└─────────────────────────────────────────────────────────────────────────────┘
```

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ IN USE                                                                     │
│ Morgan Lee currently has custody of Register 02.                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

The text—not color alone—communicates state.

## P4. Feedback and alert region

```text
Success: Cash drop 00418 recorded. Expected till cash decreased by $300.00.
```

```text
! Unable to open session. The safe has $125.00 available; $200.00 requested.
  [Change opening float]  [Open Cash Management — authorized users]
```

```text
! This transaction changed in another request. Review the refreshed values.
```

Rules:

- Success and routine status use polite announcements.
- Blocking validation and failed commits use assertive alerts.
- The message explains the outcome and recovery; it does not merely say “Invalid.”
- Overlay errors stay inside the overlay unless the entire surface changed.

## P5. Register selector/status list

```text
Select a Register                                      Store: Main Street Books

┌─────────────┬─────────────────────────────────┬─────────────────────────────┐
│ Register    │ Status                          │ Action                      │
├─────────────┼─────────────────────────────────┼─────────────────────────────┤
│ Register 01 │ Your session · Aug 27           │ [Resume]                    │
│ Register 02 │ Between sessions · Aug 27       │ [Select]                    │
│ Register 03 │ In use by Morgan Lee · Aug 27   │ [View]                      │
│ Register 04 │ Closed                          │ [Select]                    │
│ Register 05 │ Prior date open · Aug 26        │ [Review]                    │
└─────────────┴─────────────────────────────────┴─────────────────────────────┘

[Return to ShelfSense]
```

Selecting another Register never implies that the user's existing session was closed. If the user owns a session elsewhere:

```text
! Register 01 remains open under your session.
  Selecting Register 04 will not close it.
```

If the cashier owns multiple open sessions and no valid Register binding resolves one, this selector is the landing surface. Every owned session is labeled **Your session — Resume**. Never present that cashier as having no session.

```text
! You have more than one open session.
  Resume the Register you want to continue. Switching does not close the others.
```

## P6. Transaction mode and prompt strip

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ SALE             Scan or enter an identifier                               │
│ ┌─────────────────────────────────────────────┐   Customer                  │
│ │ _                                           │   Jane Smith                │
│ └─────────────────────────────────────────────┘   [Change] [Remove]         │
│ / Product · . Pickup · − Return · F1 Cash · F2 Card · F10 Menu              │
└─────────────────────────────────────────────────────────────────────────────┘
```

Variants:

```text
RETURN           Scan an item or find the original receipt
TENDER           Balance due $18.42 · Enter cash presented
PICKUP           Find a ready customer request
GIFT CARD        Enter activation or reload amount
COMPLETION       Completing transaction… inputs locked
RECOVERY         Completion failed · Review the error and retry
```

The prompt does not move when modes change. Unavailable shortcuts are omitted rather than rendered as low-contrast decoration. Composition-MVP keys follow P12; do not show a future SALE/TENDER remap here.

## P7. Merchandise basket

```text
MERCHANDISE                                                     3 sold · 1 returned

┌───┬──────────────────────────────────┬──────┬────────┬───────┬─────────────┐
│   │ Description                      │ Qty  │ Price  │ Tax   │ Extended    │
├───┼──────────────────────────────────┼──────┼────────┼───────┼─────────────┤
│ › │ The Left Hand of Darkness        │   2  │ $9.99  │ Book  │     $19.98  │
│   │ Used · Good · SKU 2210000001234  │      │        │       │             │
│   │                                  │      │ Orig.  │       │             │
│   │                                  │      │ $11.99 │       │             │
├───┼──────────────────────────────────┼──────┼────────┼───────┼─────────────┤
│   │ RETURN · Beloved                 │  −1  │ $8.50  │ Book  │      −$8.50 │
│   │ From receipt 02-104281            │      │        │       │             │
└───┴──────────────────────────────────┴──────┴────────┴───────┴─────────────┘

Selected: The Left Hand of Darkness
[* Quantity]  [F7 Discount]  [F6 Price]  [Tax Class]  [F8 Remove]
```

Secondary lines may show condition, identifier, serialized unit, linked receipt, pickup allocation, price/discount explanation, or override provenance. Returns use negative display quantity and amount while preserving the domain's positive stored quantity plus explicit direction.

### Empty state

```text
MERCHANDISE

No merchandise yet.
Scan an identifier or press / to search.
```

## P8. Gift-card issuance section

```text
GIFT CARDS                                                  1 activated · 1 reloaded

┌───┬──────────────────────────────┬──────────────────────────┬──────────────┐
│   │ Operation                    │ Card / program           │ Amount       │
├───┼──────────────────────────────┼──────────────────────────┼──────────────┤
│   │ Activate gift card           │ ShelfSense Gift Card     │      $25.00  │
│   │ System-generated voucher     │ Number assigned at sale  │              │
├───┼──────────────────────────────┼──────────────────────────┼──────────────┤
│ › │ Reload gift card             │ •••• 1234                │      $10.00  │
│   │                              │ ShelfSense Gift Card     │              │
└───┴──────────────────────────────┴──────────────────────────┴──────────────┘

Selected: Reload •••• 1234                         [Edit] [Remove]
```

In the composition MVP, Edit is omitted until safe replacement exists. Gift-card issuance does not appear as a merchandise row and is labeled **Gift cards issued** in totals to avoid confusion with gift-card tender.

## P9. Transaction totals rail

```text
SUMMARY

Merchandise                                  $29.98
Discount                                     −$2.00
Returns                                      −$8.50
Gift cards issued                            $35.00
Tax
  Sales Tax 6.000%                            $1.17
  Local Tax 1.000%                            $0.20
──────────────────────────────────────────────────
TOTAL DUE                                    $55.85

Items sold 3 · returned 1
Gift cards activated 1 · reloaded 1
```

Directional variants:

```text
REFUND DUE                                   $12.41
EVEN EXCHANGE                                  $0.00
SETTLED                                        $0.00 remaining
```

Zero rows may be omitted only when the formula remains understandable. Tax groups must reconcile to authoritative net tax.

## P10. Applied tenders rail

```text
APPLIED TENDERS

┌───┬──────────────────────────────────────────────┬────────────┐
│ › │ Cash                                         │     $20.00 │
│   │ Presented $40.00 · Change $20.00             │            │
├───┼──────────────────────────────────────────────┼────────────┤
│   │ Gift Card •••• 1234                          │     $18.00 │
│   │ Balance remaining $0.00                      │            │
└───┴──────────────────────────────────────────────┴────────────┘

BALANCE DUE                                             $17.85
[Add Tender]

{Later: Selected Cash tender                    [Edit] [Remove]}
```

Refund variant:

```text
APPLIED REFUND TENDERS
Cash refund                                           $12.41
REFUND REMAINING                                       $0.00
```

Only applied amounts settle the transaction. Cash presented and change are supporting details.

## P11. Customer context card

### No customer

```text
CUSTOMER
No customer
[Find customer]
```

### Selected customer

```text
CUSTOMER
Jane Smith                                             [Change]
Store credit $18.00 · 1 pickup ready                   [Remove]
[View summary]
```

This card is contextual, not a basket row. Removing means detach the customer from the working transaction, not delete or clear the customer record.

## P12. Shortcut legend

### Composition MVP (implementation authority until Slice 6)

Phase 6.7 map with one approved change: F10 opens the Register Menu instead of Transactions.

```text
/ Product Search   . Pickup   − Return   * Quantity   + Cash/Tender
F1 Cash   F2 Card   F3 Check   F4 Other   F5 Stored Value
F6 Price  F7 Discount  F8 Remove  F9 Cancel Transaction
F10 Register Menu
```

### Future mode-scoped concept (not implementation authority)

Do not implement, display as the live legend, or treat as 6.7 replacement until Slice 6 formally supersedes the keyboard contract. `/` is not Discount. `-` is not Remove. `F5` is not Price. `F7` is not Tax. `F8` is not Return.

```text
TARGET CONCEPT — NOT IMPLEMENTATION AUTHORITY

SALE
<Product, customer, pickup, issuance and line-action keys — to be settled>

TENDER
F1 Cash · F2 Card · F3 Check · F4 Other · F5 Stored Value

GLOBAL
F10 Register Menu
Escape leaves the innermost reversible layer
```

Rules:

- Show only implemented and currently available actions.
- Printable keys do not trigger workspace commands while typing in an applicable field.
- Selection and active section are communicated by more than color.

## P13. Report totals groups

Shared presentation shell for X, closed-session, and Z reports; the supplied presenter determines authoritative values.

```text
SALES & RETURNS
Gross sales                                    $1,402.18
Discounts                                        −$42.00
Returns                                          −$81.50
Net tax                                           $78.42

TENDERS
Cash                                             $622.10
External card                                    $601.00
Gift card                                         $94.00
Store credit                                      $40.00

STORED VALUE
Activated                                        $150.00
Reloaded                                          $45.00
Redeemed                                          $94.00

OPERATIONAL CASH
Opening float                                    $200.00
Drops                                           −$400.00
Replenishments                                    $50.00
Paid-in                                           $10.00
Paid-out                                         −$15.00
```

Expected cash and variance are included only where the report and blind-count policy allow them.

## P14. Explicit confirmation frame

```text
Cancel transaction?

This will abandon the working transaction, including 3 merchandise items,
1 gift-card issuance, and 2 applied tenders.

[Keep Transaction]                         [Cancel Transaction]
```

Every confirmation uses action-specific labels. **Cancel** never ambiguously means both abandon a form and cancel a business record.

# Part II — Primary and full surfaces

## S1. Register selection

Used when no preferred/selected Register can be resolved or when Switch Register is chosen.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ 001 Main Street Books                                  [Return to ShelfSense] │
├─────────────────────────────────────────────────────────────────────────────┤
│ SELECT A REGISTER                                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│ [Register selector/status list — P5]                                        │
│                                                                             │
│ ! {You own an open session on Register 01.}                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

Outcomes:

- Resume own session.
- Select a closed or between-sessions Register.
- View an occupied Register.
- Return to ShelfSense.

## S2. Register closed / Open Register

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ [REGISTER CONTEXT HEADER — P2]                              [F10 Menu]      │
├─────────────────────────────────────────────────────────────────────────────┤
│ REGISTER CLOSED                                                            │
│ Opening establishes the business date and begins cashier custody.           │
├─────────────────────────────────────────────────────────────────────────────┤
│ OPEN REGISTER                                                               │
│                                                                             │
│ Proposed business date                                                      │
│ August 27, 2026                                                             │
│                                                                             │
│ Opening float                                                               │
│ [$ 200.00________________]                                                  │
│                                                                             │
│ Readiness                                                                   │
│ ✓ Register active   ✓ Safe initialized   ✓ Opening float available          │
│ { ! blocker and recovery action }                                           │
│                                                                             │
│ [Open Register]                                      [Select Another]       │
├─────────────────────────────────────────────────────────────────────────────┤
│ Customer Service: [Stored Value] [Transactions] [Customers] [Pickup Queue]  │
└─────────────────────────────────────────────────────────────────────────────┘
```

Commit result: create/open reporting period, transfer float, open session, create/resume working transaction, and navigate to S4.

## S3. Between sessions

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ [REGISTER CONTEXT HEADER — P2]                              [F10 Menu]      │
├─────────────────────────────────────────────────────────────────────────────┤
│ BETWEEN SESSIONS · BUSINESS DATE AUG 27, 2026                               │
├─────────────────────────────────────────────────────────────────────────────┤
│ TODAY'S REGISTER PERIOD                         OPEN ANOTHER SESSION          │
│                                                                             │
│ Sessions                                                                   │
│  1  Jane Smith    9:04 AM–1:12 PM      Closed                              │
│  2  Morgan Lee    1:20 PM–5:45 PM      Closed                              │
│                                                                             │
│ Transactions 184 · Net sales $3,421.18                                     │
│ [View Z-Period Status]                                                      │
│                                                Opening float                │
│                                                [$ 200.00_________]           │
│                                                [Open Session]               │
│                                                                             │
│ [Finalize Aug 27 Z]                          [Select Another Register]       │
└─────────────────────────────────────────────────────────────────────────────┘
```

Prior-date variant replaces the neutral status strip:

```text
! PRIOR BUSINESS DATE STILL OPEN
Register 02 remains on Aug 26. [Continue Aug 26 — Open Session]
                                  [Review and Finalize Aug 26 Z]
```

## S4. Active transaction workspace

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Main Street Books · Register 02 · Aug 27 · Jane Smith       [F10 Menu]      │
├─────────────────────────────────────────────────────────────────────────────┤
│ SALE     Scan or enter identifier                         CUSTOMER           │
│ [________________________________________]                Jane Smith [Change]│
│ / Product · . Pickup · − Return · F1 Cash · F2 Card · F10 Menu              │
├───────────────────────────────────────────────────────┬─────────────────────┤
│ MERCHANDISE                                           │ SUMMARY             │
│ [Merchandise basket — P7]                             │ [Totals — P9]       │
│                                                       │                     │
│ GIFT CARDS                                            ├─────────────────────┤
│ [Gift-card issuances — P8]                            │ APPLIED TENDERS     │
│                                                       │ [Tenders — P10]     │
├───────────────────────────────────────────────────────┴─────────────────────┤
│ [Feedback]                                                                  │
│ [Contextual command/action area]                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│ [Shortcut legend — P12]                                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

Narrow/zoomed composition:

```text
Header
Mode / prompt / customer
Merchandise
Gift Cards
Summary
Applied Tenders
Command area
Shortcut legend
```

The underlying transaction remains working throughout lookup, correction, and F10 inquiry layers.

## S5. Occupied Register

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Main Street Books · Register 02                             [F10 Menu]      │
├─────────────────────────────────────────────────────────────────────────────┤
│ IN USE BY ANOTHER CASHIER                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ Register 02                                                                 │
│ Business date       Aug 27, 2026                                            │
│ Accountable cashier Morgan Lee                                              │
│ Session opened      1:20 PM                                                 │
│ Duration            2h 14m                                                  │
│                                                                             │
│ [Select Another Register]                         [Return to ShelfSense]     │
│                                                                             │
│ {Manager tools} [View X Report] [Session Details] [Assisted Close]          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Customer Service: [Stored Value] [Transactions] [Customers] [Pickup Queue]  │
└─────────────────────────────────────────────────────────────────────────────┘
```

There is no ordinary **Enter**, **Resume**, or transaction link.

## S6. Completed transaction result

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Main Street Books · Register 02 · Aug 27 · Jane Smith       [F10 Menu]      │
├─────────────────────────────────────────────────────────────────────────────┤
│ TRANSACTION COMPLETE                                                        │
│ Receipt 02-104282                                                           │
├──────────────────────────────────────────┬──────────────────────────────────┤
│ RESULT                                   │ CUSTOMER                         │
│ Total paid                  $55.85       │ Jane Smith                       │
│ Cash presented              $40.00       │ Email receipt: preferred         │
│ Change due                  $20.00       │                                  │
│                                          │                                  │
│ Gift card activated         $25.00       │                                  │
│ Voucher must be printed                  │                                  │
├──────────────────────────────────────────┴──────────────────────────────────┤
│ [Print Receipt] [Print Gift-Card Voucher] [Send Receipt]                    │
│                                                                             │
│ [New Transaction]                                [Close Session]            │
│ [View Transaction Details]                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

Refund variant leads with **Refund completed** and the refund tender. If completion fails, the result heading becomes **Transaction not completed**, the error and safe recovery actions are shown, and committed facts are not implied.

## S7. Session close and reconciliation

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Main Street Books · Register 02 · Aug 27 · Jane Smith       [F10 Menu]      │
├─────────────────────────────────────────────────────────────────────────────┤
│ CLOSE SESSION                                                               │
│ This ends Jane Smith's custody. The Aug 27 Z period will remain open.       │
├─────────────────────────────────────────────────────────────────────────────┤
│ STEP 1 · READINESS                                                          │
│ ✓ No working transaction                                                    │
│ ✓ No completion pending                                                     │
│ ✓ Closing snapshot available                                                │
│                                                                             │
│ STEP 2 · COUNT                                                              │
│ Count all cash currently in the till                                        │
│ Closing cash count     [$ __________]                                       │
│ {Denomination detail}  [Enter denominations]                                │
│                                                                             │
│ STEP 3 · VARIANCE                                                           │
│ {After count/policy permits}                                                 │
│ Counted $412.00 · Expected $410.00 · Over $2.00                             │
│ Reason [Select reason v]   Note [____________________________]              │
│ {Approval required — [Authorize]}                                           │
│                                                                             │
│ [Return to Transaction]                              [Close Session]        │
└─────────────────────────────────────────────────────────────────────────────┘
```

For assisted close, accountable cashier and acting manager are both shown, and a reason is required.

## S8. Session closed result

```text
SESSION CLOSED

Register 02 · Jane Smith · Aug 27, 2026
Closed 6:12 PM · Counted $412.00 · Over $2.00

[Session report totals — P13]

The Register's Aug 27 reporting period remains open.

[Print Session Report]
[Open Another Session]  [Finalize Aug 27 Z]  [Leave Period Open]
```

**Leave Period Open** returns to S3; it does not return to an obsolete POS Home.

## S9. Z-period status

```text
Z-PERIOD STATUS                                      Business date Aug 27, 2026

Register 02 · Period open

SESSIONS
1  Jane Smith    9:04 AM–1:12 PM     Closed      [Details]
2  Morgan Lee    1:20 PM–5:45 PM     Closed      [Details]

CUMULATIVE TOTALS
[Report totals groups — P13]

FINALIZATION READINESS
✓ No open session
✓ No working transaction
✓ All closing snapshots complete
✓ No unresolved finalization blocker

[Back]                                      [Finalize Aug 27 Z]
```

With an open session, status is view-only and explains why finalization is unavailable.

## S10. Finalize Z confirmation/review

```text
FINALIZE AUG 27 Z?

Register 02
2 sessions · 184 completed transactions
Net sales $3,421.18 · Cash variance $2.00 over

Finalization closes this Register's Aug 27 reporting period.
It cannot be reopened through ordinary Register operation.

[Keep Period Open]                              [Finalize Aug 27 Z]
```

Commit leads to S11. Failed finalization returns to S9 with the refreshed blocker.

## S11. Finalized Z report

```text
Z REPORT · FINALIZED

Main Street Books · Register 02 · Aug 27, 2026
Finalized Aug 27, 2026 6:18 PM by Pat Manager

[Report totals groups — P13]

Sessions included: 2                                      [View Sessions]

[Print Z Report]  [Transactions]  [Return to Register]
```

This is an immutable historical presentation.

## S12. Transactions & Receipts

Large drawer or nested full surface; not a small modal.

```text
TRANSACTIONS & RECEIPTS                                             [Close]

Search [receipt, customer, item, register________________] [Search]
Date [From____] [To____]  Register [All v]  Status [Completed v]

┌────────────┬──────────┬──────────┬──────────────────┬───────────┐
│ Receipt    │ Date/time│ Register │ Customer         │ Net       │
├────────────┼──────────┼──────────┼──────────────────┼───────────┤
│ 02-104282  │ 2:41 PM  │ 02       │ Jane Smith       │ $55.85    │
│ 01-104281  │ 2:33 PM  │ 01       │ —                │ −$12.41   │
└────────────┴──────────┴──────────┴──────────────────┴───────────┘

Selected: Receipt 02-104282
[View Details] [Reprint Receipt]
{Owned session: [Begin Linked Return]}
{Authorized/eligible: [Post-Void] [Reprint Gift-Card Voucher]}
```

Closing returns to the invoking state. **Begin Linked Return** returns to S4 in Return mode.

## S13. Transaction/receipt detail

```text
RECEIPT 02-104282                                             [Back to Results]

Aug 27, 2026 2:41 PM · Register 02 · Jane Smith
Customer: Jane Smith

LINES
2 × The Left Hand of Darkness                              $19.98
1 × Gift-card activation                                   $25.00
1 × Beloved — RETURN                                       −$8.50
    Linked to receipt 02-104201

TOTALS
Merchandise $19.98 · Returns −$8.50 · Gift cards $25.00 · Tax $1.17
Net $37.65

TENDERS
Cash applied $20.00 · Presented $40.00 · Change $20.00
Gift Card •••• 1234 $17.65 · Remaining $0.35

[Reprint Receipt]
{[Begin Linked Return]} {[Reprint Voucher]} {[Post-Void]}
```

Post-void and linked-return provenance appear as banners and linked details, not hidden metadata.

## S14. Stored Value Inquiry

May use a full-height drawer so activity and contextual actions fit. Present three labeled find paths. Do not use one search field that might accept a complete number or prefix + last four.

```text
STORED VALUE INQUIRY                                                [Close]

[Scan or enter complete gift-card number]
For balance, reload, redemption, or cash-out eligibility.
Uses the exact possession-based lookup.

[Find customer store credit]
Search by customer identity.

{Authorized management}
[Find gift-card history by prefix and last four]
Masked inquiry only; cannot begin a value-moving action.
```

### Exact-number (possession) result

```text
ACCOUNT
ShelfSense Gift Card · •••• 1234
Status             Active
Available balance  $18.00
Reloadable         Yes
Redeemable         Yes
Expires            Never

RECENT ACTIVITY
Aug 27  Redeemed on 02-104282                          −$7.00
Aug 12  Reloaded on 01-103881                         +$10.00
Jul 01  Activated                                    +$15.00
[View All Activity]

{Own transaction: [Use as Tender] [Reload]}
{Eligible session: [Cash Out Eligible Balance]}
{Elevated management: [Protected number/voucher actions]}
```

### Customer store-credit result

```text
CUSTOMER STORE CREDIT
Jane Smith
Available          $18.00
[View activity]  [View Customer Summary]
{Own transaction: [Attach Jane Smith]}
```

### Prefix + last-four history result

```text
GIFT-CARD HISTORY (masked)
Prefix 6278 · Last four 1234

> •••• 1234 · Active · $18.00 · activated Aug 12
  •••• 1234 · Closed · $0.00 · closed Jul 01

Selected: masked candidate only.
This find does not prove possession.
[View masked detail]
Do not offer Use as Tender, Reload, Cash Out, or completion from this path.
```

Ordinary inquiry remains masked. Full-number access is a separate elevated action with purpose, approval where required, and audit. Prefix + last four must not feed Register scan routing or completion.

## S15. Customer Summary

```text
CUSTOMER SUMMARY                                                   [Close]

[Search customer________________________] [Search]

Jane Smith                                                        [Open Customer]
jane@example.com · (555) 555-0124

STORE CREDIT                         PICKUPS & REQUESTS
$18.00 available                     1 ready · 2 open
[View activity]                      [View ready pickup]

RECENT TRANSACTIONS
Aug 27 · Receipt 02-104282 · $55.85                 [View]
Aug 12 · Receipt 01-103881 · $24.10                 [View]

{Working transaction: [Attach Jane Smith]}
{Already attached: [Attached to Transaction] [Detach]}
```

Full customer merge and substantial editing remain in Customer workspace.

## S16. Pickup Queue

```text
PICKUP QUEUE                                                       [Close]

Status [Ready v]  Expiration [Next 7 days v]  Search [__________]

┌─────────┬─────────────────┬──────────────────────────┬──────────┐
│ Request │ Customer        │ Items                    │ Expires  │
├─────────┼─────────────────┼──────────────────────────┼──────────┤
│ CR-1842 │ Jane Smith      │ 2 items ready            │ Aug 29   │
│ CR-1829 │ Alex Chen       │ 1 item ready             │ Today !  │
└─────────┴─────────────────┴──────────────────────────┴──────────┘

Selected: CR-1842 · Jane Smith
The Dispossessed · Used/Good · Unit U-003812
Parable of the Sower · New · Qty 1

[View Request]
{Owned working transaction: [Add Eligible Items to Transaction]}
```

Without an owned session, it is useful but view-only for transaction allocation.

## S17. Till Activity

```text
TILL ACTIVITY                                      Session opened 9:04 AM

Filter [All activity v]                            {Expected cash $412.00}

┌─────────┬───────────────────────────┬─────────────┬──────────────┐
│ Time    │ Activity                  │ Amount      │ Performed by │
├─────────┼───────────────────────────┼─────────────┼──────────────┤
│ 9:04 AM │ Opening float             │ +$200.00    │ Jane Smith   │
│ 1:18 PM │ Cash drop CD-00418        │ −$300.00    │ Jane Smith   │
│ 2:02 PM │ Paid-out PO-00119         │  −$15.00    │ Jane Smith   │
│ 2:04 PM │ Reversal of PO-00119      │  +$15.00    │ Pat Manager  │
└─────────┴───────────────────────────┴─────────────┴──────────────┘

Selected: Cash drop CD-00418
Reason: Excess till cash · Safe increased $300.00
[View Details] {If eligible: [Reverse]}
```

This is a projection across authoritative records, not a new ledger. Expected cash is hidden when blind-count policy requires it.

## S18. Session Details

```text
SESSION DETAILS

Register            Register 02
Business date       Aug 27, 2026
Cashier             Jane Smith
Status              Open
Opened              9:04 AM
Opening float       $200.00
Transactions        82
{Expected cash}     $412.00

[View X Report] [Till Activity]
{Owner: [Close Session]}
{Manager/other owner: [Begin Assisted Close]}
```

Closed variant adds close time, count, variance, reason, approver, and assisted-close provenance.

## S19. Active Sessions

```text
ACTIVE SESSIONS                                                   [Close]

┌────────────┬─────────────────┬───────────────┬──────────┬────────────┐
│ Register   │ Cashier         │ Business date │ Opened   │ Status     │
├────────────┼─────────────────┼───────────────┼──────────┼────────────┤
│ 01         │ Jane Smith      │ Aug 27        │ 9:04 AM  │ Open       │
│ 03         │ Morgan Lee      │ Aug 27        │ 1:20 PM  │ Open 2h    │
│ 05         │ Alex Chen       │ Aug 26        │ 8:42 PM  │ Prior date!│
└────────────┴─────────────────┴───────────────┴──────────┴────────────┘

Selected: Register 03 · Morgan Lee
[Session Details] [X Report] {Authorized: [Assisted Close]}
```

## S20. X Report

Live open-session X only. Closed-session reporting belongs on **Session Details** (Slice 6B route), not a redefined S20 and not a second closed-session destination.

```text
X REPORT · INTERIM — SESSION REMAINS OPEN

Register 02 · Jane Smith · Business date Aug 27, 2026
Opened 9:04 AM

[Report totals groups — P13]

{Expected cash according to blind-count policy}

[Print X Report] [Session Details]
{Owner: [Return to Transaction]}
```

Viewing or printing never changes session state.

## S21. Cash operation form

Shared route-backed surface or overlay body for drop, replenishment, paid-in, and paid-out.

```text
CASH DROP                                                          [Close]

Move cash from Register 02 to the store safe.

Amount                         [$ 300.00________]
Reason                         [Excess till cash v]
Note                           [____________________________]

EFFECT
Register expected cash         {current value}
Cash drop                      −$300.00
Resulting Register cash        {result}
Store safe                     +$300.00

{Approval requirement/status}

[Keep Till Unchanged]                                [Record Cash Drop]
```

Direction/effect variants:

- Replenishment: Register `+`, safe `−`.
- Paid-in: Register `+`, no safe effect.
- Paid-out: Register `−`, no safe effect.

The form does not show expected amounts when prohibited by blind-count policy.

## S22. Gift-card cash-out

```text
GIFT-CARD CASH-OUT                                                [Close]

Card [Scan or enter________________] [Look Up]

ShelfSense Gift Card · •••• 1234
Available balance        $7.42
Eligible cash-out        $7.42

TILL EFFECT
Cash paid to customer    −$7.42
{Resulting expected cash}

{Reason / approval / jurisdictional explanation}

[Keep Balance]                              [Pay Out $7.42 in Cash]
```

The commit atomically records the stored-value operation and cash custody effect. It is never represented as generic paid-out.

## S23. Cash activity detail and reversal

```text
CASH DROP CD-00418

Aug 27, 2026 1:18 PM · Register 02 · Jane Smith
Amount             $300.00
Reason             Excess till cash
Register effect    −$300.00
Safe effect        +$300.00
Status             Posted

{Reversed by CR-00118 on Aug 27 at 2:04 PM}

[Back to Till Activity]                       {Eligible: [Reverse]}
```

Selecting Reverse opens **O19** (`#pos_cash_reversal_overlay` / cash-reversal-confirmation) with the original operation already identified; there is no generic reference-entry reversal launcher. (O10 remains gift-card issuance.)

## S24. Manager-assisted close

```text
MANAGER-ASSISTED CLOSE

Register 03 · Business date Aug 27, 2026
Accountable cashier       Morgan Lee
Acting manager            Pat Manager
Session opened            1:20 PM

Reason for assisted close [Cashier unavailable v]
Note                      [____________________________]

! This ends Morgan Lee's custody and records you as the closing actor.

[Keep Session Open]                           [Continue to Count]
```

Continue uses the session-close surface with accountable and acting users persistently visible.

# Part III — Menus and overlays

## O1. F10 Register Menu

The menu is structurally stable and state-filtered.

### Own session

```text
REGISTER MENU                                                        [Close]
Register 02 · Aug 27 · Jane Smith

CUSTOMER SERVICE                 TILL
[Stored Value Inquiry]           [Cash Drop]
[Transactions & Receipts]        [Cash Replenishment]
[Customer Summary]               [Paid-In]
[Pickup Queue]                   [Paid-Out]
                                 [Gift-Card Cash-Out]
                                 [Till Activity]

SESSION & REGISTER
[X Report]  [Session Details]  [Z-Period Status]
{[Active Sessions]}
[Switch Register]  [Close Session]
[Return to ShelfSense — session remains open]
```

### Closed

```text
REGISTER MENU

CUSTOMER SERVICE
[Stored Value Inquiry] [Transactions & Receipts]
[Customer Summary] [Pickup Queue]

REGISTER
[Open Register] [Switch Register] [Return to ShelfSense]
```

### Between sessions

```text
REGISTER MENU

CUSTOMER SERVICE
[Stored Value Inquiry] [Transactions & Receipts]
[Customer Summary] [Pickup Queue]

SESSION & REGISTER
[Open Session] [Z-Period Status] [Finalize Z]
{[Active Sessions]} [Switch Register] [Return to ShelfSense]
```

### Occupied

```text
REGISTER MENU

CUSTOMER SERVICE
[Stored Value Inquiry] [Transactions & Receipts]
[Customer Summary] [Pickup Queue]

REGISTER
{[X Report] [Session Details] [Assisted Close]}
{[Active Sessions]} [Switch Register] [Return to ShelfSense]
```

The Till group is omitted outside an owned session. F10 navigation does not discard the working transaction. While a blocking overlay or approval dialog is open, F10 does not open this menu.

## O2. Generic lookup overlay frame

```text
┌───────────────────────────────────────────────────────────────────┐
│ <LOOKUP TITLE>                                            [Close] │
├───────────────────────────────────────────────────────────────────┤
│ <Instruction>                                                     │
│ Search [________________________________________] [Search]         │
│ {filters}                                                         │
│ {feedback / loading / no results}                                 │
├───────────────────────────────────────────────────────────────────┤
│ RESULTS                                                           │
│ > <result 1 summary>                                              │
│   <result 2 summary>                                              │
│   <result 3 summary>                                              │
├───────────────────────────────────────────────────────────────────┤
│ SELECTED                                                          │
│ <selected-result detail and eligibility>                          │
│                                                                  │
│ [Back/Keep Existing]                         [Contextual Confirm] │
└───────────────────────────────────────────────────────────────────┘
```

Escape closes the overlay only when no nested dialog/submode is active. Focus returns to the launcher or transaction command field as appropriate.

## O3. Product search and staged merchandise selection

### Product search

```text
FIND PRODUCT

Identifier/SKU [__________________]
Title/author    [__________________] [Search]

> The Left Hand of Darkness · Ursula K. Le Guin
  9780441478125 · 3 sellable variants
  Left Hand of Darkness — search other edition

[Keep Searching]                                  [Choose Product]
```

### Variant selection

```text
CHOOSE VARIANT · The Left Hand of Darkness

> New · Trade Paper · $12.99 · 4 available
  Used · Good · $9.99 · 2 individual copies
  Used · Acceptable · $7.99 · 1 individual copy

[Back to Products]                               [Choose Variant]
```

### Individual unit selection

```text
CHOOSE USED COPY · Used / Good

> Unit U-003812 · $9.99 · light cover wear
  Unit U-003944 · $8.99 · owner inscription

[Back to Variants]                                  [Add to Sale]
```

Exact scans may bypass stages when resolution is unique and safe.

## O4. Customer lookup

```text
FIND CUSTOMER                                                    [Close]

Name, email, or phone [____________________________] [Search]

> Jane Smith · jane@example.com · (555) 555-0124
  Jane A. Smith · jsmith@example.net · (555) 555-8810

Selected: Jane Smith
Store credit $18.00 · 1 pickup ready · 2 open requests

[Keep Current Customer]                        [Attach Jane Smith]
{[Create Minimal Customer]}
```

Duplicate warnings appear before minimal creation. Full customer creation/merge is out of this overlay.

## O5. Transaction pickup lookup

```text
FIND PICKUP                                                      [Close]

Customer or request [__________________________] [Search]

> CR-1842 · Jane Smith · 2 items ready · expires Aug 29
  CR-1829 · Alex Chen · 1 item ready · expires today

Selected CR-1842
[✓] The Dispossessed · Unit U-003812
[✓] Parable of the Sower · Qty 1

[Keep Transaction Unchanged]           [Add 2 Pickup Items]
```

Commit preserves request/reservation provenance on the affected transaction lines.

## O6. Return chooser

```text
START RETURN                                                     [Close]

[Find Original Receipt]
Best when the customer's purchase can be identified.

[Unlinked Return]
Requires a reason and may require authorization.

[Keep Sale Mode]
```

The user is not asked to understand internal linked/unlinked terminology without explanatory copy.

## O7. Linked-return lookup and item selection

```text
RETURN FROM ORIGINAL RECEIPT                                    [Close]

Receipt/reference [________________________] [Find]

Receipt 02-104201 · Aug 12 · Jane Smith

RETURNABLE ITEMS
> The Dispossessed · Qty purchased 1 · Qty returnable 1 · $11.99
  Bookmark · Qty purchased 2 · Qty returnable 1 · $3.50

Quantity [1]
Reason   [Changed mind v]
Note     [____________________________]

[Keep Transaction Unchanged]                     [Add Return]
```

Ineligible lines state why they cannot be returned.

## O8. Unlinked return

```text
UNLINKED RETURN                                                  [Close]

Scan or enter item [____________________________] [Look Up]

The Dispossessed · New · Current price $11.99

Quantity          [1]
Reference price   [$11.99]
Return price      [$11.99]
Reason            [Receipt unavailable v]
Note              [____________________________]

{Approval required}
[Authorize action — O11]

[Keep Transaction Unchanged]                [Add Unlinked Return]
```

If commit validation fails, no return line is added and entered information remains available for correction.

## O9. Selected-record editor

### Quantity

```text
CHANGE QUANTITY                                                  [Close]

The Left Hand of Darkness · Used / Good
Current quantity  1
New quantity      [2]

[Keep Quantity 1]                             [Apply Quantity 2]
```

### Price/discount/tax

```text
CHANGE PRICE                                                     [Close]

The Left Hand of Darkness
Current price     $11.99
New price         [$9.99]
Reason            [Damaged cover v]
Note              [____________________________]

{Approval required — O11}

[Keep $11.99]                                  [Apply $9.99]
```

Discount and tax reuse the frame with domain-specific values and consequence text.

## O10. Gift-card issuance editor

### Add

```text
ADD GIFT CARD                                                    [Close]

1. Amount              [$25.00]
2. Program             [ShelfSense Gift Card v]
   Number authority    (•) System-generated  ( ) Scan/manual
3. Card                { [Scan or enter________________] }

Result: New card will be activated for $25.00.
{Existing card: Card •••• 1234 will be reloaded for $25.00.}

[Keep Transaction Unchanged]                   [Add Gift Card]
```

### Edit later

```text
EDIT GIFT-CARD ISSUANCE

Existing issuance remains unchanged until replacement succeeds.
<same fields populated>

[Keep Existing Issuance]                    [Replace Issuance]
```

## O11. Tender selection

```text
ADD TENDER                                                       [Close]

Balance due $55.85

1  Cash
2  Check
3  External Card
4  Gift Card
5  Store Credit
6  <Configured tender>

[Return to Sale]                                    [Choose Tender]
```

Only eligible payment/refund tenders appear. Composition MVP uses the P12 / 6.7 tender keys (F1–F5 and `+`). Numbered picker rows are pointer/arrow targets, not a second undocumented shortcut map.

## O12. Cash tender entry

```text
CASH TENDER                                                      [Close]

Balance due          $37.82
Cash presented       [$40.00]

Cash applied         $37.82
Change due            $2.18

[Choose Another Tender]                    [Apply Cash Tender]
```

Refund variant asks for refund amount, validates permitted direction, and does not use “cash presented.”

## O13. External/reference tender entry

```text
EXTERNAL CARD TENDER                                             [Close]

Balance due          $37.82
Amount               [$20.00]
Reference            [00000________________]

This records the external authorization reference; ShelfSense does not
perform the external authorization in this workflow.

[Choose Another Tender]                    [Apply Card Tender]
```

Fields vary by configured tender contract.

## O14. Stored-value tender entry

```text
GIFT CARD TENDER                                                 [Close]

Balance due          $30.00
Card                 [Scan or enter________________] [Look Up]

Gift Card •••• 1234
Available balance    $18.00
Requested payment    [$30.00]

Applied              $18.00
Remaining due        $12.00

Only $18.00 is available. ShelfSense will apply the available balance.

[Choose Another Tender]               [Apply $18.00 Gift Card]
```

A request above the remaining transaction balance fails. Only the actual applied amount is persisted.

## O15. Tender edit/atomic replacement

```text
EDIT CASH TENDER                                                  [Close]

Current tender
Applied $37.82 · Presented $40.00 · Change $2.18

Replacement
Cash presented       [$50.00]
Applied              $37.82
Change               $12.18

The current tender remains applied until the replacement succeeds.

[Keep Current Tender]                       [Replace Tender]
```

On failure, the original remains unchanged. Stored-value replacement safely reverses/reapplies value inside one domain operation.

## O16. Remove tender confirmation

```text
REMOVE GIFT CARD TENDER?

Gift Card •••• 1234 · $18.00 applied
Removing it will restore $18.00 to the card and increase the transaction
balance due to $30.00.

[Keep Tender]                                  [Remove Tender]
```

Removal is idempotent and preserves reversal/audit relationships.

## O17. Return to sale with applied tenders

```text
RETURN TO SALE?

This transaction has 2 applied tenders totaling $38.00.
Commercial lines cannot be changed while these tenders remain applied.

Returning to sale will safely remove all applied tenders and require the
transaction to be tendered again.

[Keep Tendering]                   [Remove Tenders and Return to Sale]
```

If the eventual domain contract permits retaining some tenders, the consequence text and service must reflect that exact behavior.

## O18. Controlled-action approval

```text
MANAGER AUTHORIZATION                                            [Close]

Requested action      Price change: $11.99 → $9.99
Item                  The Left Hand of Darkness
Reason                Damaged cover
Requesting cashier    Jane Smith
Required permission   POS price override

Approver username     [________________________]
Approver password     [________________________]

[Keep Existing Price]                              [Authorize]
```

Approval success returns to the underlying form, which revalidates and commits. Approval alone does not guarantee that a now-stale action will succeed.

## O19. Cash reversal confirmation

```text
REVERSE CASH DROP CD-00418?

Original operation    Cash drop
Amount                $300.00
Original effect       Register −$300.00 · Safe +$300.00
Reversal effect       Register +$300.00 · Safe −$300.00

Reason                [Operation entered in error v]
Note                  [____________________________]
{Approval — O18}

[Keep Original Operation]                       [Record Reversal]
```

The original operation is preselected and immutable in this layer.

## O20. Leave Register workspace confirmation

```text
RETURN TO SHELFSENSE?

Your session on Register 02 will remain open under your name.
You can resume it later from Register.

[Stay in Register]                         [Return to ShelfSense]
```

This is not shown when no session-custody consequence exists unless unsaved form state would be lost.

## O21. Cancel transaction confirmation

```text
CANCEL TRANSACTION?

Transaction contents
3 merchandise items · 1 return · 1 gift-card issuance
2 applied tenders totaling $38.00

ShelfSense will abandon the working transaction and safely reverse applicable
temporary tender/stored-value effects.

[Keep Transaction]                         [Cancel Transaction]
```

## O22. Finalization blocker detail

```text
Z CANNOT BE FINALIZED                                             [Close]

Register 02 · Business date Aug 27

Resolve the following:
! Session for Morgan Lee remains open.                  [View Session]
! Closing snapshot is incomplete.                       [Resume Close]

[Return to Z-Period Status]
```

The layer reports authoritative blockers and links to safe resolution; it does not offer a bypass.

# Part IV — Cross-surface behavior

## Overlay precedence

When Escape is pressed:

1. Close the active nested approval/confirmation without committing.
2. Close the active lookup/editor overlay without committing.
3. Leave the current transaction submode.
4. Clear the current prompt where that is a reversible, understood action.
5. Otherwise do nothing.

Escape never cancels a transaction or closes a session.

While a blocking overlay or approval dialog is open, F10 does not open the Register Menu. The user must complete or leave the current layer first.

## Return-context rules

| Invoking context | Closing temporary layer returns to |
|---|---|
| Active transaction | Same transaction, prior mode/selection, restored focus |
| Closed Register | Closed state body |
| Between sessions | Same period state body |
| Occupied Register | Same occupied Register |
| Transactions search | Same filters, page, and selected result |
| Till Activity | Same activity filter and selected operation |
| Session Details | Same session record |

## Responsive transformation

At high zoom or constrained width:

- Header facts wrap without losing labels.
- F10 remains reachable near the beginning of focus order.
- The transaction basket remains first.
- Summary and Applied Tenders stack below the commercial basket.
- Full-height drawers become full-viewport layers where necessary.
- Dense tables may transform to labeled row cards; horizontal scrolling is a last resort and must not hide actions or totals.
- Primary and secondary actions remain adjacent in logical order even if visually stacked.

## Empty, loading, and failure states

Every search/inquiry surface provides:

```text
Loading…
No results for “<query>”. [Clear Search]
Unable to complete the search. <safe explanation> [Try Again]
```

Every commit surface distinguishes:

- validation failure: correct entered data;
- authorization failure: action remains unchanged;
- stale/concurrent failure: refreshed facts and review required;
- external failure: committed versus uncommitted effects stated explicitly;
- success: resulting authoritative record/reference and next action.

## Recommended initial prototype set

The first interactive prototype should cover these representative compositions before implementation:

1. Register closed with ready and blocked opening variants.
2. Between sessions with current-date and prior-date variants.
3. Occupied Register as cashier and as authorized manager.
4. Active transaction with mixed sale, return, gift-card issuance, and split tenders.
5. F10 in all four states.
6. Stored Value Inquiry: exact-number possession, customer store credit, and (when authorized) masked prefix/last-four history.
7. Transactions & Receipts leading into a linked return.
8. Session close, result, Z status, and finalization.
9. Till Activity leading into an eligible reversal.
10. Transaction workspace and the two largest drawers at 200% zoom.

