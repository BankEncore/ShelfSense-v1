# Phase 11 follow-up — Register workflow and tender UX

Status: **Proposed follow-up specification**  
Target: **Before the Phase 10 release**  
Depends on: Phase 10 stored value, Phase 11 cash accountability, existing Register workspace

## 1. Purpose

Phase 10 and Phase 11 added stored-value and cash-accountability capabilities to an already operational Register. The individual workflows are valid, but the Register experience now reflects the order in which features were added rather than the way a cashier works.

This follow-up recomposes the existing Register around five human questions:

1. Where am I and is my session ready?
2. What am I doing to this transaction?
3. What can I scan, enter, or press now?
4. What is in the transaction?
5. What is due, and which tenders have been applied?

The work preserves the current server-authoritative Rails services, `PosSession`, working `PosTransaction`, tender facts, stored-value facts, cash-accountability facts, optimistic locking, completion leases, and reversal behavior.

## 2. Product principles

- The Register is a purpose-built cashier instrument, not a flat navigation menu.
- With no active target session, show a small Register entry surface.
- With an active target session, the transaction workspace is the Register landing page.
- Show the next likely action prominently; progressively reveal customer-service, till, shift, and manager work.
- Keep scanning and keyboard operation primary without making pointer operation inaccessible.
- Display only commands meaningful in the current mode.
- Pending transaction and tender intent may be corrected. Completed facts remain immutable.
- Do not copy or reshape domain facts merely to simplify presentation.
- Preserve the Warm Parchment hierarchy: restrained canvas, elevated work surfaces, rust for the primary commit, outline for alternatives, ghost/link for low-emphasis navigation, and strong focus/selection treatment.

## 3. Scope

### In scope

- no-session Register entry surface;
- active-session routing directly to the transaction workspace;
- multiple-owned-session selection edge case;
- compact Register header;
- command console above the basket;
- revised keyboard contract and dynamic keyboard legend;
- F10 Register menu;
- basket, customer/pickup context, gift-card issuance, totals, and tender composition;
- streamlined gift-card issuance;
- tender selection, entry, review, arbitrary pending-tender removal, and pending-tender editing;
- partial stored-value application;
- focus, keyboard, zoom, accessibility, error recovery, and system-test updates.

### Out of scope

- changes to Register, Terminal, session, or Z identity;
- a new drawer or custody model;
- new tender types or payment integrations;
- changing completed transaction immutability;
- changing stored-value or cash-ledger authority;
- offline Register behavior;
- general navigation redesign outside the Register family;
- bank confirmation or financial reconciliation;
- new hold/suspend-transaction behavior unless separately approved.

## 4. Entry and routing

### 4.1 No active target session

`GET /pos` renders the Register entry surface when the current user has no resolvable owned open session.

The surface emphasizes:

- store;
- signed-in user;
- preferred Register and availability;
- one primary **Open Register** action;
- choose another Register;
- Transactions & receipts;
- Session and Z reports;
- manager-only active-session/oversight links when authorized;
- Return to ShelfSense as low-emphasis navigation.

Do not display session-only actions such as drop, paid-in/out, gift-card cash-out, or current X report.

Expected cash must not be disclosed here without `cash.view_expected_before_count`.

### 4.2 Active target session

When the browser is bound to an owned open session, or the cashier has exactly one open session, `GET /pos` redirects to that Register workspace.

There is no separate active-session home.

### 4.3 Multiple owned sessions

The current model can contain multiple open sessions for one cashier. If the browser has no bound Register and more than one owned session exists, the entry surface shows the sessions and requires the cashier to choose one to resume. It must not behave as though no session exists or silently choose one.

This follow-up does not add a one-open-session-per-cashier invariant.

### 4.4 Occupied preferred Register

If another cashier owns the preferred Register session, show who owns it and offer another Register. Manager exception actions remain visually separate.

## 5. Transaction workspace composition

The stable vertical order is:

1. compact session header;
2. command console;
3. dynamic keyboard legend;
4. transaction context and basket with totals/tenders rail.

### 5.1 Compact header

The default header contains one compact row:

```text
Store 000 · Store Name · Register 00 · Business date Aug 27, 2026     Cashier: Admin User · F10 Menu
```

Do not retain permanent POS Home, Transactions, X Report, and Close Register links in the header. F10 owns infrequent navigation and session tools.

Show a separate status banner only for exceptional state, including a prior business date, completion recovery, or manager-assisted context.

### 5.2 Command console

The command console has a stable position and reasonably stable height:

```text
SALE
Scan an item or enter an identifier
[________________________________________________]
```

It owns:

- mode label;
- current instruction/field label;
- primary entry field;
- conditional reference/card fields;
- routine feedback and errors;
- the dynamic keyboard legend.

Routine confirmation and error content must not cause the basket to jump materially. Preserve the existing ARIA live behavior: routine status is polite; actionable error is assertive.

### 5.3 Transaction context

Render compact context only when present:

```text
Customer: Jane Smith                                      Change · Clear
Pickup: Request R-1042 · 2 items
```

Do not reserve a large permanent customer panel. F2 customer search and F3 pickup should produce visible transaction context without introducing another persistent form.

### 5.4 Merchandise basket

Columns:

- line number;
- signed quantity;
- description and secondary identifiers/provenance;
- tax;
- unit amount and adjustment metadata;
- signed extension.

The working basket may display newest line first using `line_number DESC`. This is presentation only; completed receipt/envelope ordering does not change.

Selection uses more than color: tinted row, inset brand indicator, strong focus, `aria-selected`, and an optional textual marker. Arrow navigation follows visual order. After removal, selection moves to the nearest predictable visible row.

Return lines retain original-transaction and reason provenance. Controlled price, discount, and tax state remain visible as concise secondary text.

### 5.5 Gift-card issuance section

Gift-card issuances remain `PosStoredValueIssuance` facts. Do not create fake `PosTransactionLine` rows or a shared persisted sequence.

Display issuances as an adjacent section in the basket area:

```text
Gift cards
Gift Card · Activation                         $50.00
System generated · Number assigned at completion
```

or:

```text
Gift Card · Reload                             $25.00
•••• 4567
```

The section:

- appears only when populated;
- is compact;
- is read-only once tendering/completion prevents edits;
- exposes removal through the existing issuance-removal command;
- does not participate in merchandise line selection or quantity/discount/price/tax shortcuts.

### 5.6 Totals and tender rail

The right rail is approximately 17–20rem and remains visible while the basket scrolls.

Before tendering:

```text
Sales subtotal       $90.50
Discounts             -4.00
Returns              -10.00
Gift cards            50.00
Tax                    1.32

AMOUNT DUE            $77.82
```

Use **Returns** for negative merchandise. Use **Refund due** only when settlement direction is a refund.

During tendering, split transaction totals from applied tenders and emphasize Remaining:

```text
Amount due            $77.82

Applied tenders
> Credit Card         $10.00
  Gift Card           $25.00

REMAINING             $42.82
```

Tender references use configured, safe labels and masking. Never imply display of full card credentials.

## 6. Keyboard contract

### 6.1 Sale-entry mapping

| Action | Key |
|---|---:|
| Remove selected merchandise line | `-` |
| Quantity | `*` |
| Discount | `/` |
| Tender | `+` |
| Product search | F1 |
| Customer search | F2 |
| Pickup | F3 |
| Sell/reload gift card | F4 |
| Price | F5 |
| Reserved | F6 |
| Tax class | F7 |
| Return | F8 |
| Cancel transaction | F9 |
| Register menu | F10 |

Do not assign an action to F6 only to fill the sequence.

### 6.2 Tender shortcuts

Tender digits operate only in Tender selection/review, never as global scan-field sequences.

| Tender | Sequence |
|---|---:|
| Cash | `+1` |
| Check | `+2` |
| Credit card | `+3` |
| Gift card | `+4` |
| Store credit | `+5` |
| Other configured tenders | `+6` through `+9` |

Map fixed categories intentionally; fill other positions from active configuration using actual tender names. Refund mode omits types that do not permit refunds. Do not show two indistinguishable “Other” choices.

### 6.3 Escape

Escape is **Back / Clear Entry**, not a destructive transaction command.

Priority:

1. close the topmost overlay and restore its invoking focus;
2. abandon the current unposted prompt/edit and return to its parent mode;
3. clear the current command field;
4. leave quantity/price/discount/tax/tender-entry mode;
5. clear line selection at base sale entry when appropriate;
6. otherwise perform no destructive action.

F9 exclusively owns Cancel Transaction and its confirmation.

### 6.4 Dynamic legend

Display only currently meaningful commands. Visually distinguish key and label, for example `[F1] Product`.

Sale entry example:

```text
[*] Qty  [/] Discount  [+] Tender  [F1] Product  [F2] Customer
[F3] Pickup  [F4] Gift Card  [F5] Price  [F7] Tax  [F8] Return  [F9] Cancel  [F10] Menu
```

Selected merchandise example:

```text
[-] Remove  [*] Qty  [/] Discount  [F5] Price  [F7] Tax  [Esc] Clear  [F10] Menu
```

Tender selection example:

```text
[1] Cash  [2] Check  [3] Credit Card  [4] Gift Card  [5] Store Credit  [Esc] Back
```

The visible legend and implemented key behavior are one tested contract.

## 7. F10 Register menu

F10 opens a modal overlay over the workspace and preserves the working transaction beneath it.

```text
Register Menu

Customer service
  Stored-value inquiry
  Transactions & receipts

Till
  Drop cash
  Replenish till
  Record paid-in
  Record paid-out

Session
  X report
  Close session
```

Behavior:

- F10 or Esc closes the menu;
- Up/Down changes selection;
- Enter activates;
- Tab remains trapped;
- focus returns to the prior command/control;
- headings organize the menu but are not selections;
- Close Session is last and visually separated;
- permissions are enforced server-side and reflected in availability;
- disabled items explain why they are unavailable.

Commercial content, tendering, completion pending, and completion recovery may disable mutating till/session actions. X report and history may remain available when safe, but must preserve a clear return to the working transaction. Do not navigate to a service form that will predictably reject the current transaction state.

## 8. Gift-card issuance flow

F4 opens a focused modal. Field order:

1. Amount;
2. Program/card choice, including new system-generated card;
3. Scan/enter card only when applicable.

Example choice presentation:

```text
Amount
[$50.00_______]

Card
● New system-generated gift card
○ Standard Gift Card — scan or enter card
○ Promotional Gift Card — scan or enter card
```

Default to the ordinary system-generated program when configured. The common path should be `F4 → amount → Enter → Enter`.

Do not normally ask the cashier to choose Activation versus Reload. For a scanned/manual card:

- unused valid card → activation;
- active reloadable card → reload;
- closed, revoked, unknown, non-reloadable, or program-mismatched card → explicit rejection.

Enter advances to the next required field. A successful scan may submit automatically. Esc moves back one step; from Amount it closes the modal. After add, clear sensitive input, close the modal, announce the outcome, update totals, and return focus to the scan field.

## 9. Tender workflow

Tendering is a small settlement workspace, not one long undifferentiated input mode.

States:

```text
Tender selection → Tender entry → Tender review
```

### 9.1 Tender selection

`+` enters Tender selection. `+digit` may select a type directly.

```text
TENDER · Remaining $77.82

1 Cash          2 Check          3 Credit Card
4 Gift Card     5 Store Credit   6 Other
```

### 9.2 Tender entry

Prompt only for fields meaningful to the chosen tender.

#### Cash

Prompt for Cash received, defaulting to exact remaining and selecting the value for replacement. Cash may exceed remaining because it produces change.

#### Credit card

Prompt for amount, default remaining, then configured reference only when required/optional.

#### Check

Prompt for amount, default remaining, then check/reference number.

#### Gift card redemption

Identify the card first, display available balance, then prompt for payment amount defaulted to `min(available, remaining)`.

#### Store/trade credit

Use the attached customer to resolve the account. Display available balance and prompt for payment amount defaulted to remaining. If no customer is attached, open customer search and resume the tender flow afterward.

#### Other

Use the actual configured tender name and reference policy.

### 9.3 Tender review

After a partial tender, return to a stable review state instead of leaving another prefilled amount active:

```text
TENDER · Remaining $42.82

> Credit Card · •••• 1234       $10.00
  Gift Card · •••• 4567         $25.00

[+] Add  [Enter] Edit  [-] Remove  [Esc] Back
```

Up/Down selects a pending tender. Enter edits the selected tender. `-` removes only the selected tender. `+` adds another.

### 9.4 Arbitrary pending-tender removal

The existing `Pos::RemoveWorkingTender` already accepts a specific tender. The UI must send the selected `tender_id`, not always the last tender.

After removal:

- recalculate Remaining;
- select the nearest remaining tender;
- remain in Tender review;
- announce tender and amount removed;
- return to selection/sale entry when none remain according to the current parent state.

### 9.5 Editing pending tenders

Working tenders are draft settlement intent; completed tenders are immutable.

Add an atomic `Pos::ReplaceWorkingTender` (name may vary):

1. lock the working transaction using expected `lock_version`;
2. locate the selected tender under that transaction;
3. calculate remaining due excluding the original;
4. validate the replacement as a new pending tender;
5. replace tender and stored-value detail atomically;
6. preserve tender position/number where practical;
7. touch/increment the transaction;
8. roll back completely on failure.

Do not implement editing as separate browser delete and add requests. A failed replacement must leave the original pending tender intact.

### 9.6 Returning to sale

Escape from an active tender prompt abandons that unposted prompt and returns to Tender review without altering existing tenders.

Returning to merchandise editing remains explicit because commercial changes invalidate settlement:

```text
Return to sale?
The 3 pending tenders will be removed. No payment has been completed.
```

Continue using `Pos::AbandonTender` for the confirmed remove-all behavior. Rename/present it as **Return to sale**, not the only way to correct a tender.

### 9.7 Completion

- Exact settlement continues into completion automatically.
- Cash may create change.
- Non-cash cannot exceed remaining due.
- Completion pending/in-flight blocks tender mutation.
- Completion failure prioritizes Retry Complete and Return to sale.
- Retry Complete must not apply any tender twice.

## 10. Partial stored-value application

Cashiers should enter the payment amount the customer wants to apply, commonly the full balance due. They should not calculate the available stored-value balance.

For payment redemption:

```text
requested amount <= remaining due
applied amount = min(requested amount, available stored-value balance)
```

Continue rejecting requested amount greater than remaining due to avoid hiding an input error.

Example:

```text
Amount due             $77.82
Store credit available $25.00
Cashier requests       $77.82
Store credit applied   $25.00
Remaining              $52.82
```

Persist only actual applied amount as `PosTender#amount_cents`. Requested amount may be returned in a service result or retained as non-authoritative audit/command metadata, but is not a tender or stored-value economic fact.

Apply the rule to payment redemption from gift card, store credit, trade credit, and other balance-backed stored value. Do not apply it to issuance/reload, stored-value refunds, gift-card cash-out, or ordinary external tenders.

At tender entry, lock the working transaction, resolve the account, read current balance, calculate applied amount, and create/replace the pending tender. Completion still locks and revalidates the stored-value account. If availability changes before completion, do not silently reduce a settled tender; fail recoverably and require tender review.

## 11. Authorization and disclosure

- Preserve existing `pos.transact`, stored-value, cash-operation, session, and manager permissions.
- Do not rely on hidden menu items as authorization.
- Expected cash remains hidden unless the user holds `cash.view_expected_before_count`.
- F10 menu availability is calculated from permission and transaction/session state.
- Manager-assisted close remains an exception path and must not be presented as ordinary cashier work.

## 12. Accessibility and interaction requirements

- Preserve scan-field focus after successful ordinary commands.
- Every overlay traps focus, has an accessible name, closes predictably, and restores invoking focus.
- Function keys are claimed only inside the active Register workspace; browser keyboard locking remains best-effort.
- Pointer-accessible controls remain available for every keyboard command.
- Selection is not communicated by color alone.
- Dynamic mode and feedback changes are announced without excessive repetition.
- At 200% zoom, command field, basket, totals, tender review, and menu remain operable without loss of content or action.
- The layout supports the existing Register minimum width deliberately; narrower behavior must be tested rather than accidentally overflowing.
- Completion/recovery controls override ordinary keyboard commands.

## 13. Implementation boundaries

Reuse and extend:

- `Pos::HomesController` and `Pos::BaseController` session resolution;
- `pos/workspaces/_surface.html.erb`;
- `register_workspace_controller.js`;
- existing Turbo workspace replacement;
- existing picker/control overlay patterns;
- `Pos::RemoveWorkingTender`, `Pos::AbandonTender`, and existing add-tender services;
- existing stored-value issuance/removal endpoints;
- existing F10 destination pages.

New server behavior should be limited primarily to:

- active-session redirect/chooser behavior;
- atomic pending-tender replacement;
- partial stored-value application and result feedback;
- presentation helpers/view models needed for composition.

Do not change completed transaction, tender, stored-value, cash, receipt, close, or Z authority.

## 14. Proposed slices

### RUX-1 — Entry and static composition

- active-session redirect;
- no-session entry surface;
- multiple-session chooser;
- compact header;
- command-console placement;
- basket/totals layout;
- expected-cash disclosure correction.

### RUX-2 — Keyboard contract and legend

- replace old F-key assignments;
- add `+digit` tender selection;
- implement contextual Escape;
- add dynamic legend;
- update visible buttons, documentation, and keyboard tests.

### RUX-3 — Register menu

- grouped F10 overlay;
- state/permission availability;
- navigation and return behavior;
- focus and accessibility tests.

### RUX-4 — Basket and gift-card coherence

- newest-first merchandise presentation;
- compact customer/pickup context;
- adjacent gift-card issuance section;
- streamlined F4 modal;
- refined totals/tender rail.

### RUX-5 — Tender correction and stored-value application

- Tender selection/entry/review modes;
- arbitrary selected-tender removal;
- atomic pending-tender replacement;
- partial stored-value application;
- concurrency, completion, and recovery tests.

RUX-5 may be split if review shows atomic replacement and stored-value behavior should land separately, but both must use the same Tender review model.

## 15. Required acceptance scenarios

### Entry and context

1. No session renders the entry surface.
2. One owned active session redirects to its workspace.
3. Bound browser selects its owned session.
4. Multiple unbound owned sessions require selection.
5. Occupied preferred Register identifies the other cashier without allowing ordinary entry.
6. Expected cash is not disclosed without permission.

### Keyboard and focus

7. Every published sale-entry key performs the documented action.
8. Old conflicting shortcuts no longer perform their former action.
9. `+1` through configured tender digits work only in tender context.
10. Dynamic legend matches enabled behavior.
11. Escape follows overlay/prompt/mode/field precedence.
12. F9 remains the only transaction-cancel shortcut.
13. Turbo updates and overlay close restore correct focus.

### F10

14. F10 opens/closes the menu and traps focus.
15. Menu groups and order match the contract.
16. Permissions and commercial/tender/completion state disable appropriate actions.
17. Disabled actions explain why.
18. Transactions/X report preserve a clear return to the working transaction.

### Basket and gift cards

19. Newest merchandise line appears first and arrow selection follows visual order.
20. Receipt/completed-fact order remains unchanged.
21. Customer and pickup context appear compactly when present.
22. Gift-card activation/reload appears in the adjacent section, not as merchandise.
23. System-generated issuance accurately says number is assigned at completion.
24. F4 order is Amount → Card/program → Card number if applicable.
25. Common system-generated issuance completes with minimal keystrokes.
26. Existing active card becomes reload without a redundant type choice.
27. Removing an issuance uses its existing domain command.

### Tender review and correction

28. Partial tender returns to Tender review with Remaining emphasized.
29. Up/Down selects any pending tender.
30. `-` removes only the selected pending tender.
31. Enter edits the selected tender.
32. Failed edit leaves the original tender intact.
33. Successful edit preserves ordering and recalculates Remaining.
34. Escape from edit preserves the original.
35. Return to sale explicitly confirms removal of all pending tenders.
36. Exact settlement enters completion once.
37. Completion pending/failure blocks tender mutation and preserves retry idempotency.

### Stored value

38. Requested amount below available applies requested.
39. Requested amount equal to available applies requested.
40. Requested amount above available but within remaining applies available.
41. Requested amount above remaining is rejected.
42. Zero available is rejected.
43. Gift-card, store-credit, and trade-credit payment use the same cap rule.
44. Tender persists actual applied amount only.
45. Partial application returns to Tender review with correct Remaining.
46. Concurrent account balance change fails safely during completion without silent underpayment.

### Accessibility and resilience

47. Overlay names, focus trap, focus return, and announcements pass system coverage.
48. 200% zoom retains usable command, basket, totals, and menus.
49. Pointer users can invoke all keyboard actions.
50. Transport failure preserves the working transaction and existing completion-recovery contract.

## 16. Exit criteria

The follow-up is complete when:

- users with an active target session land directly in the Register workspace;
- users without one get a concise entry surface;
- the wireframe hierarchy is implemented without changing domain authority;
- the published keyboard map and dynamic legend agree;
- F10 owns infrequent customer-service, till, and session tools;
- gift-card issuance is compact and follows the agreed field order;
- pending tenders can be selected, edited atomically, and removed individually;
- partial stored-value application uses the lesser of requested and available balance while preserving remaining-due validation;
- completion, retry, cash accountability, stored value, receipts, session close, and Z behavior remain correct;
- relevant request, service, system, accessibility, zoom, and concurrency tests pass.
