# UDS closeout — CI artifact policy

Status: **Accepted** for [uds-foundation-closeout-plan.md](uds-foundation-closeout-plan.md).

## Phase 1 (C1–C4)

- UDS reference suites run on the integration branch and locally via:

  ```sh
  ./dev/rails-docker sh -c 'bin/rails db:test:prepare && bin/rails test test/system/uds_*'
  ```

  Use `sh -c` so both commands run inside Docker; `&& bin/rails test ...` after the helper alone executes on the host.
- Failures may write axe JSON under `tmp/uds-evidence/<sha>/<surface>/` locally.
- The dedicated `uds_accessibility` CI job is **informational** until C5 freeze.

## Phase 2 (C5+)

- Job `uds_accessibility` in GitHub Actions runs `bin/rails test test/system/uds_*` after Chrome setup.
- **On failure:** upload `tmp/uds-evidence/` as a workflow artifact.
- **On freeze SHA / nightly:** upload full evidence bundle (axe JSON, focus metadata, optional screenshots).
- Repository ledgers ([uds-foundation-closeout-evidence.md](uds-foundation-closeout-evidence.md)) record summary, SHA, result, and artifact name—not committed screenshot archives.

## axe policy

- **Critical / serious** violations → blocker.
- **Moderate / minor** → fix or document in per-surface allowlist with owner and rerun scope.
