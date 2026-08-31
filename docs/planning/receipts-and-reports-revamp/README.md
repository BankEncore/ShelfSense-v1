# Receipts and reports revamp

Status: **Accepted packet** — implementation slices R1–R4.

**Program type:** Register follow-on (not a numbered domain phase). Runs after [Register workspace consolidation](../register-workspace-consolidation/README.md) on `main`. Does not reopen transaction, tender, stored-value, cash, session, or reporting-period domain semantics.

This program **reformats** customer receipts and gift-card vouchers for thermal readability. Domain services, persisted financial facts, authorization, and print lifecycle remain.

| Document | Purpose |
|---|---|
| [plan.md](plan.md) | Goal, locked decisions, scope, slices R1–R4 |
| [implementation-plan.md](implementation-plan.md) | Slice status, merge policy, testing stack |
| [content-contract.md](content-contract.md) | D1 customer receipt and D2 voucher presentation authority |
| [visual-system.md](visual-system.md) | Shared thermal primitives, typography, print behavior |
| [user-stories.md](user-stories.md) | GitHub-issue-ready slice stories |
| [test-matrix.md](test-matrix.md) | Fixture scenarios and automated acceptance |

Visual reference: [receipt.html](../../drafts/receipts_and_reports_revamp/receipt.html) (density, hierarchy, dividers — not domain authority).

Historical draft superseded for D1/D2 implementation: [receipt-report-revamp-draft-spec.md](../../drafts/receipts_and_reports_revamp/receipt-report-revamp-draft-spec.md). Document families D3–D7 remain deferred companions in that draft until a later packet.

## Supersedes

- [receipt-presentation.md](../phase4-6-point-of-sale/phase6-pos-mvp/receipt-presentation.md) — layout, merchandise grammar, tax summary presentation, totals/tender chrome, one-line description clamp
- [phase10-gift-card-numbering.md](../phase10-stored-value/phase10-gift-card-numbering.md) §5 — printed voucher chrome only (protection and lifecycle unchanged)

## Does not reopen

- [ADR-006](../../adr/ADR-006-receipt-numbering.md) receipt identity
- [ADR-026](../../adr/ADR-026-gift-card-number-protection.md) credential delivery
- Print-is-not-posting, no receipts table, legal-name fail-closed, header/footer inheritance

## Deferred (later packet)

- D3 Gift-card cash-out receipt
- D4 Cash-custody slips
- D5 Session close tape restyle
- D6/D7 X/Z report visual revamp ([report-content-contract.md](../register-workspace-consolidation/report-content-contract.md) remains semantic authority)
