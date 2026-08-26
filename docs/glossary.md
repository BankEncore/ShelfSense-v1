# Glossary

Canonical ShelfSense terms. Add materially distinct words here rather than inventing local synonyms ([ADR-011](adr/ADR-011-naming-conventions.md)).

This file starts with stored-value and cash-accountability vocabulary and the project-wide terms those contracts depend on. Expand as other domains need a durable definition.

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
| **Store credit** | Customer-owned retail-credit liability. Organization-wide balance; activity attributed to a store. Ordinary account-bound refund destination. |
| **Trade credit** | Customer-owned buyback-related liability, distinct from store credit. Manual issue in Phase 10; buyback issue in Phase 12. Not created by retail refunds as a generic destination. Cash-out prohibited. |
| **Gift card** | Bearer stored-value **instrument** with its own account. Optional customer association is not ownership. |
| **Gift-card program** | Number namespace and operating policy (prefix, length, reload, cash-out). |
| **Gift-card instrument** | The `gift_cards` row: digest, encrypted number, status, program, 1:1 account. |
| **Gift-card activation** | POS **issuance** that creates the instrument and liability when the customer pays. Not a tender and not a merchandise line. |
| **Reload** | POS issuance that adds value to an existing active gift card. |
| **Redemption** | POS **tender** that spends stored value against amount due. |
| **Original-instrument refund** | Refund of gift-card-funded value onto the presented matching original (or verified replacement) card. |
| **Refund gift card** | New bearer instrument created only for value originally paid by gift card when the original instrument is unavailable. Receives the current refund amount only; does not replace or drain the original card. |
| **Cash-out** | Controlled Register payout of a gift card’s full eligible remaining balance. Not a generic paid-out; not a tender. |
| **Transfer** | Atomic, net-zero movement between same-type stored-value accounts. Includes customer merge, administrative transfer, and account consolidation. Cross-type movement is conversion, not transfer. |
| **Account consolidation** | Full-balance same-type transfer that closes the source account. |
| **Manual adjustment** | Controlled credit or debit of an eligible account through a reason catalog. Never a balance-field edit, POS refund, or transfer. |
| **Stored-value conversion** | Moving value from one account type to another (store credit ↔ trade credit ↔ gift card). Explicitly prohibited in Phase 10. |
| **Credential print recovery** | Narrowly authorized service that decrypts a stored number for a reasoned reprint. Not a general reveal screen. |
| **Tender versus issuance** | A tender settles what the customer owes or is owed. An issuance is customer-paid sale of gift-card liability and increases amount due. Refunds (including new refund cards) are tenders, not issuance. |

Phase 10 contracts: [phase10-plan.md](planning/phase10-stored-value/phase10-plan.md). Unused-instrument return is deferred and is not a Phase 10 glossary term.

## Cash accountability

| Term | Meaning |
|---|---|
| **POS session** | Cashier custody interval on a Register; the till for Phase 11 MVP. Not a `cash_drawers` row. |
| **Store safe** | The store’s persistent accountable cash location. One operational safe per store in MVP. |
| **Deposit in transit** | Prepared deposit that has left the safe. Bank confirmation is deferred. |
| **Opening float** | Session snapshot (`opening_float_cents`) of a safe→session transfer after Phase 11 activation. |
| **Available cash** | Expected session cash while the session is open. Cannot go negative. |
| **Paid-in / paid-out** | Non-sale cash into or out of an open session. Not a tender; not gift-card cash-out. |
| **Drop** | Mid-shift transfer from the open session to the safe. |
| **Replenishment** | Transfer from the safe to an open session. |
| **Session close transfer** | Move of **counted** session cash to the safe at close (`session_close`). |
| **Over / short** | Explicit reconcile movement that aligns expected cash with an accepted count. Not a paid-in/out. |
| **Manager-assisted close** | Privileged close of another cashier’s session; assigned cashier unchanged. |

Phase 11 contracts: [phase11-plan.md](planning/phase11-cash-accountability/phase11-plan.md). Direct session-to-session transfer and bank deposit confirmation are deferred.
