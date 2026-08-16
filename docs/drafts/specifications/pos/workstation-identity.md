# POS Domain Specification: Workstation Identity

**Design status:** Core workstation/installation identity model decided
**Implementation status:** Required in Phase 4
**Initial delivery:** Phase 4 — POS Runtime and Contract Foundation
**Expanded delivery:** Phase 6B — POS Productization
**Related specifications:** Transactions, Reporting Periods, Receipts, Local Persistence, Reference Replication, Operation Synchronization, Reconciliation
**Related workflows:** Installation Enrollment, Workstation Replacement, Installation Recovery

---

## 1. Purpose

This specification defines how ShelfSense identifies POS workstations, POS installations, and the human actors operating them.

It establishes:

* the distinction between a logical workstation and a concrete POS installation;
* store ownership of workstations;
* installation-to-workstation binding;
* the single-active-installation rule;
* machine authentication versus human authentication;
* identity carried by POS operations;
* local persistence of installation identity;
* replacement semantics;
* boundaries with receipts, Z reporting, persistence, synchronization, and recovery.

This specification intentionally does **not** define:

* the detailed enrollment protocol;
* SQLite recovery procedures;
* receipt sequence recovery;
* Z sequence recovery;
* installation clone-detection implementation;
* hardware fingerprinting;
* historical-operation recovery from retired installations;
* installer/update mechanics.

Those belong to their owning specifications, contracts, workflows, or productization work.

---

# 2. Governing principle

ShelfSense separates the durable business identity of a register from the concrete software installation currently operating it.

> **A workstation is the durable store/register identity. An installation is one concrete authenticated POS runtime bound to that workstation.**

Conceptually:

```text
Store
  └── Workstation
        └── Installation

User
  └── operates through the installation
```

These identities serve different purposes and must remain distinct.

---

# 3. Workstation

A **workstation** is the durable logical POS register identity.

Examples:

```text
Front Register 1
Front Register 2
Cafe Register
Information Desk
```

The workstation represents the business concept of a register regardless of which computer or POS installation currently operates it.

A workstation may retain continuity across:

* hardware replacement;
* operating-system replacement;
* POS reinstall;
* installation replacement.

---

# 4. Workstation ownership

A workstation belongs to exactly one store.

Conceptually:

```text
Workstation
├── id
├── store_id
├── code
├── name
└── active
```

The exact schema belongs to implementation planning.

Once a workstation has operational POS history, changing its store is not supported as an ordinary edit.

A machine moved to another store should operate through a workstation belonging to that destination store rather than rewriting the historical ownership of the original workstation.

---

# 5. Workstation identity versus display identity

Human-facing properties such as:

```text
code
name
```

are not the workstation's authoritative technical identity.

The workstation UUID is the durable identity used by relationships and operations.

Renaming:

```text
Front Register
→
Front Register 1
```

does not create a new workstation.

---

# 6. Installation

An **installation** identifies one concrete ShelfSense POS runtime and its local persistent state.

Conceptually:

```text
Installation
├── id
├── workstation_id
├── active
├── credential identity
├── enrolled_at
└── lifecycle/audit metadata
```

An installation answers:

> Which concrete POS instance originated this operation?

This matters for:

* authentication;
* synchronization;
* support;
* offline-origin tracking;
* recovery;
* conflict investigation.

---

# 7. Installation belongs to one workstation

An installation is bound to exactly one logical workstation.

Conceptually:

```text
Installation I
    ↓
Workstation W
    ↓
Store S
```

An installation does not independently choose its store.

Its store context derives from the workstation to which it is enrolled.

---

# 8. One active installation per workstation

The core installation invariant is:

> **A workstation may have at most one active installation authorized to originate new POS activity at a time.**

Valid:

```text
Front Register 1
├── Installation A — inactive
├── Installation B — inactive
└── Installation C — active
```

Invalid:

```text
Front Register 1
├── Installation A — active
└── Installation B — active
```

This reduces the risk of:

* duplicated register identity;
* divergent offline histories;
* receipt sequence collisions;
* Z sequence collisions;
* competing local authoritative state.

---

# 9. Installation lifecycle

The core domain requires only two operational states:

```text
active
inactive
```

`active` means:

> This installation may originate new ordinary POS operations for its workstation.

`inactive` means:

> This installation may no longer originate new ordinary POS operations.

An inactive installation may retain additional reason/context such as:

```text
replaced
revoked
lost
decommissioned
```

The exact representation is an implementation decision.

---

# 10. Historical installations are preserved

Making an installation inactive does not remove its historical identity.

Completed operations continue to reference the installation that actually originated them.

Example:

```text
Front Register 1

Installation A
  active January–May

Installation B
  active May–August

Installation C
  active August–
```

Transactions from January remain attributed to Installation A.

They are not rewritten to the currently active installation.

---

# 11. Workstation replacement

Hardware or software replacement normally creates a new installation while preserving the logical workstation.

Conceptually:

```text
Workstation W1
Installation A active
        ↓
A made inactive
        ↓
Installation B enrolled
        ↓
Workstation W1 unchanged
```

This preserves continuous business identity while distinguishing the old and new POS runtime instances.

---

# 12. Installation enrollment

Enrollment establishes the relationship among:

```text
installation
workstation
credential
```

The domain meaning is:

> **Enrollment creates or activates an installation identity, binds it to one workstation, and gives the installation a credential that authenticates that identity to the server.**

The exact enrollment mechanism is deferred to its workflow/contract.

Possible implementation mechanisms such as:

* enrollment codes;
* QR codes;
* bootstrap tokens;
* administrator approval;

do not change the domain model.

---

# 13. Installation credential

An installation has its own machine credential.

That credential proves:

> This request originates from the enrolled POS installation claiming this installation identity.

It does not prove the identity or authority of the cashier.

---

# 14. Human authentication is separate

ShelfSense distinguishes:

```text
installation authentication
```

from:

```text
user authentication
```

Installation authentication proves the POS instance.

User authentication proves the human actor.

Neither substitutes for the other.

A valid installation does not by itself authorize a sale, override, return, or manager action.

---

# 15. Actor identity

The current human actor remains a separate identity from both workstation and installation.

Example:

```text
Workstation W1
Installation I1

Cashier A completes Transaction 1
Cashier B later completes Transaction 2
```

Both transactions may share:

```text
workstation_id = W1
installation_id = I1
```

while preserving different:

```text
actor_id
```

values.

---

# 16. Approval actors remain separate

A second actor approving an action does not replace:

* the workstation;
* installation;
* primary performer.

Example:

```text
Workstation W1
Installation I1
Performed by Cashier A
Approved by Manager B
```

The Approval domain owns the performer/approver relationship.

---

# 17. POS operation identity

Terminal-originated operations should preserve the relevant identity tuple:

```text
store_id
workstation_id
installation_id
actor_id
```

plus their own operation/transaction identifiers.

Each identity answers a different question:

| Identity          | Meaning                         |
| ----------------- | ------------------------------- |
| `store_id`        | Where the activity occurred     |
| `workstation_id`  | Which logical register          |
| `installation_id` | Which POS runtime originated it |
| `actor_id`        | Which person performed it       |

These values should remain historically preserved after completion.

---

# 18. Identity consistency validation

The server must validate that submitted identities agree.

For example:

```text
installation I
→ workstation W
→ store S
```

A payload authenticated as Installation I must not claim:

```text
installation_id = J
```

or:

```text
workstation_id = X
```

or a different store relationship.

Such disagreement is an identity-integrity failure, not an ordinary stale-reference condition.

---

# 19. Installation authentication binds payload identity

An installation credential should authenticate a specific installation identity.

The server-known installation relationship determines:

```text
installation
→ workstation
→ store
```

The POS must not authenticate with a generic organization credential and freely choose arbitrary workstation/store identifiers.

---

# 20. Local database ownership

One POS installation owns one local SQLite database.

That database contains installation-local durable state such as:

* installation identity;
* workstation binding;
* reference data;
* working transactions;
* completed local operations;
* outbox;
* local Z records;
* local Cash state;
* synchronization state.

The local database is therefore part of the installation's persistent identity context.

---

# 21. Local identity persistence

The POS must durably store:

```text
installation_id
workstation_id
store_id
```

or sufficient equivalent binding information locally.

An offline workstation must be able to determine:

> Which installation and workstation am I?

without contacting the server.

---

# 22. Missing or inconsistent local identity

Production POS must not silently recreate its identity if the expected local database or installation state is:

* missing;
* corrupt;
* inconsistent.

Instead it enters an explicit recovery condition.

Conceptually:

```text
RECOVERY REQUIRED
```

The detailed recovery process belongs to `local-persistence.md` and related workflows.

---

# 23. Fresh installation is a new installation

If the original installation identity cannot be recovered, a fresh POS setup must not infer that it is the previous installation merely because it is intended for the same workstation.

Instead:

```text
new local runtime
→ new installation identity
→ enrollment to existing workstation
```

The workstation may remain the same.

The installation does not.

---

# 24. Software updates do not create new installations

Normal changes such as:

* ShelfSense version update;
* operating-system update;
* hostname change;
* printer replacement;
* monitor replacement;

do not inherently create a new installation.

The durable installation identity remains unchanged while its persisted identity remains intact.

---

# 25. Hardware fingerprint is not identity

ShelfSense may later retain machine information for diagnostics or clone detection.

However:

> **Hardware metadata is supporting evidence, not the authoritative installation identity.**

The installation UUID and credential define the POS instance identity.

---

# 26. Duplicate installation identity is prohibited

The same installation identity must not intentionally operate concurrently from multiple independent POS runtime/database instances.

Conceptually, this is invalid:

```text
Machine A
Installation I

Machine B
Installation I
```

both originating new activity independently.

Detailed clone-detection mechanisms are deferred to productization.

---

# 27. Inactive installation behavior

An inactive installation may not originate new ordinary POS operations.

The domain spec does not determine whether a later recovery process may submit previously committed historical operations from that installation.

That behavior belongs to:

* Local Persistence;
* Operation Synchronization;
* Reconciliation.

This distinction keeps identity lifecycle separate from historical-recovery protocol.

---

# 28. Workstation deactivation

A workstation may itself be made inactive.

Inactive means:

> The logical workstation should no longer be used for new ordinary POS activity.

Deactivation does not:

* delete history;
* delete historical installations;
* invalidate prior receipts;
* remove prior Z reports.

Workstations with operational history should not be hard-deleted.

---

# 29. Installation records are retained

Installations that originated historical POS operations should not be hard-deleted.

They remain necessary to explain:

> Which POS instance originated this operation?

They may be inactive indefinitely.

---

# 30. Receipt numbering belongs to the workstation

Human-facing receipt sequence is scoped to the logical workstation rather than the installation.

Therefore:

```text
Installation A
→ replaced by Installation B
```

does not create a new receipt-number namespace merely because hardware changed.

Exact replacement/high-water behavior belongs to `receipts.md`.

---

# 31. Z numbering belongs to the workstation

Likewise, human-facing Z sequence belongs to the logical workstation.

Installation replacement does not redefine the workstation's reporting identity.

Exact Z sequence recovery belongs to `reporting-periods.md`.

---

# 32. Sequence gaps versus identity reuse

This specification does not define the exact replacement sequence algorithm.

It establishes only the safety principle:

> **Potentially issued workstation-scoped human identifiers must not knowingly be reused merely to avoid gaps.**

Detailed receipt/Z sequence handling belongs to their owning specifications.

---

# 33. Reporting identity versus origin identity

Central reporting primarily uses:

```text
workstation_id
```

because that is the durable business register identity.

Support and distributed-systems analysis may additionally use:

```text
installation_id
```

Example:

```text
Front Register 1

Z 101 → Installation A
Z 102 → Installation A
Z 103 → Installation B
```

The workstation reporting history remains continuous while installation origin remains visible.

---

# 34. Drawer-session identity

Cash drawer sessions may retain both:

```text
workstation_id
installation_id
```

where useful.

The workstation identifies the register context.

The installation identifies the runtime originating the local Cash facts.

Human custody remains associated with the relevant actor(s).

---

# 35. Workstation configuration authority

Administrative workstation configuration is centrally mastered.

Examples include:

* store assignment;
* code/name;
* active status;
* POS configuration.

The workstation installation receives that configuration through Reference Replication.

An offline POS may use its cached configuration but does not redefine central workstation identity locally.

---

# 36. Installation-local operational authority

The installation is authoritative for its locally originated durable operational facts while offline, such as:

* completed transactions;
* local outbox entries;
* local Zs;
* local Cash facts.

That does not make it authoritative for centrally mastered workstation configuration.

This distinction mirrors ShelfSense's broader reference-data versus originating-operation model.

---

# 37. Audit requirements

Important workstation/installation administration should be auditable.

Examples:

* workstation activated/deactivated;
* installation enrolled;
* installation made inactive;
* installation replacement;
* credential-related administrative changes.

Audit records provide explanatory history.

They do not replace the underlying workstation or installation records.

---

# 38. Synchronization requirements

Synchronization must authenticate the installation independently from the human actor represented inside business operations.

A synchronized operation should be traceable to:

```text
authenticated installation
+
claimed workstation/store relationship
+
business actor
```

The synchronization contract defines the exact request/credential mechanics.

---

# 39. Offline behavior

Once enrolled, a valid installation must be able to operate without central connectivity within the capabilities permitted offline.

Its durable local state provides:

* installation identity;
* workstation identity;
* store context;
* cached configuration;
* local operational state.

The installation does not need to rediscover its identity from the server on every startup.

---

# 40. Startup identity validation

At startup, the POS should verify that its local identity context is coherent.

Conceptually:

```text
local database exists
installation identity exists
workstation binding exists
stored state is internally consistent
```

Failure enters recovery rather than ordinary cashier mode.

Exact validation and recovery mechanics belong to Local Persistence.

---

# 41. Conceptual model

Without locking physical schema:

```text
Store
│
└── Workstation
    │
    ├── id
    ├── code/name
    ├── active
    │
    └── Installations
        │
        ├── Installation A — inactive
        ├── Installation B — inactive
        └── Installation C — active
```

Installation:

```text
Installation
├── id
├── workstation_id
├── active
├── credential identity
├── enrolled_at
└── lifecycle/audit metadata
```

User identity remains separate.

---

# 42. Domain ownership

## Workstation Identity owns

* logical workstation identity;
* installation identity;
* workstation-to-installation binding;
* one-active-installation invariant;
* installation active/inactive semantics;
* enrollment meaning;
* machine versus human identity separation;
* identity preserved on POS operations;
* replacement identity semantics.

## Authentication / Authorization owns

* user authentication;
* offline cashier credentials;
* user permissions.

## Approvals owns

* second-actor authorization.

## Local Persistence owns

* SQLite storage;
* corruption detection;
* recovery-required mechanics.

## Receipts owns

* receipt identity and workstation-scoped receipt sequences.

## Reporting Periods owns

* Z identity and workstation-scoped Z sequences.

## Reference Replication owns

* delivery of workstation configuration.

## Operation Synchronization owns

* machine credential protocol;
* authenticated submission;
* historical-operation synchronization.

## Reconciliation owns

* conflicting/revoked installation conditions.

---

# 43. Phase 4 delivery

Phase 4 should implement:

* existing logical workstation as durable server-master identity;
* installation persistence;
* installation UUID;
* one installation bound to one workstation;
* one active installation per workstation;
* enrollment;
* installation credential;
* local installation/workstation identity persistence;
* authenticated reference requests;
* authenticated synchronization;
* store/workstation/installation identity on originating operations;
* basic installation deactivation;
* startup identity integrity checks.

Phase 4 does not require polished replacement/recovery tooling.

---

# 44. Phase 5 usage

Phase 5 combines workstation identity with cashier authentication.

The ordinary Cash-sale path becomes:

```text
active installation
+
active workstation
+
authenticated cashier
+
open POS operational context
        ↓
complete sale
```

The completed operation preserves:

```text
store_id
workstation_id
installation_id
actor_id
```

as separate historical identities.

---

# 45. Phase 6B productization

Later productization may add:

* guided workstation replacement;
* recovery tooling;
* corrupt/missing database handling;
* installer repair;
* clone detection;
* device diagnostics;
* receipt/Z sequence recovery;
* old-installation historical-data recovery;
* credential rotation.

These capabilities extend the core identity model rather than changing it.

---

# 46. Pending decisions

## 46.1 Installation credential mechanism

Define the exact credential form and lifecycle in the synchronization/enrollment contract.

---

## 46.2 Enrollment workflow

Define:

* who may enroll;
* how workstation selection occurs;
* bootstrap-token mechanics;
* re-enrollment behavior.

---

## 46.3 Inactive-reason taxonomy

Determine whether the system needs structured reasons such as:

```text
replaced
revoked
lost
decommissioned
```

or whether audit metadata is sufficient.

---

## 46.4 Historical upload from inactive installation

Determine whether an inactive/recovered installation may submit already-committed historical operations.

This is not required to establish workstation identity.

---

## 46.5 Clone detection

Determine production clone-detection strategy during Phase 6B.

The invariant that one installation identity must not independently originate from multiple runtime instances is already fixed.

---

# 47. Core invariants summary

The following rules are authoritative unless explicitly superseded:

1. **A workstation is the durable logical register identity.**
2. **A workstation belongs to exactly one store.**
3. **A workstation survives installation/hardware replacement.**
4. **An installation identifies one concrete POS runtime/local state instance.**
5. **An installation belongs to exactly one workstation.**
6. **A workstation may have at most one active installation originating new POS activity.**
7. **Inactive installations remain historical identities.**
8. **Installation authentication and human authentication are independent.**
9. **A valid machine credential does not substitute for cashier authority.**
10. **POS operations preserve store, workstation, installation, and actor identities separately.**
11. **Authenticated installation identity must agree with payload identity.**
12. **One local SQLite database belongs to one installation.**
13. **Installation/workstation identity must remain available offline.**
14. **Missing or inconsistent local identity requires explicit recovery.**
15. **A fresh installation without recovered identity receives a new installation identity.**
16. **Software/OS updates do not inherently create a new installation.**
17. **Hardware metadata is not authoritative installation identity.**
18. **The same installation identity must not intentionally originate concurrently from multiple independent POS instances.**
19. **Receipt human sequences belong to the logical workstation, not the installation.**
20. **Z human sequences belong to the logical workstation, not the installation.**
21. **Workstations/installations with operational history are retained rather than hard-deleted.**
22. **Replacement changes installation identity, not workstation identity.**

---

# 48. Acceptance examples

## Example A — normal operation

Given:

```text
Store S1
Workstation W1
Installation I1 active
Cashier U1 authenticated
```

when U1 completes a sale,

then the operation preserves:

```text
store_id = S1
workstation_id = W1
installation_id = I1
actor_id = U1
```

---

## Example B — cashier changes

Given Installation I1 remains active,

when Cashier U1 logs out and Cashier U2 logs in,

then:

* workstation remains W1;
* installation remains I1;
* subsequent operations identify U2 as actor.

No installation identity changes.

---

## Example C — hardware replacement

Given:

```text
Workstation W1
Installation I1 active
```

when the register computer is replaced,

then:

```text
I1 → inactive
I2 → enrolled/active
W1 → unchanged
```

Historical operations remain attributed to I1.

---

## Example D — workstation history survives replacement

Given:

```text
Z 101 originated from I1
Z 102 originated from I2
```

and both installations belong to W1,

then reporting presents both as activity of the same logical workstation W1 while retaining installation origin for support/audit.

---

## Example E — invalid second active installation

Given Workstation W1 already has active Installation I1,

when another installation attempts ordinary enrollment as another active originator for W1,

then ShelfSense must first resolve/deactivate the existing active binding.

W1 must not have two active originating installations.

---

## Example F — missing local database

Given Installation I1 was previously enrolled to W1,

when the POS starts but its expected production SQLite state is missing,

then ShelfSense enters recovery mode.

It does not silently create a blank database and continue claiming to be I1.

---

## Example G — fresh reinstall

Given the old installation identity cannot be recovered,

when ShelfSense is freshly installed for W1,

then a new installation identity is created and enrolled.

W1 remains the same logical workstation.

---

## Example H — application upgrade

Given Installation I1 runs POS version 1.2,

when it upgrades normally to version 1.3 while retaining local identity state,

then it remains Installation I1.

---

## Example I — payload identity mismatch

Given the request authenticates as Installation I1 bound to W1,

when the payload claims:

```text
installation_id = I2
```

then the server rejects the request as an identity-integrity failure.

---

## Example J — inactive historical installation

Given I1 has been replaced by I2,

then I1 may no longer originate new ordinary POS operations.

Its historical transactions continue to reference I1.

Whether I1 may later submit previously committed unsynchronized facts is handled by recovery/synchronization policy.

---

# 49. Related workflows

This specification should eventually be referenced by:

* `workflows/workstation/enrollment.md`
* `workflows/workstation/startup.md`
* `workflows/workstation/replacement.md`
* `workflows/workstation/recovery.md`
* `workflows/authentication/cashier-sign-in.md`
* `workflows/sync/completed-operation.md`

---

# 50. Related contracts

Workstation Identity will eventually require exact contracts for:

### Enrollment

```text
installation identity
+
workstation selection
+
authorized enrollment
→
server binding
+
installation credential
```

### Installation authentication

Define how requests prove:

```text
installation_id
```

and how the server resolves:

```text
installation
→ workstation
→ store
```

### Operation identity

Define representation of:

```text
store_id
workstation_id
installation_id
actor_id
```

inside POS-originated operations.

### Startup/local identity

Define the durable local identity information required before the POS may enter normal operational mode.

### Replacement/recovery

Later contracts may define how a new installation safely assumes operation of an existing logical workstation without reusing unsafe receipt/Z sequence ranges.

The Workstation Identity domain defines **who the logical register is, which POS installation currently operates it, and which concrete installation originated each operation**.

Everything beyond that—database recovery, sequence recovery, clone detection, and historical-operation salvage—belongs to narrower operational contracts and productization work.
