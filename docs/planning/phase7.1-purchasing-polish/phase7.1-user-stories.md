# Phase 7.1 — User stories

Status: **Proposed** backlog. Coordination **Accepted** — ready for slice implementation.

Concise stories for slices 7.1.1–7.1.4; acceptance bullets are the review bar.

---

## Slice 7.1.1 — Purchasing work hub

### 7.1.1.1 See active purchasing work

**As a** buyer or store manager with purchasing permissions, **I want** a store-scoped hub that summarizes work awaiting action **so that** I do not hunt through flat navigation links.

Acceptance:

- Hub requires `current_store` when any section needs store scope; sections omit when unauthorized or empty.
- Minimum sections when data exists: location queue count, open draft PO count, sent POs with open quantity, in-progress receipt drafts.
- Each section links to the correct admin list or ops workspace.
- Hub is reachable from flat admin nav before grouped nav ships.

### 7.1.1.2 Hub respects permissions

**As a** narrowly scoped store user, **I want** the hub to show only sections I can use **so that** navigation does not advertise forbidden work.

Acceptance:

- At least one integration test mirrors navigation-proposal Profile B style (e.g. receiving-only user sees only receiving-related sections).
- Direct URL to unauthorized destinations remains denied by controllers.

---

## Slice 7.1.2 — Admin purchasing indexes

### 7.1.2.1 Consistent purchasing history indexes

**As a** buyer, **I want** orders, purchase orders, and receipt history to use the same admin patterns as other modern screens **so that** I can search, filter, and scan results quickly.

Acceptance:

- Indexes use shared page header, filters where useful, and data tables.
- Status filters on PO index remain; presentation improves without changing query semantics.
- `ActionButtonHelper` on touched primary/secondary actions.

### 7.1.2.2 Follow purchasing cross-links

**As a** buyer, **I want** to move between order, PO, receipt, and request **so that** I can trace lineage without copying identifiers.

Acceptance:

- Show pages link to related entities per [coordination cross-link conventions](phase7.1-uds-coordination.md#cross-link-conventions).
- Posted receipt facts remain read-only; no edit affordances on immutable rows.

---

## Slice 7.1.3 — Ops workspace parity

### 7.1.3.1 Location queue matches Receiving ergonomics

**As a** floor associate, **I want** the location queue to behave like receiving **so that** keyboard and scanner workflows feel consistent.

Acceptance:

- Shortcut help visible; focus restoration after successful locate/not-located actions.
- Existing [location_queue_buttons_test.rb](../../../test/system/location_queue_buttons_test.rb) assertions unchanged or strengthened only.

### 7.1.3.2 Draft PO workspace matches Receiving ergonomics

**As a** buyer, **I want** draft PO editing to share receiving-grade error handling and dirty guards **so that** I do not lose work silently.

Acceptance:

- Dirty-form confirm behavior matches receiving/draft PO tests in [purchasing_ops_workspace_test.rb](../../../test/system/purchasing_ops_workspace_test.rb).
- program-plan allowlist updated for touched selectors.

---

## Slice 7.1.4 — Customer-request cross-links (optional)

### 7.1.4.1 Request show emphasizes next purchasing action

**As a** associate, **I want** the customer request show page to link to the relevant order, PO, or receipt **so that** I know what to do next.

Acceptance:

- Deferred if 7.1.1 hub + existing request show already satisfy the workflow.
- No “mark completed” without POS; Phase 7 rule preserved.
