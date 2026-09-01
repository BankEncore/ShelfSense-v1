# GitHub work management

How ShelfSense uses GitHub for planning, review, and releases. Keep this lightweight: add process only when coordination, review, or release pain appears.

## Principles

1. Repository documentation is the source of truth for durable product and technical decisions (`docs/`, ADRs, phase plans).
2. Issues track discrete outcomes; pull requests review the implementation.
3. Milestones define phase delivery scope.
4. Labels classify type; do not duplicate project status, phase, or priority unless automation requires it.
5. Git tags mark stable release checkpoints, not ordinary merges.

## Documentation authority

Prefer linking to existing docs over copying them into issues or PRs:

| Location | Purpose |
|---|---|
| [README.md](../README.md) | Project overview, roadmap summary, quick start |
| [docs/adr/](adr/README.md) | Accepted and proposed architecture decisions |
| [docs/planning/](planning/README.md) | Phase plans, schema, authorization contracts |
| [docs/development.md](development.md) | Docker workflow and local commands |
| [docs/testing.md](testing.md) | Active CI coverage and system-test workflow |
| [AGENTS.md](../AGENTS.md) | Contributor and coding-agent rules |

Update applicable docs in the same PR as the behavior change (or in a prerequisite docs PR).

## Lightweight defaults (current scale)

Use this minimal setup until multi-person or multi-domain coordination requires more:

1. **One milestone per active phase** (e.g. `Phase 1 — Operational Foundation`).
2. **One GitHub Project** with Status only: Backlog, Ready, In progress, In review, Done.
3. **Type labels:** `type: feature`, `type: bug`, `type: documentation`, `type: refactor`, `type: maintenance`, `type: test`, `type: decision`.
4. **Special labels when needed:** `needs-decision`, `security`, `breaking-change`.
5. Optional later: Project fields for Phase / Domain / Priority / Size; domain labels; parent/child issue trees.

Do not create labels for status, milestone membership, priority, size, or individual tables/technologies.

## Issues

Implementation issues should usually be one focused PR. Structure:

```markdown
## Summary
Outcome and why.

## References
- Phase plan / schema / ADR links
- Parent issue, if any: #

## Acceptance criteria
- [ ] Verifiable behavior
- [ ] Tests / checks
- [ ] Docs updated

## Exclusions
Deferred work

## Dependencies
Blocking issues or decisions
```

Split when work spans unrelated concerns, needs independently reviewable prerequisites, or would produce an unreviewable PR. Do not split tightly coupled implementation and tests merely to create smaller tasks.

Small maintenance (dependency bumps, tiny fixes) may use an issue + PR without a parent issue or Project Size field.

## Branches and pull requests

Branch naming: `<issue-number>-<short-description>` (lowercase, hyphenated). Merge to the primary development branch (`main`). No long-lived phase branches unless a release strategy requires them.

Active exception: [Register workspace consolidation](planning/register-workspace-consolidation/implementation-plan.md) uses integration branch `register-workspace-consolidation` until [closeout](planning/register-workspace-consolidation/closeout-plan.md). An incomplete Register replacement on `main` would leave cashiers without POS Home and without F10. Slice PRs for that program target the integration branch; merge `main` into it regularly. Phase 11 used the same pattern and has merged. The Admin Page Frame temporary sprint branch `apf-development` has merged to `main` and is retired.

PR structure:

```markdown
## Summary
- Material changes and important choices

## Verification
- `./dev/rails-docker bin/rails test`
- `./dev/rails-docker bin/rubocop`
- `./dev/rails-docker bin/brakeman --no-pager`
- `./dev/rails-docker bin/bundler-audit`
- Manual checks, if any

## Documentation and migrations
- Docs touched
- Migrations / rollback notes

Closes #N
```

PRs must stay focused, include appropriate tests, update docs, pass CI, and avoid unrelated cleanup. Record follow-up work as new issues.

## Releases

Create an annotated tag and GitHub Release when the repo reaches a meaningful checkpoint (completed phase in a known-good state, internal test release, RC, or production readiness)—not for ordinary merges.

Pre-1.0 versions mark capability checkpoints (e.g. `v0.1.0` after Phase 1 verification). Closing a milestone and tagging a release are related but distinct.

## Phase completion

1. Review milestone issues; move deferred work to the backlog or a later milestone.
2. Verify phase acceptance criteria and CI on the release commit.
3. Ensure docs match the implemented system.
4. Close the milestone.
5. Tag a release only if the result is a stable checkpoint.

## Policy maintenance

Revise this document when the team repeatedly works around it. Do not add fields, labels, views, or steps solely because GitHub supports them.
