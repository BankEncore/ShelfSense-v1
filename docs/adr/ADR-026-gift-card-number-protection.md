# ADR-026: Gift-card number protection

- **Status:** Accepted
- **Date:** 2026-08-25
- **Accepted:** 2026-08-25

## Context

A gift-card number is a bearer credential. Anyone who knows it can redeem the remaining balance online. Phase 10 generates numbers at successful POS completion for system-generated programs and accepts manual/external numbers at activation.

[ADR-009](ADR-009-concurrency-and-idempotency.md) requires completion retries to return the stored outcome, including enough data for the controlled first print. Ordinary receipt reprints must not reproduce the full number. [AGENTS.md](../../AGENTS.md) and [ADR-008](ADR-008-audit-events.md) forbid placing secrets in audit payloads, logs, fixtures, and indiscriminate event dumps.

Digest-only storage cannot satisfy complete-retry print. Leaving encryption as an optional implementation detail postpones key management until the first printer failure.

## Decision

1. **The full normalized number is a secret.** ShelfSense stores it as non-deterministic Active Record encryption ciphertext plus a keyed HMAC digest for uniqueness and exact lookup. Display fields are prefix and last four only.
2. **Keys live outside the repository.** Encryption keys come from credentials or environment configuration (Docker/CI test keys are documented and distinct from production). Support `key_id` / previous-keys rotation. Do not commit production keys, plaintext numbers, or decryptable fixtures.
3. **Lookup is exact-match on the digest.** No prefix search, autocomplete, or unmasked lists. Failed lookup uses a generic error. Repeated failures are throttled and audited without recording the submitted number.
4. **The completed POS envelope never contains the full number.** Command payload for system-generated cards expresses “generate a number from program X.” The envelope snapshots masked identity and Core foreign keys. Decrypt for the controlled activation print channel and for idempotent complete-retry of that first print.
5. **Ordinary reprints stay masked.** Revealing or reprinting the full credential requires `gift_cards.reveal_number` (or the equivalent keyed in the Phase 10 authorization contract), a reason, and an audit event whose payload records outcome and last four—not the number.
6. **Outbox, URLs, logs, exceptions, screenshots, and support dumps never include the full number or ciphertext that tests could treat as a credential.** Tests use the documented test key and synthetic numbers.

PIN/access codes remain out of Phase 10. Offline number pools remain a future ADR-005 design; they do not change this protection model.

## Consequences

- Gift-card rows carry `number_digest`, encrypted `number_ciphertext` (or Rails `encrypts`), `number_prefix`, `number_last_four`, and encryption key metadata as specified in [phase10-gift-card-numbering.md](../planning/phase10-stored-value/phase10-gift-card-numbering.md).
- First-print after commit and complete-retry can recover the number; abandoned working transactions never persist a number or liability.
- Operators who lack reveal permission cannot recover a lost printed card except through the replacement workflow.
- CI and local Docker must configure Active Record encryption keys; document them in development guidance when implementation lands.

## Related documentation

- [Phase 10 gift-card numbering](../planning/phase10-stored-value/phase10-gift-card-numbering.md)
- [Phase 10 authorization](../planning/phase10-stored-value/phase10-authorization.md)
- [ADR-008](ADR-008-audit-events.md)
- [ADR-009](ADR-009-concurrency-and-idempotency.md)
- [ADR-020](ADR-020-pos-operation-envelope-and-core-facts.md)
