# Register workspace consolidation

Status: **Accepted packet** on `main` (Slice 1). Implementation slices 2–7 land on integration branch `register-workspace-consolidation` and merge to `main` only after closeout.

GitHub: [milestone](https://github.com/BankEncore/ShelfSense-v1/milestone/7); slice issues in [user-stories.md](user-stories.md).

**Program type:** Cross-phase Register UX (not a numbered domain phase). After Phases 10–11 capabilities; does not reopen those ledgers.

This program **replaces** the current POS presentation. It does not run a parallel POS Home, keep obsolete keyboard contracts after their owning slice, or add runtime compatibility flags. Domain services, persisted financial facts, authorization, and behavioral coverage remain.

| Document | Purpose |
|---|---|
| [plan.md](plan.md) | Goal, locked decisions, states, slices 1–7 |
| [implementation-plan.md](implementation-plan.md) | Merge policy, slice status, GitHub tracker |
| [routing-and-authority.md](routing-and-authority.md) | 6.7 supersession, resolver, Register Menu, routes, stored-value, expected cash |
| [test-matrix.md](test-matrix.md) | Classification of existing POS tests; gap tests |
| [user-stories.md](user-stories.md) | GitHub-issue-ready slice stories |
| [closeout-plan.md](closeout-plan.md) | End-to-end and manual evidence before `main` merge |
| [textual-wireframes.md](textual-wireframes.md) | Companion composition contracts (not 6.7 authority) |
| [slice4-composition-plan.md](slice4-composition-plan.md) | Locked Slice 4 presenter / summary / DOM contracts |
| [slice4-manual-verification.md](slice4-manual-verification.md) | Slice 4 workstation evidence |
| [slice5a-lookup-overlays-plan.md](slice5a-lookup-overlays-plan.md) | Locked Slice 5A overlay lifecycle / lookup contracts |
| [slice5a-manual-verification.md](slice5a-manual-verification.md) | Slice 5A workstation evidence |
| [slice5b-return-overlays-plan.md](slice5b-return-overlays-plan.md) | Locked Slice 5B return overlay contracts |
| [slice5b-manual-verification.md](slice5b-manual-verification.md) | Slice 5B workstation evidence |
| [slice5c-controlled-actions-plan.md](slice5c-controlled-actions-plan.md) | Locked Slice 5C controlled-action / confirmation contracts |
| [slice5c-manual-verification.md](slice5c-manual-verification.md) | Slice 5C workstation evidence |
| [slice5d-tender-issuance-plan.md](slice5d-tender-issuance-plan.md) | Locked Slice 5D tender selection / issuance Add contracts |
| [slice5d-manual-verification.md](slice5d-manual-verification.md) | Slice 5D workstation evidence |

UX adoption: follow [ux-adoption-template.md](../ux-design-system/ux-adoption-template.md) in the slice that materially changes a screen. Printed receipts stay locked unless a slice explicitly owns print.

Overlapping drafts are **superseded**. Do not implement from them:

- [shelvesense-register-workspace-project-brief.md](../../drafts/phase-10-followup-pos-transaction-workspace/shelvesense-register-workspace-project-brief.md)
- [pos-transaction-workspace.md](../../drafts/phase-10-followup-pos-transaction-workspace/pos-transaction-workspace.md)
- [phase-11-followup-register-ux-spec.md](../../drafts/phase-9-product/phase-11-followup-register-ux-spec.md)
