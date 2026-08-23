# Phase 7.1 ↔ UDS-4 coordination

Status: **Accepted** (August 2026). Binding for Phase 7.1 and UDS-4 implementation.

Authority for overlapping UX and purchasing ergonomics work. [Phase 7.1](phase7.1-plan.md) and [UDS-4](../ux-design-system/uds-4-plan.md) both cite this document. Implementation PRs for either program must not start until this packet is **Accepted**.

## Purpose

[roadmap.md](../roadmap.md) describes two forward programs that overlap:

| Program | Primary concern |
|---|---|
| **UDS-4** | Grouped administrative navigation, cross-cutting Warm Parchment adoption, cross-link conventions |
| **Phase 7.1** | Purchasing-specific ergonomics deferred from [Phase 7](../phase7-orders-and-receiving/README.md) §17 |

Without a single ownership table, parallel work will conflict on `application.html.erb`, admin purchasing templates, ops workspace styling, and [program-plan.md](../ux-design-system/program-plan.md) slice allowlists.

## Governing split

> **UDS-4 owns navigation chrome and cross-cutting presentation rules. Phase 7.1 owns purchasing domain screens, queries, and ops-workflow parity. Neither program invents routes, permissions, or domain commands the other owns.**

Until this document was accepted, implementation was blocked. From acceptance forward:

- Phase 7.1 and UDS-4 application slices may proceed per the merge sequencing below
- UDS-4.1 grouped nav still requires the [navigation prototype gate](../ux-design-system/navigation-proposal.md#required-prototype-gate)

## Decision table

Each row must remain stable after acceptance. Change ownership only through an explicit amendment to this file and the affected program plan.

| # | Topic | Owner | Slice | Decision | Status |
|---|---|---|---|---|---|
| 1 | **Purchasing work hub** (counts, exceptions, deep links) | **Phase 7.1** | 7.1.1 | Domain read-model at **`GET /admin/purchasing`**. UDS-4 supplies only shared admin chrome. | Accepted |
| 2 | **Grouped nav canonical group names** | **UDS-4** | 4.0–4.1 | Adopt the eight groups in [navigation-proposal.md](../ux-design-system/navigation-proposal.md). Roadmap aspirational names are future groupings when destinations exist. | Accepted |
| 3 | **`application.html.erb` structure** | **UDS-4** | 4.1 | UDS-4.1 only slice that introduces grouped nav markup. Phase 7.1 adds flat-nav **Purchasing** link to hub before 4.1; **keeps** existing Orders / PO / Receipt links until 4.1 deduplicates them under the **Purchasing** group (hub primary entry). | Accepted |
| 4 | **Admin purchasing indexes** (orders, POs, receipts) | **Phase 7.1** | 7.1.2 | Phase 7.1 owns templates, filters, tables, and cross-links. | Accepted |
| 5 | **Customer requests admin** (index/show polish) | **Phase 7.1** | 7.1.4 optional | Purchasing cross-links in 7.1.4; general Warm Parchment on migration-matrix schedule. | Accepted |
| 6 | **Ops Location + Draft PO** interaction closeout | **Phase 7.1** | 7.1.3 | Unblocked after UDS-4.1; implemented in [phase7.1.3-plan.md](phase7.1.3-plan.md). Update program-plan allowlist when 7.1.3 ships. | Accepted |
| 7 | **`ActionButtonHelper` on purchasing surfaces** | **Screen owner slice** | 7.1.x / 4.2 | Adopt helper on touched actions in the owning slice PR only. | Accepted |
| 8 | **Cross-link conventions** | **Shared doc; purchasing links in 7.1** | Coordination + 7.1.2 | Patterns below; UDS-4.2 owns non-purchasing cross-links. | Accepted |
| 9 | **Purchasing entry / Home** | **Phase 7.1** | 7.1.1 | Dedicated **`GET /admin/purchasing`** hub. Supplements history indexes; grouped nav lists under **Purchasing**. | Accepted |
| 10 | **Prototype gate vs Phase 7.1 timing** | **Both** | 4.0 then 4.1 | 7.1.1–7.1.2 on flat nav; UDS-4.0 parallel; UDS-4.1 after gate. | Accepted |

### Resolved decisions (August 2026)

1. **Hub route** — **`GET /admin/purchasing`** (`Admin::PurchasingController#show`). Orders index remains order history only.
2. **7.1.3 vs UDS-4.1** — **7.1.1 → 7.1.2 → UDS-4.0 → UDS-4.1 → 7.1.3**. Ops closeout does not share a PR with grouped nav; 7.1.3 may parallel UDS-4.2. **7.1.3 is unblocked** with UDS-4.1 on `main`.
3. **Roadmap nav vocabulary** — [roadmap.md](../roadmap.md) UDS-4 section points here and [navigation-proposal.md](../ux-design-system/navigation-proposal.md); aspirational group names deferred until destinations exist.

## Cross-link conventions

Shared patterns for Phase 7.1.2+ (UDS-4.2 may reuse for non-purchasing):

| From | To | Label pattern |
|---|---|---|
| Order show | PO line / PO show | “Purchase order …” / “PO line …” |
| Customer request show | Order, PO, receipt, ops workspace | Status-appropriate primary action + secondary history links |
| PO show | Orders, receipts, draft ops | “Open in draft PO workspace” when draft |
| Receipt show | PO line, order, request allocation | Immutable posted facts only |
| Product / variant show | Existing quick actions unchanged | No new purchasing commands |

Use existing routes; add helpers in `PurchasingHelper` only when the same link triple appears three or more times.

**Authorization:** helpers return `nil` when the current user lacks destination permission, store access, or record visibility. Views render a link only when the helper returns a path. Direct URL access remains denied by controllers. Tests must cover narrow users viewing an allowed record related to a forbidden destination (link absent; direct access denied)—especially receipt → customer request and PO → internal order.

## Merge sequencing (after Accept)

```text
1. Coordination doc accepted
2. Parallel allowed:
   - UDS-4.0 navigation prototype + gate evidence
   - Phase 7.1.1 purchasing work hub at GET /admin/purchasing (flat nav)
3. Phase 7.1.2 admin purchasing indexes
4. UDS-4.1 grouped nav (after prototype gate) — **removes redundant top-level Orders / PO / Receipt links**; hub remains primary **Purchasing** group entry (Phase 7.1.1 flat nav intentionally keeps duplicate links until this step)
5. Phase 7.1.3 ops interaction closeout (UDS-4.1/4.2 on `main`; may parallel UDS-4.2)
6. UDS-4.2 non-purchasing adoption (complete on `main`)
7. Phase 7.1.4 deferred unless separately opened
```

Phase 8/9 domain work may proceed in parallel if it does not modify purchasing admin shell, grouped nav, or ops layouts under active slices.

## Acceptance criteria (this document)

**Accepted** August 2026. Documentation follow-up complete:

1. [program-plan.md](../ux-design-system/program-plan.md) slice allowlist and behavior gates include Phase 7.1.1–7.1.3 and UDS-4.0–4.2 (August 2026).
2. [migration-matrix.md](../ux-design-system/migration-matrix.md) ownership rows updated for purchasing admin, hub, and ops Location/Draft PO (August 2026).

## Related documents

| Document | Relationship |
|---|---|
| [phase7.1-plan.md](phase7.1-plan.md) | Phase 7.1 slices and out-of-scope locks |
| [uds-4-plan.md](../ux-design-system/uds-4-plan.md) | UDS-4 slices and deferrals |
| [navigation-proposal.md](../ux-design-system/navigation-proposal.md) | Canonical nav inventory and prototype gate |
| [phase7-spec.md](../phase7-orders-and-receiving/phase7-spec.md) §17 | Purchasing UX authority Phase 7.1 extends |
