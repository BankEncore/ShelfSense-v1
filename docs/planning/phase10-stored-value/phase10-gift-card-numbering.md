# Phase 10 — Gift-card numbering and scan routing

Status: **Proposed**. Policy: [ADR-026](../../adr/ADR-026-gift-card-number-protection.md).

### Actually locked

```text
20-digit dedicated namespace; not identifier_registry
PPP + body + Luhn check digit
system_generated vs manual_external programs
exact digest lookup; throttle; generic failure
AR encryption + HMAC digest; prefix + last four display
generate at completion; no reservation table
ordinary reprint masked; reveal is elevated + audited without the number in the payload
scan: gift-card shape before merchandise lookup
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

1. Normalize scan.
2. If the value matches an active program’s prefix, length, and check digit, route to the current gift-card context (activate, reload, redeem, inquiry, cash-out, unused return)—not merchandise add.
3. Otherwise use existing merchandise lookup (GTIN / `222` / unit / variant / lookup code).

Program save must reject a prefix+length that is ambiguous with another scanned-identifier namespace. Merchandise **lookup codes** must be rejected (or warned and blocked) when they match an active gift-card shape.

Unknown numbers cannot be redeemed, reloaded, inquired, replaced, or cashed out. They may enter only through permitted activation (manual/external program).

## 3. Storage

| Persist | Do not persist / leak |
|---|---|
| HMAC digest (keyed, unique) | Plaintext in logs, URLs, audit JSON, outbox, envelope |
| Encrypted ciphertext (Rails `encrypts`, non-deterministic) | Unmasked lists or autocomplete |
| Prefix, last four | Fixtures with production keys or plaintext production-like numbers |
| `encryption_key_id` / previous keys as Rails provides | Ciphertext in exception messages |

Lookup: compute digest of normalized input; equality on `number_digest`. Keys from credentials/ENV. Docker/CI uses a documented test key.

## 4. Generation timing

System-generated: create the number inside authoritative POS completion after uniqueness claim. Working state stores only `gift_card_program_id`. Abandoned baskets leave no card, account, or liability.

Manual/external: number comes from the card at activation; uniqueness at complete.

If the number must be printed **before** payment, that is out of Phase 10 (would require a reservation table).

## 5. Print and reveal

| Channel | Full number |
|---|---|
| Controlled first print after successful activation complete (and complete-retry of that command) | Yes, decrypt to the print surface only |
| Ordinary receipt reprint / history / envelope | Masked (prefix + last four) |
| `gift_cards.reveal_number` exception | Yes; reason required; audit outcome + last four only |
| Replacement workflow | New number; old number remains stored encrypted, not printed |

Print failure after commit does not reopen the transaction ([receipt-presentation.md](../phase4-6-point-of-sale/phase6-pos-mvp/receipt-presentation.md)). Recovery is reprint-via-reveal, replacement of an unused card, or unused-instrument return—not a second unauthenticated print.

## 6. Inquiry and abuse

Exact match only. Generic failure (do not distinguish missing vs suspended unless the operator already has `gift_cards.view` and a successful digest hit). Throttle and audit repeated failures **without** storing the submitted number.

No PIN in Phase 10.

## 7. Future offline pools

Conceptual only: server-allocated identity pools to a Terminal; allocation is not a card or liability. Requires a later ADR-005 decision. Not Phase 10 schema.
