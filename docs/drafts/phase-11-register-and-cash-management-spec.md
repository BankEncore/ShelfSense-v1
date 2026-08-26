# Phase 11 — Register and Cash Management

**Status:** Superseded  
**Canonical packet:** [docs/planning/phase11-cash-accountability/README.md](../planning/phase11-cash-accountability/README.md)  
**ADRs:** [ADR-021](../adr/ADR-021-register-and-terminal-identity.md), [ADR-025](../adr/ADR-025-domain-owned-operational-ledgers.md)

This draft is historical. Do not implement from it. Independent cash drawers, workstation vocabulary, copied POS cash tenders, offline/`closing` lifecycle, cashless-without-session, and hard store-day finalization in the text below are **rejected**. The packet extends `Register`, `PosSession`, `Pos::SessionTotals`, and `CloseSession`.

---

# Phase 11 — Register and Cash Management (historical draft)

**Status:** Proposed (superseded)  
**Date:** 2026-08-26  
**Depends on:** POS transaction and tender completion; workstations; stores and business dates; users, roles, permissions, and approval authentication; audit events; Phase 10 stored-value cash-out contract  
**Enables:** Phase 12 cash-based buyback payouts; later financial and bank reconciliation

## 1. Purpose

Phase 11 completes ShelfSense's operational cash lifecycle before cash-based buyback payouts are introduced.

The phase makes each pool of cash accountable from the time money leaves the store safe as an opening float, through drawer activity and reconciliation, until the cash returns to the safe and is prepared for deposit.

The MVP uses a deliberately narrow operating model:

```text
Store safe → Cash drawer session → Store safe → Deposit in transit
```

This is an operational cash-accountability system, not a general ledger, bank-reconciliation system, or general cash-logistics platform.

## 2. Goals

Phase 11 must allow an authorized store to:

1. Configure identifiable cash drawers independently from workstations.
2. Open a cash drawer session with an opening count and float transferred from the safe.
3. Associate every cash-affecting POS fact with an open drawer session.
4. Record paid-ins, paid-outs, cash drops, and safe-to-drawer replenishments.
5. Determine available cash before refunds, stored-value cash-outs, and future buyback payouts.
6. Close a drawer using a blind count, reconcile expected versus counted cash, and transfer all counted cash to the safe.
7. Count and reconcile the store safe independently from drawer reconciliation.
8. Retain an approved safe balance and prepare the remaining cash as a deposit.
9. Report drawer, safe, deposit, over/short, and non-sale cash activity by store business date.
10. Correct completed cash activity through explicit reversal and replacement rather than mutation.

## 3. Non-goals

The following are deferred:

- direct drawer-to-drawer transfers;
- multiple operational safes per store;
- multi-stage internal transfer states such as initiated, released, received, and disputed;
- internal cash-in-transit locations for drawer/safe transfers;
- integrated offline or sealed-drawer close workflows;
- dedicated forced-takeover or cash-investigation case management;
- allocation of one deposit across multiple business dates;
- bank statement import, bank matching, or full bank reconciliation;
- bank-confirmed deposit adjustments and returned-deposit workflows;
- foreign currency;
- configurable approval-rule engines;
- per-store overrides of organization cash thresholds;
- general-ledger posting or account mapping;
- retained cash in a closed drawer;
- arbitrary transfers between cash locations.

When a store needs to move money between drawers, it must use two movements:

```text
Drawer A → Safe
Safe → Drawer B
```

## 4. Terminology and identity

### 4.1 Workstation

A workstation is the POS device/configuration identity. It owns operational configuration and its receipt-number sequence. It never owns cash.

### 4.2 Cash drawer

A cash drawer is a durable, identifiable physical till or removable cash insert. It exists independently of any workstation and may be assigned to different workstations over time.

A drawer may be active or inactive. Deactivation is prohibited while it has an open session.

### 4.3 Cash drawer session

A cash drawer session is one interval of cash custody and accountability. The phase does not introduce a separate abstract `register_session`; the register session is the cash drawer session.

Each session belongs to exactly one:

- store;
- cash drawer;
- workstation;
- responsible user;
- business date.

A drawer may have many sessions over time but no more than one open session. A workstation may have no more than one open cash drawer session.

The responsible user remains accountable for the session. Other authorized users may perform activity against it, but every operation records its actual actor.

### 4.4 Store safe

The store safe is the store's persistent accountable cash location. The MVP supports one operational safe per store.

The safe is not a daily session. Its expected balance carries forward until changed by immutable cash movements or an accepted reconciliation.

### 4.5 Deposit in transit

Deposit in transit represents a prepared deposit that has left safe custody. Phase 11 records deposit preparation and release from store custody. Confirmation against the bank is deferred.

### 4.6 Z-period and store day

The following remain separate contracts:

- transaction business date;
- workstation Z-period;
- cash drawer session;
- store-day finalization.

A workstation may have multiple drawer sessions during a Z-period. A drawer session does not close a Z-period. Store-day reporting aggregates underlying transaction, tender, and cash facts rather than relying only on saved Z totals.

## 5. Core invariants

1. Workstations do not hold cash balances.
2. Every cash drawer session has exactly one drawer and one responsible user.
3. A drawer and workstation may each participate in no more than one open drawer session.
4. Cash sales, cash refunds, cash payouts, and drawer cash activity require an open, unfrozen drawer session.
5. Cashless POS transactions do not require an open drawer session.
6. Completed cash movements, counts, reconciliations, transfers, and deposits are immutable.
7. Corrections use linked reversals and, when necessary, replacement facts.
8. Cash movements use integer cents in the organization's base currency.
9. Expected cash is derived from cash movements; a count is an observation of physical cash.
10. An accepted variance is recorded explicitly as cash over or cash short and rebases expected cash to the accepted physical count.
11. No cash location may post an operation that makes its expected balance negative.
12. Every internal transfer creates balanced source and destination ledger entries atomically.
13. All counted drawer cash must transfer to the safe before the drawer session closes.
14. A closed drawer has an expected balance of zero and cannot receive later activity.
15. Closed drawer sessions are never reopened.
16. Every deposit belongs to one store and one business date in the MVP.
17. Retried commands are idempotent and cannot duplicate cash movements.
18. Authorization and available-cash rules are revalidated under lock immediately before posting.

## 6. Authoritative cash ledger

Cash movements are the authoritative record of expected cash. A balance projection may be maintained for efficient access, but it must be rebuildable from the ledger.

Each movement records at minimum:

- store;
- accountable cash location;
- amount and direction;
- movement type;
- business date;
- occurred-at timestamp;
- performed-by user;
- approved-by user when approval was required;
- source domain record and idempotency key;
- reason where applicable;
- reversal lineage;
- audit and policy context required by the authorization framework.

Movement types must distinguish at least:

- opening float transfer;
- POS cash tender;
- POS cash refund;
- paid in;
- paid out;
- cash drop;
- safe-to-drawer replenishment;
- stored-value cash-out;
- future buyback cash payout;
- deposit preparation;
- cash over recognition;
- cash short recognition;
- reversal.

Gift-card cash-out and future buyback payout are not generic paid-outs. They retain their own domain operation and are atomically linked to their cash movements.

## 7. Expected cash and available cash

### 7.1 Drawer expected cash

At any point in an open session:

```text
expected drawer cash
  = opening float
  + net POS cash received
  + paid-ins
  + replenishments received
  - paid-outs
  - cash drops
  - cash refunds
  - stored-value cash-outs
  - future buyback cash payouts
  ± accepted reconciliation entries and reversals
```

Net POS cash received accounts for cash accepted less change returned.

### 7.2 Safe expected cash

```text
expected safe cash
  = prior reconciled safe balance
  + drawer transfers and drops received
  - opening floats and replenishments issued
  - deposits prepared
  ± accepted safe reconciliation entries and reversals
```

### 7.3 Available drawer cash

For MVP:

```text
available drawer cash = expected drawer cash
```

A payout or refund is prohibited when it would make expected drawer cash negative. Organization policy may also require approval when the operation would reduce cash below a configured preferred retained amount, but approval cannot authorize a negative expected balance.

The available-cash check and movement posting occur within one transaction using location/session locking and post-lock revalidation.

## 8. Cash counting

Cash counts are immutable observations and do not independently change expected cash.

Counts support:

- drawer opening;
- drawer closing;
- safe reconciliation;
- deposit preparation.

Each count records:

- store and cash location;
- drawer session when applicable;
- business date;
- purpose;
- counter;
- timestamp;
- total;
- denomination lines;
- status;
- superseded count when applicable.

The total is derived from denomination quantities and values. Before a count is accepted, it may be discarded and replaced. After acceptance, a mistake requires reversal of the resulting reconciliation and a replacement count.

Closing drawer and safe counts are blind for ordinary staff: expected cash is not displayed until the count is submitted. Authorized managers may have permission to view expected cash before counting.

## 9. Drawer lifecycle

### 9.1 States

The drawer session lifecycle is:

```text
open → closing → closed
```

A `closing` session rejects new cash activity while synchronization, count, reconciliation, approval, and safe transfer complete. A failed close may return the session to `open` only if no count, reconciliation, or transfer has been accepted. A completed session never reopens.

### 9.2 Opening

To open a drawer session, an authorized user must:

1. select an active, available drawer;
2. use a workstation without another open drawer session;
3. enter a denomination opening count;
4. confirm the responsible user and business date;
5. transfer the counted opening float from the store safe to the drawer.

Opening is atomic: the session and balanced safe-to-drawer transfer either both post or neither posts.

Opening is prohibited when:

- the drawer or workstation already has an open session;
- the drawer is inactive;
- the safe has insufficient expected cash;
- the user lacks permission;
- another opening wins a concurrent race.

The MVP treats the opening count as the intended float amount. It does not separately model a target-float replenishment workflow.

### 9.3 Operation

All drawer cash activity references the open drawer session. Every operation records the actual performing user even when that user is not the responsible user.

Non-sale cash activity requires connectivity and server authorization. Ordinary POS cash transactions may complete under the existing offline POS contract, but an authoritative drawer close cannot complete until all locally completed facts for that session have synchronized.

### 9.4 Closing

An authorized user closes a drawer by:

1. placing the session into `closing` so it rejects new cash activity;
2. synchronizing all locally completed POS transaction and tender facts for the session;
3. calculating authoritative expected cash;
4. entering a blind denomination count;
5. calculating and accepting any drawer variance;
6. obtaining approval when the variance exceeds the configured threshold;
7. transferring the entire counted amount to the safe;
8. closing the session with a zero expected balance.

The transfer amount is the accepted counted amount, not the pre-count expected amount.

If expected cash is $500 and counted cash is $480, acceptance posts a $20 cash-short recognition before transferring $480 to the safe. The drawer then closes at zero while the shortage remains visible as a drawer variance.

The responsible user, closing user, and approving user remain separately attributable.

## 10. Non-sale cash activity

### 10.1 Paid in

A paid-in records cash entering a drawer for a reason other than a POS tender or transfer. It requires an active drawer session, reason code, amount, actor, and any policy-required note or approval.

### 10.2 Paid out

A paid-out records an authorized non-sale disbursement. It requires:

- an active drawer session;
- a permitted reason;
- sufficient available cash;
- notes when required;
- exact-action approval when required by amount threshold.

Refunds, stored-value cash-outs, and future buyback payouts are not paid-outs.

### 10.3 Cash drop

A cash drop transfers cash from an open drawer session to the safe. It is posted atomically as a completed transfer. The drawer must retain sufficient expected cash to post the requested amount.

### 10.4 Replenishment

A replenishment transfers cash from the safe to an open drawer session. The safe must have sufficient expected cash.

### 10.5 Direct drawer-to-drawer transfer

Direct drawer-to-drawer transfer is prohibited in the MVP. Staff must drop cash from the source drawer to the safe and replenish the destination drawer from the safe.

## 11. Activity reasons

Managed cash activity reasons provide stable reporting categories.

Each reason includes:

- stable normalized code;
- display name;
- applicable operation type;
- active/inactive lifecycle;
- whether notes are required.

Historical facts retain their reason identity and displayed label after a reason is renamed or deactivated.

MVP reasons apply to:

- paid in;
- paid out;
- cash over;
- cash short;
- correction/reversal.

GL mapping and complex accounting classification are deferred.

## 12. Variance and approval

For a submitted count:

```text
variance = counted cash - expected cash
```

- positive variance is cash over;
- negative variance is cash short;
- zero variance requires no recognition movement.

The organization configures:

1. a nonzero variance threshold above which a reason/note is required;
2. an absolute variance threshold above which manager approval is required;
3. a paid-out amount threshold above which manager approval is required;
4. a payout amount or retained-cash threshold above which approval is required.

Threshold evaluation uses absolute variance magnitude where applicable.

Approval follows ShelfSense's direct, approval-required, or prohibited authorization outcome. The second actor authenticates for the exact action. `performed_by` and `approved_by` must be different when policy requires a second actor.

Accepting a nonzero reconciliation creates an explicit cash-over or cash-short movement that aligns expected balance with the accepted physical count. It must never be represented as a paid-in or paid-out.

Variance records preserve:

- expected amount;
- counted amount;
- variance;
- count;
- location and drawer session when applicable;
- business date;
- reason and notes;
- performed-by and approved-by users;
- reversal/correction lineage.

The MVP does not assign investigation states or retroactively allocate a safe variance to drawer sessions.

## 13. Safe reconciliation and deposit

### 13.1 Safe count integrity

A safe count must compare physical cash to a stable ledger position.

For MVP, beginning safe reconciliation temporarily blocks new safe movements. The system records the balance/version being reconciled. The lock is released when reconciliation is completed or abandoned.

### 13.2 Safe variance

Safe reconciliation is independent of drawer reconciliation. A safe variance remains a safe variance even when all drawer sessions balanced.

ShelfSense must not distribute or assign a safe variance to drawer sessions without a later explicit correction supported by evidence.

Once accepted, a safe over/short recognition rebases the expected safe balance so the same difference does not recur on the next store day.

### 13.3 Deposit preparation

After safe reconciliation, an authorized user divides the accepted physical safe balance between:

- cash retained in the safe for future floats;
- cash prepared for deposit.

The deposit record includes:

- store and business date;
- source safe;
- deposit number;
- bag/reference number when used;
- denomination count and total;
- prepared-by user;
- approved-by user when required;
- prepared and released timestamps;
- reversal lineage.

Preparing/releasing the deposit transfers the prepared amount from the safe to deposit in transit. The expected safe balance becomes the retained amount.

The MVP treats deposit preparation as the final cash-custody step. Bank-posted confirmation and discrepancies are deferred.

### 13.4 Initial safe balance

When a store first adopts Phase 11, an authorized initialization count establishes the safe's opening expected balance.

Initialization:

- is allowed once per store safe through the normal application workflow;
- requires a denomination count, effective business date, notes, and manager approval;
- is explicitly typed as initialization rather than paid in;
- is fully audited.

## 14. Store-day reporting and finalization

The store-day cash report aggregates underlying immutable facts and presents at minimum:

- drawer sessions opened and closed;
- opening floats;
- POS cash received and cash refunds;
- paid-ins and paid-outs by reason;
- drops and replenishments;
- stored-value cash-outs;
- future buyback cash payouts when enabled;
- expected and counted close amounts by drawer session;
- drawer over/short amounts;
- safe opening/carrying balance and movements;
- expected and counted safe balance;
- safe over/short amount;
- retained safe cash;
- prepared deposit amount and reference;
- corrections and reversals;
- open or incomplete drawer sessions;
- unsynchronized cash transactions;
- approvals and exceptions.

Store-day finalization is distinct from drawer close and workstation Z-period close.

Finalization is prohibited while:

- any drawer session for the business date remains open or closing;
- any locally completed cash transaction for those sessions remains unsynchronized;
- a required drawer or safe variance approval is missing;
- safe reconciliation is incomplete;
- deposit preparation for the business date is incomplete.

An accepted and properly approved variance does not prevent finalization.

Post-finalization corrections are new facts posted through an authorized correction workflow. They do not reopen or rewrite the finalized store day.

## 15. Corrections and reversals

Completed facts are never edited or deleted.

A reversal must:

- reference the original operation;
- reverse its financial effect exactly;
- preserve the original business facts and actors;
- record reason, performed-by user, approval when required, and timestamp;
- be idempotent;
- prevent double reversal.

Where corrected data is required, reversal is followed by a new replacement operation linked to the original and reversal.

Internal transfers reverse both source and destination ledger entries atomically. A reversal is prohibited if it would make the destination's expected balance negative; cash must first be restored through an appropriate compensating operation.

Accepted count mistakes are corrected by reversing the reconciliation recognition and recording a replacement count/reconciliation. Closed drawer sessions remain closed; correction facts reference the affected session but post as new activity.

## 16. Connectivity and failure behavior

Normal drawer open, non-sale cash activity, safe activity, reconciliation, deposit preparation, and drawer close require server connectivity.

Ordinary POS transactions retain their existing offline contract. Therefore:

- a drawer session may accumulate locally completed POS cash facts while disconnected;
- ShelfSense must not calculate or accept a final drawer variance until those facts synchronize;
- normal drawer close is unavailable until synchronization completes.

During an extended outage, stores use an external operating procedure to stop use, manually count, and secure the drawer. An integrated sealed or pending-sync close workflow is deferred.

Atomic operations must fail without partial posting. Recoverable failures preserve entered count data where safe, but no accepted movement, reconciliation, transfer, or close may be half-created.

## 17. Concurrency and locking

Commands that spend or move cash must use a consistent lock order and revalidate after locking.

At minimum, Phase 11 must prevent:

- two users opening the same drawer;
- two drawers opening on the same workstation;
- cash posting after a session begins closing;
- two payouts both relying on the same available cash;
- a drop and payout jointly making a drawer negative;
- two replenishments jointly making the safe negative;
- safe movement while a safe reconciliation is active;
- duplicate posting caused by retry;
- reversal of an operation more than once;
- finalization racing with a new store-day cash fact.

Cross-location transfers lock locations in a deterministic order before revalidation and posting.

## 18. Authorization and audit

Phase 11 introduces or formalizes permission points for:

- configure and deactivate drawers;
- initialize safe balance;
- open own drawer session;
- open or close a drawer for another user;
- view expected cash before count;
- record paid in;
- record paid out;
- perform drop or replenishment;
- perform stored-value cash-out;
- perform future buyback payout;
- approve paid-out or payout exception;
- accept drawer variance;
- approve material drawer variance;
- count and reconcile safe;
- approve material safe variance;
- prepare/release deposit;
- reverse or correct cash activity;
- finalize store day;
- view store-wide cash reporting.

Audit must preserve the actual actor, responsible drawer user, approving actor, reason, authorization outcome, policy/configuration context, source record, reversal lineage, store, workstation, drawer, session, and business date as applicable.

## 19. Conceptual records

Exact migrations are an implementation-plan concern, but the Phase 11 contract is expected to require concepts equivalent to:

- cash drawers;
- accountable cash locations;
- cash drawer sessions;
- immutable cash movements;
- cash transfers with balanced legs;
- cash counts and denomination lines;
- cash reconciliations/variances;
- cash activity reasons;
- cash deposits;
- expected-balance projections;
- idempotency and reversal lineage.

The schema should permit future additional safe locations without exposing multi-safe behavior in the MVP.

## 20. Suggested delivery slices

### Phase 11.0 — Contract and policy

- approve terminology and invariants;
- document cash-ledger authority and projections;
- document workstation/session/Z-period/store-day separation;
- define lock order, idempotency, authorization outcomes, and reversal rules;
- align POS and Phase 10 stored-value cash-out integration contracts.

### Phase 11.1 — Drawer lifecycle

- drawer administration;
- safe initialization;
- drawer session open;
- denomination counts;
- opening-float transfer;
- POS cash linkage;
- closing count and drawer variance;
- mandatory counted-cash transfer to safe;
- session close.

### Phase 11.2 — Non-sale cash activity

- activity reasons;
- paid in and paid out;
- cash drops;
- safe-to-drawer replenishment;
- available-cash service;
- authorization thresholds;
- operation reversals.

### Phase 11.3 — Safe, deposit, and store day

- safe reconciliation lock;
- safe count and variance;
- retained cash;
- deposit preparation and deposit-in-transit movement;
- store-day cash report;
- finalization gates;
- post-finalization correction reporting.

### Phase 11.4 — Payout readiness and hardening

- integrate Phase 10 gift-card cash-out;
- expose the cash-payout eligibility contract for Phase 12;
- verify atomic available-cash checks;
- complete concurrency, retry, failure, authorization, and reversal coverage;
- validate reporting totals against authoritative facts.

## 21. Required scenario coverage

Automated tests must cover at least:

1. successful safe initialization;
2. duplicate safe initialization rejection;
3. successful drawer open and safe-to-drawer transfer;
4. competing attempts to open the same drawer;
5. competing attempts to use the same workstation;
6. cash sale and refund posting to the correct open session;
7. cash transaction rejection without an open drawer;
8. cashless transaction without an open drawer;
9. paid-in and paid-out authorization and reason requirements;
10. insufficient drawer cash for paid-out, refund, or cash-out;
11. concurrent payouts against the same available cash;
12. cash drop and replenishment;
13. direct drawer-to-drawer transfer rejection;
14. drawer close with zero variance;
15. drawer over and drawer short;
16. material drawer variance requiring a distinct approver;
17. counted rather than expected cash transferred at close;
18. drawer closing at zero and rejecting later activity;
19. close rejection while offline POS facts remain unsynchronized;
20. safe variance despite all drawers balancing;
21. safe activity rejection during active safe reconciliation;
22. accepted safe variance rebasing the next expected balance;
23. retained safe cash plus deposit equaling the accepted safe count;
24. insufficient safe cash for opening or replenishment;
25. store-day finalization gates;
26. accepted variance permitting finalization;
27. reversal and replacement of paid-in, paid-out, transfer, and reconciliation;
28. double-reversal rejection;
29. retry idempotency for every posting command;
30. report totals reconciling to the authoritative movement ledger.

## 22. Exit criteria

Phase 11 is complete when:

- every cash-affecting POS operation is attributed to an open drawer session;
- a store can open, operate, count, reconcile, empty, and close each drawer;
- a store can record controlled non-sale cash activity;
- expected and available cash are concurrency-safe;
- the safe independently reconciles even when all drawers balance;
- accepted variances explicitly align expected and physical cash without hiding the difference;
- the store can retain float and prepare a one-day deposit;
- the store-day report explains cash from safe opening balance through deposit preparation;
- completed facts can be reversed and replaced without mutation;
- gift-card cash-out uses the Phase 11 cash-payout control;
- Phase 12 can determine cash payout eligibility and atomically post a buyback payout without inventing a second cash-accountability model.

## 23. Deferred follow-on candidates

Future phases may add:

- direct drawer-to-drawer transfers;
- transfer release/receipt acknowledgement and discrepancies;
- multiple safes and safe-to-safe transfers;
- integrated offline/sealed-drawer close;
- formal forced custody takeover;
- variance investigation cases;
- deposits spanning multiple business dates;
- armored-car or bank custody acknowledgement;
- bank-confirmed deposit amounts and discrepancies;
- bank reconciliation;
- store-specific cash policies;
- GL mappings and financial posting.

These extensions must build on the same immutable cash ledger, accountable-location identity, reconciliation, authorization, and reversal contracts established in Phase 11.
