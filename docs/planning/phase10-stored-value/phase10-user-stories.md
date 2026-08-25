# Phase 10 — User stories

GitHub-issue-ready stories. Keep 10.4 issuance and signed-net in the same implementation PR when they land.

## 10.1 — Stored-value core

### US-10.1.1 — Account and ledger persistence

**As** the system  
**I want** stored-value accounts, operations, and entries with database constraints  
**So that** balances cannot be edited as fields.

**Acceptance:**

- Tables and checks in [phase10-schema.md](phase10-schema.md) §§1–3
- `balance_cents` rejected on generic update
- `reversal_of_id` unique when present; no `reversed_by_id` column

### US-10.1.2 — Posting service

**As** a domain command  
**I want** `StoredValue::Post` to lock accounts in UUID order and append entries atomically  
**So that** concurrent redeems cannot overdraw.

**Acceptance:**

- Same-key/same-payload replay; same-key/different-payload fails
- Negative balances rejected
- Outbox events committed in the same transaction

### US-10.1.3 — Projection verification

**As** an administrator  
**I want** a verification that compares `balance_cents` to the sum of effective entries  
**So that** drift is visible without silent repair.

## 10.2 — Customer credit

### US-10.2.1 — One account per type

**As** staff  
**I want** separate store-credit and trade-credit accounts per customer  
**So that** liabilities stay distinguishable.

**Acceptance:**

- Created only for active canonical customers
- Currency snapshot from system settings only

### US-10.2.2 — Manual adjust

**As** staff with `stored_value.adjust`  
**I want** explicit add/remove credit actions  
**So that** I never edit a balance field.

**Acceptance:**

- Debits always second-user; credits above threshold second-user
- Performer cannot self-approve
- Reason snapshot + audit without secrets

### US-10.2.3 — Merge transfer

**As** staff merging customers  
**I want** `Customers::MergeStoredValueAccounts` to run inside `Customers::MergeCustomers`  
**So that** balances move through a transfer operation.

**Acceptance:**

- Matrix in [phase10-plan.md](phase10-plan.md) / schema §5
- Ledger `customer_id` unchanged
- Concurrent redeem serialized with merge locks
- Gift-card `customer_id` association reassigned; value not transferred as customer-owned credit

### US-10.2.4 — Deactivate with balance

**As** staff deactivating a customer  
**I want** a warning or block when store or trade credit is nonzero  
**So that** liability is not trapped silently.

**Acceptance:**

- Inactive customers cannot receive new credit
- Redemption requires reactivation
- Historic reversals still allowed

### US-10.2.5 — Customer activity

**As** staff with `stored_value.view_activity`  
**I want** balances and recent operations on customer show  
**So that** I can explain the account without seeing gift-card full numbers.

## 10.3 — Gift-card identity

### US-10.3.1 — Programs

**As** a global administrator  
**I want** gift-card programs with prefix, length, and cash-out policy  
**So that** scan namespaces do not collide.

### US-10.3.2 — Secure instrument

**As** the system  
**I want** digest + encrypted number + last four  
**So that** lookup is exact and reprints stay masked by default ([ADR-026](../../adr/ADR-026-gift-card-number-protection.md)).

### US-10.3.3 — Inquiry, suspend, replace, associate

**As** authorized staff  
**I want** masked inquiry, suspend/reinstate, replacement, and optional customer association  
**So that** bearer cards can be administered without changing ledger ownership rules.

## 10.4 — POS commercial

### US-10.4.1 — Issuance child and signed-net

**As** a cashier with `pos.transact`  
**I want** to add gift-card activation or reload that increases amount due without a merchandise SKU  
**So that** liability issuance is not recorded as sales revenue.

**Acceptance:**

- [phase10-pos-issuance-and-tenders.md](phase10-pos-issuance-and-tenders.md)
- DB signed-net identity includes `stored_value_issuance_cents`
- Envelope golden files updated; Core FKs present

### US-10.4.2 — Stored-value tenders

**As** a cashier  
**I want** system-protected store-credit, trade-credit, and gift-card tenders  
**So that** redemption settles amount due against an authoritative balance.

**Acceptance:**

- Customer required and revalidated for store/trade
- Multiple SV tenders allowed; lock UUID order
- Same-transaction activate/reload + redeem forbidden

### US-10.4.3 — Refund-to-credit

**As** a cashier  
**I want** to refund remaining value to store credit  
**So that** retail returns do not issue trade credit or a new gift card.

### US-10.4.4 — Unused-instrument return

**As** a cashier  
**I want** to return an unused activated (or unused reloaded increment) gift card  
**So that** the customer can receive a refund without a merchandise return or post-void.

**Acceptance:**

- [phase10-refund-post-void.md](phase10-refund-post-void.md) unused definition
- Reverse issuance + refund tenders atomically

### US-10.4.5 — Post-void fail-closed

**As** a cashier attempting post-void  
**I want** a block with downstream stored-value lineage when issued value was spent  
**So that** no partial post-void occurs.

## 10.5 — Cash-out, closeout, print, nav

### US-10.5.1 — Gift-card cash-out

**As** a store manager with `gift_cards.cash_out`  
**I want** to pay the full eligible remaining balance from an open Register session  
**So that** cash-out is not a generic paid-out.

### US-10.5.2 — Expected cash and Z

**As** a cashier closing a session  
**I want** expected cash to subtract completed gift-card cash-outs  
**So that** blind close still reconciles.

**Acceptance:**

- Surfaces in [phase10-reporting-closeout.md](phase10-reporting-closeout.md)
- Closed-session snapshots immutable

### US-10.5.3 — Print and reveal

**As** a cashier  
**I want** the first activation print to show the generated number, and ordinary reprints to stay masked  
**So that** complete-retry can print without putting the secret in the public envelope.

**As** a global administrator with `gift_cards.reveal_number`  
**I want** an audited exception path to recover the credential  
**So that** a failed physical card can be reprinted without logging the number in audit payloads.

### US-10.5.4 — Admin navigation

**As** authorized staff  
**I want** gift-card program and operational destinations in the navigation catalog  
**So that** there are no one-off header links.
