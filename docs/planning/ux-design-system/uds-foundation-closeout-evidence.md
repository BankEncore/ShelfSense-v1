# UDS foundation closeout — evidence roll-up

Status: **Frozen** on integration branch `uds-foundation-closeout`.

This document records automated verification at foundation closeout. It does **not** claim screen-reader certification, human cashier timing, or independent accessibility review.

## Freeze commit

Record the merge commit SHA when `uds-foundation-closeout` merges to `main`. Local development SHA at authoring: see `git rev-parse HEAD` on the integration branch.

## Summary

| Surface | Migration state | Layer A | Layer B | Layer C | Evidence |
|---|---|---|---|---|---|
| Supplier administration | `verified-automated` | Pass | Pass | Pass | `test/system/uds_supplier_reference_test.rb`, `test/integration/suppliers_admin_test.rb` |
| Receiving | `verified-automated` | Pass | Pass | Pass | `test/system/uds_receiving_reference_test.rb`, `test/system/purchasing_ops_workspace_test.rb`, `test/integration/receiving_line_lookup_test.rb` |
| Transaction history/detail | `verified-automated` | Pass | Pass | Pass | `test/system/uds_history_reference_test.rb`, `test/integration/pos_transaction_history_test.rb` |
| Native review dialogs | `verified-automated` (contract) | — | Pass | — | `test/support/uds_review_dialog_contract.rb` |
| Register | `verified-automated` | Pass | Pass | Pass | `test/system/uds_register_reference_test.rb`, `test/system/pos_register_workspace_test.rb` |
| Location / Draft PO | `partial` | — | Partial | Partial | [phase7.1.3-ops-evidence.md](../phase7.1-purchasing-polish/phase7.1.3-ops-evidence.md) |

## Deferred (not passed)

| Category | Notes |
|---|---|
| SR-MANUAL | No screen-reader validation in CI |
| PERF-HUMAN | Register median timing is optional/nightly; CI checks correctness only |
| UX-INDEPENDENT | No independent reviewer sign-off |
| Touch emulation | Keyboard/scanner paths only |
| Firefox | Chromium baseline only |
| Lighthouse | Not run |

## axe allowlist

Per-surface moderate/minor allowlists: `test/support/uds_axe_allowlist.yml` (empty at freeze—all critical/serious violations remediated or absent).

## CI

Job `uds_accessibility` runs `bin/rails test test/system/uds_*` per [uds-ci-artifact-policy.md](uds-ci-artifact-policy.md).

## Remediation in this closeout

- Transaction history index: wrapped results table in `.table-scroll` for narrow-viewport reflow (`app/views/pos/transactions/index.html.erb`).

## Governance

Future phases: [ux-adoption-template.md](ux-adoption-template.md). Authoritative plan: [uds-foundation-closeout-plan.md](uds-foundation-closeout-plan.md).
