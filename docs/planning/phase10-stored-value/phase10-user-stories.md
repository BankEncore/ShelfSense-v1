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
- Source rows hold `stored_value_operation_id`; operations do not hold source FKs

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
**I want** explicit add/remove credit actions on store credit, trade credit, and eligible gift cards  
**So that** I never edit a balance field.

**Acceptance:**

- Explicit credit/debit direction; positive magnitude
- Reason catalog; no `opening_balance` ordinary reason
- Debits always second-user; credits at/above threshold second-user
- Performer cannot self-approve
- Program maximum and lifecycle checks (active allowed; suspended elevated; replaced/closed blocked)
- Reverse rather than edit
- Reason snapshot + audit without secrets

### US-10.2.3 — Merge transfer

**As** staff merging customers  
**I want** `Customers::MergeStoredValueAccounts` to run inside `Customers::MergeCustomers`  
**So that** balances move through a transfer operation.

**Acceptance:**

- Matrix in [phase10-schema.md](phase10-schema.md) §6
- Ledger `customer_id` unchanged
- Concurrent redeem serialized with merge locks
- Gift-card `customer_id` association reassigned; value not transferred as customer-owned credit
- Zero-balance source accounts close; no survivor account created for zero

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
**I want** balances and per-account ledger history on customer show  
**So that** I can explain store and trade credit without seeing gift-card full numbers.

**Acceptance:**

- Open balances remain on customer show; closed customer-owned accounts stay visible in history
- Each store-credit and trade-credit account has paginated activity (store, business date, operation type, amount, balance-after, actor/reason when present, POS reference when attributable)
- Gift-card show uses `gift_cards.view` for the same table on that card’s account
- No plaintext gift-card numbers; gift-card rows stay masked
- Policy: [phase10-account-transfers-and-adjustments.md](phase10-account-transfers-and-adjustments.md)

### US-10.2.6 — Transfer customer credit

**As** authorized staff with `stored_value.transfer`  
**I want** to move some or all store/trade credit to another same-type account  
**So that** misapplied and customer-authorized balances can be corrected without editing history.

**Acceptance:**

- Same type and currency
- Paired net-zero entries
- Second user; performer cannot self-approve
- Partial or full
- Account consolidation closes source
- Cross-type conversion blocked
- Reversal blocked after downstream spend
- Policy: [phase10-account-transfers-and-adjustments.md](phase10-account-transfers-and-adjustments.md)

## 10.3 — Gift-card identity

### US-10.3.1 — Programs

**As** a global administrator  
**I want** gift-card programs with prefix, length, cash-out policy, and `cash_out_approval_required`  
**So that** scan namespaces do not collide.

### US-10.3.2 — Secure instrument

**As** the system  
**I want** gift-card numbers stored with Rails Active Record Encryption plus an HMAC digest  
**So that** lookup is exact and only prefix and last four appear outside controlled print services ([ADR-026](../../adr/ADR-026-gift-card-number-protection.md)).

**Acceptance:**

- `encrypts :number`; no custom `encryption_key_id`
- Digest uniqueness and exact lookup
- No general reveal permission or reveal screen

### US-10.3.3 — Inquiry, suspend, replace, associate

**As** authorized staff  
**I want** masked inquiry, suspend/reinstate, replacement, and optional customer association  
**So that** bearer cards can be administered without changing ledger ownership rules.

**Acceptance:**

- Exact-number inquiry remains digest lookup
- Admin history may inquire by prefix + last four ([ADR-027](../../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md)): unique match opens the card; collisions show a short masked candidate list; zero matches use the generic failure
- POS redeem, reload, cash-out, and original-card refund stay exact digest
- Replacement of a system-generated card lands on a one-shot credential voucher for the **new** number; the old number is not revealed
- Manual/external replacements that already have a physical number do not print a generated credential

## 10.4 — POS commercial

### US-10.4.1 — Issuance child and signed-net

**As** a cashier with `pos.transact`  
**I want** to add gift-card activation or reload that increases amount due without a merchandise SKU  
**So that** liability issuance is not recorded as sales revenue.

**Acceptance:**

- [phase10-pos-issuance-and-tenders.md](phase10-pos-issuance-and-tenders.md)
- DB signed-net identity includes `stored_value_issuance_cents`
- Envelope golden files updated; Core FKs on source rows
- Working manual activation uses encrypted pending identity; `gift_card_id` null until complete
- Controlled first print after generated-card activation and generated refund cards while the originating session is open; after session close, `gift_cards.recover_print`; complete-retry reprints that outcome only before delivery and while the session is open; ordinary receipts stay masked
- Credential voucher is a distinct 80mm print from the customer receipt; **Print receipt** never includes the full number; **Print gift card** is the first-print channel until delivery is recorded
- Voucher paper: Store identity, issued timestamp, amount, `Gift Card`, Code 128, space-separated number; organization `gift_card_voucher_footer` when set
- Register gift-card scan routing (sale, activation, reload, redeem, refund)
- Every new POS transaction snapshots `system_settings.base_currency_code`

### US-10.4.2 — Stored-value tenders

**As** a cashier  
**I want** system-protected store-credit, trade-credit, and gift-card tenders with destination details  
**So that** redemption settles amount due against an authoritative balance.

**Acceptance:**

- Customer required and revalidated for store/trade
- Cashiers attach, change, or clear the customer via operational search on working tickets; gift-card-only tickets do not require a customer; pickup does not auto-attach
- Multiple SV tenders allowed; lock UUID order
- Same-transaction activate/reload + redeem forbidden
- One detail row per stored-value tender

### US-10.4.3 — Gift-card refund destinations

**As** a cashier  
**I want** to refund gift-card-funded value to the presented original card, a new refund card, or store credit  
**So that** the customer is not forced to create a profile when the original card is missing, and trade credit is never a generic destination.

**Acceptance:**

- Presented matching original card
- New generated or manual refund card (not paid issuance; does not increase `stored_value_issuance_cents`)
- Customer store credit when a canonical active customer is attached
- No trade credit as generic destination
- Value originally paid from trade credit returns to that same trade-credit account
- Missing original card handled without requiring customer creation
- Complete-retry of a new refund card creates only one instrument/liability
- [phase10-refund-post-void.md](phase10-refund-post-void.md)

### US-10.4.4 — Post-void fail-closed

**As** a cashier attempting post-void  
**I want** a block with downstream stored-value lineage when issued value was spent  
**So that** no partial post-void occurs.

## 10.5 — Cash-out, closeout, recovery print, reporting nav

### US-10.5.1 — Gift-card cash-out

**As** a store manager with `gift_cards.cash_out`  
**I want** to pay the full eligible remaining balance from an open Register session  
**So that** cash-out is not a generic paid-out.

**Acceptance:**

- Reversal requires confirmation that cash physically returned to an open Register session
- The reversing session receives the positive expected-cash effect
- Bookkeeping-only reversal is prohibited

### US-10.5.2 — Expected cash and Z

**As** a cashier closing a session  
**I want** expected cash to subtract completed gift-card cash-outs  
**So that** blind close still reconciles.

**Acceptance:**

- Surfaces in [phase10-reporting-closeout.md](phase10-reporting-closeout.md)
- Closed-session snapshots immutable

### US-10.5.3 — Exceptional print recovery

**As** authorized staff  
**I want** controlled print recovery of a generated credential with a reason  
**So that** a failed first print can be recovered without a general reveal screen.

**Acceptance:**

- Requires `gift_cards.recover_print` and a reason
- Audits last four only; does not write the number
- `gift_cards.view` alone is not sufficient

### US-10.5.4 — Cash-out and reporting navigation

**As** authorized staff  
**I want** cash-out and reporting destinations that first exist in this slice  
**So that** the catalog stays complete.

10.2 and 10.3 already add their administrative destinations. This slice performs the final navigation audit.

## Deferred policy

Unused-instrument return (cash/card refund of an unused activated gift card that is neither merchandise return nor post-void) is a later POS policy slice. Research remains in git history of this packet; do not implement it in Phase 10.
