# Phase 8 — Customer foundation implementation plan

Status: **Complete** on `main` (PR #42, merge `b5ed590`, August 2026).

Authority: [phase8-plan.md](phase8-plan.md), [phase8-schema.md](phase8-schema.md), [ADR-023](../../adr/ADR-023-customer-merge.md).

## Locked decisions

1. Integration branch `phase-8-customer-foundation`; slice work landed there; final PR #42 merged to `main`.
2. Phone normalization: **E.164** (`phone_normalized`); display `phone` may remain as entered.
3. Merge permission: `customers.manage`.
4. Survivor profile authoritative; no field combine on merge.
5. Reassign only `CustomerRequest::ACTIVE_STATUSES`; preserve completed/cancelled FKs.
6. Idempotency via `Idempotency::OperationService` (`merge_customers`).
7. Admin UI: server-rendered Rails; UDS primitives on changed screens.
8. ADR-023 Accepted with Phase 8.

## Slice status

| Slice | Status |
|---|---|
| 8.1 Identity and lookup | Complete |
| 8.2 Essential contact methods | Complete |
| 8.3 Duplicates and merge | Complete |
| 8.4 Lifecycle and governance | Complete |

## Final gate to `main`

1. Acceptance criteria in [phase8-plan.md](phase8-plan.md) verified
2. Full test suite + rubocop + brakeman + bundler-audit
3. ADR-023 Accepted; roadmap Phase 8 marked **Complete**
4. No stored-value ledger tables
5. Manual / review smoke covered in PR #42 review cycles
