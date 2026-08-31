# Slice 7B — Manual verification evidence

Status: **Complete** on `register-workspace-consolidation` ([#94](https://github.com/BankEncore/ShelfSense-v1/issues/94) / PRs [#118](https://github.com/BankEncore/ShelfSense-v1/pull/118)–[#121](https://github.com/BankEncore/ShelfSense-v1/pull/121); remediation on `94-slice7b-remediation`). Packet: [slice7b-stored-value-issuance-plan.md](slice7b-stored-value-issuance-plan.md).

Workstation assumptions: Chrome (or Chromium) on a Register-class display; print not required for 7B.

## Checklist

| # | Case | Pass criteria | Result | Notes |
|---|---|---|---|---|
| 1 | Nested customer lookup | Customer-required SV/refund opens Lookup; attach enables continue | pass | JS prompt + auto-open; service tests |
| 2 | Dependent change/detach refuse | Change/detach refused while store/trade-credit tender or CSC refund depends on customer; same attach idempotent | pass | `attach_customer_test` |
| 3 | Gift-card issuance alone | Mere txn-customer association does not block detach unless destination requires customer | pass | `attach_customer_test` |
| 4 | Quick Customer identity | Create+attach with `customers.create`; no trade credit / balance / redeemable account provisioned | pass | `create_test` + `pos_quick_customer_test` |
| 5 | Eligibility after Quick Customer | Originating flow re-resolves accounts; explains when none eligible | pass | integration feedback |
| 6 | Auto-cap payment | Requested > available → applied capped; prominent feedback; persist applied only | pass | `stored_value_correction_test` |
| 7 | Over remaining due | Rejected (not capped above remainder) | pass | service |
| 8 | Cap lease replay | Lost-response retry restores Cap Result (not “account already on transaction”) | pass | service |
| 9 | SV remove (O16) | Confirm; tender gone; no ledger-restore claim; lease replay safe | pass | service + overlay copy |
| 10 | SV replace (O15) | Cap rules; same-account replace excludes original; failure keeps original | pass | service |
| 11 | Return to Sale with SV | O17 clears ordinary + SV atomically | pass | tender_review_mutations + overlay |
| 12 | Issuance edit no tenders | Edit control; lease-backed replace; original replaced | pass | `ReplaceStoredValueIssuance` + Edit in sale/tender |
| 13 | Issuance edit with tenders | O17-class confirm; validate before clear; atomic clear+mutate or nothing; Edit/Remove reachable in Tender Review | pass | service + UI mutate in tender mode |
| 14 | Masked card data | Audit/facts/envelopes never contain full pending gift-card number | pass | lease payloads use digest/last four |
| 15 | Completion Failed recovery | Balance/account/capacity failure keeps tenders; Tender Review; affected tender selected when known; no auto-clear | pass | `StoredValueCompletionFailure` + correction tests |
| 16 | Nested post rollback | Mid-completion failure + retry → one posted op per final tender/issuance | pass | correction tests |
| 17 | No new global shortcuts | Buttons / Tab / Enter / semantic events only; F2 remains Card | pass | no new document-level key maps |
| 18 | Quick Customer Create Anyway | Duplicate probe then acknowledge with rotated key creates and attaches | pass | integration + JS key rotation |
| 19 | Contact rule server-derived | Forged `require_contact=0` cannot bypass store/trade-credit context | pass | request test |

## Sign-off

- Date: 2026-08-30
- Browser / OS: CI Chromium system tests + focused Docker suite; remediation covers issuance Edit + Quick Customer Create Anyway
- Verified by: automated 7B suite including replace-issuance and Quick Customer acknowledge/bypass tests
- Follow-ups (if any): Slice 7C ([#95](https://github.com/BankEncore/ShelfSense-v1/issues/95))
