# Phase 10 — Stored Value

**Status:** Superseded  
**Canonical packet:** [docs/planning/phase10-stored-value/README.md](../planning/phase10-stored-value/README.md)  
**ADRs:** [ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md), [ADR-026](../adr/ADR-026-gift-card-number-protection.md)

This draft is historical. Do not implement from it. POS issuance, signed-net, source FKs, encryption, unused-instrument return, and tender category design in the packet **replace** the corresponding sections below.

---

# Phase 10 — Stored Value (historical draft)

**Status:** Proposed (superseded)  
**Depends on:** Phase 8 — Customer identity foundation  
**Unlocks:** Phase 11 cash management; Phase 12 trade-credit buyback payout; later accounting export and financial reporting  
**Primary domains:** Stored value, Customers, POS  

## 1. Objective

Implement authoritative stored-value accounts and bearer gift cards without representing balances as editable customer or card fields.

ShelfSense must be able to:

- Maintain distinct store-credit, trade-credit, and gift-card liabilities.
- Issue, activate, reload, redeem, refund, adjust, transfer, cash out, and reverse stored value.
- Support split tender and mixed stored-value tender at the Register.
- Reconcile stored-value activity and its limited cash effects through existing POS sessions, X reports, Z reports, and store-day reporting.
- Preserve immutable operational history, deterministic balance reconstruction, idempotency, and reversal lineage.

Phase 10 is a stored-value domain program. It does **not** introduce a general financial-event table, general ledger, accounting export subsystem, or broad cash-management foundation.

## 2. Architectural position

ShelfSense already records financial and operational consequences in domain-specific authoritative facts:

- Completed POS transactions and lines preserve commercial facts.
- POS tenders preserve settlement facts and configuration snapshots.
- Inventory ledger and valuation entries preserve inventory effects.
- Tax components preserve calculated tax facts.
- Balance and inventory records are projections over immutable facts.
- Post-voids and corrections append reversing facts rather than editing completed records.

Stored value follows the same pattern:

```text
StoredValueOperation       what business action occurred
  └── StoredValueEntry     how one account balance changed
        └── Account balance projection
```

Where applicable, the same operation links atomically to an existing POS fact:

```text
activation or reload  -> completed POS transaction
redemption            -> completed POS tender
refund                -> POS return/refund allocation
cash-out              -> active POS session and Register cash effect
trade-credit issue    -> future completed buyback
```

No additional generic financial-event row is required. Later accounting work will consume these immutable operational facts through versioned posting rules or an accounting-specific staging contract.

## 3. Phase boundaries

### 3.1 In scope

- Shared stored-value accounts, operations, ledger entries, and balance projections.
- Separate store-credit and trade-credit accounts owned by customers.
- Gift-card programs, bearer instruments, secure number lookup, and check digits.
- System-generated and activation-time manually supplied gift-card numbers.
- Gift-card activation, reload, redemption, balance inquiry, suspension, replacement, transfer, and cash-out.
- Manual account adjustments with elevated permission and reason capture.
- POS stored-value tenders and split-tender completion.
- Refund allocation to original stored value or store credit according to policy.
- Correct reversal and post-void behavior.
- Customer balance and activity presentation.
- Register-session, X/Z, store-day, and liability reporting.
- Online authorization, locking, idempotency, immutable history, and audit evidence.

### 3.2 Explicitly out of scope

- General `financial_events` or universal monetary-event persistence.
- Debit/credit journals, balanced entries, accounting periods, or GL export batches.
- Historic POS conversion into an accounting subledger.
- General cash movements: paid-ins, paid-outs, drops, safe transfers, drawer transfers, or cash corrections.
- Buyback intake, valuation, completion, or payout workflows.
- Offline stored-value activation, reload, redemption, inquiry, transfer, replacement, or cash-out.
- Gift-card PINs or access codes.
- Customer-facing online balance inquiry or ecommerce redemption.
- External gift-card processor integration.
- Promotional certificates, coupons, loyalty points, or rewards.
- Arbitrary transfer between customers or unrelated active gift cards.
- Multi-currency stored value.
- Expiration, dormancy fees, or escheatment processing unless separately approved after legal and operational review.

## 4. Locked policy decisions

| Decision | Phase 10 contract |
| --- | --- |
| Balance authority | Immutable ledger entries; stored balance is a locked projection |
| Money | Integer cents in organization base currency |
| Store credit and trade credit | Separate customer-owned accounts and liabilities |
| Gift cards | Separate bearer instruments with their own accounts |
| Customer-credit scope | Organization-wide balance with entry-level store attribution |
| Negative balances | Prohibited |
| Stored-value authorization | Online only |
| Gift-card number security | Program prefix, high-entropy generation where ShelfSense is authority, required check digit, exact secure lookup, throttling |
| Gift-card PIN | Deferred |
| Manual gift-card number | May first appear at activation; preregistration is not required |
| Gift-card cash-out | Full eligible remaining balance only; dedicated stored-value operation |
| Retail refund alternative | Store credit is the ordinary stored-value destination |
| Trade credit from retail refund | Prohibited |
| Gift card as generic refund destination | Prohibited by default |
| Customer-to-customer transfer | Out of scope |
| Gift-card transfer | Controlled replacement only |
| Correction | Reversal facts; no edits or deletes |
| Accounting mapping and export | Deferred to later accounting phase |

## 5. Slice plan

### Slice 10.1 — Stored-value core

Build the shared account, operation, ledger, projection, policy, authorization, and idempotency infrastructure.

### Slice 10.2 — Customer store credit and trade credit

Create and operate customer-owned accounts, manual adjustments, refund-to-credit behavior, and customer balance/activity presentation.

### Slice 10.3 — Gift cards

Implement program-based identity, activation, reload, redemption, inquiry, cash-out, suspension, replacement, transfer, and bearer-card reporting.

### Slice 10.4 — POS and reconciliation integration

Integrate stored value into POS completion, refunds, post-voids, transaction history, expected cash, X/Z reports, and store-day reporting.

## 6. Shared stored-value model

### 6.1 `stored_value_accounts`

One account is one authoritative balance container.

| Field | Type | Contract |
| --- | --- | --- |
| `id` | UUID | UUIDv7 primary key |
| `account_type` | string | `store_credit`, `trade_credit`, or `gift_card` |
| `customer_id` | UUID, nullable | Required for customer account types; prohibited for gift-card accounts |
| `currency_code` | string(3) | Organization base currency |
| `balance_cents` | bigint | Required; default `0`; nonnegative projection |
| `status` | string | `active`, `suspended`, or `closed` |
| `opened_at` | timestamptz | Required |
| `closed_at` | timestamptz, nullable | Required only when closed |
| `lock_version` | integer | Required; default `0` |
| timestamps | timestamptz | Required |

Constraints:

- `balance_cents >= 0`.
- Customer ID is present exactly for `store_credit` and `trade_credit`.
- At most one non-closed store-credit account per customer and currency.
- At most one non-closed trade-credit account per customer and currency.
- Gift-card accounts have no direct customer owner.
- Currency cannot change after any ledger entry exists.
- Account type cannot change.
- An account with history cannot be deleted.

An account balance can change only through the stored-value posting service. Generic account update routes must not permit `balance_cents` assignment.

### 6.2 `stored_value_operations`

One operation records one completed stored-value business action. It is the root for one or more ledger entries.

| Field | Type | Contract |
| --- | --- | --- |
| `id` | UUID | UUIDv7 primary key |
| `operation_type` | string | Stable operation classification |
| `store_id` | UUID | Required operational attribution |
| `business_date` | date | Required immutable store business date |
| `occurred_at` | timestamptz | Required occurrence time |
| `actor_id` | UUID | Required responsible user |
| `source_type` | string | Required approved source type |
| `source_id` | UUID | Required approved source ID |
| `pos_session_id` | UUID, nullable | Register-session context where applicable |
| `idempotency_operation_id` | UUID | Required link to claimed operation |
| `reversal_of_id` | UUID, nullable | Original stored-value operation reversed |
| `reason_code` | string, nullable | Required for policy-controlled actions |
| `reason_name_snapshot` | string, nullable | Historic display fact |
| `notes` | text, nullable | Controlled operator explanation |
| timestamps | timestamptz | Required |

Operation types:

- `issue`
- `activate`
- `reload`
- `redeem`
- `refund`
- `cash_out`
- `transfer`
- `adjust`
- `reverse`

Approved source types are explicit and narrow. Initial examples include:

- `PosTransaction`
- `PosTender`
- `StoredValueAdjustment`
- `GiftCardReplacement`
- `GiftCardCashOut`

Future buyback completion may become an approved source without changing the ledger contract.

Operation invariants:

- Completed operations are immutable and cannot be deleted.
- The same approved source may create only its defined effect set.
- One idempotency claim produces at most one operation.
- A reversal references exactly one earlier operation.
- An operation can have at most one effective reversal.
- A reversal uses the dedicated `reverse` type and contains entries opposite to the original effective entries.
- Generic CRUD cannot create operations.

### 6.3 `stored_value_entries`

One entry records one account balance delta within an operation.

| Field | Type | Contract |
| --- | --- | --- |
| `id` | UUID | UUIDv7 primary key |
| `stored_value_operation_id` | UUID | Required operation root |
| `stored_value_account_id` | UUID | Required affected account |
| `entry_sequence` | integer | Required; nonnegative; unique per operation |
| `amount_cents` | bigint | Required signed nonzero balance change |
| `balance_after_cents` | bigint | Required nonnegative balance snapshot |
| `reversal_of_id` | UUID, nullable | Original entry reversed |
| `created_at` | timestamptz | Required persistence time |

Attribution such as store, business date, actor, source, and occurrence time lives on the operation and is not duplicated on every entry.

Entry invariants:

- `amount_cents != 0`.
- `balance_after_cents >= 0`.
- Unique `(stored_value_operation_id, entry_sequence)`.
- An original entry has at most one effective reversing entry.
- Entries are append-only.
- Transfer operations contain at least two entries and net to zero.
- All accounts in one operation use the same currency.
- Entry creation and account projection updates occur within the same database transaction.

`balance_after_cents` supports audit and activity presentation. The balance remains reconstructable from the sum of effective entry amounts.

### 6.4 Supporting operation records

Policy-controlled workflows may use focused source records rather than overloading the ledger operation with workflow state.

#### `stored_value_adjustments`

Records a requested and approved manual credit or debit:

- Account.
- Signed amount.
- Reason code and name snapshot.
- Required notes where policy demands.
- Requested actor.
- Approving actor, when required.
- Store and occurrence context.
- Resulting operation.

The adjustment record becomes immutable once posted.

#### `gift_card_cash_outs`

Records the controlled Register cash-out action:

- Gift card and account.
- Full balance paid.
- Applicable program policy snapshot.
- Register, POS session, store, and business date.
- Performing and approving users where applicable.
- Resulting stored-value operation.

#### `gift_card_replacements`

Records replacement authorization and lineage:

- Original card.
- Replacement card.
- Reason.
- Actor and approval.
- Resulting transfer operation.

These focused records are introduced only when their workflow needs facts not represented cleanly by the operation and entries. Do not create a generic source-record table.

## 7. Shared posting service

All balance changes go through one application boundary, conceptually:

```ruby
StoredValue::Post.call(
  operation_type:,
  entries:,
  source:,
  store:,
  business_date:,
  occurred_at:,
  actor:,
  idempotency_key:,
  pos_session: nil,
  reversal_of: nil
)
```

Within one database transaction, the service:

1. Claims or replays the existing `IdempotencyOperation` contract.
2. Resolves every affected account.
3. Locks accounts in deterministic UUID order.
4. Revalidates account, instrument, source, permission, and policy state.
5. Calculates every resulting balance.
6. Rejects negative balances, currency mismatches, and invalid effect sets.
7. Creates the stored-value operation.
8. Appends its entries in stable sequence order.
9. Updates account balance projections.
10. Commits linked POS tender, POS transaction, controlled-action, or Register effect atomically where applicable.
11. Returns the immutable operation result.

Same-key/same-payload replay returns the original result. Same-key/different-payload reuse fails.

Model callbacks must not create financial or stored-value facts implicitly.

## 8. Account lifecycle

### 8.1 Active

An active account may receive or surrender value according to account-type policy.

### 8.2 Suspended

A suspended account retains its balance and history but cannot be redeemed, debited, transferred, or cashed out. Policy may permit a controlled credit or reversal needed to correct an earlier operation.

### 8.3 Closed

A closed account is terminal. Closure requires a zero balance and no pending workflow. The account remains available for history and reporting.

Customer-account closure does not delete the customer. Gift-card instrument lifecycle is handled separately from account lifecycle.

## 9. Slice 10.1 — Stored-value core

### 9.1 Deliverables

- `stored_value_accounts`.
- `stored_value_operations`.
- `stored_value_entries`.
- Posting and reversal services.
- Projection rebuild and verification service.
- Account lifecycle controls.
- Store, business-date, actor, source, and idempotency attribution.
- Permission scaffolding.
- Activity-query services.
- Liability reporting by account type.

### 9.2 Projection verification

Provide an administrative verification service that compares each account's `balance_cents` with the sum of effective ledger entries.

It may report inconsistencies but must not silently correct them. A repair requires an explicit controlled operation or a separately approved projection rebuild that does not alter ledger history.

### 9.3 Liability reporting

Phase 10 reports operational outstanding balances by:

- Account type.
- Store of originating activity.
- Activity date range.
- Account status.

Outstanding organization-wide liability is calculated from current accounts or reconstructed ledger balances. Store attribution describes where activity occurred; it does not fragment an organization-wide customer or gift-card balance into store-owned sub-balances.

### 9.4 No accounting contract

Slice 10.1 does not add:

- GL account IDs to operations or entries.
- Journal direction.
- Accounting export status.
- Posting batches.
- General financial-event types.

Later accounting rules will determine how effective stored-value operations map to liability, tender-clearing, and cash accounts.

## 10. Slice 10.2 — Customer store credit and trade credit

### 10.1 Account ownership

Each customer may have:

- One active store-credit account per currency.
- One active trade-credit account per currency.

The accounts are separate and never combined into one fungible balance.

They may be displayed together for convenience, but redemption, activity, reporting, and policy remain distinguishable.

Customer merge workflows introduced in Phase 8 must define controlled account handling:

- Accounts are not silently reassigned by changing `customer_id`.
- If both customers have the same account type, balances are transferred through a controlled operation before the source account closes.
- Merge lineage remains visible.
- Active redemption cannot race with the transfer.

### 10.2 Store credit

Store credit may be issued from:

- A POS refund allocation.
- An authorized manual adjustment.
- A controlled opening-balance migration, if approved.

Store credit may be redeemed at any authorized store through a POS stored-value tender.

### 10.3 Trade credit

Trade credit may initially be issued through an authorized manual adjustment. Phase 12 adds issuance from completed buyback payout.

Trade credit is not created by a retail refund and is not automatically convertible to cash.

### 10.4 Manual adjustment

Manual adjustments require:

- Explicit credit or debit direction.
- Amount greater than zero in the operator command.
- Stable reason code and historic name snapshot.
- Performing user.
- Elevated permission.
- Notes or approval where policy requires them.
- Idempotency key.

Debit adjustments cannot produce a negative balance.

The UI must use explicit actions such as `Add store credit` and `Remove store credit`; it must not expose a balance-edit field.

### 10.5 Customer detail

Customer detail shows:

- Store-credit balance.
- Trade-credit balance.
- Account status.
- Recent activity by account.
- Operation type and amount.
- Store and business date.
- Source transaction, future buyback, or adjustment.
- Reversal and transfer lineage.
- Actor and reason where permitted.

### 10.6 Refund-to-credit policy

The Phase 10 default is:

- Return value to original tenders where supported and policy requires it.
- Use store credit as the normal stored-value alternative.
- Do not issue trade credit from retail returns.
- Do not use a new gift card as the ordinary generic refund destination.

Refund allocation is explicit and committed atomically with the POS refund.

### 10.7 Customer-credit cash-out

The shared ledger supports a future `cash_out` operation, but Phase 10 enables cash-out only for gift-card programs. Store-credit cash-out is prohibited unless a separate explicit policy is approved. Trade-credit cash-out is prohibited by default.

## 11. Slice 10.3 — Gift cards

### 11.1 Gift-card programs

A program defines an accepted number namespace and card policies.

Suggested `gift_card_programs` fields:

| Field | Contract |
| --- | --- |
| `id` | UUIDv7 primary key |
| `code` | Stable immutable machine code |
| `name` | Operator-facing name |
| `number_authority` | `system_generated` or `manual_external` |
| `prefix` | Unique normalized numeric prefix |
| `number_length` | Total normalized length, including check digit |
| `check_digit_algorithm` | Initially `luhn` |
| `reload_allowed` | Reload policy |
| `minimum_activation_cents` | Optional minimum activation value |
| `maximum_balance_cents` | Optional post-operation balance maximum |
| `cash_out_policy` | `prohibited`, `permitted_when_eligible`, or `required_when_eligible` |
| `cash_out_threshold_cents` | Eligibility threshold |
| `cash_out_threshold_inclusive` | Whether equality qualifies |
| `active` | Whether new cards may be activated |
| `lock_version` | Optimistic configuration concurrency |
| timestamps | Required |

At least two programs are expected:

1. ShelfSense-generated numbers.
2. Manual or externally printed numbers.

Their prefixes do not overlap each other or another scan namespace ambiguously.

Prefix, length, authority, and check-digit algorithm cannot change after cards have been activated under the program. Operating policies may change prospectively; material policy facts are retained on controlled operations where needed.

### 11.2 Gift-card instruments

Suggested `gift_cards` fields:

| Field | Contract |
| --- | --- |
| `id` | UUIDv7 primary key |
| `gift_card_program_id` | Required program |
| `stored_value_account_id` | Required one-to-one gift-card account |
| `number_digest` | Required keyed exact-lookup digest |
| `number_prefix` | Safe routing snapshot |
| `number_last_four` | Safe display value |
| `status` | `active`, `suspended`, `replaced`, or `closed` |
| `customer_id` | Optional administrative association |
| `activated_at` | Required activation time |
| `activated_store_id` | Required issuing store |
| `replaced_by_id` | Replacement lineage |
| `closed_at` | Terminal lifecycle time |
| `lock_version` | Lifecycle concurrency protection |
| timestamps | Required |

The ordinary lifecycle begins directly at `active` when activation completes. Manual numbers do not require preregistration as inactive cards.

### 11.3 Number format

Gift-card numbers use a dedicated numeric namespace rather than EAN-13, UPC, ISBN, product primary identifiers, SKUs, or inventory-unit identifiers.

A recommended 20-digit format is:

```text
PPP RRRR RRRR RRRR RRRR C
```

- `PPP`: configured program prefix.
- `R`: card-number body.
- `C`: check digit.

Presentation separators are removed during normalization.

System-generated bodies use a cryptographically secure random generator and are never sequential. Manual/external bodies are provided by the physical card or printing process.

### 11.4 Check digit

Every new-format number requires a valid check digit. Phase 10 uses Luhn unless another algorithm is explicitly adopted before implementation.

The check digit detects common input errors. It is not authentication and does not make predictable numbers secure.

### 11.5 Number authorities

#### System-generated prefix

- Only ShelfSense may introduce a previously unknown number.
- An operator cannot invent a number in this namespace.
- The number is generated or recognized as an allocation before activation.

#### Manual/external prefix

- A previously unknown number may first appear when scanned or keyed for activation.
- No import, allocation, or preregistration is required.
- Prefix, length, check digit, uniqueness, and program status are validated at completion.

An unknown number cannot be redeemed, reloaded, queried, replaced, transferred, or cashed out. It may enter the domain only through permitted activation.

### 11.6 Secure lookup

Lookup is exact-match only.

Store:

- Keyed digest of the normalized full number.
- Prefix.
- Last four digits.
- Recoverable encrypted full number only if an approved printing or reissuance workflow actually requires it.

Do not provide:

- Prefix or substring search.
- Autocomplete.
- Unmasked display in lists, ordinary activity, receipts, logs, URLs, or audit payloads.

Use generic failure behavior where disclosure of nonexistent versus unavailable cards is unnecessary. Throttle and audit repeated failed lookups.

### 11.7 PIN/access code

Phase 10 treats the card number as the bearer credential. It does not implement a PIN or access code.

An additional credential may be introduced later for customer-facing inquiry, ecommerce, or another higher-risk channel without changing the card's number, account, or ledger history.

### 11.8 Activation

Activation is a POS issuance action, not a tender.

For a manually supplied number, the Register:

1. Normalizes input.
2. Resolves the manual/external program.
3. Validates prefix, length, and check digit.
4. Performs an advisory uniqueness check.
5. Adds a pending activation to the working transaction.
6. Revalidates uniqueness, program status, and amount at completion.
7. Atomically creates the gift card, account, activation operation and entry, and completed POS facts.

For a system-generated number, ShelfSense:

1. Selects the active generated program.
2. Generates a cryptographically random body.
3. Calculates the check digit.
4. Claims uniqueness.
5. Associates the identity with the pending issuance.
6. Atomically creates and activates the card at POS completion.

If issuance requires the number to be printed before completion, ShelfSense may reserve the identity temporarily. A reservation is not a gift card, account, balance, or liability.

An abandoned or failed transaction leaves no active card, account, balance, or liability.

The same card cannot be activated and redeemed in one transaction during Phase 10.

### 11.9 Reload

Reload is also a POS issuance action, not a tender.

- Card must exist and be active.
- Program must permit reload.
- Resulting balance must respect program maximum.
- Value is added only when the POS transaction completes.
- Abandoned transactions have no balance effect.
- Reversal appends an opposite entry.

### 11.10 Redemption

Redemption is a stored-value POS tender.

- Customer association is not required.
- Partial redemption is allowed.
- Split tender is allowed.
- Multiple stored-value instruments may be used.
- Completion locks accounts in deterministic order and revalidates balances.
- Redemption cannot overdraw an account.
- POS tender, operation, entry, and balance projection commit atomically.

### 11.11 Balance inquiry

Balance inquiry requires a structurally valid exact number and authoritative online lookup.

Successful inquiry may show:

- Masked number.
- Current balance.
- Operator-appropriate status.
- Limited recent activity according to permission.

Inquiry creates no ledger operation. Security audit or throttling evidence may be recorded separately.

### 11.12 Cash-out

Gift-card cash-out settles stored-value liability and pays cash from an active Register session. It is neither a generic paid-out nor a merchandise refund.

Program policies:

- `prohibited`
- `permitted_when_eligible`
- `required_when_eligible`

Eligibility uses the configured threshold and explicit inclusive/exclusive boundary.

Cash-out rules:

- Full remaining eligible balance only.
- No arbitrary partial withdrawal.
- Active Register session required.
- Online authorization required.
- Card and account locked before revalidation.
- Cannot produce a negative balance.
- Customer association is irrelevant.
- Permission and approval policy enforced.
- Receipt uses masked identity.

One atomic cash-out creates:

- `GiftCardCashOut` source record.
- `cash_out` stored-value operation.
- Negative entry for the full balance.
- Zero account projection.
- Negative expected-cash effect for the active POS session.

The operation is reported separately from refunds, generic paid-outs, and future buyback payouts.

### 11.13 Customer association

- Optional.
- Does not change bearer semantics.
- Does not make the balance customer-owned store credit.
- Is not proof of ownership by itself.
- Does not move value.
- Changes are audited.

### 11.14 Suspension

Authorized users may suspend and reinstate a card with reason capture.

Suspension changes access state but not value. It creates audit history, not a stored-value operation.

While suspended, the card cannot be redeemed, reloaded, transferred, or cashed out. Controlled correction and reversal behavior follows explicit policy.

### 11.15 Replacement and transfer

Replacement creates a new instrument and account; it never changes the old card number.

Within one transaction:

1. Lock and revalidate the original card and account.
2. Capture reason, actor, and approval.
3. Create or resolve the replacement identity.
4. Create the replacement card and account.
5. Create one transfer operation.
6. Append `-balance` to the old account and `+balance` to the new account.
7. Mark the original card replaced and link it to the new card.
8. Activate the new instrument.

The original card remains permanently unusable and its account balance becomes zero. Complete lineage remains available.

Discretionary transfer among unrelated active cards is out of scope.

### 11.16 Future offline number generation

Phase 10 does not implement offline gift-card operations. The future automatic-number approach is nevertheless fixed conceptually:

- The server generates valid random numbers under the system-generated prefix.
- It reserves a bounded pool centrally.
- It assigns that pool to one terminal while online.
- The terminal may later consume an allocated identity under a separately approved ADR-005 activation contract.

Allocation reserves identity only. It does not create a card, account, balance, or liability.

The future design must separately define activation availability, redemption delay, exposure limits, terminal-loss handling, synchronization, reversals, and customer disclosure. Exhausting a terminal pool stops offline automatic generation.

## 12. Slice 10.4 — POS and reconciliation integration

### 12.1 Tender configuration

Add `stored_value` to `TenderType::CATEGORIES`.

Configure distinct tender types for:

- Store credit.
- Trade credit.
- Gift card.

The shared behavioral category drives Register and reconciliation behavior. The configured tender type identifies the specific account resolver and reporting classification.

Completed `PosTender` continues to snapshot:

- Tender type/code.
- Tender name.
- Behavioral category.
- Payment/refund direction.
- Applied amount.

Add an explicit link from the stored-value tender to its completed stored-value operation. Do not hide this relationship in generic metadata.

### 12.2 Operation distinctions

| Action | POS treatment | Stored-value treatment |
| --- | --- | --- |
| Activation | Issuance action/line | `activate`, positive entry |
| Reload | Issuance action/line | `reload`, positive entry |
| Redemption | Tender | `redeem`, negative entry |
| Refund to original stored value | Refund allocation/tender direction | `refund`, positive entry |
| Cash-out | Controlled Register operation | `cash_out`, negative full-balance entry |
| Replacement | Administrative controlled operation | `transfer`, paired entries |
| Manual adjustment | Administrative controlled operation | `adjust`, signed entry |

Activation and reload must not be represented as tenders because they issue value rather than settle the sale.

### 12.3 Completion sequence

At POS completion:

1. Resolve all stored-value instruments and accounts.
2. Lock accounts in deterministic UUID order.
3. Revalidate card, account, program, customer, and tender policies.
4. Revalidate balances and tender totals.
5. Complete POS transaction, lines, issuance actions, and tenders.
6. Create stored-value operations and entries.
7. Update account projections.
8. Complete inventory and tax effects.
9. Build the versioned completed POS operation envelope.
10. Commit atomically.

Any failure rolls back all linked effects.

### 12.4 Completed POS operation envelope

Extend the existing envelope with stored-value facts where applicable:

- Stored-value operation ID.
- Account type.
- Masked gift-card identity where applicable.
- Activation, reload, redemption, refund, or cash-out classification.
- Amount.
- Balance-after snapshot when appropriate.
- Reversal or replacement lineage.

Do not include full gift-card numbers.

### 12.5 Refund allocation

The cashier or policy service creates an explicit allocation plan before completion.

- Cash refunds reduce expected cash.
- External card refunds retain their existing external-reference behavior.
- Original stored-value portions ordinarily return to the same account.
- Store credit is the normal stored-value alternative when value cannot or should not return to another tender.
- Retail refunds do not create trade credit.
- Gift card is not the ordinary generic alternative destination.
- Total refund allocation cannot exceed the refundable amount.

Refund, POS facts, stored-value operations, entries, and projections commit atomically.

### 12.6 Post-void

Post-void appends a reversing POS transaction and reversing stored-value operations.

- Redemption reversal restores value.
- Refund reversal removes the refunded value.
- Activation or reload reversal removes issued value.
- Cash-out reversal restores value and expected cash.
- Original facts remain immutable.

Post-void is blocked if value issued by the original transaction has subsequently been spent, transferred, or cashed out and cannot be fully removed without a negative balance or broken lineage.

ShelfSense displays the conflicting downstream activity and requires a separate elevated correction workflow. It must not partially post-void or silently create a negative balance.

### 12.7 Expected cash

Before Phase 10:

```text
opening float + cash payments - cash refunds
```

During Phase 10:

```text
opening float
+ cash payments
- cash refunds
- completed gift-card cash-outs
+ reversed gift-card cash-outs
```

Phase 10 may extend `SessionTotals` directly using completed cash-out source facts. It does not need to introduce Phase 11's generalized cash-movement ledger prematurely.

### 12.8 X, Z, and store-day reporting

Report separately:

- Store credit issued.
- Store credit redeemed.
- Trade credit issued.
- Trade credit redeemed.
- Gift cards activated.
- Gift cards reloaded.
- Gift cards redeemed.
- Stored-value refunds.
- Gift-card cash-outs.
- Transfers.
- Reversals.
- Net liability movement by account type.
- Outstanding balance by account type.

Stored-value tenders do not directly affect expected cash. Their enclosing transaction's cash tender may affect expected cash. Gift-card cash-out directly reduces expected cash.

Closed session and reporting-period snapshots remain immutable. Reporting aggregates underlying authoritative facts rather than relying only on saved Z totals.

## 13. Reversal rules

### 13.1 General reversal

A reversal:

- References one original operation.
- Recreates every effective original entry with the opposite amount.
- Locks the same affected accounts.
- Revalidates that the reversal will not violate balance or lifecycle rules.
- Uses its own actor, store, business date, occurrence time, reason, and idempotency key.
- Preserves the original operation and entries unchanged.

### 13.2 Transfer reversal

Reversing a transfer swaps its paired effects. It is permitted only if instrument lifecycle and subsequent activity allow the original relationship to be restored safely.

Ordinary reversal must not reactivate a replaced or compromised card automatically.

### 13.3 Adjustment correction

An incorrect manual adjustment is reversed and replaced by a new correct adjustment. It is never edited.

## 14. Permissions and approvals

Suggested permissions:

### Shared/customer accounts

- `stored_value.view_customer_balances`
- `stored_value.view_activity`
- `stored_value.redeem_customer_credit`
- `stored_value.issue_manual_credit`
- `stored_value.debit_manual_credit`
- `stored_value.suspend_customer_account`
- `stored_value.reinstate_customer_account`

### Gift cards

- `gift_cards.balance_inquiry`
- `gift_cards.activate`
- `gift_cards.reload`
- `gift_cards.redeem`
- `gift_cards.cash_out`
- `gift_cards.suspend`
- `gift_cards.reinstate`
- `gift_cards.replace`
- `gift_cards.associate_customer`
- `gift_cards.view_activity`
- `gift_cards.manage_programs`

### Approval policy

Elevated approval may be required for:

- Manual debit adjustments.
- Adjustments above a configured threshold.
- Gift-card replacement.
- Cash-out according to program policy or amount.
- Exceptional correction after blocked post-void.

Approval captures both user identity and historic display-name snapshot. The performer cannot self-approve where separation is required.

## 15. Audit and security

Audit successful, failed, and denied attempts for:

- Manual adjustment.
- Account suspension and reinstatement.
- Gift-card activation failure due to duplicate identity.
- Repeated failed gift-card lookup.
- Cash-out.
- Replacement.
- Customer association changes.
- Program configuration changes.
- Reversal and exceptional correction.

Never place full gift-card numbers in audit subjects, logs, URLs, exported envelopes, or ordinary error messages.

Use correlation and operation IDs to trace one workflow across POS, stored-value, and audit facts.

## 16. Concurrency and idempotency

Required scenarios:

- Two registers attempt to redeem the final balance.
- Two registers attempt to activate the same manual number.
- Redemption races with suspension.
- Redemption races with replacement.
- Cash-out races with redemption.
- Cash-out races with reload.
- Post-void races with later redemption.
- Customer merge transfer races with redemption.
- One sale uses multiple stored-value accounts in different UI order.
- A request retries after commit but before receiving the response.
- The same idempotency key is reused with a different payload.

Rules:

- Account locks are acquired in deterministic UUID order.
- Instrument lifecycle locks are acquired before posting where instrument state controls access.
- Completion-time validation is authoritative.
- Database uniqueness constraints resolve final card-number races.
- No partial stored-value or POS completion is externally visible.

## 17. Validation and database constraints

Use database constraints where practical for:

- Account type and customer ownership shape.
- Account and card status enums.
- Nonnegative account and balance-after amounts.
- Nonzero entry amounts.
- Operation and entry reversal uniqueness.
- Entry sequence uniqueness.
- Gift-card account one-to-one relationship.
- Gift-card number digest uniqueness.
- Program prefix uniqueness.
- Customer account uniqueness.

Application services enforce cross-row invariants requiring locks, including balances, transfer net-zero behavior, lifecycle compatibility, source effect sets, and policy thresholds.

## 18. Administrative and cashier UX

### 18.1 Customer detail

- Separate store-credit and trade-credit summary panels.
- Clear account status.
- Recent activity table.
- Explicit `Add credit` and `Remove credit` controlled actions.
- Source links and reversal indicators.
- No editable balance input.

### 18.2 Gift-card administration

- Exact number lookup form.
- Masked identity after lookup.
- Balance and status.
- Recent activity.
- Suspend, reinstate, replace, and associate-customer actions according to permission.
- Program administration separate from card activity.

### 18.3 Register

- Scan or key gift card.
- Distinguish unknown valid manual card available for activation from an existing card.
- Add activation or reload as issuance action.
- Apply stored-value redemption as tender.
- Show available balance only after successful lookup.
- Offer cash-out only when eligible and authorized.
- Show remaining balance after completed operation.
- Preserve keyboard-first operation and unambiguous action labels.

## 19. Seed and configuration expectations

Seed or setup must provide:

- `stored_value` tender behavioral category support.
- Store-credit tender type.
- Trade-credit tender type.
- Gift-card tender type.
- At least one generated-number gift-card program.
- At least one manual/external-number gift-card program.
- Distinct non-overlapping prefixes.
- Required permissions assigned to appropriate seeded roles.
- Stable adjustment and replacement reason codes where workflows require them.

Do not seed active gift cards with arbitrary balances. Test fixtures create balances through operations and entries.

## 20. Test strategy

### 20.1 Unit/model tests

- Account ownership shape.
- Status transitions.
- Program immutability after activation history.
- Prefix, length, normalization, and Luhn validation.
- Cash-out threshold inclusive/exclusive boundary.
- Entry and reversal constraints.

### 20.2 Service tests

- Issue, activate, reload, redeem, refund, cash-out, transfer, adjust, and reverse.
- Balance projection after each operation.
- Negative-balance rejection.
- Deterministic multi-account lock ordering.
- Same-key replay and payload mismatch.
- Transaction rollback after injected failure.
- Projection verification.

### 20.3 POS integration tests

- Store-credit, trade-credit, and gift-card tender.
- Split cash/stored-value tender.
- Multiple stored-value instruments.
- Activation paid by cash or external card.
- Reload and subsequent redemption.
- Linked and policy-authorized refund allocation.
- Post-void restoration.
- Blocked post-void after downstream spend.
- Expected cash with cash-out and reversal.
- Completed operation envelope excludes full card number.

### 20.4 Concurrency tests

- Final-balance double redemption.
- Duplicate manual activation.
- Redemption versus cash-out.
- Replacement versus redemption.
- Suspension versus redemption.
- Refund retry.

### 20.5 Reporting tests

- Account balances equal effective entry sums.
- Liability totals by account type.
- Tender totals by configured stored-value tender type.
- Cash-out affects expected cash exactly once.
- Reversals net correctly.
- X, Z, and store-day totals derive from completed facts.

## 21. Phase-level acceptance criteria

1. A customer has separate store-credit and trade-credit balances.
2. Balances cannot be edited directly.
3. Every balance is reconstructable from immutable entries.
4. Retrying a completed operation cannot apply value twice.
5. A manual adjustment records actor, reason, store, business date, source, and approval where required.
6. A customer can redeem part of a store-credit balance and pay the remainder with another tender.
7. A retail refund may issue store credit but cannot issue trade credit.
8. ShelfSense can generate a random gift-card number with generated-program prefix and valid check digit.
9. A cashier can activate a previously unknown valid manual-program number without preregistration.
10. An abandoned activation leaves no card, balance, or liability.
11. Two registers cannot activate the same number.
12. An unknown generated-prefix number cannot be manually introduced.
13. Gift-card lookup is exact and ordinary interfaces expose only masked identity.
14. A bearer card can be redeemed without customer association or PIN.
15. Two registers cannot spend the same remaining balance.
16. Reload respects program and maximum-balance policies.
17. An eligible gift-card balance can be cashed out in full through an active Register session.
18. Cash-out reduces stored-value balance and expected cash atomically.
19. Cash-out is reported separately from refunds and generic paid-outs.
20. Replacement transfers the complete balance and permanently disables the original instrument.
21. Customer association does not change bearer semantics or move value.
22. Refunds and reversals append new entries rather than editing originals.
23. Post-void restores redeemed value.
24. Post-void is blocked when originally issued value has been spent or transferred.
25. X/Z and store-day reports distinguish stored-value issuance, redemption, refund, cash-out, transfer, and reversal.
26. Stored-value tenders do not alter expected cash except through their enclosing cash tender; cash-out does.
27. Projection verification detects any mismatch between account balance and effective ledger entries.
28. No Phase 10 workflow authorizes a stored-value balance offline.
29. No general financial-event, journal, or accounting-export table is introduced.
30. Existing POS, tender, tax, inventory, idempotency, reversal, session, and business-date contracts remain authoritative and are extended rather than duplicated.

## 22. Slice adoption gates

### 22.1 Slice 10.1 gate

- Account, operation, and entry schemas accepted.
- Posting and reversal services verified.
- Projection reconstruction proven.
- No generic financial-event persistence introduced.

### 22.2 Slice 10.2 gate

- Store and trade credit remain distinct.
- Manual adjustment controls verified.
- Customer merge interaction tested.
- Customer activity is reconstructable and permission-filtered.

### 22.3 Slice 10.3 gate

- Both number authorities work.
- Manual activation requires no preregistration.
- Check-digit and secure lookup behavior verified.
- Cash-out and replacement concurrency verified.
- PIN and offline value operations remain absent.

### 22.4 Slice 10.4 gate

- POS completion is atomic across transaction, tender, stored-value, inventory, and tax effects.
- Refund and post-void behavior verified.
- Expected cash includes cash-out exactly once.
- X/Z and store-day reporting reconcile to underlying facts.

## 23. Follow-on contracts

### Phase 11 — Cash management

Phase 11 adds the general Register cash-movement ledger for paid-ins, paid-outs, drops, transfers, buyback payouts, and corrections. It incorporates gift-card cash-out as a distinct existing source classification rather than converting it into a generic paid-out.

### Phase 12 — Buyback

Phase 12 may issue trade credit by using the Phase 10 posting service with the completed buyback as source. Cash payout depends on Phase 11.

### Later accounting phase

Accounting work evaluates the real operational sources then present:

- POS transactions and tenders.
- Inventory and valuation entries.
- Tax facts.
- Stored-value operations and entries.
- Cash movements.
- Buyback payouts.

It then defines versioned posting rules, GL mapping behavior, balanced journal construction, export batches, retries, and reversal handling. Phase 10 does not predict that persistence model.

### Future offline stored value

A separate bounded design may add terminal number pools and terminal-originated stored-value operations. Number allocation alone never authorizes offline value creation or redemption.

## 24. Deliverable

> ShelfSense can issue, activate, reload, redeem, refund, adjust, transfer, cash out, reverse, and reconcile store credit, trade credit, and gift cards through immutable stored-value operations and ledger entries. Customer balances remain separate by liability type; gift cards retain bearer identity; POS and Register effects commit atomically; and Phase 10 does not introduce a premature general financial or accounting contract.
