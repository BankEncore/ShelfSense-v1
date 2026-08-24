# UDS foundation closeout

Status: **Complete** — merged to `main` (`328cbbf`, PR #41).

Authority: [program-plan.md](program-plan.md), [accessibility-ergonomic-test-matrix.md](accessibility-ergonomic-test-matrix.md), [migration-matrix.md](migration-matrix.md), [button-action-semantics.md](button-action-semantics.md), [surface-contracts.md](surface-contracts.md).

## Goal

Close the separate UDS implementation program by proving that five reference surfaces satisfy reproducible structural, interaction, responsive, and workflow gates; accurately record evidence limits; and make UX adoption an ordinary responsibility of later feature phases.

This is verification, bounded remediation, and governance—not UDS-5 and not another broad redesign.

## Deliverable

ShelfSense's design-system foundation is supported by repeatable automated evidence on reference surfaces. Remaining screens retain accurate migration states and migrate only when their owning feature phase materially changes them.

## Evidence limitation

The project does not currently have real screen-reader testing, an independent accessibility reviewer, representative human cashier timing, or every physical input environment named by the original manual matrix.

Automated checks identify many accessibility failures but cannot establish complete WCAG conformance or prove real assistive-technology usability. The closeout must not claim screen-reader or spoken-output validation. Automated Register timing is a regression signal, not human productivity evidence.

The foundation program may close **operationally** when the automated gate passes, without describing the result as complete accessibility certification.

## Migration states

| State | Meaning |
|---|---|
| `legacy` | Accepted UDS patterns not meaningfully adopted |
| `partial` | Some patterns present; one or more gates incomplete |
| `verified-automated` | Layer A/B/C automated gates pass at recorded SHA; human/AT gaps documented |
| `conforming` | `verified-automated` plus SR-MANUAL, PERF-HUMAN, independent review |
| `locked` | Deliberate presentation contract must not change incidentally |

## Reference surfaces

| Surface | Closeout responsibility |
|---|---|
| Supplier administration | Server-rendered CRUD, forms, tables, validation, lifecycle |
| Receiving | Keyboard/scanner workflow, dense grid, errors, review, posting |
| Transaction history/detail | Immutable facts, filters, disclosures, eligibility actions |
| Native review dialogs | Shared contract module across consumers |
| Register | Scanning, keyboard, overlays, recovery, timing correctness |

Location and Draft PO remain `partial` per [phase7.1.3-ops-evidence.md](../phase7.1-purchasing-polish/phase7.1.3-ops-evidence.md); not in the full reference gate.

## Three evidence layers

| Layer | Covers | Implementation |
|---|---|---|
| **A — axe** | WCAG A/AA, contrast, names/roles | `axe-core-capybara` per stable state |
| **B — workflow** | K, D, E, I | Extend frozen system/integration suites |
| **C — layout** | R, S, T, M smoke | `with_viewport` + layout helpers |

**Deferred:** SR-MANUAL, PERF-HUMAN, UX-INDEPENDENT, touch emulation, Firefox, Lighthouse.

## Slices

| Slice | Deliverable |
|---|---|
| C0 | Docs, migration states, UX adoption template |
| C1 | axe gem, shared helpers, Supplier pilot, CI artifact policy |
| C2 | Receiving + history + dialog contract |
| C3 | Register workflow + layout smoke |
| C4 | Bounded remediation |
| C5 | Freeze SHA, evidence roll-up, matrix, CI gate, governance |

## Branch policy

Integration branch `uds-foundation-closeout` from `main`; slice branches merge into integration; single merge PR to `main` after C5.

Evidence: [uds-foundation-closeout-evidence.md](uds-foundation-closeout-evidence.md) (completed at freeze).
