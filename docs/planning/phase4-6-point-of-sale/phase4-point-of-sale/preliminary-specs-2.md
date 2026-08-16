Yes. This is a **very reasonable breakdown**, and I think it is substantially better than treating the whole “initial complete POS” spec as one implementation phase. It correctly separates architectural proof, the first operational cash path, and later POS breadth.

I would make about **six changes** before locking it.

## 1. Move cashier PIN replication out of “First cash sale”

This row is the main mismatch:

> POS cashier#/PIN replication → **Build offline-capable shape if needed**

Because the first Rails-native POS is online, I would make it:

| Area             | Foundation                       | First cash sale                                         | Later / standalone                                   |
| ---------------- | -------------------------------- | ------------------------------------------------------- | ---------------------------------------------------- |
| POS cashier#/PIN | Design credential semantics only | Use central Rails authentication / POS cashier identity | Build replicated PIN verifier for standalone runtime |

We should certainly establish:

```text
cashier_number
POS actor identity
POS permissions
future PIN semantics
```

but there is little benefit in implementing offline credential replication before there is an offline client.

---

## 2. Be explicit that working transactions do **not** reserve inventory initially

Your caution here is correct:

> Inventory: working → reserved — Design only or Skip

I would actually make the first implementation decision stronger:

> **Open and suspended POS transactions do not initially affect `reserved`. Inventory availability changes authoritatively only when the transaction completes.**

Then later, if we decide suspended/open transactions should hold stock:

```text
working transaction
→ reservation fact
→ reserved increases
```

can be added deliberately.

This avoids introducing a provisional inventory subsystem merely because the architecture allows one.

So:

| Area                           | Foundation                | First cash sale | Later core POS                                                |
| ------------------------------ | ------------------------- | --------------- | ------------------------------------------------------------- |
| Working transaction → reserved | Design compatibility only | **Skip**        | Build only when reservation behavior is explicitly introduced |

That also keeps Phase 3's existing inventory meaning clean.

---

## 3. Don't require the discount allocation algorithm in Foundation

This is slightly premature:

> **M Discounts — Allocation algorithm in fixtures (even if UI off)**

I would distinguish **contract accommodation** from **algorithm implementation**.

Foundation should ensure a completed line can eventually represent:

```text
line discounts
transaction-discount allocation
```

but I don't think we need to implement or fixture proportional allocation before discounts exist.

I would change it to:

| Foundation                                   | First cash sale | Later core POS                                                                  |
| -------------------------------------------- | --------------- | ------------------------------------------------------------------------------- |
| Design completed-operation fields/hooks only | Skip            | Lock allocation algorithm + fixtures immediately before discount implementation |

Otherwise Phase 4 starts accumulating calculations for capabilities it deliberately doesn't expose.

The general rule should be:

> **Foundation must not make later capabilities impossible, but it does not need to implement their business algorithms early.**

---

## 4. Move the approval framework earlier within “Later core POS”

Your build order currently ends later-core work with:

> `... → K reports → O full approvals`

I would change that.

Approvals are infrastructure for several capabilities:

```text
price override
discount
tax override
unlinked return
return exception
post-void
paid-out
Cash variance
```

So the approval framework needs to land **before the first controlled action that depends on it**.

I would sequence later core more like:

```text
B merchandise breadth
        ↓
O approval / controlled-action foundation
        ↓
L price override
        ↓
M discounts
        ↓
P non-Cash tenders
        ↓
Q + C3/C4 + F returns
        ↓
C5/C6 suspend/recall
        ↓
G post-void
        ↓
I full Cash operations
        ↓
K broader reporting
```

Not every threshold or action needs to be defined up front. But the common:

```text
direct
approval_required
prohibited

performed_by
approved_by
reason
exact approved request
```

framework should exist before we start sprinkling bespoke manager checks into individual features.

---

## 5. Rename “First cash sale” slightly if it includes session close and Z

Your bucket includes:

* opening float;
* session;
* closing count;
* variance;
* Z finalization;
* receipt printing.

That's more than literally “first cash sale.”

It is still the right scope, but I might call the bucket:

> **First operational cash register**

or:

> **First cash-sale register**

Then the distinction is clearer:

### Foundation

```text
Can ShelfSense correctly complete and post a Cash sale?
```

### First operational cash register

```text
Can a cashier actually run the minimum register lifecycle around that sale?
```

That matches what you've placed in the column better.

If you retain “First cash sale,” the contents are still defensible; the label is just slightly narrower than the work.

---

## 6. Clarify receipt scope

This is mostly right:

> H Receipt assign — Build store+register sequence at complete
> Print on one path

I would make the split:

### Foundation

Build:

```text
receipt identity
Store + Register sequence
assignment atomically at completion
```

No printer required.

### First operational cash register

Build:

```text
receipt rendering
print prompt
one supported print path
printer failure after commit
```

### Later core POS

Build:

```text
completed transaction lookup
reprint
richer receipt rendering/configuration
diagnostics
```

I don't think **reprint** is required for proving the first cash-sale path unless you consider it necessary for the first usable register. It's inexpensive enough that either choice is reasonable.

---

# A few smaller edits

### B. Line ops

Instead of:

> `void empty-or-simple line`

I'd say:

> **remove/void a working line according to the meaningful-line persistence rule**

We don't want to create a special concept of “simple line” that later becomes difficult to define.

---

### D4 Zero-net

I agree with keeping it out of the first cash register.

I'd probably put:

```text
Foundation → Design settlement equation / optional fixture
First cash sale → Skip
Later core POS → Build
```

A zero-net transaction only really becomes operationally relevant once returns coexist with sale lines.

---

### Externally processed Card

Your placement in **Later core POS** is exactly right.

It's particularly useful because it lets us prove:

```text
Card tender semantics
refund tender semantics
mixed tender
reporting
```

without taking on processor integration.

---

### Suspend / recall

Also correctly later-core.

I would probably implement it **before returns or around the same general maturity stage**, rather than viewing it as a return dependency. It mainly depends on:

* persistent working transactions;
* reference revalidation;
* inventory-unit claims if those exist;
* approval invalidation.

It is operationally valuable and relatively independent.

---

### T. “offline-ish server down”

I would remove that wording entirely.

For the Rails implementation:

```text
server unavailable
→ POS unavailable
```

That is acceptable and intentional.

Phase 5 should test:

* request failure;
* lost response;
* retry;
* browser refresh;
* duplicate submission protection.

But it should **not** imply degraded offline selling.

Your note below the tables correctly makes this distinction.

---

# Revised build order

I would tighten your suggested sequence to this:

```text
1. FOUNDATION
   R Completed-operation contract
   R Idempotent authoritative posting
   L Basic pricing
   N Ordinary tax
   P Cash settlement contract
   C8 Completion
   H Receipt identity
   Inventory posting
   Golden fixtures

   Minimum context:
   Store
   Register
   Session
   actor
   occurred_at
   business_date
```

Then:

```text
2. FIRST OPERATIONAL CASH REGISTER
   A Minimum Register/Z + Session lifecycle
   B Standard quantity-tracked merchandise
   C1 Open transaction
   C2 Sale lines
   C7 Cancel
   E Cash
   J Minimum session/Cash totals
   H Receipt rendering/print
   K Minimum close/Z view
   S Keyboard/scanner workspace
   T Browser/request failure behavior
```

Then later core:

```text
3. CORE POS BREADTH

   3A Merchandise breadth
      individually tracked
      non-inventory
      open ring

   3B Controlled-action foundation
      permissions
      reasons
      approval framework

   3C Transaction controls
      price override
      richer void/cancel
      tax override

   3D Discounts
      line
      transaction
      allocations

   3E Tender breadth
      Check
      external Card
      Other
      mixed tender

   3F Suspend / recall

   3G Returns
      linked
      unlinked
      refund policy
      historical reversal
      mixed sale/return
      zero-net

   3H Post-void

   3I Full Cash operations
      paid-in/out
      drawer ↔ safe

   3J Reporting breadth
```

And finally:

```text
4. DEFERRED

Stored Value
Customer reservation pickup
Customer display
Card processor integration

Standalone runtime:
  .NET
  SQLite
  replication
  offline auth
  outbox
  operation synchronization
  local inventory overlay
  installation/recovery
```

## Overall assessment

The key insight in your map is correct:

> **The “initial complete POS” specification is the destination, not one development phase.**

And the implementation gradient should be:

```text
Foundation
    ↓
First operational Cash register
    ↓
Core POS breadth
    ↓
Standalone/offline client later
```

I would use this map as the bridge between the durable POS specification and the rewritten Phase 4–6 roadmap. The only material sequencing correction is that **approvals should precede the controlled capabilities that consume them**, while offline credential replication and discount allocation implementation should move later than your current table suggests.
