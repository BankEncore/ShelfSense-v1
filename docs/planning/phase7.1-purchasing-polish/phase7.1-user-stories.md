# Phase 7.1 — User stories

Status: **Complete** — **7.1.1–7.1.3** and **UDS-4** on `main` ([phase7.1.3-plan.md](phase7.1.3-plan.md)); **7.1.4 deferred**.

Concise stories for slices 7.1.1–7.1.4; acceptance bullets are the review bar.

---

## Slice 7.1.1 — Purchasing work hub

**Status:** Complete on `main`.

### 7.1.1.1 See active purchasing work

**As a** buyer or store manager with purchasing permissions, **I want** a purchasing hub that summarizes work awaiting action **so that** I do not hunt through flat navigation links.

Acceptance:

- Hub reachable without auto-redirect when no store is selected; shows store-selection CTA and no store-scoped counts until a store is selected.
- With `current_store`, authorized sections appear even when count is zero (compact “none awaiting” state).
- Unauthorized sections are omitted entirely; hub layout is stable for authorized users.
- Minimum store-scoped sections when authorized: location queue, draft POs, sent POs with open quantity, receipt drafts.
- Sent PO count uses SQL relation scope, not per-record Ruby filtering.
- Receipt drafts section links to receiving workspace index, not an ambiguous “latest draft.”
- Hub is reachable from flat admin nav **Purchasing** link when user has any hub-eligible permission globally or on any accessible store.

### 7.1.1.2 Hub respects permissions

**As a** narrowly scoped store user, **I want** the hub to show only sections I can use **so that** navigation does not advertise forbidden work.

Acceptance:

- Integration test mirrors navigation-proposal Profile B style (e.g. receiving-only user sees only receiving-related sections).
- No-store integration test shows history links only where controllers allow without store scope.
- Direct URL to unauthorized destinations remains denied by controllers.

---

## Slice 7.1.2 — Admin purchasing indexes

**Status:** Complete on `main`.

### 7.1.2.1 Consistent purchasing history indexes

**As a** buyer, **I want** orders, purchase orders, and receipt history to use the same admin patterns as other modern screens **so that** I can scan results quickly.

Acceptance:

- Indexes use shared page header, breadcrumbs, and data tables.
- PO index keeps existing status filter only; orders and receipts indexes do not add new filter behavior.
- `ActionButtonHelper` on touched primary/secondary actions per button-action-semantics (one solid brand dominant action per surface where applicable).

### 7.1.2.2 Follow purchasing cross-links

**As a** buyer, **I want** to move between order, PO, receipt, and request **so that** I can trace lineage without copying identifiers.

Acceptance:

- Show pages link to related entities per [coordination cross-link conventions](phase7.1-uds-coordination.md#cross-link-conventions).
- Cross-links omitted when user lacks destination permission, store access, or record visibility.
- Integration test: narrow user on allowed record does not see link to forbidden related record; direct access denied.
- Posted receipt facts remain read-only; receipt tables use explicit `.table-scroll` / `.data-table`.

---

## Slice 7.1.3 — Purchasing ops interaction closeout

**In progress.** Hub exit links on Location/Draft PO/Receiving are incidental **7.1.1** integration and do not close these stories.

### 7.1.3.1 Location queue interaction closeout

**As a** floor associate, **I want** the location queue to honor shared ops interaction contracts **so that** I can work safely with keyboard and scanner without losing in-progress entries.

Acceptance:

- Contextual shortcut chrome (no misleading lookup/save/primary controls).
- Dirty panel tracking with **“Discard this location entry?”** on Close/Escape.
- Focus restoration after success, cancel, and recoverable errors (post-redirect).
- Stable cancel vs convert commit buttons (no morphing single submit).
- Additive assertions in [location_queue_buttons_test.rb](../../../test/system/location_queue_buttons_test.rb).

### 7.1.3.2 Draft PO interaction repair

**As a** buyer, **I want** draft PO editing to honor shared ops interaction contracts **so that** I do not lose work silently and errors focus the right field.

Acceptance:

- Add-line form dirty tracking; conditional lookup auto-focus when server designates error fields.
- Stale/validation failures focus affected row fields.
- Additive coverage in [purchasing_ops_workspace_test.rb](../../../test/system/purchasing_ops_workspace_test.rb).
- One Draft PO index keyboard smoke test.

---

## Slice 7.1.4 — Customer-request cross-links (optional)

**Status:** Deferred — hub covers active-work discovery.

### 7.1.4.1 Request show emphasizes next purchasing action

**As a** buyer, **I want** request show pages to surface the next purchasing step **so that** I can act without re-reading status codes.

Acceptance:

- Reopen only if hub does not subsume this need.
- Cross-links permission-gated per coordination conventions.
