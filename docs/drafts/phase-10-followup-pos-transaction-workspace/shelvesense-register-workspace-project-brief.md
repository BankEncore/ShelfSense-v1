# ShelfSense Register Workspace Consolidation

## Project brief

**Status:** Proposed  
**Program type:** POS/Register user-experience consolidation and capability completion  
**Primary users:** Cashiers, customer-service staff, shift leads, and managers  
**Related work:** Phase 5 Register foundation, Phase 6 POS MVP ([pos-workflow.md](../../planning/phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md) 6.7 keyboard and POS Home), Phase 10 stored value, Phase 11 Register and cash management, [ADR-026](../../adr/ADR-026-gift-card-number-protection.md), [ADR-027](../../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md), and the ShelfSense UX design system

**Authority:** This brief and its companion wireframes are proposed composition. They do **not** supersede Phase 6.7. An accepted planning packet must name every 6.7 section it replaces. Until then, 6.7 remains implementation authority for POS Home, the selling keyboard map, and F10-as-Transactions. This draft intends that packet to supersede, in order: POS Home and entry chrome; then F10 only (Transactions → Register Menu); then, only in the interaction-completion slice, the wider keyboard map.

## Executive summary

ShelfSense already contains most of the domain behavior required to operate a Register: reporting periods, cashier sessions, transaction entry, returns, gift-card issuance, tendering, receipts, session close, X/Z reporting, and operational cash movements. The current user experience, however, exposes those capabilities as several loosely connected pages: a generic POS Home, a Register-opening page, the transaction workspace, independent cash forms, transaction-history pages, and report pages with their own navigation.

This project will consolidate those capabilities into one state-aware **Register workspace**. Entering Register will resolve the selected Register's operational state and take the user to the appropriate primary surface. A shared shell will preserve Store, Register, business-date, cashier, and session context. A common F10 Register Menu will provide contextual access to customer-service, till, and session activities without turning the Register into a second back-office workspace.

This is not a new POS subsystem and must not introduce a second transaction, cash, stored-value, or reporting model. Existing authoritative services and records remain in place. The project primarily recomposes existing behavior, extracts reusable interaction patterns, retires redundant navigation, and adds a bounded set of missing inquiry and operational-detail surfaces.

## Problem statement

The current POS experience has three related problems:

1. **Operational state is not the organizing principle.** A generic POS Home presents a flat list of links rather than taking the user directly to the work appropriate for a closed Register, an open reporting period, an owned session, or an occupied Register.
2. **Register context and navigation are duplicated.** Transaction, report, session-close, cash, and history pages use separate headers and return paths, making business date, custody, and navigation inconsistent.
3. **Mature capabilities are fragmented.** Transaction search, X/Z reports, cash movements, stored-value activity, pickups, and customer context exist at different levels of completion but are not composed into a coherent cashier workspace.

The result is a capable system that feels like a collection of POS utilities rather than a continuous Register workflow.

## Product vision

For the end user, Register should feel like one operational place:

- ShelfSense takes the user directly to the correct surface for the Register's current state.
- Store, Register, business date, cashier, and session custody remain visible and consistent.
- The active transaction is the primary sustained workspace when the user owns a session.
- Frequent transaction actions remain direct and keyboard-friendly.
- F10 opens less frequent customer-service, till, and session activities.
- Temporary inquiries and corrections preserve the working transaction and restore focus on return.
- Session close and Z finalization remain distinct, explicit operations.
- Store-wide safe, deposit, configuration, and cross-session administrative work stays outside the Register workspace.

The governing boundary is:

> Work serving the current customer, current till, or current Register custody interval belongs in Register. Store-wide cash custody, deposits, configuration, and broad administration belong in their dedicated ShelfSense workspaces.

## Goals

1. Make Register entry state-aware and eliminate unnecessary intermediate navigation.
2. Establish a shared Register shell and consistent operational vocabulary.
3. Recompose the transaction workspace around merchandise, gift-card issuance, totals, tenders, and customer context.
4. Consolidate contextual navigation under a state- and permission-aware F10 menu.
5. Extract reusable lookup, approval, confirmation, and cash-activity presentation patterns.
6. Reuse existing transaction, cash, stored-value, reporting, and authorization services.
7. Add the missing inquiry/detail surfaces needed for a complete Register workspace.
8. Preserve keyboard efficiency, accessible non-keyboard equivalents, focus restoration, and usable layouts at 200% zoom.

## Non-goals

This project will not:

- replace the existing Rails POS architecture;
- create a second transaction or settlement calculation;
- merge gift-card issuances into merchandise lines;
- create a duplicate cash or stored-value ledger;
- redesign all customer, product, or request administration;
- move safe reconciliation or deposit preparation into Register;
- expose full gift-card numbers through ordinary cashier inquiry;
- make configuration or maintenance part of F10;
- complete every advanced tender-editing behavior in the initial composition slice;
- silently roll an open Register reporting period to a new business date;
- silently remap Phase 6.7 selling shortcuts during composition (the only approved keyboard change through Slice 5 is F10 → Register Menu);
- treat prefix + last-four gift-card find as possession or as input to redeem, reload, cash-out, or completion.

## Register state model

A Register does not directly own a business date. Its open reporting period establishes the Register's business date. The user-facing workspace has four primary states.

| Internal condition | User-facing state | Primary surface | Primary outcomes |
|---|---|---|---|
| No open reporting period | Register closed | Open Register | Confirm proposed business date, enter opening float, open period and session |
| Open reporting period; no open session | Between sessions | Open Session / Z status | Open another session or finalize Z |
| Open session owned by current user | Session open | Transaction workspace | Sell, return, issue stored value, tender, and perform Register operations |
| Open session owned by another user | In use by cashier | Occupied Register | Identify custody, select another Register, or use authorized management tools |

An open reporting period from a previous business date is a prominent qualifier on the between-sessions or session-open state, not a separate persisted state. ShelfSense must clearly state that opening another session will continue the established date.

Configuration or readiness conditions—such as an inactive Register, insufficient safe cash, missing authorization, or an uninitialized safe—are blockers or lifecycle statuses, not additional daily Register states.

## State routing

Entering `/pos` or choosing a Register should resolve as follows:

```text
No Register selected                                         → Register selector
Cashier owns multiple open sessions and no valid Register
  binding resolves one                                       → Register selector
                                                              (every owned session labeled
                                                               Your session — Resume)
No open reporting period                                     → Register closed
Open period, no session                                      → Between sessions
Current user's session                                       → Transaction workspace
Another user's session                                       → Occupied Register
```

Never present a cashier who owns one or more open sessions as having no session.

Preferred Register (cookie), request-bound `session[:pos_register_id]`, and actual session custody are distinct. Changing preference or selecting another Register never transfers or closes custody.

`Pos::OpenGate` remains authoritative for per-Register state. GET routing may resolve a Register, evaluate the gate, select or redirect to a state body, and display an existing working transaction. It must not open a reporting period, open a session, transfer opening float, or create a working transaction. Mutating entry remains `POST` enter / `EnterRegister` / `ResumeOrStartTransaction`. Workspace GET only loads an existing working transaction and redirects to entry if none exists.

The generic POS Home becomes unnecessary once state routing and F10 reach functional parity.

## Experience architecture

### Shared Register shell

All Register states and most Register-supporting surfaces use a common shell containing:

- Store and Register identity;
- business date or proposed-date status;
- cashier and session custody where applicable;
- state/status strip;
- prior-date or blocker warning slot;
- consistent feedback region;
- F10 Register Menu launcher;
- state-specific main-content slot;
- shared overlay host;
- explicit Return to ShelfSense behavior.

The shell owns operational context and navigation. Domain-specific services continue to own financial, lifecycle, authorization, and concurrency decisions.

### Primary surfaces

#### Register closed

Shows the selected Register, proposed business date, opening readiness, opening float, and **Open Register**. Opening creates the reporting period and first session as one guided user workflow. State-independent customer-service tools remain accessible.

#### Between sessions

Shows the established business date, prior sessions in the period, Z-period status, opening float, **Open Session**, and **Finalize Z**. If the period is from a prior date, the date and consequences of continuing it are conspicuous.

#### Transaction workspace

The transaction workspace is the direct landing destination when the current user owns the session. It contains:

1. **Register context:** Store, Register, business date, cashier, session, and F10.
2. **Mode and prompt:** SALE, RETURN, TENDER, PICKUP, or GIFT CARD; current instruction; stable scan/input field; shortcuts; feedback; customer identity.
3. **Commercial basket:** Merchandise sale/return lines and a distinct Gift Cards subsection.
4. **Totals rail:** Merchandise, discounts, returns, gift cards issued, net tax, and signed result.
5. **Applied tenders:** Applied amount and tender-specific supporting detail, plus remaining payment/refund.
6. **Customer context:** Selected customer or No customer, with compact relevant stored-credit and pickup information.

Commercial components determine the total; tenders settle it; contextual components explain it. These roles must remain visually and structurally distinct.

#### Occupied Register

Shows the accountable cashier, business date, session opening time, and Register status. Ordinary users may select another Register or use state-independent customer-service tools. Authorized managers may view X/session details or enter a manager-assisted-close workflow. Users must not enter another cashier's transaction through ordinary navigation.

#### Session close

Session close remains a dedicated, consequential surface. It resolves working-transaction blockers, captures the closing cash count, handles variance and approval, records assisted-close context when applicable, and ends cashier custody. It then returns to the between-sessions state. It does not automatically finalize Z.

#### Z finalization

Z finalization remains separate from session close. It reviews the reporting period, included sessions, totals, blockers, and permanent consequence before finalizing the business date for that Register.

#### Completed transaction

The result surface shows receipt identity, payment/refund outcome, change, receipt and voucher actions, and **New Transaction**. Completed commercial and settlement facts are immutable. Failure returns the user to a recoverable working/completion-failed state where possible.

## Keyboard contract

Phase 6.7 remains the selling keyboard map through composition. This project makes one approved breaking change in Slice 2:

```text
F10: Transactions → Register Menu
```

Transactions remains available from that menu with the existing “working basket untouched” behavior. All other 6.7 bindings (`F1`–`F9`, `/`, `-`, `.`, `*`, `+`, Enter, Escape) stay in force through Slice 5.

A mode-scoped SALE/TENDER remap is a **future target, not MVP instruction**. Collisions among `/` vs discount, `-` vs remove, `.` vs pickup, `F7` discount vs tax, and `F8` remove vs Return remain unsettled. Slice 6 may propose a replacement only after:

1. composition preserves 6.7 except F10;
2. TENDER is a first-class announced mode;
3. every current shortcut and scanner-sensitive character is inventoried;
4. the proposed map is prototyped;
5. scan strings containing punctuation are tested;
6. an accepted packet formally supersedes 6.7 §6 (and related Enter/modal sections as needed).

F10 is implemented in Slice 2 because it replaces POS Home navigation; it is not deferred to Slice 6. Slice 6 owns the broader remap and a centralized SALE vs TENDER dispatcher. Slice 2 still needs a **shell-level F10 dispatcher** so the menu works on closed, between-sessions, occupied, and inquiry surfaces, not only the selling workspace.

While a blocking overlay or approval dialog is open, F10 does not open another layer. The user must complete or leave the current layer first.

## F10 Register Menu

F10 is available across the four primary states. Its structure remains stable while contents are filtered by Register state and permission. Empty groups are omitted rather than filled with unavailable actions.

### Customer Service

- **Stored Value Inquiry** — Three labeled find paths, not one ambiguous search field (see Stored-value inquiry below).
- **Transactions & Receipts** — Search completed transactions; view details; reprint; begin an eligible linked return; access controlled post-void and voucher actions. Reached via F10; does not discard the working transaction.
- **Customer Summary** — View contact summary, recent transactions, requests/pickups, and store-credit context; attach to a working transaction when applicable.
- **Pickup Queue** — View ready and expiring pickups; add eligible lines when the current user owns a working transaction.

### Till

Shown only where the user can operate on an owned active session:

- Cash Drop
- Cash Replenishment
- Paid-In
- Paid-Out
- Gift-Card Cash-Out
- Till Activity

### Session & Register

Shown contextually:

- X Report
- Session Details
- Z-Period Status
- Active Sessions, permission-controlled
- Switch Register
- Close Session
- Return to ShelfSense

**Return to ShelfSense** leaves the session open. **Close Session** ends custody. **Finalize Z** closes the reporting period. The UI must never blur these three outcomes.

### Stored-value inquiry

Do not present a single search that might accept a complete number or prefix + last four. Expose distinct choices:

```text
Stored Value Inquiry

[Scan or enter complete gift-card number]
For balance, reload, redemption, or cash-out eligibility.
Uses the exact possession-based lookup (ADR-026).

[Find customer store credit]
Search by customer identity. Store credit is located through
the identified customer relationship, not a card-number
possession contract.

{Authorized management}
[Find gift-card history by prefix and last four]
Masked inquiry only (ADR-027). Cannot begin redeem, reload,
cash-out, original-card refund, or any other value-moving POS action.
Must not feed Register scan routing or completion.
```

Actionable gift-card operations (redeem, reload, cash-out, original-card refund) require the complete number and the exact protected lookup. Prefix + last four never establishes possession. Ordinary inquiry remains masked; full-number access stays elevated, audited, and purpose-specific.

New F10 inquiry/detail surfaces (Till Activity, Session Details, Z-Period Status, Customer Summary, Pickup Queue, Stored Value Inquiry) are presenters over existing facts. They must not create a consolidated cash ledger, another customer-history store, another reservation state, another reporting-period aggregate, or another transaction-total calculation. Till Activity is a unified presentation across domain-owned cash records, not a new authoritative activity table.

## Reusable components and interaction layers

### Shared partials

| Component | Reuse |
|---|---|
| Register context header | All states and Register-supporting surfaces |
| State/status strip | All states |
| Feedback/alert region | All states and overlays |
| Register selector/status list | Initial entry, closed, between sessions, occupied, and F10 |
| Transaction basket sections | Active transaction and read-only completion/detail variants where appropriate |
| Totals/report groups | Transaction summary, X, session, and Z presentations using their appropriate presenters |
| Approval fields/result | Controlled actions across POS domains |
| Explicit confirmation frame | Cancellation, removal, finalization, and custody-sensitive exits |

### Shared overlays

#### Lookup frame

Provides common title, search, results, selected detail, feedback, confirm/back behavior, Escape precedence, focus containment, and focus restoration. Domain bodies include product, customer, pickup, linked-return, receipt, stored-value, variant, and inventory-unit lookup.

#### Selected-record editor frame

Provides record summary, current/proposed values, reason, authorization, validation, **Apply Change**, and **Keep Existing**. It supports quantity, price, discount, tax, gift-card issuance, and later tender editing without making them one domain operation.

#### Approval layer

Standardizes requesting user, requested action, consequence, required permission, approving user, reason, and result. The underlying service must still revalidate authorization and business eligibility.

#### Cash-movement frame

Standardizes amount, managed reason, note, session/safe effect, approval, and result for drop, replenishment, paid-in, and paid-out. Gift-card cash-out remains its own domain operation while reusing lookup, approval, and cash-effect presentation.

### Full surfaces rather than overlays

The following remain full surfaces because they are sustained, complex, or custody-changing workflows:

- Transaction workspace
- Open Register/Open Session
- Session close and reconciliation
- Z finalization
- Manager-assisted close
- Completed transaction result
- Transaction/receipt detail when extensive
- Safe reconciliation
- Deposit preparation

F10 may launch these surfaces, but it should not compress them into inappropriate dialogs.

## Current-code disposition

### Exists and should be revised

| Current capability | Disposition |
|---|---|
| Register entry and `OpenGate` state logic | Preserve authoritative state logic; render through state-specific bodies |
| Preferred Register selection | Evolve into a richer Register selector/status list |
| Transaction workspace and services | Preserve behavior; recompose and split the monolithic surface |
| Product/variant/unit/customer/pickup/return dialogs | Extract into shared lookup frame with domain bodies |
| Controlled-action and unlinked-return approval UI | Extract shared approval/editor presentation |
| Transaction history and receipt detail | Become Transactions & Receipts; add context-aware actions/return paths |
| Completed transaction view | Align with shell; clarify receipt, voucher, new transaction, and Close Session actions |
| Session close and closed-session result | Retain as full workflow; clarify custody and Z distinction |
| X, closed-session, and finalized-Z reports | Preserve presenters/print output; integrate through common context/navigation |
| Active Sessions | Extend with Session Details, warnings, and assisted-close entry |
| Paid-in/out, drop, replenishment, and gift-card cash-out | Preserve services; present through Till menu and common cash-operation frame |
| Cash reversal service | Preserve; initiate from an eligible original activity |

### Exists and should be deprecated

| Current presentation/entry point | Replacement |
|---|---|
| Generic POS Home | Direct state routing and F10 menu |
| Independent POS headers/chrome | Shared Register shell/context header |
| `_report_nav` and transaction `_chrome` navigation | Shell, F10, and context-aware back actions |
| Flat action-button collections | Grouped, state-aware menu and primary state actions |
| Generic Reverse Cash launcher | Reverse from selected Till Activity or manager cash history |
| “Close register” terminology for session close | Close Session; reserve Finalize Z for period close |
| Duplicated approval markup | Shared approval/editor frame |
| Monolithic workspace partial structure | Composed basket, summary, tender, command, and overlay partials |

Deprecation applies first to user-facing entry points and duplicated presentation. Existing routes may remain temporarily as redirects or internal targets until replacement parity and tests are established.

### Must be created

| New component/capability | Purpose |
|---|---|
| Shared Register shell | Consistent context, state, F10, feedback, and overlay hosting |
| Four state bodies | Closed, between sessions, owned session, and occupied Register |
| F10 Register Menu | Contextual customer-service, till, and session navigation |
| Reusable overlay foundation | Accessible dialog lifecycle, server errors, and focus restoration |
| Stored Value Inquiry | Split find: exact-number possession lookup; customer store-credit lookup; optional permission-controlled masked prefix/last-four history |
| Customer Summary | Register-focused customer, transaction, pickup, and credit context |
| Pickup Queue | Ready/expiring pickup inquiry and contextual add-to-transaction action |
| Till Activity | Unified current-session operational cash history and reversal origin |
| Session Details | Current, occupied, and historical custody/session information |
| Open Z-Period Status | Sessions, cumulative totals, blockers, and finalization eligibility |
| Rich Register selector | State, date, cashier, warning, and appropriate action per Register |
| Shared confirmation frame | Explicit action/consequence labels for destructive or custody changes |

## Transaction composition: MVP and later interaction work

### Composition MVP

The first transaction slice can be implemented largely with current behavior:

- shared Register context and stable mode/prompt region;
- merchandise/return table;
- adjacent Gift Cards subsection;
- customer context;
- authoritative totals breakdown;
- Applied Tenders presentation;
- correct payment/refund/even-exchange labels;
- existing tender-addition and abandonment behavior;
- existing transaction lookup and controlled-action workflows;
- responsive stacking and accessibility verification.

Preserve **all other** Phase 6.7 keyboard bindings during this slice. Do not display a future SALE/TENDER shortcut legend. Applied tender rows must not appear individually editable until safe replacement behavior exists.

### Interaction completion

Later slices add behavior that changes selection, financial reversal, concurrency, or the 6.7 keyboard contract:

- unified selection across merchandise, gift-card issuance, and tenders;
- first-class announced TENDER mode, then a prototyped mode-scoped dispatcher;
- formal supersession of 6.7 keyboard sections (not an undocumented remap);
- individual tender edit and removal;
- atomic tender replacement;
- stored-value requested-versus-applied capping and explanation;
- gift-card issuance editing;
- shared tax-group projection across workspace and receipt;
- explicit return-to-sale behavior when tenders exist.

Only the actual applied stored-value amount is persisted. Completion must revalidate balances and preserve the original tender if replacement fails.

## State and permission availability

| Activity | Closed | Between sessions | Own session | Occupied |
|---|---:|---:|---:|---:|
| Stored Value Inquiry | Yes (paths filtered by permission and whether a value-moving action is eligible) | Yes | Yes | Yes |
| Transactions & Receipts | Yes | Yes | Yes | Yes |
| Customer Summary | Yes | Yes | Yes | Yes |
| Pickup Queue | View | View | Add eligible pickup | View |
| Transaction entry | No | No | Yes | No |
| Gift-card issuance/reload | No | No | Yes | No |
| Till operations | No | No | Yes | No |
| Till Activity | Historical/contextual | Historical/contextual | Current session | Permission-controlled |
| X Report | No current session | Historical sessions | Current session | Permission-controlled |
| Z-Period Status | Historical | Yes | View only | Permission-controlled |
| Finalize Z | No | Yes | No | No |
| Active Sessions | Permission-controlled | Permission-controlled | Permission-controlled | Permission-controlled |
| Switch Register | Yes | Yes | Yes, with warning | Yes |

## Accessibility and interaction requirements

The consolidated workspace must:

- work at the supported Register resolution and at 200% browser zoom;
- preserve logical DOM, focus, and keyboard order;
- provide accessible non-keyboard equivalents for every action;
- restore focus after overlays and temporary supporting surfaces;
- never use color alone for mode, selection, return direction, or warning state;
- omit unavailable menu actions or present them with an accessible explanation;
- not intercept printable characters while the user is typing in an applicable field;
- give Escape documented contextual precedence and never silently cancel a transaction;
- keep F10 from opening another layer while a blocking overlay or approval dialog is open;
- handle long product, customer, tender, and identifier values;
- stack the totals/tender rail below the basket when width is constrained;
- announce mode changes, errors, and remaining payment/refund appropriately.

## Architectural constraints

1. Existing domain records and services remain authoritative.
2. Shared UI frames collect and present information; they do not replace domain validation.
3. No financial total is independently persisted for presentation convenience.
4. Tax summaries must derive from the same facts as completed receipts.
5. Gift-card full-number access remains elevated, audited, and purpose-specific.
6. Actionable gift-card operations require the exact possession-based lookup. Prefix/last-four administrative inquiry cannot begin a value-moving POS action, feed Register scan routing, or authorize completion.
7. Manager authorization never bypasses post-entry eligibility, lock, balance, or concurrency checks.
8. Reversals begin from and remain linked to the original operation.
9. Temporary overlays preserve the working transaction and restore the user's prior context.
10. An open session always belongs to an open reporting period; inconsistent persisted combinations are errors, not UI states.
11. GET requests may resolve and render Register state but must not open a reporting period, open a session, transfer cash, or create a transaction.
12. Preferred Register, request-bound Register, and session custody are distinct. Preference changes never transfer or close custody.

## Delivery plan

### Slice 1 — Register shell and state routing

- Add the shared Register shell, context header, state strip, feedback region, and selector.
- Render closed, between-sessions, and occupied state bodies from existing gate logic.
- Route an owned session directly to transaction entry.
- When the cashier owns multiple open sessions and no valid Register binding resolves one, show the selector with every owned session labeled **Your session — Resume**. Never present that cashier as having no session.
- Add prior-date warnings and state-appropriate vocabulary.
- Keep POS Home temporarily as a fallback.
- Prove GET/state-routing is read-only: no period open, session open, cash transfer, or transaction create during routing or workspace refresh.

**Exit:** Register entry reliably lands on the correct state surface without changing lifecycle behavior.

### Slice 2 — F10 and navigation consolidation

- Add the state- and permission-aware F10 menu.
- Add a shell-level F10 dispatcher so the menu works on every Register state, not only the selling workspace.
- Explicitly supersede **only** current F10 behavior: Transactions → Register Menu.
- Move Transactions under F10 with existing basket-preservation behavior.
- While a blocking overlay or approval dialog is open, F10 does not open another layer.
- Route existing history, report, cash, session, and Register-selection capabilities through the menu.
- Add explicit Return to ShelfSense behavior.
- Replace duplicate headers/navigation with the shared shell.
- Retire POS Home after functional parity.

**Exit:** Users can reach every currently supported Register activity without the generic POS Home or duplicate navigation. F10 is Register Menu; all other 6.7 keys are unchanged.

### Slice 3 — Transaction composition MVP

- Split the workspace into basket, issuance, summary, tender, command, and customer components.
- Implement the two-region/stacking composition.
- Add precise signed totals and Applied Tenders presentation.
- Preserve existing transaction and tender behavior.
- Preserve all other Phase 6.7 keyboard bindings. Do not display the future shortcut legend.
- Verify the representative sale, return, gift-card, split-tender, refund, and zoom scenarios.

**Exit:** The transaction screen matches the agreed composition without expanding financial interaction contracts or remapping sale/tender keys.

### Slice 4 — Existing overlay extraction

- Create the shared overlay lifecycle and lookup frame.
- Migrate product, customer, pickup, linked return, and staged merchandise selection.
- Extract controlled-action/approval and confirmation frames.
- Preserve focus and server-error behavior.
- Preserve the Slice 2 F10 blocking-overlay rule.

**Exit:** Existing transaction overlays use common accessible mechanics and can be reused elsewhere in Register.

### Slice 5 — Missing inquiry and detail surfaces

- Stored Value Inquiry, split into:
  - exact-number gift-card possession lookup;
  - customer store-credit lookup;
  - optional permission-controlled masked administrative history inquiry (prefix + last four; no value-moving actions).
- Customer Summary
- Pickup Queue
- Till Activity (presenter over existing cash records, not a new ledger)
- Session Details
- Open Z-Period Status
- Active Sessions enhancements

**Exit:** The F10 information architecture is substantively complete without duplicating back-office administration.

### Slice 6 — Interaction completion

- Unified selection and keyboard routing
- Formal supersession of the Phase 6.7 keyboard sections
- SALE versus TENDER key tables after inventory, prototype, and scanner-punctuation tests
- Shell versus workspace dispatcher ownership
- Modal/overlay precedence tests
- Tender review
- Individual removal and atomic replacement
- Stored-value capping
- Gift-card issuance editing
- Return-to-sale rules
- Shared tax-group projection

**Exit:** The recomposed workspace supports safe correction of individual commercial and settlement components, and any new shortcut map is an accepted replacement of 6.7 rather than an informal overlay.

## Migration and deprecation strategy

- Introduce the shell and new routes alongside existing pages.
- Preserve existing services and request contracts while replacing views incrementally.
- Treat old POS Home and navigation links as temporary compatibility entry points.
- Add state-routing, permission, focus, and return-context tests before redirecting old entry points.
- Redirect `/pos` only after each Register state has an equivalent landing surface.
- Remove obsolete view partials only after all callers use the shared shell.
- Remove the generic reversal launcher only after Till Activity provides an eligible reversal path.
- Avoid combining visual recomposition with tender replacement or other high-risk financial changes in the same merge gate.

## Acceptance themes

### State routing

- Closed Register opens a new period/session with confirmed date and float.
- Between sessions can open another session or finalize Z.
- Prior-date period is never silently advanced.
- Owned session resumes directly into its working transaction.
- Occupied Register never exposes the other cashier's transaction.
- Multiple unbound owned sessions land on the selector with Resume labels, never a false empty-session Home.
- GET `/pos` and workspace refresh do not open a period, session, or working transaction.

### Context continuity

- Store, Register, business date, cashier, and session facts agree across surfaces.
- F10 inquiry preserves an active working transaction.
- Overlay close or completion restores a sensible focus target.
- Switching preferred Register does not imply session close.
- Preferred Register, request-bound Register, and session custody remain distinct.

### Transaction composition

- Ordinary, mixed sale/return, gift-card issuance, split-tender, refund, and even-exchange transactions reconcile.
- Gift-card issuances remain distinct from merchandise and gift-card tenders.
- Cash presented, applied, and change remain distinct.
- Completed receipts and workspace summaries derive from consistent facts.

### Custody and reporting

- Close Session and Finalize Z remain separate.
- Manager-assisted close is explicit and audited.
- X Report never closes a session.
- Till Activity does not become a second authoritative ledger.

### Security and permissions

- F10 contents reflect state and effective permissions.
- Full gift-card numbers are not shown through ordinary inquiry.
- Exact-number gift-card find may lead to eligible value-moving actions; prefix/last-four history inquiry must not.
- Approval failure leaves the underlying action unchanged.
- Stale, concurrent, or no-longer-eligible operations fail safely.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Large workspace rewrite destabilizes POS | Decompose and recompose while retaining existing services and request contracts |
| F10 becomes a second administrative menu | Enforce the current-customer/current-till/current-custody boundary |
| Shared frames erase domain differences | Share presentation mechanics only; keep separate domain services and validations |
| Keyboard handlers collide | Preserve 6.7 through composition except documented F10; inventory, prototype, and punctuation tests before any SALE/TENDER remap |
| Old and new navigation coexist indefinitely | Define parity gates and explicit deprecation/removal criteria per slice |
| Reports and workspace totals diverge | Reuse authoritative presenters/projections rather than calculate in views |
| Overlays become inaccessible at high zoom | Use responsive full-height drawers/surfaces where content density requires them |
| Manager approval is treated as permanent authorization | Revalidate eligibility, locks, balances, and permissions at commit |

## Success measures

The project is successful when:

- users enter Register and immediately understand its operational state;
- an owned session lands directly in transaction entry;
- the generic POS Home is no longer required;
- all Register activities are organized consistently through direct transaction actions or F10;
- transaction, session, cash, and report surfaces show consistent custody context;
- existing POS behavior remains financially and operationally correct;
- shared overlay mechanics reduce duplicated interaction code;
- missing inquiry/detail surfaces complete the Register workflow without duplicating back-office administration;
- the experience remains keyboard-efficient, pointer-operable, and usable at 200% zoom;
- composition preserves the 6.7 keyboard map except the documented F10-to-Register-Menu change.

## Decisions captured by this brief

1. Use four primary Register states; treat prior-date periods as a qualifier.
2. Replace POS Home with state-aware entry and F10 after parity.
3. Use one shared Register shell across state and supporting surfaces.
4. Land owned sessions directly in the transaction workspace.
5. Keep opening, session closing, and Z finalization distinct.
6. Recompose rather than replace the existing transaction architecture.
7. Keep gift-card issuance, commercial lines, tenders, and context structurally distinct.
8. Reuse existing lookup and approval behavior through extracted shared frames.
9. Initiate cash reversals from an original activity rather than a generic launcher.
10. Keep safe reconciliation, deposits, configuration, and broad administration outside Register.
11. GET routing is read-only; mutating entry remains POST enter.
12. Multiple unbound owned sessions route to the selector with Resume labels.
13. Through Slice 5, supersede 6.7 only for F10 (Transactions → Register Menu).
14. Split Stored Value Inquiry into possession lookup, customer store-credit lookup, and separately authorized masked administrative inquiry.

## Open decisions before implementation planning

The brief does not require these decisions to validate the overall architecture, but they should be resolved in the owning slices:

1. Whether Transactions & Receipts is initially a full-height drawer or a route-backed nested Register surface.
2. Whether existing cash forms become overlays in the first F10 slice or remain route-backed surfaces styled within the shell.
3. The eventual SALE versus TENDER shortcut map (unsettled; Slice 6 only, after prototype and scanner-punctuation tests). Composition MVP preserves 6.7 except F10.
4. The exact visibility policy for expected cash under blind-count configuration.
5. Whether voucher reprint requires approval in addition to its existing stored-value permissions and audit requirements.
6. Whether Customer Summary permits minimal edits or remains strictly read-only with a link to Customer workspace.
7. The supported baseline Register viewport in addition to the 200% zoom requirement.

