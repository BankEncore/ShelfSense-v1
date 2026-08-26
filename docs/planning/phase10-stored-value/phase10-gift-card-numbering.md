# Phase 10 — Gift-card numbering and scan routing

Status: **Proposed**. Policy: [ADR-026](../../adr/ADR-026-gift-card-number-protection.md).

### Actually locked

```text
20-digit dedicated namespace; not identifier_registry
PPP + body + Luhn check digit
system_generated vs manual_external programs
exact digest lookup; throttle; generic failure
GiftCard encrypts :number using default nondeterministic Active Record Encryption
PosStoredValueIssuance encrypts :pending_card_number
PosStoredValueTenderDetail encrypts :pending_card_number
HMAC digest remains the exact lookup and uniqueness key
generate at completion; no reservation table
ordinary reprint masked; no general reveal permission
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

Lookup: compute digest of normalized input; equality on `number_digest`. Repeated encrypted writes must not rely on ciphertext equality. Active Record Encryption keys use the standard Rails credentials/environment mechanism. HMAC secret is separate. Docker/CI uses documented test keys.

Number identity on `gift_cards` is immutable after insert.

## 4. Generation timing and pending identity

System-generated: create the number inside authoritative POS completion after uniqueness claim. Working activation stores only `gift_card_program_id` until complete. Abandoned baskets leave no card, account, or liability.

Manual activation and new refund-card working state persist **encrypted pending identity** on the issuance or tender detail without creating a gift-card row before completion. `gift_card_id` stays null while working.

If the number must be printed **before** payment, that is out of Phase 10 (would require a reservation table).

## 5. Print and recovery

| Channel | Full number |
|---|---|
| Controlled first print | Yes |
| Idempotent retry of same completion | Yes |
| Ordinary reprint / history / envelope | No |
| Controlled print-recovery service | Only with reason and appropriate authority |
| Replacement | Print new credential; do not reveal old |

Print failure after commit does not reopen the transaction ([receipt-presentation.md](../phase4-6-point-of-sale/phase6-pos-mvp/receipt-presentation.md)). Recovery is the print-recovery service or replacement—not a general reveal screen and not unused-instrument return (deferred).

Audit records card identity by ID and last four only.

## 6. Inquiry and abuse

Exact match only. Generic failure (do not distinguish missing vs suspended unless the operator already has `gift_cards.view` and a successful digest hit). Throttle and audit repeated failures **without** storing the submitted number.

No PIN in Phase 10.

## 7. Future offline pools

Conceptual only: server-allocated identity pools to a Terminal; allocation is not a card or liability. Requires a later ADR-005 decision. Not Phase 10 schema.
