# Register workspace consolidation — Test matrix

Status: **Slice 1.** Classification of tests that exist on `main` before presentation replacement. Gap characterization tests live in [test/integration/pos_home_test.rb](../../../test/integration/pos_home_test.rb).

## Policy

When a slice replaces a user-facing contract, replace obsolete tests in the **same PR**. Preserve tests of domain truth. Do not preserve tests whose only purpose is removed markup, routes, labels, or keyboard behavior.

Never weaken: financial calculations, session/period transitions, Register custody, stored-value balance protection, cash effects, authorization, idempotency, concurrency, receipt/voucher facts, cross-store scoping.

F10 working-basket preservation is already covered in [test/system/pos_register_workspace_test.rb](../../../test/system/pos_register_workspace_test.rb). Do not duplicate that suite here.

## Classification

| Test file | Classification | Treatment |
|---|---|---|
| `test/services/pos/enter_register_test.rb` | Domain / request still required | Preserve |
| `test/services/pos/enter_register_legal_name_test.rb` | Domain | Preserve |
| `test/services/pos/workspace_invariants_test.rb` | Domain | Preserve |
| `test/services/pos/working_commands_test.rb` | Domain | Preserve |
| `test/services/pos/complete_transaction_test.rb` | Domain | Preserve |
| `test/services/pos/concurrency_test.rb` | Domain | Preserve |
| `test/services/pos/operation_lease_test.rb` | Domain | Preserve |
| `test/services/pos/tender_breadth_test.rb` | Domain | Preserve |
| `test/services/pos/merchandise_breadth_test.rb` | Domain | Preserve |
| `test/services/pos/controlled_actions_test.rb` | Domain | Preserve |
| `test/services/pos/returns_linked_test.rb` | Domain | Preserve |
| `test/services/pos/returns_mixed_test.rb` | Domain | Preserve |
| `test/services/pos/execute_unlinked_return_test.rb` | Domain | Preserve |
| `test/services/pos/lookup_linked_return_test.rb` | Domain | Preserve |
| `test/services/pos/unlinked_return_completion_test.rb` | Domain | Preserve |
| `test/services/pos/post_void_transaction_test.rb` | Domain | Preserve |
| `test/services/pos/stored_value_completion_test.rb` | Domain | Preserve |
| `test/services/pos/attach_customer_test.rb` | Domain | Preserve |
| `test/services/pos/allocation_pickup_test.rb` | Domain | Preserve |
| `test/services/pos/search_merchandise_test.rb` | Domain | Preserve |
| `test/services/pos/resolve_and_open_price_test.rb` | Domain | Preserve |
| `test/services/pos/session_totals.rb` coverage via `session_totals` callers | Domain | Preserve |
| `test/services/pos/completed_transaction_search_test.rb` | Domain | Preserve |
| `test/services/pos/receipt_identity_test.rb` | Domain | Preserve |
| `test/services/pos/customer_receipt_test.rb` | Domain | Preserve |
| `test/services/pos/golden_fixtures_test.rb` | Domain | Preserve |
| `test/services/pos/cash_accountability_test.rb` | Domain | Preserve |
| `test/services/cash/*` | Domain | Preserve |
| `test/services/gift_cards/cash_out_test.rb` | Domain | Preserve |
| `test/services/gift_cards/*` inquiry/admin | Domain; prefix/last-four vs possession | Preserve; POS S14 in 6A.2 |
| `test/models/pos_schema_test.rb` | Domain | Preserve |
| `test/integration/pos_register_test.rb` | Request still required (enter, occupied, resume) | Preserve; retarget paths if `/pos` semantics change |
| `test/integration/pos_home_test.rb` | Mixed: GET immutability / auth (keep); `h1` POS Home and Home link lists (replace Slice 2); workspace “POS Home” chrome (replace Slice 2–3); F10 not covered here | Replace Home-specific assertions in Slice 2 |
| `test/integration/pos_transaction_history_test.rb` | Request still required; shell wrap + return ownership | Slice 6A.1 |
| `test/services/pos/register_shell_context_test.rb` | Return paths / inquiry menu surface / expected-cash flag | Slice 6A.1 |
| `test/integration/pos_stored_value_inquiry_test.rb` | S14 three POST paths; no GET number leakage; admin isolation | Slice 6A.2 |
| `test/integration/pos_customer_service_surfaces_test.rb` | S15/S16 read-only shell surfaces | Slice 6A.3 |
| `test/services/pos/register_menu_test.rb` | Menu capability keys; inquiry suppresses proxies; 6A customer-service items | Slice 3 / 6A |
| `test/integration/pos_return_items_test.rb` | Request still required | Preserve |
| `test/integration/pos_post_void_workspace_test.rb` | Request still required | Preserve |
| `test/integration/pos_*_return_workspace_test.rb` | Request still required | Preserve |
| `test/integration/pos_customer_attach_test.rb` | Request still required | Preserve |
| `test/integration/pos_cash_activities_test.rb` | Request still required; reverse retargeted in 6B.3 | Preserve; shell wrap 6B.2; nested reversal 6B.3 |
| `test/integration/pos_till_session_surfaces_test.rb` | S17/S18/S19 shell; session selection; expected-cash; GET immutability | Slice 6B.1 |
| `test/services/pos/till_activity_test.rb` | S17 custody projection (CashOperation + GiftCardCashOut) | Slice 6B.1 |
| `test/services/pos/inquiry_session_resolver_test.rb` | Session selection table + ID validation | Slice 6B.1 |
| `test/integration/pos_cash_operation_detail_test.rb` | S23 detail; nested reverse; generic launcher gone | Slice 6B.3 |
| `test/integration/pos_close_z_test.rb` | Request still required | Preserve |
| `test/integration/pos_mvp_closeout_test.rb` | Request still required | Preserve |
| `test/integration/pos_gift_card_voucher_test.rb` | Domain/print | Preserve |
| `test/helpers/pos_helper_test.rb` | Shared receipt/history helpers | Keep; workspace chrome moved to presenter |
| `test/services/pos/workspace_presenter_test.rb` | Summary formula, tax groups, settlement DTOs, mismatch fallback, non-summary chrome | Slice 4 |
| `test/integration/pos_register_test.rb` | `#pos_tenders` sibling of `#pos_totals`; Merchandise / no Sales | Slice 4 DOM |
| Financial/domain POS suites | Signing / settlement unchanged under provisional tax persistence | Slice 4 regression |
| `test/system/pos_register_workspace_test.rb` | Keyboard, F10→menu, overlays, scan; Slice 5A lookup stack/inert/async/pointer/open-price; Slice 5B return Escape ladder / chooser stack / linked add; Slice 5C O9/O18 nesting, cancel consequence, invocation isolation; Slice 5D O11 `+`/F4–F5 selection + restore, O10 issuance Add | Slice 5A–5D |
| Slice 5A cases in workspace system suite | Root/nested inert; Escape restores parent stage; pointer Choose Product / Attach Customer / Add Pickup; Escape-during-fetch ignores late response; zero open-price select-all | [#86](https://github.com/BankEncore/ShelfSense-v1/issues/86) |
| Slice 5B return overlay cases | Chooser parent stack; linked Escape ladder; Escape during lines fetch ignores late response; prohibited unlinked disabled in chooser; linked add clears ancestry; unlinked failure preserves fields/clears password; nested picker Cancel aborts; unlinked variant Back to Item Lookup | [#87](https://github.com/BankEncore/ShelfSense-v1/issues/87) |
| Slice 5C controlled-action / confirmation cases | O9 action titles; direct-policy Apply; O18 nest Escape restores parent; auth failure typed feedback; cross-parent O18 isolation; cancel presenter consequence | [#88](https://github.com/BankEncore/ShelfSense-v1/issues/88) |
| Slice 5D tender selection / issuance cases | `+` tenderability preconditions; O11 Choose Tender vs Escape restore; F1 direct; F4/F5 many→O11; split-tender survival; O10 validation persist + activation; O10 open scan populates card; O10 reload card requirement; O10 field order / Enter submit; numbered O11 rows | [#89](https://github.com/BankEncore/ShelfSense-v1/issues/89) / remediation |
| `test/system/pos_register_shell_test.rb` | Shell zoom, F10 lifecycle on all compositions | Slice 3 |
| `test/system/pos_linked_return_test.rb` | F10 menu then Transactions & Receipts | Slice 3 |
| `test/system/pos_mixed_return_test.rb` | F10 menu then Transactions & Receipts; Escape restores chooser then command | Slice 3 / 5B |
| `test/services/pos/register_menu_test.rb` | Menu capability keys | Slice 3 |
| `test/system/pos_unlinked_return_test.rb` | Unlinked chrome, nested picker; Slice 5C O18 authorization failure while parents inert | [#87](https://github.com/BankEncore/ShelfSense-v1/issues/87) / [#88](https://github.com/BankEncore/ShelfSense-v1/issues/88) |
| `test/services/pos/overlay_failure_test.rb` | Typed OverlayFailure vocabulary | [#88](https://github.com/BankEncore/ShelfSense-v1/issues/88) |
| `test/system/pos_close_z_test.rb` | Interaction | Preserve |

## Gap characterization (this slice)

Added to `PosHomeTest`:

1. **GET `/pos` does not mutate** period, session, cash location/operation/entry, or transaction **counts or selected lock/state attributes**, including when a session already exists.
2. **Multiple unbound owned sessions:** Slice 2 inverts the Home defect. `GET /pos` renders the selector with **Your session** / **Resume** on every owned Register, even when a preferred Register exists.

## Slice 2 resolver tests (not in Slice 1)

Unit-test `RegisterStateResolver` with explicit arguments. Do not implement the resolver in Slice 1.
