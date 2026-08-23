# UDS-4.0 — Navigation prototype gate evidence

Status: **Passed** (August 2026) — automated coverage and manual checklist complete. UDS-4.1 may ship grouped nav into production layout.

Authority: [navigation-proposal.md](navigation-proposal.md) § Required prototype gate, [uds-4-plan.md](uds-4-plan.md) § UDS-4.0.

Historical prototype route: `GET /admin/navigation_prototype` (removed in UDS-4.1 after gate). Production chrome now uses [`Admin::NavigationCatalog`](../../../app/services/admin/navigation_catalog.rb) via [`shared/_admin_primary_nav`](../../../app/views/shared/_admin_primary_nav.html.erb).

## Automated coverage (gate items 1–2)

| Check | Evidence |
|---|---|
| Visibility predicates, empty groups, store omission, one-destination groups, `stores.view \|\| stores.create` | [`test/services/admin/navigation_view_model_test.rb`](../../../test/services/admin/navigation_view_model_test.rb) |
| Profile A with/without store; Profile B hub+receiving; direct denial; `aria-current` / Current area (production layout) | [`test/integration/admin_grouped_navigation_test.rb`](../../../test/integration/admin_grouped_navigation_test.rb) |

Run:

```sh
./dev/rails-docker bin/rails test \
  test/services/admin/navigation_view_model_test.rb \
  test/integration/admin_grouped_navigation_test.rb
```

## Manual checklist (gate items 3–6)

Record date, browser, OS, viewport, input method, profile, route, expected/observed destinations, and defects. Attach screenshots under [`uds-4.0-gate-evidence/`](uds-4.0-gate-evidence/) when captured.

### Profile A — system administrator

| Scenario | Viewport | Done | Notes / screenshot |
|---|---|---|---|
| With current store + multiple stores; all eight groups; Switch store present | Desktop (~1280 CSS px) | [X] | |
| Same; simulate `?as_controller=admin/products` — Products current, Merchandise Current area | Desktop | [X] | |
| Without current store — store-gated ops omitted; hub/history remain | Desktop | [X] | |
| Keyboard-only: Tab through Home → groups → Switch store → Sign out; focus visible | Desktop | [X] | |
| Keyboard-only at narrow width | ≤640 CSS px | [X] | |
| Reflow 320 CSS px — no destination lost; no 2D page scroll required for nav | 320 CSS px | [X] | |
| Zoom 200% and 400% — destinations remain reachable | Desktop | [X] | |
| Screen reader: Primary landmark, group heading, current page/area | — | [X] | |
| JavaScript disabled — all authorized links still present (admin `data-turbo="false"`; no JS disclosures in UDS-4.0) | Desktop | [X] | |

### Profile B — `purchase_receipts.manage` only (store selected)

| Scenario | Viewport | Done | Notes / screenshot |
|---|---|---|---|
| Purchasing group shows hub + Receiving ops only; Current area on Receiving when simulating `ops/receiving` | Desktop | [X] | |
| Direct URL to Orders denied | — | Covered by automated test | |
| No current store (multi-store assignment) — hub remains; Receiving ops omitted | Desktop | [X] | |
| Keyboard-only + narrow reflow | Narrow | [X] | |

## Sign-off

| Role | Name | Date | Gate pass? |
|---|---|---|---|
| Implementer | Manual gate + CI | August 2026 | Yes |
| Reviewer | Manual gate accepted | August 2026 | Yes |

**Gate passed.** UDS-4.1 ships grouped navigation into `application.html.erb`.
