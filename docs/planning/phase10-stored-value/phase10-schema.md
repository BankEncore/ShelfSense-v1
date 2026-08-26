# Phase 10 — Schema contract

Status: **Proposed**. PostgreSQL is authoritative. Do not edit `db/schema.rb` until migrations land. UUIDv7 via `create_uuid_table` / application-assigned ids ([AGENTS.md](../../../AGENTS.md) §10).

Companions: [phase10-plan.md](phase10-plan.md), [phase10-pos-issuance-and-tenders.md](phase10-pos-issuance-and-tenders.md), [phase10-gift-card-numbering.md](phase10-gift-card-numbering.md), [phase10-account-transfers-and-adjustments.md](phase10-account-transfers-and-adjustments.md).

## Naming

- User FKs: `performed_by_id`, `approved_by_id` (not `actor_id`).
- Compensating: `reversal_of_id` only; inverse association `reversed_by` ([ADR-011](../../adr/ADR-011-naming-conventions.md)).
- No polymorphic `source_type` / `source_id` on stored-value operations.
- Source rows hold `stored_value_operation_id`. Operations do **not** store inverse source FKs.

## 1. `stored_value_accounts`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `account_type` | string | `store_credit`, `trade_credit`, `gift_card` |
| `customer_id` | uuid, nullable | Required for store/trade credit; prohibited for gift_card |
| `currency_code` | char(3) | Snapshot of `system_settings.base_currency_code` at open; not caller-selectable |
| `balance_cents` | bigint | Default 0; nonnegative projection; never assigned via generic update |
| `status` | string | `active`, `suspended`, `closed` |
| `opened_at` | timestamptz | Required |
| `closed_at` | timestamptz, nullable | Required iff closed |
| `lock_version` | integer | Required; default 0 |
| timestamps | timestamptz | Required |

Checks:

- `balance_cents >= 0`
- `(account_type IN ('store_credit','trade_credit') AND customer_id IS NOT NULL) OR (account_type = 'gift_card' AND customer_id IS NULL)`
- `account_type` and `currency_code` immutable after insert
- Closed ⇒ `balance_cents = 0` and `closed_at` present

Indexes:

- Unique `(customer_id, account_type)` where `customer_id IS NOT NULL AND status <> 'closed'`
- FK `customer_id` → `customers`

Gift-card accounts are 1:1 with `gift_cards.stored_value_account_id`.

## 2. `stored_value_operations`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `operation_type` | string | `issue`, `activate`, `reload`, `redeem`, `refund`, `cash_out`, `transfer`, `adjust`, `reverse` |
| `store_id` | uuid | Required operational attribution |
| `business_date` | date | Required; store business date at occurrence — never reconstructed from `created_at` |
| `occurred_at` | timestamptz | Required |
| `performed_by_id` | uuid | Required user |
| `pos_session_id` | uuid, nullable | Register-session context when the action is Register-originated |
| `idempotency_operation_id` | uuid | FK to claimed `idempotency_operations` |
| `reversal_of_id` | uuid, nullable | Original operation; unique when present |
| `reason_code` | string, nullable | Required for policy-controlled actions |
| `reason_name_snapshot` | string, nullable | Historic label |
| `notes` | text, nullable | Controlled |
| timestamps | timestamptz | Required |

No `lock_version` (immutable after insert). No `register_id` on this table; cash-out Register identity lives on `gift_card_cash_outs`.

Do **not** persist `pos_tender_id`, `pos_stored_value_issuance_id`, `gift_card_cash_out_id`, `stored_value_adjustment_id`, `gift_card_replacement_id`, or `stored_value_transfer_id` on this table.

Inverse `has_one` from the operation to the unique source row. Exactly one source table references a given operation (application invariant + tests). Unique `reversal_of_id` where not null. Reversals use `operation_type = reverse`.

`refund` is used for refund to original gift card, refund to store credit, and refund to a new gift card. `issue` is non-refund value creation (manual accommodation or a later domain source such as buyback). Do not use “issue or refund” as alternatives for the same POS refund.

## 3. `stored_value_entries`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `stored_value_operation_id` | uuid | Required |
| `stored_value_account_id` | uuid | Required |
| `entry_sequence` | integer | ≥ 0; unique per operation |
| `amount_cents` | bigint | Signed, nonzero |
| `balance_after_cents` | bigint | ≥ 0 snapshot |
| `reversal_of_id` | uuid, nullable | Unique when present |
| `created_at` | timestamptz | Required |

Append-only. Transfer operations have at least two entries that net to zero. All accounts in one operation share `currency_code`.

## 4. `stored_value_adjustment_reasons`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `code` | string | Immutable machine code |
| `name` | string | Display |
| `description` | text, nullable | |
| `allowed_direction` | string | `credit`, `debit`, or `either` |
| `allowed_account_types` | string[] or equivalent | Subset of `store_credit`, `trade_credit`, `gift_card` |
| `notes_required` | boolean | |
| `approval_required` | boolean | Additional to the global debit/threshold rules |
| `active` | boolean | |
| `display_order` | integer | |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

Do not add `opening_balance` as an ordinary reason.

## 5. `stored_value_adjustments`

Posted manual credit or debit. Immutable after post.

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `stored_value_account_id` | uuid | Required |
| `adjustment_direction` | string | `credit` or `debit` |
| `amount_cents` | bigint | Positive magnitude |
| `reason_id` | uuid | FK → `stored_value_adjustment_reasons` |
| `reason_code` / `reason_name_snapshot` | string | Historic snapshots |
| `customer_explanation` | text, nullable | |
| `internal_notes` | text, nullable | Required when the reason says so |
| `store_id` | uuid | Required |
| `performed_by_id` | uuid | Required |
| `approved_by_id` | uuid, nullable | Required when second-user rule applies; ≠ `performed_by_id` |
| `stored_value_operation_id` | uuid, nullable | Unique when present; set at post |
| `idempotency_operation_id` | uuid | Required |
| `reversal_of_id` | uuid, nullable | Unique when present |
| `posted_at` | timestamptz | Required when posted |
| timestamps | timestamptz | Required |

Signed ledger entry = `+amount_cents` for credit, `-amount_cents` for debit. Gift-card eligibility: [phase10-account-transfers-and-adjustments.md](phase10-account-transfers-and-adjustments.md).

## 6. `stored_value_transfers`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `transfer_type` | string | `customer_merge`, `administrative`, `account_consolidation` |
| `from_account_id` | uuid | Source |
| `to_account_id` | uuid | Destination; ≠ source |
| `amount_cents` | bigint | > 0 |
| `source_customer_id` / `survivor_customer_id` | uuid, nullable | Merge snapshots when `customer_merge` |
| `reason_code` / `reason_name_snapshot` | string, nullable | Required for administrative/consolidation |
| `notes` | text, nullable | |
| `performed_by_id` | uuid | Required |
| `approved_by_id` | uuid, nullable | Required for administrative/consolidation; ≠ performer |
| `stored_value_operation_id` | uuid, nullable | Unique when present |
| `posted_at` | timestamptz | Required when posted |
| `reversal_of_id` | uuid, nullable | Unique when present |
| `merge_idempotency_operation_id` | uuid, nullable | Correlation with `Customers::MergeCustomers` |
| timestamps | timestamptz | Required |

Same account type and currency. Source has enough value. Entries net to zero. Merge and consolidation transfer the full remaining balance and close source. Ordinary partial administrative transfer leaves source active. Cross-type conversion prohibited.

Zero-balance merge: close source customer-owned accounts; do not create a survivor account for a zero balance; no transfer row when amount is 0.

| Source | Survivor | Behavior |
|---|---|---|
| No account | No account | Close nothing of stored value; nothing to transfer |
| Positive balance only on source | No survivor account | Create survivor account, transfer full amount, close source |
| Accounts on both | Existing survivor account | Transfer source balance into survivor, close source |
| Zero source balance | Any | Close source accounts; do not create a survivor account for zero |
| Concurrent redemption | Any | Lock and serialize; merge cannot rewrite ownership |

## 7. `gift_card_programs`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `code` | string | Immutable machine code |
| `name` | string | Display; may be renamed |
| `number_authority` | string | `system_generated` or `manual_external` |
| `prefix` | string | Unique normalized numeric prefix |
| `number_length` | integer | Total normalized length including check digit (Phase 10: 20) |
| `check_digit_algorithm` | string | `luhn` |
| `reload_allowed` | boolean | Required |
| `minimum_activation_cents` | bigint, nullable | |
| `maximum_balance_cents` | bigint, nullable | |
| `cash_out_policy` | string | `prohibited`, `permitted_when_eligible`, `required_on_request_when_eligible` |
| `cash_out_threshold_cents` | bigint, nullable | |
| `cash_out_threshold_inclusive` | boolean | |
| `cash_out_approval_required` | boolean | When true, cash-out needs second user |
| `active` | boolean | New activations allowed |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

Prefix uniqueness. Prefix, length, authority, and check-digit algorithm cannot change after any card has been activated under the program. Reject configuration that collides with merchandise identifier namespaces ([phase10-gift-card-numbering.md](phase10-gift-card-numbering.md)).

Seed at least one `system_generated` and one `manual_external` program with non-overlapping prefixes.

## 8. `gift_cards`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `gift_card_program_id` | uuid | Required |
| `stored_value_account_id` | uuid | Required; unique |
| `number` | text | Required; Rails Active Record Encryption ciphertext |
| `number_digest` | string | Required; unique keyed HMAC of the normalized number |
| `number_prefix` | string | Required; display/routing snapshot |
| `number_last_four` | string | Required; display snapshot |
| `status` | string | `active`, `suspended`, `replaced`, `closed` |
| `customer_id` | uuid, nullable | Optional association; not ownership |
| `activated_at` | timestamptz | Required after activation |
| `activated_store_id` | uuid | Required |
| `replaced_by_id` | uuid, nullable | Replacement instrument |
| `closed_at` | timestamptz, nullable | |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

```ruby
encrypts :number
```

Default nondeterministic Active Record Encryption. No caller-selected encryption scheme. No custom per-row key ID. HMAC secret is separate from Active Record Encryption keys. Number identity is immutable after insert.

Do not persist plaintext numbers in logs or public columns. Lifecycle starts at `active` when activation or refund-card creation completes. No preregistration table. No working-transaction reservation table in Phase 10.

## 9. `gift_card_cash_outs`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `gift_card_id` | uuid | Required |
| `stored_value_account_id` | uuid | Required |
| `amount_cents` | bigint | Full remaining eligible balance; > 0 |
| `register_id` | uuid | Required |
| `pos_session_id` | uuid | Required; open session at post |
| `store_id` | uuid | Required |
| `business_date` | date | Required |
| `program_policy_snapshot` | jsonb or typed columns | Policy facts used |
| `performed_by_id` | uuid | Required |
| `approved_by_id` | uuid, nullable | When `cash_out_approval_required` |
| `stored_value_operation_id` | uuid, nullable | Unique when present |
| `posted_at` | timestamptz | Required |
| timestamps | timestamptz | Required |

Not a generic paid-out. Not a POS tender.

## 10. `gift_card_replacements`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `original_gift_card_id` | uuid | Required |
| `replacement_gift_card_id` | uuid | Required; ≠ original |
| `amount_cents` | bigint | Remaining balance moved |
| `reason_code` / `reason_name_snapshot` | string | Required |
| `notes` | text, nullable | |
| `performed_by_id` | uuid | Required |
| `approved_by_id` | uuid, nullable | When policy requires; ≠ performer |
| `stored_value_operation_id` | uuid, nullable | Unique when present |
| `posted_at` | timestamptz | Required when posted |
| `reversal_of_id` | uuid, nullable | Unique when present |
| timestamps | timestamptz | Required |

Unique effective replacement per original instrument (partial unique on `original_gift_card_id` where posted and not reversed). Replacement transfers remaining balance and marks the original `replaced`. It is not a refund gift card.

## 11. POS extensions

### 11.1 `pos_transactions`

Add:

| Column | Type | Contract |
|---|---|---|
| `stored_value_issuance_cents` | bigint | Default 0; sum of activation/reload issuance amounts. Post-void reversals persist the negated contribution so signed-net stays one formula. |
| `customer_id` | uuid, nullable | FK → `customers`; optional until complete |

Replace check `pos_transactions_signed_net_matches_components`:

```text
signed_net_cents = subtotal_cents - discount_cents + tax_cents
                   + stored_value_issuance_cents
                   - return_total_cents
```

Keep `total_cents = abs(signed_net_cents)`.

`customer_id` required at completion when any store-credit or trade-credit tender is present, or when a refund destination is customer store credit. Gift-card-only payments do not require it. Customer must be canonical, satisfy active policy, and own the tendered customer account. Revalidate under lock.

Working mutations of issuances and SV tenders increment `lock_version`.

### 11.2 `pos_stored_value_issuances`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `pos_transaction_id` | uuid | Required |
| `issuance_number` | integer | Dense 1..N per transaction (like `line_number`) |
| `issuance_type` | string | `activation` or `reload` |
| `amount_cents` | bigint | > 0 |
| `gift_card_program_id` | uuid, nullable | Required for generate-at-complete activation |
| `gift_card_id` | uuid, nullable | Null while working for both generated and manual **activation**; required for reload (existing card) |
| `number_authority` | string | `system_generated` or `manual_external` |
| `pending_card_number` | text, nullable | Encrypted working identity for manual activation |
| `pending_card_number_digest` | string, nullable | Working uniqueness / complete claim |
| `pending_card_number_prefix` | string, nullable | |
| `pending_card_number_last_four` | string, nullable | |
| `stored_value_operation_id` | uuid, nullable | Unique when present; set at completion |
| `post_void_source_issuance_id` | uuid, nullable | Post-void generated row → source issuance |
| `masked_card_snapshot` | string, nullable | Prefix + last four after identity exists |
| timestamps | timestamptz | Required |

```ruby
encrypts :pending_card_number
```

For manual activation: `gift_card_id` remains null while working. Pending encrypted identity is persisted on the working issuance. Completion creates the final gift card atomically. Completed/public serialization never exposes the pending plaintext. No preregistered inactive gift card is created.

Not a `pos_transaction_lines` row. No `product_variant_id`. Amount is not taxable merchandise and is not a tender. Refund-to-new-gift-card is **not** an issuance row.

### 11.3 `tender_types`

Extend `TenderType::CATEGORIES` with `stored_value`.

Add `stored_value_account_type` (`store_credit` | `trade_credit` | `gift_card`), present **iff** `behavioral_category = stored_value`.

System-protected codes: `store_credit`, `trade_credit`, `gift_card` (in addition to `cash`, `card`, `check`). Admins may rename display labels and deactivate subject to policy; they must not change system identity or account type. Admin-created types remain `other`.

Update DB checks on `tender_types` and `pos_tenders` (category list, cash presented/change rules). `cashier_selectable` sort must give `stored_value` an explicit slot. `cashier_payload` includes `stored_value_account_type` and the refund flags below.

Existing `allows_refund` remains the Phase 6 flag for cash/card/check/other. It is **not** the stored-value destination oracle. Stored-value types use:

| Column | Meaning |
|---|---|
| `allows_original_tender_refund` | Return value to the same account/instrument |
| `allows_generic_refund_destination` | Accept leftover refund value not originally paid on this type |
| `allows_refund_instrument_replacement` | Create a new refund gift card for originally gift-card-funded value |

| Type | Original-tender refund | Generic destination | New refund instrument |
|---|---:|---:|---:|
| Store credit | Yes | Yes | No |
| Trade credit | Yes to original account | No | No |
| Gift card | Yes when presented/matched | No | Yes |

### 11.4 `pos_tenders`

Do **not** add `stored_value_operation_id` on `pos_tenders`. The stored-value operation FK belongs on `pos_stored_value_tender_details`. Multiple `stored_value` payment tenders allowed; existing at-most-one cash payment unchanged.

At most one payment tender per `(pos_transaction_id, stored_value_account_id)` when one combined amount would suffice.

### 11.5 `pos_stored_value_tender_details`

Exactly one detail row when the tender’s behavioral category is `stored_value`.

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `pos_tender_id` | uuid | Required; unique |
| `stored_value_operation_id` | uuid, nullable | Unique when present; set at completion. This is the source-row FK. |
| `stored_value_account_id` | uuid, nullable | Existing target; null for working `new_gift_card` |
| `gift_card_id` | uuid, nullable | When the target is a gift card |
| `destination_mode` | string | `existing_account`, `customer_store_credit`, `new_gift_card` |
| `gift_card_program_id` | uuid, nullable | For `new_gift_card` |
| `pending_card_number` | text, nullable | Encrypted working identity for new/manual refund card |
| `pending_card_number_digest` | string, nullable | |
| `pending_card_number_prefix` | string, nullable | |
| `pending_card_number_last_four` | string, nullable | |
| `masked_card_snapshot` | string, nullable | After identity exists |
| timestamps | timestamptz | Required |

```ruby
encrypts :pending_card_number
```

Rules:

- Payment tender requires an existing target account (`existing_account`).
- Original gift-card refund requires presented card matching the original tender account.
- New-gift-card refund has no account/card until completion.
- Store-credit refund requires transaction customer (`customer_store_credit` or store-credit `existing_account`).
- Trade credit as a **generic** refund destination is prohibited (original-tender refund to the original trade account remains allowed).
- Completed detail retains account/card and masked snapshots.
- New refund card does not increase `stored_value_issuance_cents`.

## 12. Outbox

Same database transaction as the business change ([ADR-010](../../adr/ADR-010-transactional-outbox.md)). Event types (versioned; minimum facts; no full number):

- `stored_value.issued`
- `stored_value.redeemed`
- `stored_value.refunded`
- `stored_value.transferred`
- `stored_value.adjusted`
- `stored_value.reversed`
- `stored_value.cash_out_completed`
- `gift_card.activated`
- `gift_card.replaced`

These are integration messages, not `financial_events` rows.

## 13. System settings

- Manual-adjustment approval threshold (organization): `system_settings.stored_value_adjust_credit_approval_threshold_cents` (default 5000). Credits at or above require second user; all debit adjustments require second user.
- Do not put gift-card cash-out threshold here (program-level).

## 14. Idempotency

Reuse `IdempotencyOperation`. POS complete remains `pos.complete_transaction` with `command_payload_hash` excluding generated secrets ([phase10-pos-issuance-and-tenders.md](phase10-pos-issuance-and-tenders.md)). Nested stored-value posts key by POS operation id plus issuance or tender id so complete-retry cannot double-post.

## 15. Merge consumers (Phase 8 checklist)

See [phase8-schema.md](../phase8-customer-foundation/phase8-schema.md). Phase 10 adds `Customers::MergeStoredValueAccounts`.
