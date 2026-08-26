# ADR-026: Gift-card number protection

- **Status:** Accepted
- **Date:** 2026-08-25
- **Accepted:** 2026-08-25

## Context

A gift-card number is a bearer credential. Anyone who knows it can redeem the remaining balance online. Phase 10 generates numbers at successful POS completion for system-generated programs and accepts manual/external numbers at activation and new-refund-card creation.

[ADR-009](ADR-009-concurrency-and-idempotency.md) requires completion retries to return the stored outcome, including enough data for the controlled first print. Ordinary receipt reprints must not reproduce the full number. [AGENTS.md](../../AGENTS.md) and [ADR-008](ADR-008-audit-events.md) forbid placing secrets in audit payloads, logs, fixtures, and indiscriminate event dumps.

Digest-only storage cannot satisfy complete-retry print. Custom ciphertext envelopes and per-row key identifiers would invent key management ShelfSense does not operate.

## Decision

1. **ShelfSense stores the normalized gift-card number through Rails Active Record Encryption using nondeterministic encryption.** A separate keyed HMAC digest provides exact lookup and uniqueness. Prefix and last four digits are stored for ordinary display.
2. **Active Record Encryption keys are configured through the standard Rails credentials/environment mechanism.** ShelfSense does not implement custom ciphertext envelopes, IV handling, per-row key identifiers, or application-specific key-rotation metadata. Future rotation uses Rails-supported encryption schemes. HMAC secret is separate from Active Record Encryption keys. Do not commit production keys, plaintext numbers, or decryptable fixtures. Docker/CI test keys are documented and distinct from production.
3. **Lookup is exact-match on the digest.** No prefix search, autocomplete, or unmasked lists. Failed lookup uses a generic error. Repeated failures are throttled and audited without recording the submitted number.
4. **The completed POS envelope never contains the full number.** Command payload for system-generated cards expresses “generate a number from program X.” The envelope snapshots masked identity and Core foreign keys. Decrypt for the controlled activation/refund-card print channel and for idempotent complete-retry of that first print.
5. **Full-number decryption is limited to controlled first-print, idempotent completion retry, and narrowly authorized print-recovery or replacement services.** Phase 10 does not provide a general administrative reveal screen. Audit records card identity by ID and last four only.
6. **Outbox, URLs, logs, exceptions, screenshots, and support dumps never include the full number or ciphertext that tests could treat as a credential.** Tests use the documented test key and synthetic numbers.

Working manual activation and new refund cards may persist `pending_card_number` with `encrypts :pending_card_number` on the working POS row. No gift-card row exists until completion.

PIN/access codes remain out of Phase 10. Offline number pools remain a future ADR-005 design; they do not change this protection model.

## Consequences

- Gift-card rows carry `number` (`encrypts :number`), `number_digest`, `number_prefix`, and `number_last_four` as specified in [phase10-gift-card-numbering.md](../planning/phase10-stored-value/phase10-gift-card-numbering.md). There is no `number_ciphertext`, `encryption_key_id`, or `gift_cards.reveal_number` permission.
- First-print after commit and complete-retry can recover the number; abandoned working transactions never persist a gift-card liability.
- Lost physical cards are recovered through print-recovery or replacement, not a general reveal UI.
- CI and local Docker must configure Active Record encryption keys; document them in development guidance when implementation lands.

## Related documentation

- [Phase 10 gift-card numbering](../planning/phase10-stored-value/phase10-gift-card-numbering.md)
- [Phase 10 authorization](../planning/phase10-stored-value/phase10-authorization.md)
- [ADR-008](ADR-008-audit-events.md)
- [ADR-009](ADR-009-concurrency-and-idempotency.md)
- [ADR-020](ADR-020-pos-operation-envelope-and-core-facts.md)
