# Phase 11 — User stories

Status: **Proposed**. GitHub-issue-ready stories for slices 11.0–11.3.

## 11.0 — Contract

### US-11.0.1 — Packet authority

**As** implementers  
**I want** a packet that extends Register/`PosSession` rather than a drawer/workstation model  
**So that** Phase 11 does not fork POS identity.

**Acceptance:**

- [phase11-plan.md](phase11-plan.md) identity and ADR-021 vocabulary
- Draft spec marked superseded
- Optimistic safe-count revalidation, reversal/source-row model, second-user/`direct` permissions, and production cutover are explicit in this directory

## 11.1 — Safe-backed session

### US-11.1.1 — Initialize safe

**As** a store manager  
**I want** a one-time counted safe opening balance without an open POS session  
**So that** floats have a source location and production cutover can happen before cashiers open.

**Acceptance:** [phase11-schema.md](phase11-schema.md) §4.4; [phase11-session-lifecycle.md](phase11-session-lifecycle.md) §1; second init rejected; not a paid-in; not reversible via `Cash::Reverse`; always a distinct `cash.approve_initialize_safe` actor (never `direct`)

### US-11.1.2 — Open from safe

**As** a cashier  
**I want** my opening float transferred from the store safe  
**So that** session cash is accounted from the first cent.

**Acceptance:**

- Positive float: `opening_float_cents` equals the transfer
- Zero float: snapshot 0, no operation or entries
- Insufficient safe cash fails a positive float
- Uninitialized safe fails

### US-11.1.3 — Available cash

**As** the system  
**I want** cash refunds and gift-card cash-outs to fail when the session would go negative  
**So that** we do not pay out cash that is not in the till.

**Acceptance:**

- Concurrent last-cent exclusion
- Change on a cash sale still allowed
- Operator message names replenish or another payout method
- Existing $0-float refund/cash-out tests updated

### US-11.1.4 — Close to safe

**As** a cashier  
**I want** to blind-count, recognize over/short, and send counted cash to the safe  
**So that** the till ends at zero without rewriting Z snapshots.

**Acceptance:**

- Snapshots: expected before recon, counted, variance CHECK unchanged
- Transfer `session_close` uses counted amount
- Closed `SessionTotals` return snapshots
- Session location balance zero
- Material variance (`abs(variance) >=` approval threshold): `direct` if closer has `cash.approve_variance`; otherwise a different approver
- Any nonzero variance requires a managed reason code; free-text note only at/above the note threshold

### US-11.1.5 — Manager-assisted close

**As** a store manager  
**I want** to close an abandoned session without becoming its cashier  
**So that** the register and Z are not stuck.

**Acceptance:** [phase11-session-lifecycle.md](phase11-session-lifecycle.md) §5

### US-11.1.6 — Production cutover

**As** operations  
**I want** a documented maintenance-window order for 11.1  
**So that** cashiers are not locked out of the Register after deploy.

**Acceptance:** [phase11-implementation-plan.md](phase11-implementation-plan.md) **Production cutover**; every active store initialized before first open; historical sessions untouched

## 11.2 — Non-sale activity

### US-11.2.1 — Paid-in and paid-out

**As** a store manager  
**I want** reason-coded paid-ins and paid-outs on the open session  
**So that** non-sale cash is not mixed with tenders or gift-card cash-out.

**Acceptance:** effective paid-out threshold is `COALESCE(store, org)` and inclusive `>=`; performer with `cash.approve_paid_out` is `direct`; otherwise a different user with that key

### US-11.2.2 — Drop and replenish

**As** staff  
**I want** atomic session↔safe transfers  
**So that** a low till can be funded and a high till can be skimmed without drawer-to-drawer moves.

**Acceptance:** direct session-to-session rejected; available-cash on drop; safe cover on replenish

### US-11.2.3 — Reverse

**As** a privileged user  
**I want** to reverse an eligible Phase 11 operation exactly once without inventing an inverse business event  
**So that** mistakes do not require editing facts.

**Acceptance:** [phase11-non-sale-activity.md](phase11-non-sale-activity.md) §7; original source row unchanged; reverse has no fabricated paid-in/out/transfer/deposit row

## 11.3 — Safe, deposit, report

### US-11.3.1 — Reconcile safe

**As** a store manager  
**I want** to count the safe independently of session results without freezing the store for the whole count  
**So that** a balanced set of tills can still show a safe over/short.

**Acceptance:** activity may continue during the count; submit rejects a stale `lock_version` or expected snapshot; zero variance still counts as reconciled for the store-day status; nonzero uses the same reason / note / approval bands as session close

### US-11.3.2 — Prepare deposit

**As** a store manager  
**I want** to move part of the safe to deposit in transit  
**So that** cash has a recorded exit from store custody without bank import.

**Acceptance:** retain-all-overnight allowed; next date can open; no bank columns; reverse while in transit restores safe and reduces DIT; original deposit row unchanged

### US-11.3.3 — Store-day report

**As** a manager  
**I want** one report of session, safe, and deposit facts for a business date  
**So that** I can see incomplete work without a fourth close.

**Acceptance:** daily deposits listed for the selected date; DIT location balance is cumulative and is not presented as cash still in the store
