# Phase 10 — Stored value plan

Status: **Proposed**.

## Goal

Implement authoritative store credit, trade credit, and gift cards without treating balances as editable customer or card fields, and without a universal financial-event table ([ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md)).

## Exit outcome

> ShelfSense can issue, activate, reload, redeem, refund, reverse, cash out eligible gift cards, and reconcile those facts on the Register without treating balances as editable fields, without a gift-card merchandise SKU, and without a cross-domain financial-event subledger.

## Scope boundary

| In scope | Out of scope (defer) |
|---|---|
| Shared accounts, operations, entries, `StoredValue::Post` | Universal `financial_events` table; GL IDs; journal direction; export status ([ADR-025](../../adr/ADR-025-domain-owned-operational-ledgers.md)) |
| Store credit and trade credit as distinct customer-owned liabilities | Opening-balance migration |
| Gift-card programs, bearer instruments, encrypted numbers | Gift-card PIN; ecommerce inquiry; external processor |
| POS issuance table (activation/reload); `stored_value` tenders | Gift-card merchandise SKU / tax class / department |
| Unused-instrument return (deactivate unused card + refund tenders) | Store-credit or trade-credit cash-out |
| Gift-card cash-out vs expected cash | Phase 11 paid-in/out, drops, safe transfers |
| Merge transfer command | Customer-to-customer discretionary transfer |
| Online-only SV | Offline activation/redeem (ADR-005) |
| Trade-credit tender seeded; manual issue | Phase 12 buyback intake and payout workflow |
| Print/reveal of generated numbers ([ADR-026](../../adr/ADR-026-gift-card-number-protection.md)) | Multi-currency; expiration; escheatment; loyalty |

## Slices

### 10.1 — Stored-value core

Accounts, operations, entries, posting and reversal, projection verification, outbox event types, permission scaffolding. No POS completion changes except what tests need for the service API.

### 10.2 — Customer store credit and trade credit

Customer-owned accounts; `Customers::MergeStoredValueAccounts`; admin adjust with second-user rule; deactivate-with-balance warning/block; customer show activity; refund-to-credit policy (implemented with POS in 10.4). Seed system-protected `store_credit` and `trade_credit` tender types when tenders land in 10.4; account types exist here.

### 10.3 — Gift-card programs and instruments

Programs, instruments, numbering, encryption, scan routing, inquiry, suspend/reinstate, replacement, optional customer association. Activation/reload/redeem wait for 10.4. Cash-out waits for 10.5.

### 10.4 — POS issuance, tenders, unused return, post-void

`pos_stored_value_issuances`; `stored_value` tender category; `pos_transactions.customer_id`; signed-net rewrite; envelope/core links; nested idempotency; unused-instrument return; post-void fail-closed on downstream spend. Same-transaction activate+redeem and reload+redeem (any cards) forbidden.

### 10.5 — Cash-out, closeout, print, admin nav

Gift-card cash-out; expected-cash formula; X/Z and reporting-period snapshots; receipt/print contracts; UDS admin screens; `Admin::NavigationCatalog` destinations.

## Architectural position

```text
StoredValueOperation       completed business action
  └── StoredValueEntry     signed balance change
        └── Account.balance_cents  locked projection
```

POS links:

```text
activation / reload     -> pos_stored_value_issuances -> operation
redemption / refund-to-credit -> pos_tenders -> operation
unused-card return      -> reverse issuance + refund tenders -> reverse operation
cash-out                -> gift_card_cash_outs -> operation
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
| Register ordinary SV | `pos.transact` covers activate, reload, redeem store/trade/gift |
| Exceptional Register | `gift_cards.cash_out`; reveal is never ordinary reprint |
| Merge | Transfer operation; no `customer_id` rewrite on ledger rows |
| Inactive customer | No new credit; redeem only after reactivation; reversals of historic ops allowed; deactivate warns/blocks on nonzero balance |
| Cash-out | Gift cards only; full remaining eligible balance; policy values `prohibited`, `permitted_when_eligible`, `required_on_request_when_eligible` |
| Trade-credit cash-out | Prohibited |
| Approval thresholds | Organization/system setting for manual adjust; gift-card program for cash-out threshold |
| `issue` vs `activate` | Customer credit is issued; gift cards are activated |

## Sequencing

```text
10.1 core
  → 10.2 customer credit (merge, adjust, lifecycle)
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
3. Completed Core holds FKs to stored-value operations; envelope snapshots masked facts only.
4. Merge transfers via `Customers::MergeStoredValueAccounts`; ledger `customer_id` unchanged.
5. Unused-instrument return and ordinary post-void-when-spent behave as [phase10-refund-post-void.md](phase10-refund-post-void.md).
6. Expected cash includes gift-card cash-outs; closed-session snapshots stay immutable.
7. Full gift-card numbers never appear in logs, audit payloads, envelopes, or ordinary reprints.
8. No `financial_events` table, GL mapping columns, or Phase 11 cash-movement ledger.

## Parallel work

Phase 10 is the next domain program after Phase 9. UDS-6/7 stay parked. Do not pull buyback or cash locations into these slices.
