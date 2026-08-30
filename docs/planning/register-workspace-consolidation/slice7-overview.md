# Slice 7 — Overview

Status: **7.0 keyboard contract accepted** on `register-workspace-consolidation` ([#95](https://github.com/BankEncore/ShelfSense-v1/issues/95) / PR [#112](https://github.com/BankEncore/ShelfSense-v1/pull/112)). **Tender lifecycle inventory complete** ([slice7-tender-lifecycle-inventory.md](slice7-tender-lifecycle-inventory.md)). **Slice 7A packet Fully locked** ([slice7a-tender-review-plan.md](slice7a-tender-review-plan.md)); implementation next under [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93). Issues [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93)–[#95](https://github.com/BankEncore/ShelfSense-v1/issues/95).

Authority: [plan.md](plan.md) (esp. locked decision 13), [routing-and-authority.md](routing-and-authority.md), [slice5d-tender-issuance-plan.md](slice5d-tender-issuance-plan.md), [textual-wireframes.md](textual-wireframes.md) P10 / O11–O17, [slice7-keyboard-contract.md](slice7-keyboard-contract.md), [slice7-tender-lifecycle-inventory.md](slice7-tender-lifecycle-inventory.md), [slice7a-tender-review-plan.md](slice7a-tender-review-plan.md). Historical thinking: [slice-7-draft.md](../../drafts/phase-10-followup-pos-transaction-workspace/slice-7-draft.md) (superseded for implementation; do not implement from the draft).

## Boundary statement

> Slice 7 completes the active transaction interaction model. It introduces tender review, record-specific correction, stored-value capping and replacement, gift-card issuance replacement, Quick Customer as a child of the shared Register Customer Lookup family, and one authoritative keyboard dispatcher. It preserves the existing transaction, tender, stored-value, completion, authorization, and audit models unless a packet explicitly identifies a required service extension.

## Clarification of plan.md locked decision 13

Decision 13 requires Slice 7’s **first merge** to establish the replacement keyboard contract, then 7A → 7B → 7C.

**“First merge” means** accepting the SALE / TENDER / overlay tables, Escape and scanner contracts, Keyboard Lock ownership, semantic action vocabulary, and Phase 6.7 supersession map in [slice7-keyboard-contract.md](slice7-keyboard-contract.md).

**It does not mean** implementing the dispatcher or remapping live keys in that first merge. Dispatcher implementation and obsolete-handler deletion are **7C only**, after Tender Review, stored-value correction, and nested customer flows expose the final semantic actions the dispatcher must dispatch.

## Sequencing

```text
7.0 Keyboard contract amendment (docs-only)   ✓
  → Tender lifecycle inventory                 ✓
  → 7A Tender Review (ordinary tender correction)  packet locked; implement 7A.1–7A.3
  → 7B Stored value, issuance, and Quick Customer
  → 7C Dispatcher implementation and obsolete-handler deletion
```

| Step | Artifact | Issue |
|---|---|---|
| 7.0 | [slice7-keyboard-contract.md](slice7-keyboard-contract.md) | [#95](https://github.com/BankEncore/ShelfSense-v1/issues/95) (contract) |
| Inventory | [slice7-tender-lifecycle-inventory.md](slice7-tender-lifecycle-inventory.md) (**Complete**) | gates 7A/7B lock |
| 7A | [slice7a-tender-review-plan.md](slice7a-tender-review-plan.md) (**Fully locked**) | [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93) |
| 7B | `slice7b-stored-value-issuance-plan.md` | [#94](https://github.com/BankEncore/ShelfSense-v1/issues/94) |
| 7C | `slice7c-keyboard-dispatcher-plan.md` + implement contract | [#95](https://github.com/BankEncore/ShelfSense-v1/issues/95) |

## 7A / 7B keyboard law

7A and 7B may add:

- buttons and accessible controls
- controller actions
- semantic events required by their workflows

They must **not** add:

- temporary global shortcuts
- independent document-level key handlers that 7C would immediately replace

Until 7C ships the dispatcher, **runtime** key behavior remains Phase 6.7 as staged by [routing-and-authority.md](routing-and-authority.md) (including the Slice 5D `+` → O11 exception).

## Locked product defaults

| Decision | Lock |
|---|---|
| Keyboard first merge | Docs-only 7.0 ([slice7-keyboard-contract.md](slice7-keyboard-contract.md)) |
| Ordinary edit | Cash, check, and configured manual-reference tenders via atomic replace; externally authorized **card** = remove + re-authorize (no field edit of external auth) |
| Working tender persistence | **Audited destroy + add** under one txn lock ([slice7-tender-lifecycle-inventory.md](slice7-tender-lifecycle-inventory.md)); no supersession schema |
| Return to Sale | Atomic remove of all reversible working tenders, or change nothing; not Cancel Transaction |
| Confirmations | Destructive / reversal yes; ordinary field edits no |
| SV cap | Auto-apply with prominent feedback; requested amount is prompt / audit context only |
| Completed tenders | Immutable; correction via post-void / refund only |
| `+1`–`+9` sequences | **Omitted** from the accepted contract |
| Customer Lookup | Semantic action `open-customer-lookup` only; **no 7.0 key**; **F2 remains Card Tender** |
| Quick Customer | In scope for **7B.2**; extract `Customers::Create`; authorize Register with **`customers.create`** (add permission); admin create continues under `customers.manage`; idempotent create; must not invent a Register-only create path or repurpose F2 |
| Ambiguous external / activation outcome | Recovery surface; never ordinary retry |

## Speculative wireframe remap rejected

[textual-wireframes.md](textual-wireframes.md) P12 “TARGET CONCEPT” that reassigns `/` to Discount and `-` to Remove is **not** the accepted Slice 7 map. Accepted SALE keys preserve merchandise search (`/`), return chooser (`-`), and related composition-MVP meanings, with **mode-scoped** Remove on TENDER and on SALE for selected commercial lines via F8 / semantic remove — see [slice7-keyboard-contract.md](slice7-keyboard-contract.md).

## Explicit non-goals (Slice 7)

- Second customer-maintenance UI
- Merging gift-card issuances into merchandise lines
- Weakening completion, custody, authorization, or cross-store tests
- Runtime feature flags for old/new keyboard maps
- Implementing from the superseded draft after packets land
