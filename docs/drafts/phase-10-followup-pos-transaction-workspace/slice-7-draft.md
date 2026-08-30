> **Superseded for implementation.** Authoritative Slice 7 planning lives under [`docs/planning/register-workspace-consolidation/`](../../planning/register-workspace-consolidation/slice7-overview.md) (`slice7-overview.md`, `slice7-keyboard-contract.md`, and subsequent inventory / 7A–7C packets). Keep this draft for historical context only.

The three-part split is correct, but Slice 7 needs more contract work than Slices 5–6 because 7A and 7B change financial records rather than presentation alone.

The first planning task should be a code-backed tender lifecycle inventory, followed by separate locked packets for 7A, 7B, and 7C.

## Program boundary

I would define Slice 7 as:

> Slice 7 completes the active transaction interaction model. It introduces tender review, record-specific correction, stored-value capping and replacement, gift-card issuance replacement, and one authoritative keyboard dispatcher. It preserves the existing transaction, tender, stored-value, completion, authorization, and audit models unless a packet explicitly identifies a required service extension.

The sequencing remains:

```
7A Tender review and ordinary tender correction
        ↓
7B Stored-value and issuance correction
        ↓
7C Final keyboard contract
```

Do not begin 7A until Slices 2–6 are merged and green on the integration branch.

# Before 7A: lifecycle inventory

Create:

```
slice7-tender-lifecycle-inventory.md
```

Inventory every tender and issuance type:

| Type | Add service | Current side effect | Removable now | Editable now | Reversal authority | Concurrency protection | 7A/7B disposition |
| :---- | :---- | :---- | ----: | ----: | :---- | :---- | :---- |
| Cash | `Pos::TenderCash` | Tender row/change facts | Verify | No | Tender deletion/replacement | Transaction lock | 7A |
| Card | Existing service | Tender/reference | Verify | No | Verify external-reference rules | Transaction lock | 7A |
| Check | Existing service | Tender/reference | Verify | No | Verify | Transaction lock | 7A |
| Other | Existing service | Tender/reference | Verify | No | Verify | Transaction lock | 7A |
| Gift card payment | `AddStoredValueTender` | Tender \+ stored-value ledger | Verify | No | Stored-value reversal | Account \+ transaction locks | 7B |
| Store credit | Existing SV service | Tender \+ stored-value ledger | Verify | No | Stored-value reversal | Account \+ transaction locks | 7B |
| Gift-card issuance | Issuance service | Working issuance; activation at completion | Remove exists | No | Depends on completion state | Transaction/card locks | 7B |

The inventory must establish:

* when value actually moves;  
* what “remove” currently does;  
* what completion revalidates;  
* which records are immutable;  
* whether external tender references can legally be changed;  
* existing idempotency contracts;  
* lock order;  
* audit relationships.

This will prevent “atomic replacement” from becoming a generic service that works for cash but corrupts stored value.

# Slice 7A — Tender-review framework

## Recommended outcome

> Add a distinct Tender Review mode over the existing working transaction. Applied tenders become selectable and expose eligible record-specific actions. Introduce an atomic replacement orchestration contract for ordinary tender types. Stored-value tender mutation remains unavailable until 7B. No final shortcut remapping occurs in 7A.

## Important boundary correction

Do not promise removal of every tender in 7A.

Use:

| Tender family | 7A behavior |
| :---- | :---- |
| Cash | Select, remove, replace |
| Card/check/other | Select, remove, replace where current authority permits |
| Gift card/store credit | Select and inspect; Edit/Remove unavailable until 7B |
| Refund destination tender | Same family-specific rule |
| Unsupported/external final tender | Read-only with explanation |

Otherwise 7A would need exact-once stored-value reversal, which is explicitly 7B.

## Tender Review state

The workspace should enter Tender Review when at least one tender has been applied.

State should include:

```
Transaction
Current settlement direction
Applied tenders
Selected tender
Remaining due/refund
Available actions for selected tender
Completion eligibility
Pending mutation status
```

User-facing states:

| Settlement | Label |
| :---- | :---- |
| Positive remainder | Balance Due |
| Negative remainder | Refund Remaining |
| Exactly settled | Settled |
| Zero commercial total with mixed activity | Even Exchange |
| Completion running | Completing |
| Completion failed | Completion Failed |

Do not describe applied tenders as pending authorizations.

## Selection contract

Tender selection should be semantic rather than encoded only in CSS:

* one selected tender at most;  
* selected record ID survives whole-workspace Turbo replacement when still present;  
* selection falls to the nearest remaining row after removal;  
* selection clears when the list becomes empty;  
* focus and selection are distinct;  
* selected state uses `aria-selected` or an appropriate equivalent;  
* state is not communicated only through color or a chevron.

7A should provide standard Tab, Enter, and pointer access. Do not create temporary `-`, `+1`, or other POS shortcuts that 7C will immediately replace.

## Tender actions

For the selected tender:

* View details;  
* Edit, when supported;  
* Remove, when supported;  
* Add another tender;  
* Return to Sale;  
* Complete, when exactly settled.

Unavailable actions should either be omitted or provide a concise reason, for example:

> Stored-value tender correction becomes available after stored-value verification is complete.

That message is useful during staged integration but should be removed once 7B lands.

## Atomic replacement service

Do not implement replacement as:

```
delete old → attempt new
```

Use an orchestration service such as:

```
Pos::ReplaceTender.call(
  transaction:,
  tender:,
  replacement:,
  actor:,
  expected_transaction_lock_version:,
  source_id:,
  idempotency_key:
)
```

Its contract:

1. authorize the actor;  
2. lock transaction/session/tender in the documented order;  
3. verify the transaction remains working;  
4. verify session and Register custody;  
5. verify the tender still belongs to the transaction;  
6. verify replacement family is supported;  
7. validate the full replacement;  
8. create replacement and supersession relationship atomically;  
9. recalculate remaining settlement;  
10. leave the original authoritative tender unchanged if anything fails.

I prefer a durable supersession relationship over destructive row replacement:

```
Original tender
  └── superseded by replacement tender
```

If the current model requires deletion before completion, the audit event must still preserve:

* original safe details;  
* original amount;  
* replacement amount;  
* tender type;  
* actor;  
* reason;  
* source and idempotency identifiers.

Do not copy full card or stored-value numbers into audit metadata.

## Cash replacement

Lock these distinctions:

```
Cash presented = Cash applied + Change
```

Replacement inputs:

* amount intended to settle;  
* cash presented.

Persist:

* actual applied cash;  
* presented amount;  
* change.

Validate:

* presented cash is sufficient for a payment;  
* refund cash uses the correct direction and availability rules;  
* replacement cannot over-settle except for legitimate cash change behavior;  
* change does not become another tender fact.

## Return to Sale

Lock the product decision now.

Recommended behavior:

* no applied tenders → return directly;  
* applied tenders → explain that all tenders must be removed/reversed before commercial content changes;  
* confirm once;  
* atomically remove eligible tenders;  
* if any tender cannot be reversed, leave everything unchanged and remain in Tender Review.

Do not make “Return to Sale” synonymous with “Cancel Transaction.”

## 7A testing

Required:

* select each supported ordinary tender;  
* remove first/middle/last tender;  
* edit cash/card/check/other;  
* replacement failure preserves original;  
* stale transaction/tender;  
* concurrent removal/replacement;  
* idempotent retry;  
* cash presented/change correction;  
* settlement changes after correction;  
* exact settlement enables completion;  
* over/under settlement;  
* payment and refund directions;  
* even exchange;  
* unsupported stored-value tender remains untouched;  
* Return to Sale success and atomic failure;  
* basket survives F10 inquiry round-trip;  
* pointer and standard keyboard accessibility.

# Slice 7B — Stored-value and issuance completion

## Recommended outcome

> Extend the 7A correction framework to stored-value tenders and working gift-card issuances. Add requested-versus-applied capping, completion-time revalidation, exact-once reversal, and atomic replacement without introducing a second stored-value ledger.

## Stored-value capping

Lock:

```
actual applied =
  min(
    requested amount,
    currently available stored value,
    remaining transaction settlement
  )
```

Rules:

* requested amount defaults to remaining due/refund where appropriate;  
* a request above the transaction remainder fails;  
* a request above account availability but not above transaction remainder is capped;  
* only actual applied is persisted;  
* requested amount is prompting/audit context, not a financial entry;  
* the UI explains the cap before returning to review.

Example:

```
Requested                         $30.00
Available store credit            $18.00
Applied                           $18.00
Remaining due                     $12.00
```

Decide explicitly whether the cashier confirms the capped amount or whether it applies automatically with feedback. I recommend automatic application with prominent feedback because the requested maximum already expresses consent.

## Revalidation

Revalidate stored value:

* when the tender is initially applied;  
* when it is replaced;  
* immediately before transaction completion.

Completion must fail recoverably if the account changed concurrently. It must not silently reduce an already displayed tender during final completion.

## Stored-value removal

Exact-once removal must:

* lock transaction, tender, account, and ledger facts in a fixed order;  
* verify the tender has not already been removed/reversed;  
* create one compensating stored-value operation;  
* mark the tender relationship;  
* restore available value exactly once;  
* recalculate settlement;  
* return the existing result on idempotent replay.

## Stored-value replacement

Treat replacement as one orchestration:

```
Validate proposed replacement
Lock all relevant facts
Reverse original effect
Apply replacement effect
Commit both or neither
```

If replacement validation or application fails, the original tender and account balance remain unchanged.

Cross-account replacement requires deterministic account lock ordering to avoid deadlocks.

## Issuance replacement

Working gift-card issuance actions:

* edit amount;  
* change program where legal;  
* change system-generated/manual authority before assignment;  
* provide or replace scanned card;  
* remove issuance;  
* preserve original if replacement validation fails.

Lock the lifecycle boundary:

| Issuance state | Editable from workspace |
| :---- | ----: |
| Working/unactivated | Yes |
| Activation already committed | No |
| Completed transaction | No |
| Failed completion with no activation | Recoverable |
| Ambiguous external activation outcome | Recovery surface, not ordinary Edit |

The agreed prompt order remains:

1. amount;  
2. program/number authority;  
3. scan or enter card when required.

## 7B testing

Include:

* request below/equal/above available balance;  
* request above amount due;  
* availability changes before apply;  
* availability changes before completion;  
* remove restores value once;  
* concurrent double remove;  
* replace on same account;  
* replace across accounts;  
* failed replacement preserves original balance and tender;  
* expired/suspended/closed account;  
* gift-card and store-credit payment/refund directions;  
* issuance edit/remove;  
* scanned-card conflict;  
* generated-number replacement;  
* activation failure and ambiguous result recovery.

# Slice 7C — Keyboard supersession

## Recommended outcome

> Replace accumulated workspace key handlers with one documented mode-aware dispatcher. Supersede the remaining Phase 6.7 key contract only after SALE, TENDER, and overlay precedence tables are accepted in the packet.

## Packet amendment first

Before JavaScript changes, lock three tables.

### SALE

| Key | Meaning |
| :---- | :---- |
| Printable scan characters | Command/scanner input |
| `Enter` | Submit current command |
| `*` | Quantity |
| `/` | Discount |
| `+` | Open tender selection |
| `-` | Remove selected commercial record |
| F-keys | Accepted final map |

### TENDER

| Key | Meaning |
| :---- | :---- |
| `+` | Add another tender |
| `-` | Remove selected tender |
| Arrows | Change selected tender |
| `Enter` | Open selected tender action/editor |
| `Esc` | Leave submode or invoke Return to Sale contract |
| `+1`–`+9` | Tender category sequences, if retained |

### Overlay precedence

```
Top blocking overlay
  → owns Escape, Enter, arrows and printable input

Register Menu
  → owns F10 and its focus trap

Workspace submode
  → owns mode-specific commands

Sale command field
  → receives scanner/command input only when allowed
```

## Central dispatcher

The dispatcher must know:

* surface;  
* workspace mode;  
* active section;  
* selected record type and ID;  
* active overlay stack;  
* focused element;  
* whether a request is in flight;  
* whether completion is pending/failed;  
* permitted actions.

It should dispatch semantic actions:

```
open-product-lookup
open-tender-selection
remove-selected-record
edit-selected-tender
return-to-sale
cancel-transaction
```

Controllers consume those actions. Do not leave key meaning embedded across unrelated handlers.

## Scanner punctuation

Lock allowed scanner input explicitly. Do not redirect printable characters when focus is in:

* text/password/search/tel/email/number fields;  
* textareas;  
* selects;  
* contenteditable controls;  
* blocking overlays;  
* authorization fields;  
* tender/issuance entry controls.

Cover scanner strings containing:

* `/`;  
* `-`;  
* `+`;  
* `*`;  
* leading zeroes;  
* rapid input;  
* Enter terminator.

The dispatcher needs a sequence rule so a scanned `+` is not mistaken for Tender and a typed `-` in an applicable field is not Remove.

## Escape precedence

Recommended:

1. close the top child overlay;  
2. return to its parent overlay;  
3. leave the active workspace submode;  
4. clear the current command;  
5. do nothing.

Escape must never cancel the transaction or close the session without an explicit confirmation action.

## Keyboard Lock

Retain shell ownership:

* workspace surface requests F1–F10;  
* non-workspace Register surfaces request F10 only;  
* blocking overlays do not create a competing lock owner;  
* acquisition failure must not break typed/scanned input;  
* release on navigation/visibility loss.

## Delete obsolete behavior in the same PR

7C should remove:

* superseded document/window handlers;  
* old key maps;  
* unused Stimulus values;  
* duplicate scanner redirects;  
* obsolete Phase 6.7 tests;  
* compatibility adapters.

Update `pos-workflow.md` so the remaining §6 keyboard contract is explicitly superseded.

# Recommended delivery split

Even with 7A–7C, I would default-split internally:

```
7A.1 Tender Review presentation and selection
7A.2 Ordinary tender removal
7A.3 Ordinary atomic replacement and Return to Sale

7B.1 Stored-value capping and completion revalidation
7B.2 Stored-value removal/replacement
7B.3 Issuance replacement and recovery

7C.1 Accepted keyboard packet amendment
7C.2 Dispatcher and SALE/TENDER bindings
7C.3 Scanner/overlay hardening and obsolete-handler deletion
```

Each PR should target `register-workspace-consolidation`.

# Decisions to lock before implementation

The remaining product decisions are:

- [ ] Which ordinary tender types can be edited rather than only removed and re-added?  
- [ ] Can external card/check references be replaced after recording?  
- [ ] Does capped stored value apply automatically or require confirmation?  
- [ ] Does Return to Sale atomically remove all reversible tenders?  
- [ ] Which actions require confirmation versus direct execution?  
- [ ] Are `+1`–`+9` sequences retained in the final keyboard contract?  
- [ ] How is ambiguous external tender/activation outcome recovered?  
- [ ] Do finalized/completed tenders remain absolutely immutable, with correction only through post-void/refund workflows?

My recommended defaults are:

* edit cash, check, and configured manual-reference tenders;  
* treat externally authorized card tenders as remove/re-authorize rather than field editing;  
* apply stored-value caps automatically with explicit feedback;  
* Return to Sale removes all tenders atomically or changes nothing;  
* confirm destructive/reversal actions, not ordinary field edits;  
* retain numbered tender sequences only if cashiers demonstrably use them;  
* route ambiguous external outcomes to recovery, never ordinary retry;  
* completed transaction tenders remain immutable.

The immediate next artifact should be the tender lifecycle inventory. That inventory will determine where 7A can safely end and where 7B must begin.

---

I agree. Store credit and trade credit are customer-owned value, so forcing the cashier to leave tendering, return to Sale mode, attach a customer, and restart tendering would be unnecessarily disruptive.

This should be part of Slice 7B.

## Recommended rule

| Stored-value type | Customer required |
| :---- | ----: |
| Gift card | No; possession/card identification is sufficient |
| Store credit | Yes |
| Trade credit | Yes |
| Refund to new gift card | No |
| Refund to customer store credit | Yes |
| Refund to trade credit | Yes |

## Tender flow

```
Choose Store Credit
        ↓
Transaction has customer?
  ├─ Yes → resolve that customer’s account
  └─ No  → nested customer lookup
                 ↓
          select customer
                 ↓
          attach to transaction
                 ↓
          resolve account
                 ↓
     request/apply stored value
```

The lookup should use the existing customer-search family rather than create another search implementation.

## Overlay behavior

Customer lookup should be a child of the stored-value tender overlay:

```
Tender selection
  └── Store-credit tender
        └── Customer lookup
```

Behavior:

* Escape from Customer Lookup returns to Store Credit entry.  
* Escape from Store Credit returns to Tender Review.  
* Selecting a customer restores the Store Credit overlay with the customer and balance shown.  
* F10 remains suppressed while either blocking overlay is open.  
* Focus returns to the appropriate tender control.  
* Canceling lookup makes no customer or tender change.

## When the customer association commits

I recommend:

1. cashier selects a customer;  
2. ShelfSense validates that the customer is active and canonical;  
3. cashier explicitly chooses **Use This Customer**;  
4. the transaction customer is attached;  
5. the tender flow continues.

If the subsequent tender fails because of insufficient balance, concurrency, or account status, retain the customer association. Attaching the customer was an explicit, independently useful transaction action—not a failed monetary fact.

If the cashier merely searches, highlights a row, or cancels, do not attach anyone.

## Existing customer behavior

When a customer is already attached:

```
Store Credit
Jane Smith
Available: $18.00
Requested: $30.00
Applied:   $18.00
```

Provide a deliberate **Change Customer** action, but do not silently replace the transaction customer.

Changing the customer must be blocked when existing transaction facts depend on the current customer, including:

* a store-credit or trade-credit tender;  
* a customer-specific refund destination;  
* pickup allocations;  
* other customer-owned stored-value operations.

Recommended message:

> Remove customer-dependent tenders and allocations before changing the transaction customer.

Changing customers should never silently move a tender to the new customer’s account.

## Customer without an account

If the selected customer has no store-credit/trade-credit account or no available balance, show that state explicitly:

```
Jane Smith
No Store Credit account
```

or:

```
Jane Smith
Available Store Credit: $0.00
```

Do not automatically create an account merely because the tender type was selected. Account creation should occur only through an existing authorized domain operation that actually issues value.

For a refund destination, creating/opening an account may be legitimate, but that must be an explicit refund-credit service contract—not a side effect of lookup.

## Stored-value service contract

The tender service should receive the selected customer/account explicitly:

```
Pos::ApplyStoredValueTender.call(
  transaction:,
  customer:,
  account:,
  tender_type: :store_credit,
  requested_amount_cents:,
  actor:,
  expected_transaction_lock_version:,
  expected_account_lock_version:,
  source_id:,
  idempotency_key:
)
```

It must verify:

* transaction customer still matches;  
* customer is active and canonical;  
* account belongs to that customer;  
* account type matches the tender;  
* account is active;  
* current balance;  
* transaction remainder;  
* customer/account association again at completion.

Never trust a customer ID or account ID merely because it came from a hidden form field.

## Customer merge handling

If the selected customer has been merged since lookup:

* resolve to the canonical customer where safe;  
* re-resolve the canonical customer’s account;  
* explain any changed identity;  
* never apply value from both the former and canonical account accidentally.

This should reuse the existing customer-merge authority rather than implementing tender-specific canonicalization.

## 7B packet addition

Add:

### Customer-owned stored value

> Store-credit and trade-credit tenders require a transaction customer. When none is attached, the tender flow opens the existing customer lookup as a nested blocking child. Confirming a customer attaches the active canonical customer to the working transaction and resumes tender entry. Canceling lookup changes nothing. Gift-card tenders remain possession/account based and do not require a transaction customer.

### Customer-change guard

> A transaction customer cannot be replaced while customer-dependent tenders, refund destinations, pickups, or other allocations remain. ShelfSense identifies the blocking facts and requires their explicit removal before customer replacement.

## Tests to add

* Store Credit with an existing customer.  
* Store Credit with no customer → lookup → attach → tender.  
* Cancel customer lookup → no attachment.  
* Selected customer has no account.  
* Selected customer has zero balance.  
* Capped application after attaching customer.  
* Tender failure retains explicitly attached customer.  
* Stale/merged customer during tender.  
* Submitted account belongs to another customer.  
* Change customer with an existing store-credit tender is blocked.  
* Remove customer-dependent tender, then change customer.  
* Gift-card tender does not require a customer.  
* Refund to customer store credit requires a customer.  
* Pointer-only and keyboard-only nested lookup.  
* Escape restores the Store Credit overlay rather than leaving tendering.  
* Concurrent account/customer change before completion.

This belongs in 7B’s stored-value flow, while the final shortcut behavior for opening and navigating the nested lookup belongs in 7C.

---

I would support creating a minimal customer from the Register in Slice 7B, but I would not build a full customer-maintenance surface there.

Without minimal creation, a new customer who wants a return credited to store credit—or later receives trade credit—forces the cashier to abandon tendering, leave the Register workspace, create the customer elsewhere, and recover the transaction. That defeats the purpose of adding customer lookup inside the stored-value flow.

## Recommended boundary

Call it **Quick Customer**, not Create Customer or Customer Maintenance.

It should create enough identity to support the transaction safely:

* display/name fields required by the current customer model;  
* at least one contact method when policy requires it;  
* receipt/contact preference only if currently mandatory;  
* duplicate warning;  
* explicit confirmation.

It should not include:

* multiple addresses;  
* multiple phone/email records;  
* customer notes;  
* privacy/retention administration;  
* merge controls;  
* status management;  
* request history;  
* stored-value adjustment;  
* customer editing;  
* marketing preferences beyond required consent;  
* full Customer workspace fields.

## Flow

```
Store-credit tender
  └── Customer lookup
        ├── Select existing customer
        └── Quick Customer
              ├── Duplicate check
              ├── Create and attach
              └── Return to tender
```

The same Quick Customer child should also be available from the ordinary F2 Customer Lookup. It should not be implemented only inside Store Credit.

That gives ShelfSense one Register customer-acquisition path:

* F2 during Sale;  
* customer-required tender;  
* customer-required refund destination;  
* future trade-credit issuance;  
* future buyback seller intake, if later appropriate.

## Minimum fields

Use the existing Phase 8 customer model rather than creating a simplified parallel record.

Recommended fields:

```
First name
Last name
Email or phone
```

If the current model supports organizations or preferred/display names, do not expose all of that initially unless required. Let the domain service generate the display name through the same rules as the full Customer workspace.

I would require:

* a usable name;  
* at least one of email or phone for store-credit/trade-credit ownership.

A customer-owned monetary balance needs enough identity for staff to locate the customer later. A name-only customer is too easy to duplicate and too difficult to verify.

Allow a manager-controlled exception only if the business genuinely needs anonymous/name-only credit accounts; do not make that the default.

## Duplicate prevention

Quick Customer must run the existing normalized duplicate-candidate search before creation.

Possible result:

```
Possible existing customers

Jane Smith
jane@example.com · 555-0199
[Use Existing Customer]

No match is correct
[Create New Customer]
```

Do not automatically merge or block all similar names. Normalize and compare:

* email;  
* phone;  
* exact/near name;  
* former/merged customer identities.

If the entered email or phone already belongs to an active canonical customer, prefer selecting that customer rather than creating another.

## Commit behavior

Creating the customer is an explicit action independent of the tender:

1. validate fields;  
2. check duplicates;  
3. cashier confirms creation;  
4. create canonical customer through the existing customer service;  
5. attach the customer to the working transaction;  
6. return to the parent tender overlay;  
7. resolve the customer’s relevant account.

If the later tender fails, keep the newly created and attached customer. The customer creation itself succeeded and should not be rolled back because an account has no balance.

If the cashier cancels before choosing **Create and Use Customer**, create nothing.

## Stored-value account behavior

Quick Customer should not automatically open a zero-balance stored-value account during a payment tender.

For payment:

* new customer will normally have no available store/trade credit;  
* explain that no balance exists;  
* do not manufacture an account.

For refund credit:

* the authorized refund service may open the required account and issue value;  
* customer creation and account issuance remain separate audited operations.

This means Quick Customer is most immediately useful for:

* refund to store credit;  
* future trade-credit issuance;  
* attaching the customer to the sale;  
* preparing for future customer-owned activity.

It will not make a newly created customer able to pay with nonexistent store credit.

## Authorization

Use separate permissions:

```
pos.transact
customers.create
```

Creating a customer must not be implicitly authorized solely because someone can run a Register.

If ordinary cashiers should be able to create customers, grant `customers.create` through their role. Do not bypass the current permission evaluator.

Quick Customer must retain:

* store/user audit;  
* normalized contact validation;  
* canonical-customer rules;  
* duplicate checks;  
* server-authoritative creation;  
* CSRF and idempotency;  
* no sensitive values in URLs.

## Overlay contract

Quick Customer is nested under Customer Lookup:

```
Tender overlay
  └── Customer Lookup
        └── Quick Customer
              └── Duplicate Review, when needed
```

Escape behavior:

1. Duplicate Review → Quick Customer;  
2. Quick Customer → Customer Lookup;  
3. Customer Lookup → stored-value tender;  
4. stored-value tender → Tender Review.

A successful creation unwinds directly to the customer-dependent tender with the new customer attached.

Do not build independent modal stacks for the F2 and tender versions. Reuse the same overlay family and return-context mechanism.

## Slice placement

I would add it to 7B, but split it internally:

### 7B.1 — Customer-required stored-value flow

* nested lookup;  
* attach existing customer;  
* account resolution;  
* customer-change guards.

### 7B.2 — Quick Customer

* minimal fields;  
* duplicate candidates;  
* create and attach;  
* reuse from F2.

### 7B.3 — Stored-value correction

* capping;  
* exact-once removal;  
* atomic replacement;  
* completion revalidation.

If 7B becomes too large, Quick Customer can be its own Slice 7B.2 PR without blocking the rest of the Register workspace.

## Deferral alternative

Deferring is acceptable only if the MVP explicitly accepts this workflow:

> Cashiers may select existing customers at the Register, but must leave the Register workspace to create a new customer.

If deferred, preserve the working transaction and provide a clear return path. But this would be a noticeable usability gap for store-credit refunds and future trade credit.

## Recommendation

Implement **Quick Customer** in 7B as a small, permission-controlled reuse of the existing Customer creation domain—not as a miniature Customer workspace.

That closes the customer-owned stored-value workflow without allowing Slice 7 to turn into a customer-management redesign.  