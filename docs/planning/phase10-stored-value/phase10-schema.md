# Phase 10 — Schema contract

Status: **Proposed**. PostgreSQL is authoritative. Do not edit `db/schema.rb` until migrations land. UUIDv7 via `create_uuid_table` / application-assigned ids ([AGENTS.md](../../../AGENTS.md) §10).

Companions: [phase10-plan.md](phase10-plan.md), [phase10-pos-issuance-and-tenders.md](phase10-pos-issuance-and-tenders.md), [phase10-gift-card-numbering.md](phase10-gift-card-numbering.md).

## Naming

- User FKs: `performed_by_id`, `approved_by_id` (not `actor_id`).
- Compensating: `reversal_of_id` only; inverse association `reversed_by` ([ADR-011](../../adr/ADR-011-naming-conventions.md)).
- No polymorphic `source_type` / `source_id` on stored-value operations.

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
| One source FK | uuid, nullable | See §2.1 |
| timestamps | timestamptz | Required |

No `lock_version` (immutable after insert). No `register_id` on this table; cash-out Register identity lives on `gift_card_cash_outs`.

### 2.1 One-source constraint

Exactly one of the following is non-null:

| Column | Use |
|---|---|
| `pos_tender_id` | Redeem or refund-to-credit (and original-tender stored-value refund) |
| `pos_stored_value_issuance_id` | Activate, reload, or unused-instrument reverse issuance |
| `gift_card_cash_out_id` | Cash-out |
| `stored_value_adjustment_id` | Manual adjust |
| `gift_card_replacement_id` | Replacement transfer |
| `stored_value_transfer_id` | Customer-merge transfer |

Check: count of non-null source FKs = 1. All are FKs with `ON DELETE RESTRICT`.

Do not also store `pos_transaction_id` as a peer source; reach the transaction through the tender or issuance.

Unique `reversal_of_id` where not null. Reversals use `operation_type = reverse` and point `reversal_of_id` at the original.

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

## 4. `stored_value_adjustments`

Posted manual credit or debit. Immutable after post.

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `stored_value_account_id` | uuid | Required |
| `amount_cents` | bigint | Signed, nonzero (command magnitude > 0 with explicit direction) |
| `reason_code` / `reason_name_snapshot` | string | Required |
| `notes` | text, nullable | Required when policy says so |
| `store_id` | uuid | Required |
| `performed_by_id` | uuid | Required |
| `approved_by_id` | uuid, nullable | Required when second-user rule applies; ≠ `performed_by_id` |
| `posted_at` | timestamptz | Required when posted |
| timestamps | timestamptz | Required |

## 5. `stored_value_transfers`

Merge (and only merge in Phase 10, besides gift-card replacement which uses `gift_card_replacements`).

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `from_account_id` | uuid | Source account (closed after transfer) |
| `to_account_id` | uuid | Survivor account (same `account_type`) |
| `amount_cents` | bigint | > 0; entire source balance |
| `source_customer_id` / `survivor_customer_id` | uuid | Merge pair snapshots |
| `merge_idempotency_operation_id` | uuid, nullable | Correlation with `Customers::MergeCustomers` |
| `performed_by_id` | uuid | Merge actor |
| timestamps | timestamptz | Required |

Zero source balance: close or retain per lifecycle policy in the merge command; no transfer operation if amount is 0.

| Source | Survivor | Behavior |
|---|---|---|
| No account | No account | Nothing |
| Balance/account only on source | No survivor account | Create/resolve survivor account, transfer, close source |
| Accounts on both | Existing survivor account | Transfer source balance into survivor, close source |
| Zero source balance | Any | Close or retain per lifecycle; no transfer operation |
| Concurrent redemption | Any | Lock and serialize; merge cannot rewrite ownership |

## 6. `gift_card_programs`

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
| `active` | boolean | New activations allowed |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

Prefix uniqueness. Prefix, length, authority, and check-digit algorithm cannot change after any card has been activated under the program. Reject configuration that collides with merchandise identifier namespaces ([phase10-gift-card-numbering.md](phase10-gift-card-numbering.md)).

Seed at least one `system_generated` and one `manual_external` program with non-overlapping prefixes.

## 7. `gift_cards`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `gift_card_program_id` | uuid | Required |
| `stored_value_account_id` | uuid | Required; unique |
| `number_digest` | string | Required; unique keyed HMAC of normalized number |
| `number_ciphertext` | text | Required; Active Record encryption (or equivalent ciphertext column) |
| `encryption_key_id` | string, nullable | Rotation metadata if not wholly owned by Rails encryption |
| `number_prefix` | string | Display/routing snapshot |
| `number_last_four` | string | Display snapshot |
| `status` | string | `active`, `suspended`, `replaced`, `closed` |
| `customer_id` | uuid, nullable | Optional association; not ownership |
| `activated_at` | timestamptz | Required after activation |
| `activated_store_id` | uuid | Required |
| `replaced_by_id` | uuid, nullable | Replacement instrument |
| `closed_at` | timestamptz, nullable | |
| `lock_version` | integer | Required |
| timestamps | timestamptz | Required |

Do not persist plaintext numbers. Lifecycle starts at `active` when activation completes. No preregistration table for manual numbers. No working-transaction reservation table in Phase 10 (generate at completion).

## 8. `gift_card_cash_outs`

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
| `approved_by_id` | uuid, nullable | When policy requires |
| `posted_at` | timestamptz | Required |
| timestamps | timestamptz | Required |

Not a generic paid-out. Not a POS tender.

## 9. `gift_card_replacements`

Original card, replacement card, reason, `performed_by_id`, `approved_by_id`, resulting transfer operation via `gift_card_replacement_id` on the operation.

## 10. POS extensions

### 10.1 `pos_transactions`

Add:

| Column | Type | Contract |
|---|---|---|
| `stored_value_issuance_cents` | bigint | Default 0; ≥ 0; sum of issuance amounts |
| `customer_id` | uuid, nullable | FK → `customers`; optional until complete |

Replace check `pos_transactions_signed_net_matches_components`:

```text
signed_net_cents = subtotal_cents - discount_cents + tax_cents
                   + stored_value_issuance_cents
                   - return_total_cents
```

Keep `total_cents = abs(signed_net_cents)`.

`customer_id` required at completion when any store-credit or trade-credit tender is present. Gift-card-only tenders do not require it. Customer must be canonical, satisfy active policy, and own the tendered account. Revalidate under lock.

Working mutations of issuances and SV tenders increment `lock_version`.

### 10.2 `pos_stored_value_issuances`

| Column | Type | Contract |
|---|---|---|
| `id` | uuid | UUIDv7 PK |
| `pos_transaction_id` | uuid | Required |
| `issuance_number` | integer | Dense 1..N per transaction (like `line_number`) |
| `issuance_type` | string | `activation`, `reload`, `unused_return` |
| `amount_cents` | bigint | > 0; unused_return amount is the reversed issuance magnitude |
| `gift_card_program_id` | uuid, nullable | Required for generate-at-complete activation |
| `gift_card_id` | uuid, nullable | Null on working generate-at-complete activation; required for reload, unused_return, and manual-number activation once identity is known |
| `number_authority` | string | `system_generated` or `manual_external` |
| `manual_number_digest` | string, nullable | Working-state uniqueness check for keyed manual numbers; not a liability |
| `stored_value_operation_id` | uuid, nullable | Set at completion |
| `post_void_source_issuance_id` | uuid, nullable | Post-void generated row → source issuance |
| `unused_return_of_issuance_id` | uuid, nullable | Unused-return row → original activation/reload issuance |
| `masked_card_snapshot` | string, nullable | Prefix + last four after identity exists |
| timestamps | timestamptz | Required |

Not a `pos_transaction_lines` row. No `product_variant_id`. Amount is not taxable merchandise and is not a tender.

### 10.3 `tender_types`

Extend `TenderType::CATEGORIES` with `stored_value`.

Add `stored_value_account_type` (`store_credit` | `trade_credit` | `gift_card`), present **iff** `behavioral_category = stored_value`.

System-protected codes: `store_credit`, `trade_credit`, `gift_card` (in addition to `cash`, `card`, `check`). Admins may rename display labels and deactivate subject to policy; they must not change system identity or account type. Admin-created types remain `other`.

Update DB checks on `tender_types` and `pos_tenders` (category list, cash presented/change rules). `cashier_selectable` sort must give `stored_value` an explicit slot. `cashier_payload` includes `stored_value_account_type`.

`allows_refund`: store and trade credit **true** (refund-to-credit). Gift-card tender **false** in Phase 10 (unused-card return is issuance reversal, not a gift-card refund tender).

### 10.4 `pos_tenders`

Add `stored_value_operation_id` (nullable FK, unique when present) for completed stored-value tenders. Multiple `stored_value` payment tenders allowed; existing at-most-one cash payment unchanged.

At most one tender per `(pos_transaction_id, stored_value_account_id)` when one combined amount would suffice (reject duplicate account rows).

Gift-card tenders snapshot masked identity, not the full number.

## 11. Outbox

Same database transaction as the business change ([ADR-010](../../adr/ADR-010-transactional-outbox.md)). Event types (versioned; minimum facts; no full number):

- `stored_value.issued`
- `stored_value.redeemed`
- `stored_value.refunded`
- `stored_value.transferred`
- `stored_value.reversed`
- `stored_value.cash_out_completed`
- `gift_card.activated`
- `gift_card.replaced`

These are integration messages, not `financial_events` rows.

## 12. System settings

- Manual-adjustment approval threshold (organization): credits at or above require second user; all debit adjustments require second user.
- Do not put gift-card cash-out threshold here (program-level).

## 13. Idempotency

Reuse `IdempotencyOperation`. POS complete remains `pos.complete_transaction` with `command_payload_hash` excluding generated secrets ([phase10-pos-issuance-and-tenders.md](phase10-pos-issuance-and-tenders.md)). Nested stored-value posts key by POS operation id plus issuance or tender id so complete-retry cannot double-post.

## 14. Merge consumers (Phase 8 checklist)

See [phase8-schema.md](../phase8-customer-foundation/phase8-schema.md). Phase 10 adds `Customers::MergeStoredValueAccounts`.
