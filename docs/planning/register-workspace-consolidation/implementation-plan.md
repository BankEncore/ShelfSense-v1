# Register workspace consolidation — Implementation plan

Status: **Slice 6C complete** on `register-workspace-consolidation` ([#92](https://github.com/BankEncore/ShelfSense-v1/issues/92) / PR [#109](https://github.com/BankEncore/ShelfSense-v1/pull/109); [slice6c-reporting-period-plan.md](slice6c-reporting-period-plan.md)). Slice 6B complete ([#91](https://github.com/BankEncore/ShelfSense-v1/issues/91) / PR [#108](https://github.com/BankEncore/ShelfSense-v1/pull/108)). Slice 6A complete ([#90](https://github.com/BankEncore/ShelfSense-v1/issues/90) / PRs [#104](https://github.com/BankEncore/ShelfSense-v1/pull/104)–[#107](https://github.com/BankEncore/ShelfSense-v1/pull/107)).

Authority: [plan.md](plan.md), [routing-and-authority.md](routing-and-authority.md).

## Merge policy

This program uses a long-lived integration branch because an incomplete Register replacement on `main` would leave cashiers without Home **and** without F10. That is a documented exception to [github-workflow.md](../../github-workflow.md) (“no long-lived phase branches unless a release strategy requires them”).

- Slice 1 (this packet) merges to **`main`**.
- Create integration branch **`register-workspace-consolidation` from `main` after Slice 1 is on `main`**. Ordinary branch; starting commit includes Slice 1. Not an orphan/empty branch.
- Slice branches: `<issue-number>-<short-description>`.
- Slice PRs for 2–7 target **`register-workspace-consolidation`**, not `main`.
- Regularly merge `main` into the integration branch.
- Merge the integration branch to `main` only after [closeout-plan.md](closeout-plan.md) is executed.
- Delete replaced presentation in the owning slice. No runtime flags.

## Slice status

| Slice | Status | Issue |
|---|---|---|
| 1 Packet / test matrix | **Accepted** on `main` (this change) | — |
| 2 Shell and state routing | Merged to integration ([#83](https://github.com/BankEncore/ShelfSense-v1/issues/83) / PR #96) | [#83](https://github.com/BankEncore/ShelfSense-v1/issues/83) |
| 3 F10 and navigation | Merged to integration ([#84](https://github.com/BankEncore/ShelfSense-v1/issues/84) / PR #97) | [#84](https://github.com/BankEncore/ShelfSense-v1/issues/84) |
| 4 Transaction composition | Merged to integration ([#85](https://github.com/BankEncore/ShelfSense-v1/issues/85) / PR #98) | [#85](https://github.com/BankEncore/ShelfSense-v1/issues/85) |
| 5A Lookup overlays | Merged to integration ([#86](https://github.com/BankEncore/ShelfSense-v1/issues/86) / PR [#99](https://github.com/BankEncore/ShelfSense-v1/pull/99)) | [#86](https://github.com/BankEncore/ShelfSense-v1/issues/86) |
| 5B Return overlays | Merged to integration ([#87](https://github.com/BankEncore/ShelfSense-v1/issues/87) / PR [#100](https://github.com/BankEncore/ShelfSense-v1/pull/100)) | [#87](https://github.com/BankEncore/ShelfSense-v1/issues/87) |
| 5C Controlled-action overlays | Merged to integration ([#88](https://github.com/BankEncore/ShelfSense-v1/issues/88) / PR [#101](https://github.com/BankEncore/ShelfSense-v1/pull/101)) | [#88](https://github.com/BankEncore/ShelfSense-v1/issues/88) |
| 5D Tender/issuance overlays | Complete on integration ([#89](https://github.com/BankEncore/ShelfSense-v1/issues/89) / PR [#102](https://github.com/BankEncore/ShelfSense-v1/pull/102); remediation PR [#103](https://github.com/BankEncore/ShelfSense-v1/pull/103)) | [#89](https://github.com/BankEncore/ShelfSense-v1/issues/89) |
| 6A Customer-service surfaces | **Complete** on integration ([#90](https://github.com/BankEncore/ShelfSense-v1/issues/90) / PRs [#104](https://github.com/BankEncore/ShelfSense-v1/pull/104)–[#106](https://github.com/BankEncore/ShelfSense-v1/pull/106)) | [#90](https://github.com/BankEncore/ShelfSense-v1/issues/90) |
| 6B Till and session detail | **Complete** on integration ([#91](https://github.com/BankEncore/ShelfSense-v1/issues/91) / PR [#108](https://github.com/BankEncore/ShelfSense-v1/pull/108)) | [#91](https://github.com/BankEncore/ShelfSense-v1/issues/91) |
| 6C Reporting-period surfaces | **Complete** on integration ([#92](https://github.com/BankEncore/ShelfSense-v1/issues/92) / PR [#109](https://github.com/BankEncore/ShelfSense-v1/pull/109)) | [#92](https://github.com/BankEncore/ShelfSense-v1/issues/92) |
| 7A Tender-review framework | Gated on 2–6 | [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93) |
| 7B Stored-value/issuance completion | Gated on 7A | [#94](https://github.com/BankEncore/ShelfSense-v1/issues/94) |
| 7C Keyboard supersession | Gated on 7A–7B packet amendment | [#95](https://github.com/BankEncore/ShelfSense-v1/issues/95) |

## Testing stack

- **Service/unit:** resolver, presenters, `can_view_expected_cash?`, later replacement/capping.
- **Request:** state rendering, GET immutability (counts **and** record state), visible actions, Turbo, routes.
- **System:** F10, focus, overlays, Escape, scan/Enter, F-keys, representative journeys.
- Do **not** add a JavaScript unit test framework.

When a slice replaces a user-facing contract, replace obsolete tests in the same PR. Preserve tests of domain truth.

## GitHub tracker

[Milestone Register workspace consolidation](https://github.com/BankEncore/ShelfSense-v1/milestone/7). Slice stories: [user-stories.md](user-stories.md).
