# UDS-1 user stories

Status: **Proposed** (issue-ready backlog for [uds-1-plan.md](uds-1-plan.md))

Thin stories mapped to delivery sub-slices. Acceptance bullets are suitable for GitHub issues. Do not start coding until [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md) is Accepted and the [start gates](uds-1-plan.md#prerequisites-start-gates) are met.

---

## UDS-1a — Tokens and aliases

### US-UDS-1a-1 — Land Warm Parchment tokens with legacy aliases

As an implementer, I need Warm Parchment custom properties in `:root` with temporary Phase 2.2 aliases so existing screens inherit the new palette without markup rewrites.

**Acceptance**

- [x] `application.css` `:root` includes tokens from [warm-parchment.md](warm-parchment.md) (brand `#A84320`, semantic families, focus ring, dialog scrim).
- [x] Legacy `--color-*` aliases map only as documented in the [alias retirement register](migration-matrix.md#legacy-alias-retirement-register).
- [x] PR / stylesheet records prior Phase 2.2 values as `legacy-phase-2-2` for rollback.
- [x] No reference-view markup or print selector changes in this commit.
- [x] Token/alias change is a dedicated, revertible unit (isolated from ActionButtonHelper / view rewrites).

---

## UDS-1b — ActionButtonHelper and button CSS

### US-UDS-1b-1 — Ship ActionButtonHelper with unit coverage

As an implementer, I need a single helper API for action links, `button_to`, submits, and buttons so UDS-2 can adopt a style/intent allowlist without label-inferred danger.

**Acceptance**

- [x] `ActionButtonHelper` exposes `action_link_to`, `action_button_to`, `action_submit`, and `action_button`.
- [x] Classes emit exactly `btn btn--STYLE btn--INTENT btn--SIZE`; invalid pairs and class smuggling raise `ArgumentError`.
- [x] Helper never injects `confirm()` or opens review dialogs.
- [x] Disabled navigation renders non-focusable `span[aria-disabled=true]`.
- [x] `test/helpers/action_button_helper_test.rb` covers all four entry points, allowlist, CSRF/`button_to` structure, and Stimulus attribute pass-through.
- [x] Compatibility CSS covers bare `btn`, `btn--secondary`, style-less `btn--danger`, and incomplete `btn--ghost`.
- [x] Global `.btn, button, input[type="submit"]` primary-fill hazard is split (reset vs intent).
- [x] No broad admin/ops/POS template rewrites to the helper yet.

---

## UDS-1c — Shared primitives and dialogs

### US-UDS-1c-1 — Tokenize shared chrome without changing contracts

As an implementer, I need flashes, badges, forms, tables, empty states, technical details, pagination/filters, and review dialogs to use Warm Parchment surfaces so shells look consistent without changing Stimulus or authz.

**Acceptance**

- [ ] Allowlisted shared partials/primitives use Warm Parchment tokens (no new domain behavior).
- [ ] Review-dialog opaque surfaces, borders, severity fills, and scrim use tokens from the warm-parchment migration map.
- [ ] Dialog Stimulus focus restoration and existing dialog contracts are unchanged.
- [ ] Focus-visible uses `--color-focus-ring`.
- [ ] Density classes are contextual by screen type only (no user preference).
- [ ] Fonts: Source Sans 3 packaged or Plus Jakarta self-hosted (no CDN); receipt Inconsolata unchanged.
- [ ] `application` / `ops` layouts: token/chrome only; flat nav unchanged.

---

## UDS-1d — Docs and matrix exit

### US-UDS-1d-1 — Close docs and evidence for UDS-1 exit

As a reviewer, I need conventions and migration evidence updated so Phase 2.2 palette supersession is explicit and UDS-2 can start from a clear baseline.

**Acceptance**

- [ ] [ux-conventions.md](../../ux-conventions.md) palette section points to Warm Parchment and this packet.
- [ ] Migration-matrix rows for tokens/shared primitives are **partial** or **conforming** only with evidence columns filled.
- [ ] ADR-022 marked **Implemented** when UDS-1 merges.
- [ ] Packet README notes Phase 2.2 palette superseded for screen chrome.

---

## Cross-cutting review

### US-UDS-1-R1 — Confirm shells distinct and print frozen

As a reviewer, I need confidence that UDS-1 did not collapse shells or touch print.

**Acceptance**

- [ ] Admin, purchasing-ops, and Register remain distinct shells.
- [ ] Flat permission-gated admin nav unchanged (no grouped nav / sidebar / Cmd+K).
- [ ] Print preview smoke: receipt/report still matches locked print contract.
- [ ] Frozen suites from the [rollout contract](program-plan.md#implementation-rollout-contract) stay green without rewritten workflow assertions.
- [ ] Chromium baselines and indirect shared-CSS spot checks recorded per contract.
