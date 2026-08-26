# Phase 10 — Stored value plan

Status: **Proposed**.

## Goal

Implement authoritative store credit, trade credit, and gift cards without treating balances as editable customer or card fields, and without a universal financial-event table ([ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md)).

## Exit outcome

> ShelfSense can issue, activate, reload, redeem, refund, transfer, consolidate, manually adjust, reverse, cash out, and reconcile store credit, trade credit, and gift cards without editable balances or a cross-domain financial-event subledger.

## Scope boundary

| In scope | Out of scope (defer) |
|---|---|
| Shared accounts, operations, entries, `StoredValue::Post` | Universal `financial_events` table; GL IDs; journal direction; export status ([ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md)) |
| Store credit and trade credit as distinct customer-owned liabilities | Opening-balance migration |
| Gift-card programs, bearer instruments, Rails-encrypted numbers | Gift-card PIN; ecommerce inquiry; external processor |
| POS issuance table (activation/reload); `stored_value` tenders | Gift-card merchandise SKU / tax class / department |
| Gift-card refund destinations (original card, new refund card, store credit) | Unused-instrument return (later POS policy slice) |
| Gift-card cash-out vs expected cash | Store-credit or trade-credit cash-out |
| Same-type transfers, consolidation, merge transfer | Cross-type conversion between store credit, trade credit, and gift-card value |
| Online-only SV | Customer-initiated self-service transfer |
| Trade-credit tender seeded; manual issue | Phase 11 paid-in/out, drops, safe transfers |
| Controlled first print and print recovery ([ADR-026](../../adr/ADR-026-gift-card-number-protection.md)) | Offline activation/redeem (ADR-005) |
| | Phase 12 buyback intake and payout workflow |
| | Multi-currency; expiration; escheatment; loyalty |
| | General administrative plaintext reveal of gift-card numbers |

## Slices

### 10.1 — Stored-value core

Accounts, operations, entries, posting and reversal, projection verification, outbox event types, permission scaffolding. No POS completion changes except what tests need for the service API.

### 10.2 — Customer store credit and trade credit

Customer-owned store-credit and trade-credit accounts; full and partial same-type transfers; account consolidation; `Customers::MergeStoredValueAccounts`; controlled manual credit/debit adjustments; adjustment reasons and approvals; deactivate-with-balance; customer activity. Refund destination rules are implemented with POS in 10.4. Seed system-protected `store_credit` and `trade_credit` tender types when tenders land in 10.4; account types exist here. Policy: [phase10-account-transfers-and-adjustments.md](phase10-account-transfers-and-adjustments.md).

### 10.3 — Gift-card programs and instruments

Programs, instruments, numbering, Rails Active Record Encryption, administrative inquiry resolver, inquiry, suspend/reinstate, replacement, optional customer association, gift-card nav destinations. Do **not** insert gift-card routing into the Register scan path. Activation/reload/redeem and Register scan integration wait for 10.4. Cash-out waits for 10.5.

### 10.4 — POS issuance, tenders, refund destinations, first print, post-void

`pos_stored_value_issuances`; `stored_value` tender category and `pos_stored_value_tender_details`; `pos_transactions.customer_id`; signed-net rewrite; envelope/core links; nested idempotency; Register gift-card scan routing; controlled first print of generated activation and generated refund cards (plus complete-retry of that outcome); masked ordinary receipts; post-void fail-closed on downstream spend. Same-transaction activate+redeem and reload+redeem (any cards) forbidden.

Refund destinations:

- Refund to original gift card when the customer presents the matching instrument.
- Refund to a newly created refund gift card when the original instrument is unavailable.
- Refund to customer store credit.
- Explicit prohibition on retail-refund creation of trade credit.
- Stored-value tender destination details in Core.

### 10.5 — Cash-out, closeout, recovery print, reporting nav

Gift-card cash-out (physical-cash confirmation on reversal); expected-cash formula; X/Z and reporting-period snapshots; exceptional print recovery; cash-out receipts; cash-out/reporting `Admin::NavigationCatalog` destinations and final nav audit. Administrative destinations for 10.2/10.3 screens land in those slices.

## Architectural position

```text
StoredValueOperation       completed business action
  └── StoredValueEntry     signed balance change
        └── Account.balance_cents  locked projection
```

POS and administrative sources hold `stored_value_operation_id`. Operations do not store inverse source FKs.

```text
activation / reload     -> pos_stored_value_issuances -> operation
redemption / refund     -> pos_tenders + tender details -> operation
cash-out                -> gift_card_cash_outs -> operation
adjust                  -> stored_value_adjustments -> operation
transfer / consolidation / merge -> stored_value_transfers -> operation
replacement             -> gift_card_replacements -> operation
```

No generic `source_type` / `source_id` on operations.

## Locked policy

| Decision | Contract |
|---|---|
| Balance authority | Ledger entries; `balance_cents` is a projection |
| Money | Integer cents; immutable `currency_code` snapshot from `system_settings.base_currency_code` |
| Uniqueness | One non-closed store-credit and one non-closed trade-credit account per customer (not per currency) |
| Negative balances | Prohibited |
| Authorization | Online only |
| Register ordinary SV | `pos.transact` covers activate, reload, redeem store/trade/gift, and refund destinations |
| Exceptional Register | `gift_cards.cash_out`; full number only on controlled print/recovery |
| Merge | Transfer operation; no `customer_id` rewrite on ledger rows; close zero-balance source accounts without creating a survivor account |
| Inactive customer | No new credit; redeem only after reactivation; reversals of historic ops allowed; deactivate warns/blocks on nonzero balance |
| Cash-out | Gift cards only; full remaining eligible balance; policy values `prohibited`, `permitted_when_eligible`, `required_on_request_when_eligible` |
| Trade-credit cash-out | Prohibited |
| Approval thresholds | Organization/system setting for manual adjust; gift-card program for cash-out threshold and `cash_out_approval_required` |
| `issue` vs `activate` vs `refund` | `issue` is non-refund value creation; gift cards are `activate`d; all POS refund destinations use `refund` |

### Gift-card-funded refund

```text
Gift-card-funded refund:
- Original matching card when presented and usable
- New refund gift card when original instrument is unavailable
- Customer store credit when customer is identified and chooses account-bound value
- Never trade credit
```

A new gift card is not a generic destination for arbitrary refund value. It is permitted as a substitute bearer instrument for value originally paid by gift card.

### Same-type store-credit and trade-credit transfer

```text
Same-type store-credit and trade-credit transfer:
- Full or partial
- Same customer or different customers
- Elevated permission
- Second-user approval
- Paired entries net to zero
- Cross-type conversion prohibited
```

Detail: [phase10-account-transfers-and-adjustments.md](phase10-account-transfers-and-adjustments.md).

### Manual adjustments

```text
Manual adjustments:
- Store credit, trade credit, and eligible gift-card accounts
- Explicit credit/debit direction
- Required reason
- All debits require second user
- Credits at or above organization threshold require second user
- Never direct balance editing
```

## Sequencing

```text
10.1 core
  → 10.2 customer credit (merge, transfer, adjust, lifecycle)
  → 10.3 gift-card identity (can overlap late 10.2)
  → 10.4 POS commercial (depends on 10.1–10.3)
  → 10.5 cash-out, closeout, print, nav (depends on 10.4)
```

Do not ship Register redemption before Core posting, tenders, and signed-net checks exist.

## UX adoption

- New administrative and customer-detail stored-value screens use current UDS primitives (feature-led).
- Register stays on the POS shell (Importmap + Turbo + Stimulus). Issuance is a distinct basket section, not a merchandise line.
- New destinations go through `Admin::NavigationCatalog` ([navigation-proposal.md](../ux-design-system/navigation-proposal.md)); no one-off header links.

## ADR and documentation triggers

- [ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md) Accepted — domain ledgers.
- [ADR-026](../../adr/ADR-026-gift-card-number-protection.md) Accepted — gift-card numbers.
- [ADR-011](../../adr/ADR-011-naming-conventions.md) — `reversal_of_id` only.
- [ADR-023](../../adr/ADR-023-customer-merge.md) §14 — merge command pointer.
- [docs/glossary.md](../../glossary.md) — stored-value terms.

## Acceptance

1. Store credit, trade credit, and gift-card liabilities are distinct; balances reconstruct from entries.
2. Gift-card activation/reload is not merchandise and not a tender; amount due includes issuance; issuance is not taxable merchandise.
3. Completed Core holds FKs from source rows to stored-value operations; envelope snapshots masked facts only.
4. Merge transfers via `Customers::MergeStoredValueAccounts`; ledger `customer_id` unchanged; zero-balance source accounts close without creating a survivor account.
5. Gift-card refund destinations and ordinary post-void-when-spent behave as [phase10-refund-post-void.md](phase10-refund-post-void.md).
6. Same-type transfers and eligible-account adjustments behave as [phase10-account-transfers-and-adjustments.md](phase10-account-transfers-and-adjustments.md).
7. Expected cash includes gift-card cash-outs; closed-session snapshots stay immutable.
8. Full gift-card numbers never appear in logs, audit payloads, envelopes, or ordinary reprints.
9. No `financial_events` table, GL mapping columns, or Phase 11 cash-movement ledger.

## Parallel work

Phase 10 is the next domain program after Phase 9. UDS-6/7 stay parked. Do not pull buyback or cash locations into these slices.
