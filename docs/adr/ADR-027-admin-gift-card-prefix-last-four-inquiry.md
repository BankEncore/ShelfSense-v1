# ADR-027: Admin gift-card inquiry by prefix and last four

- **Status:** Accepted
- **Date:** 2026-08-26
- **Accepted:** 2026-08-26

## Context

[ADR-026](ADR-026-gift-card-number-protection.md) §3 requires gift-card lookup to be exact-match on the HMAC digest: no prefix search, autocomplete, or unmasked lists. That rule is the correct possession test for redemption, reload, cash-out, and original-card refund.

Staff who already have `gift_cards.view` often have only the printed prefix and last four from a receipt, envelope, or card face. Those snapshots are stored on `gift_cards` for ordinary display, but there is no authorized query path. Using prefix + last four as a **redemption** path would weaken bearer-credential protection. Using it only as an **administrative history inquiry** does not prove possession and must not feed Register scan routing.

## Decision

1. **Operational use stays exact digest.** POS `GiftCards::Lookup.by_number`, Register scan routing, redeem, reload, cash-out, and original-card refund possession continue to resolve only by HMAC digest of the normalized full number. Prefix + last four is not proof of possession. Do not add `gift_cards.reveal_number`.

2. **Admin/management inquiry may resolve by `number_prefix` + `number_last_four`.** This is a history/find path for staff with `gift_cards.view`. The inquiry form accepts an exact number **or** prefix + last four. The exact-number path remains digest lookup (`GiftCards::Resolver`).

3. **Match handling:**
   - **Unique match:** open the card show (masked).
   - **Two or more matches:** show a short **masked** candidate list (status, program, balance, activated-at) and let staff pick. Do not show full numbers.
   - **Zero matches:** generic failure, same wording as digest miss. Do not distinguish missing vs ineligible.

4. **Abuse controls match ADR-026.** Failed inquiries are throttled and audited without recording submitted digits. Successful and ambiguous inquiries audit card IDs and last four only. Lists, URLs, and flash never contain the full number.

5. **Index.** A non-unique composite index on `gift_cards (number_prefix, number_last_four)` supports the inquiry. Collisions are expected and are a product path, not a uniqueness violation.

ADR-026 §3 is refined: exact digest for operational use; admin history may use prefix + last four.

## Consequences

- Register and POS completion code must not call the prefix + last-four inquiry service.
- Candidate lists are a disclosure of which cards share a face fragment; they remain masked and are not a reveal channel.
- Print, recover-print, and replacement credential vouchers are unchanged by this decision ([ADR-026](ADR-026-gift-card-number-protection.md) §4–5).

## Related documentation

- [ADR-026](ADR-026-gift-card-number-protection.md)
- [Phase 10 gift-card numbering](../planning/phase10-stored-value/phase10-gift-card-numbering.md)
- [Phase 10 authorization](../planning/phase10-stored-value/phase10-authorization.md)
