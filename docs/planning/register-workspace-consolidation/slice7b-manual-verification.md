# Slice 7B — Manual verification evidence

Status: **Stub** — fill after 7B.1–7B.3 land on `register-workspace-consolidation`. Packet: [slice7b-stored-value-issuance-plan.md](slice7b-stored-value-issuance-plan.md). Issue [#94](https://github.com/BankEncore/ShelfSense-v1/issues/94).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; print not required for 7B.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Nested customer lookup | Customer-required SV/refund opens Lookup; attach enables continue | | |
| 2 | Dependent change/detach refuse | Change/detach refused while store/trade-credit tender or CSC refund depends on customer; same attach idempotent | | |
| 3 | Gift-card issuance alone | Mere txn-customer association does not block detach unless destination requires customer | | |
| 4 | Quick Customer identity | Create+attach with `customers.create`; no trade credit / balance / redeemable account provisioned | | |
| 5 | Eligibility after Quick Customer | Originating flow re-resolves accounts; explains when none eligible | | |
| 6 | Auto-cap payment | Requested > available → applied capped; prominent feedback; persist applied only | | |
| 7 | Over remaining due | Rejected (not capped above remainder) | | |
| 8 | Cap lease replay | Lost-response retry restores Cap Result (not “account already on transaction”) | | |
| 9 | SV remove (O16) | Confirm; tender gone; no ledger-restore claim; lease replay safe | | |
| 10 | SV replace (O15) | Cap rules; same-account replace excludes original; failure keeps original | | |
| 11 | Return to Sale with SV | O17 clears ordinary + SV atomically | | |
| 12 | Issuance edit no tenders | Mutates issuance directly | | |
| 13 | Issuance edit with tenders | O17-class confirm; validate before clear; atomic clear+mutate or nothing | | |
| 14 | Masked card data | Audit/facts/envelopes never contain full pending gift-card number | | |
| 15 | Completion Failed recovery | Balance/account/capacity failure keeps tenders; Tender Review; affected tender selected when known; no auto-clear | | |
| 16 | Nested post rollback | Mid-completion failure + retry → one posted op per final tender/issuance | | |
| 17 | No new global shortcuts | Buttons / Tab / Enter / semantic events only; F2 remains Card | | |

## Sign-off

- Date:
- Browser / OS:
- Verified by:
- Follow-ups (if any): Slice 7C ([#95](https://github.com/BankEncore/ShelfSense-v1/issues/95))
