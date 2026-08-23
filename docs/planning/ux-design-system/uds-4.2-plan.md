# UDS-4.2 — Non-purchasing adoption

Status: **In progress** — UDS-4.1 on `main`; sub-slices 4.2a–4.2d implemented on `uds-4.2-non-purchasing-adoption`.

Authority: [uds-4-plan.md](uds-4-plan.md) § UDS-4.2, [program-plan.md](program-plan.md) allowlist, [phase7.1-uds-coordination.md](../phase7.1-purchasing-polish/phase7.1-uds-coordination.md) rows 5–8, [migration-matrix.md](migration-matrix.md).

## Goal

Continue Warm Parchment and `ActionButtonHelper` adoption on admin families **not** owned by Phase 7.1, and standardize **non-purchasing** cross-links—without new routes, permissions, or domain commands.

## Prerequisites

1. UDS-4.1 grouped nav on `main`
2. Coordination remains Accepted
3. May parallel Phase 7.1.3 (no shared templates)

## Hard excludes

- `admin/orders/**`, `admin/purchase_orders/**`, `admin/purchase_receipts/**`, `admin/purchasing/**`
- `ops/locations/**`, `ops/draft_pos/**`
- Purchasing cross-links on customer-request show/index (Order / PO / receipt / ops) — Phase 7.1.4 optional
- Purchasing helpers (`order_stock_path_for`, `create_customer_request_path_for`) — restyle only
- Ops/POS chrome, Register, print, Hotwire on admin chrome

## Sub-slices

| Slice | Allowlist | Status |
|---|---|---|
| **UDS-4.2a** | `admin/products/**`, `admin/product_variants/**` | Implemented |
| **UDS-4.2b** | `admin/inventory_balances/**`, `admin/inventory_adjustments/**`, `admin/inventory_reconciliations/**` | Implemented |
| **UDS-4.2c** | `admin/customers/**`, `admin/customer_requests/**` (non-purchasing polish) | Implemented |
| **UDS-4.2d** | Org config, reference, security, audit, merch tasks, shell entry | Implemented |

### Per-PR contract

- Name matrix paths in the PR description
- Adopt `ActionButtonHelper` only on touched actions
- Prefer shared partials; no new IA
- No domain/behavior changes; frozen suites green
- Update matrix + this plan + roadmap in the same PR
- Manual Chromium viewport + keyboard spot-check on touched screens

### Non-purchasing cross-links

Helpers live in [`AdminCrossLinksHelper`](../../../app/helpers/admin_cross_links_helper.rb). Return `nil` when the user lacks permission or the record is blank; views render plain text or omit the link. Patterns:

- Product ↔ merchandise category
- Variant ↔ product, merchandise class, department, tax class
- Variant ↔ inventory balance / adjust (store-scoped)
- Customer ↔ customer request; request ↔ customer / product / variant / POS transaction (non-PO)

## Acceptance

1. Allowlisted families improved with matrix updates, or explicitly deferred in the backlog table above
2. No Phase 7.1 paths modified
3. New cross-link helpers permission-nil + narrow-user coverage where introduced
4. UDS-4 program still requires 4.1 on main and Profiles A/B green
