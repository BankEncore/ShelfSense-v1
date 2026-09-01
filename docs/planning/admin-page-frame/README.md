# Admin Page Frame Program

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Slice 0 complete. Slice 1 authorized only within [change-allowlist.md](change-allowlist.md).

This is a UDS-adjacent administrative composition program, not a numbered domain phase and not a numbered UDS slice. UDS-6 (staff history) and UDS-7 (sidebar / Cmd+K) remain parked.

## Two decisions

1. **ShelfSense needs a shared Admin page-frame contract** — width modes, region order, and orchestration of existing shared partials.
2. **ShelfSense does not yet authorize a page-by-page restyle** — remaining surfaces adopt through separately approved family or feature slices after the Slice 1 closeout gate.

Slice 0 choices: [choices.md](choices.md) (APF-001–APF-008).

## Document map

| Document | Purpose |
|---|---|
| [plan.md](plan.md) | Program authority: goal, UDS-5.5 amendment, locked decisions, families, width, regions, Slice 0/1, closeout |
| [choices.md](choices.md) | Slice 0 accepted choices APF-001–APF-008 |
| [slice-0.md](slice-0.md) | Inventory, evidence set vs implementation set, completion bar |
| [slice-0-evidence.md](slice-0-evidence.md) | Route reconciliation, composition, CSS viewport geometry |
| [change-allowlist.md](change-allowlist.md) | Slice 1 **locked** file and selector list |
| [user-stories.md](user-stories.md) | Issue-ready stories for Slice 0 (complete) and Slice 1 |
| [test-matrix.md](test-matrix.md) | Frozen suites, viewport gates, non-regression surfaces |
| [adoption-outlook.md](adoption-outlook.md) | Former family-migration slices — **not authorized** |

## Authorized program

| Slice | Authority | Production code |
|---|---|---|
| **Slice 0** — Inventory, evidence, and contract | **Complete** | None |
| **Slice 1** — Frame + Adjustment Reasons | Authorized within the locked allowlist | Bounded allowlist |
| **Closeout gate** | Required before any further adoption | None in this packet |

[adoption-outlook.md](adoption-outlook.md) is not a delivery plan.

## Next action

Implement Slice 1 within [change-allowlist.md](change-allowlist.md): `admin/shared/page`, width helper + `content_for` on `main.app-content`, Adjustment Reasons index/show `standard` and new/edit `narrow`. Do not migrate other families.

## Does not reopen

- `Admin::NavigationCatalog` membership, permission predicates, destination labels, or group membership
- Register workspace, keyboard, Turbo, Stimulus, or print contracts
- Purchasing Ops interaction, shortcuts, or dirty-form behavior
- Domain queries, lifecycle commands, authorization, or persisted values
- UDS-6 staff history composition
- UDS-7 sidebar or Cmd/Ctrl+K
- Home landing purpose (deferred product decision)
- Stylesheet extraction into separate CSS files

## Prior art

- [UDS-5 — Administrative composition](../ux-design-system/uds-5-plan.md) — compact nav, type roles, Product reference family; standing feature-led adoption
- [ux-conventions.md](../../ux-conventions.md) — page anatomy and shared partials
- [Warm Parchment](../ux-design-system/warm-parchment.md) — tokens and typography
- [deferred-patterns.md](../ux-design-system/deferred-patterns.md) — parked interaction patterns

The historical draft at [`docs/drafts/administrative-ux-revamp/shelvesense-admin-page-frame-slice-0.md`](../../drafts/administrative-ux-revamp/shelvesense-admin-page-frame-slice-0.md) is superseded by this packet.
