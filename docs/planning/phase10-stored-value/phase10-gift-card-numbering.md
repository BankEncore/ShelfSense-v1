# Phase 10 — Gift-card numbering and scan routing

Status: **Proposed**. Policy: [ADR-026](../../adr/ADR-026-gift-card-number-protection.md), [ADR-027](../../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md).

### Actually locked

```text
20-digit dedicated namespace; not identifier_registry
PPP + body + Luhn check digit
system_generated vs manual_external programs
exact digest lookup for operational use; admin history may use prefix+last-four ([ADR-027](../../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md)); throttle; generic failure
GiftCard encrypts :number using default nondeterministic Active Record Encryption
PosStoredValueIssuance encrypts :pending_card_number
PosStoredValueTenderDetail encrypts :pending_card_number
HMAC digest remains the exact lookup and uniqueness key
generate at completion; no reservation table
ordinary reprint masked; dedicated credential voucher for first print and system-generated replacement; no general reveal permission
scan: gift-card shape before merchandise lookup (Register integration is 10.4; 10.3 uses the resolver for admin inquiry only)
```

## 1. Format

Normalized number is 20 digits:

```text
PPP RRRR RRRR RRRR RRRR C
```

- `PPP`: program prefix (unique, numeric)
- `R`: body (system: CSPRNG, never sequential; manual: from the physical card)
- `C`: Luhn check digit

Strip presentation separators before validation. Do not insert values into `identifier_registry`.

## 2. Scan routing (Register)

10.3 ships the validator/resolver and uses it for administrative inquiry. **Do not insert gift-card routing into the Register scan path until 10.4.** 10.4 wires sale, activation, reload, redemption, and refund. 10.5 wires cash-out.

1. Normalize scan.
2. If the value matches an active program’s prefix, length, and check digit, route to the current gift-card context (activate, reload, redeem, inquiry, cash-out, original-instrument refund)—not merchandise add.
3. Otherwise use existing merchandise lookup (GTIN / `222` / unit / variant / lookup code).

Program save must reject a prefix+length that is ambiguous with another scanned-identifier namespace. Merchandise **lookup codes** must be rejected (or warned and blocked) when they match an active gift-card shape.

Unknown numbers cannot be redeemed, reloaded, inquired, replaced, or cashed out. They may enter only through permitted activation or new-refund-card creation (manual/external program).

## 3. Storage

| Persist | Do not persist / leak |
|---|---|
| HMAC digest (keyed, unique) | Plaintext in logs, URLs, audit JSON, outbox, envelope |
| `number` via `encrypts :number` (nondeterministic) | Unmasked lists or autocomplete |
| Prefix, last four | Fixtures with production keys or plaintext production-like numbers |
| Pending working numbers via `encrypts :pending_card_number` | Ciphertext in exception messages; custom `encryption_key_id` columns |

Operational lookup: compute digest of normalized input; equality on `number_digest`. Repeated encrypted writes must not rely on ciphertext equality. Active Record Encryption keys use the standard Rails credentials/environment mechanism. HMAC secret is separate. Docker/CI uses documented test keys. Admin history inquiry may also match `number_prefix` + `number_last_four` ([ADR-027](../../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md)); that path is not used for POS redeem, reload, cash-out, or original-card refund.

Number identity on `gift_cards` is immutable after insert, including the encrypted `number` attribute. Normalized number, digest, prefix, and last four must agree.

## 4. Generation timing and pending identity

System-generated: create the number inside authoritative POS completion after uniqueness claim. Working activation stores only `gift_card_program_id` until complete. Abandoned baskets leave no card, account, or liability.

Manual activation and new refund-card working state persist **encrypted pending identity** on the issuance or tender detail without creating a gift-card row before completion. `gift_card_id` stays null while working.

If the number must be printed **before** payment, that is out of Phase 10 (would require a reservation table).

## 5. Print and recovery

The **credential voucher** is a distinct 80mm print from the customer receipt. Ordinary **Print receipt** (including history reprint) stays masked. Explicit **Print gift card** prints the decrypted number only when first-print delivery has not yet been recorded **and** the originating POS session is still open: undelivered completed POS activation or new refund card, or complete-retry of that outcome before delivery while the session remains open. After the session closes, recovery requires `gift_cards.recover_print` plus a reason. System-generated replacement of a card uses the replacement credential route only for a card that is the `replacement_gift_card` on a `GiftCardReplacement`. Reloads of an existing number do not first-print. Manual/external replacements that already have a physical number do not need generated-credential print.

On-screen completed-transaction copy may list undelivered credentials. The voucher HTML is **not** inside `.pos-receipt__screen` (print CSS hides that block). After delivery, **Print gift card** is gone; recover-print is the exceptional path. Responses that include a full number send `Cache-Control: no-store`.

Printed voucher order, centered on 80 mm:

```text
Store legal name
address and phone (omit blank lines)
Issued: {completed_at in the Store timezone, same format as receipts}
{amount}
Gift Card
[Code 128 of the normalized number]
PPP RRRR RRRR RRRR RRRR C
{system_settings.gift_card_voucher_footer, when present}
```

The human-readable number is the space-separated grouping from §1 (strip separators before lookup). Do not print a hyphenated form, per-digit spacing, program name, or issuance kind on the voucher. Barcode payload is the normalized digits. One slip per credential, with a page break between cards.

The voucher footer is organization configuration (`system_settings.gift_card_voucher_footer`): plain text, 500-character limit after trim. Blank omits the footer. The token `{organization legal name}` is replaced with `system_settings.legal_name` when that name is present. Store receipt header/footer messages are not used on this slip.

| Channel | Full number |
|---|---|
| Credential voucher (undelivered first print) | Yes |
| Idempotent retry of same completion before delivery, originating session still open | Yes |
| Ordinary Print receipt / later completed-transaction view / history / envelope | No |
| Controlled print-recovery service (`gift_cards.recover_print` + reason) | Only with reason and appropriate authority |
| System-generated replacement | Print new credential voucher once for the replacement card only; do not reveal old; do not use this route for ordinary POS cards |

First-print delivery is mutable processing state (`pos_gift_card_credential_deliveries`), not an edit of the completed POS fact. POS completions key delivery by transaction. System-generated replacements key delivery by the new gift card. `Pos::FirstPrint` decrypts only while the originating session is open and no delivery row exists; the first successful first-print call then records delivery. After session close, or after delivery, print recovery or another replacement is the path to a credential.

Print failure after commit does not reopen the transaction ([receipt-presentation.md](../phase4-6-point-of-sale/phase6-pos-mvp/receipt-presentation.md)). Recovery is the print-recovery service or replacement—not a general reveal screen and not unused-instrument return (deferred).

Audit records card identity by ID and last four only.

## 6. Inquiry and abuse

Operational lookup is exact digest only. Admin/management inquiry may use prefix + last four per [ADR-027](../../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md). Generic failure (do not distinguish missing vs suspended unless the operator already has `gift_cards.view` and a successful digest hit). Ambiguous prefix + last-four matches show a short masked candidate list. Throttle and audit repeated failures **without** storing the submitted number. Successful and ambiguous admin inquiries audit IDs and last four only.

No PIN in Phase 10.

## 7. Future offline pools

Conceptual only: server-allocated identity pools to a Terminal; allocation is not a card or liability. Requires a later ADR-005 decision. Not Phase 10 schema.
