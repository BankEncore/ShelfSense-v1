# Glossary

Canonical ShelfSense terms. Add materially distinct words here rather than inventing local synonyms ([ADR-011](adr/ADR-011-naming-conventions.md)).

This file starts with stored-value vocabulary for [Phase 10](planning/phase10-stored-value/README.md) and the project-wide terms those contracts depend on. Expand as other domains need a durable definition.

## Project-wide

| Term | Meaning |
|---|---|
| **supplier** | Merchandise source; not “vendor.” |
| **register** | Durable logical POS checkout position in a store ([ADR-021](adr/ADR-021-register-and-terminal-identity.md)). |
| **terminal** | Concrete POS client/device identity (deferred until standalone/offline POS). |
| **session** | Authenticated or operational period; qualify when ambiguous (for example Register session). |
| **inventory_unit** | Individually tracked physical unit. |
| **inventory_balance** | Mutable inventory projection. |
| **reserved** | Inventory commitment; not “pending.” |
| **cancelled** | Spelled with two l’s. |
| **reversal_of_id** | Stored FK on the compensating record. Inverse association name is `reversed_by`; do not persist `reversed_by_id`. |

## Stored value

| Term | Meaning |
|---|---|
| **Stored value** | Organization liability held as store credit, trade credit, or gift-card balances. Not merchandise revenue, not a generic financial-event row. |
| **Stored-value account** | Authoritative balance container. `balance_cents` is a locked projection over entries. |
| **Stored-value operation** | One completed stored-value business action (issue, activate, reload, redeem, refund, cash-out, transfer, adjust, reverse). Immutable. |
| **Stored-value entry** | One signed balance change on one account inside an operation. Append-only. |
| **Store credit** | Customer-owned retail-credit liability. Organization-wide balance; activity attributed to a store. Ordinary refund-to-credit destination. |
| **Trade credit** | Customer-owned buyback-related liability, distinct from store credit. Manual issue in Phase 10; buyback issue in Phase 12. Not created by retail refunds. Cash-out prohibited. |
| **Gift card** | Bearer stored-value **instrument** with its own account. Optional customer association is not ownership. |
| **Gift-card program** | Number namespace and operating policy (prefix, length, reload, cash-out). |
| **Gift-card instrument** | The `gift_cards` row: digest, encrypted number, status, program, 1:1 account. |
| **Gift-card activation** | POS **issuance** that creates the instrument and liability when the customer pays. Not a tender and not a merchandise line. |
| **Reload** | POS issuance that adds value to an existing active gift card. |
| **Redemption** | POS **tender** that spends stored value against amount due. |
| **Cash-out** | Controlled Register payout of a gift card’s full eligible remaining balance. Not a generic paid-out; not a tender. |
| **Transfer** | Ledger move of a balance (customer merge, or gift-card replacement). Not discretionary customer-to-customer transfer. |
| **Tender versus issuance** | A tender settles what the customer owes or is owed. An issuance is customer-paid sale of gift-card liability and increases amount due. Refund-to-credit is a tender, not an issuance. |
| **Unused-instrument return** | Reverse an unused gift-card issuance and refund tenders. Not a merchandise return. |

Phase 10 contracts: [phase10-plan.md](planning/phase10-stored-value/phase10-plan.md).
