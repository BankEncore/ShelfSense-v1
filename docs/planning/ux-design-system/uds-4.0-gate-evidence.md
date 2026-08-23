# UDS-4.0 — Navigation prototype gate evidence

Status: **In progress** — automated coverage landed; manual checklist below must be completed before UDS-4.1 starts.

Authority: [navigation-proposal.md](navigation-proposal.md) § Required prototype gate, [uds-4-plan.md](uds-4-plan.md) § UDS-4.0.

Prototype route: `GET /admin/navigation_prototype` (optional `?as_controller=admin/products` to simulate current area). Production [`application.html.erb`](../../../app/views/layouts/application.html.erb) remains flat.

## Automated coverage (gate items 1–2)

| Check | Evidence |
|---|---|
| Visibility predicates, empty groups, store omission, one-destination groups, `stores.view \|\| stores.create` | [`test/services/admin/navigation_view_model_test.rb`](../../../test/services/admin/navigation_view_model_test.rb) |
| Profile A with/without store; Profile B hub+receiving; direct denial of omitted Orders; denied prototype with no destinations; `aria-current` / Current area | [`test/integration/admin_navigation_prototype_test.rb`](../../../test/integration/admin_navigation_prototype_test.rb) |

Run:

```sh
./dev/rails-docker bin/rails test \
  test/services/admin/navigation_view_model_test.rb \
  test/integration/admin_navigation_prototype_test.rb
```

## Manual checklist (gate items 3–6)

Record date, browser, OS, viewport, input method, profile, route, expected/observed destinations, and defects. Attach screenshots under [`uds-4.0-gate-evidence/`](uds-4.0-gate-evidence/) when captured.

### Profile A — system administrator

| Scenario | Viewport | Done | Notes / screenshot |
|---|---|---|---|
| With current store + multiple stores; all eight groups; Switch store present | Desktop (~1280 CSS px) | [ ] | |
| Same; simulate `?as_controller=admin/products` — Products current, Merchandise Current area | Desktop | [ ] | |
| Without current store — store-gated ops omitted; hub/history remain | Desktop | [ ] | |
| Keyboard-only: Tab through Home → groups → Switch store → Sign out; focus visible | Desktop | [ ] | |
| Keyboard-only at narrow width | ≤640 CSS px | [ ] | |
| Reflow 320 CSS px — no destination lost; no 2D page scroll required for nav | 320 CSS px | [ ] | |
| Zoom 200% and 400% — destinations remain reachable | Desktop | [ ] | |
| Screen reader: Primary landmark, group heading, current page/area | — | [ ] | |
| JavaScript disabled — all authorized links still present (admin `data-turbo="false"`; no JS disclosures in UDS-4.0) | Desktop | [ ] | |

### Profile B — `purchase_receipts.manage` only (store selected)

| Scenario | Viewport | Done | Notes / screenshot |
|---|---|---|---|
| Purchasing group shows hub + Receiving ops only; Current area on Receiving when simulating `ops/receiving` | Desktop | [ ] | |
| Direct URL to Orders denied | — | Covered by automated test | |
| No current store (multi-store assignment) — hub remains; Receiving ops omitted | Desktop | [ ] | |
| Keyboard-only + narrow reflow | Narrow | [ ] | |

## Sign-off

| Role | Name | Date | Gate pass? |
|---|---|---|---|
| Implementer | | | Automated yes / manual pending |
| Reviewer | | | |

**UDS-4.1 must not start until the reviewer marks the gate passed.**
