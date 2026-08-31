# Register surface polish — User stories

GitHub issues should usually be one focused PR per slice.

## Slice S1 — Packet lock

**Outcome:** Proposed packet reviewed and accepted; roadmap points here; allowlist frozen.

**Acceptance:**

- [x] `docs/planning/register-surface-polish/` README and companions exist
- [x] Roadmap cross-phase section references this program as Proposed/Accepted
- [x] Deferred surfaces (transaction review, blur overlays, aux-bar ownership) documented
- [x] ADR-022 already authorizes local packaging + optional Register adoption (no further ADR required unless scope expands)

## Slice S2 — Local font packaging

**Outcome:** Noto Sans Mono and Plus Jakarta Sans ship from `app/assets/fonts/`; thermal CDN loaders removed; print remains font-ready.

**Acceptance:**

- [x] Latin subset `.woff2` files + OFL (or equivalent) license texts committed
- [x] `@font-face` rules in `application.css` for weights actually used
- [x] `_thermal_fonts.html.erb` no longer loads `fonts.googleapis.com` / `fonts.gstatic.com`
- [x] `pos_receipt_controller.js` preloads local face names
- [x] Integration assertions prefer local faces / refute Google Fonts CDN
- [x] D1/D2 print still waits for `document.fonts.ready` when supported
- [x] Admin/ops remain on Source Sans 3 / Source Serif 4
- [x] Report/tape remain Inconsolata

## Slice S3 — Active workspace visual polish

**Outcome:** Header, command, basket, summary rail, and action keypad approach `active_transaction.html` without contract changes.

**Acceptance:**

- [x] Carded regions / spacing / selection accent aligned to visual system
- [x] Balance-due / settlement emphasis clearer without new totals math
- [x] Shortcut groups remain visually grouped; button labels and Stimulus targets unchanged
- [x] Optional Register adoption of Plus Jakarta Sans / Noto Sans Mono documented in PR
- [x] Frozen ids/targets preserved
- [ ] System suites listed in test-matrix green
- [ ] Manual 1280×720 and 200% zoom: no unreachable Open/Sale/Tender controls

## Slice S4 — Menu, overlay chrome, optional history skin

**Outcome:** F10 menu and overlay panels match draft panel chrome; optional history filter/table skin; packet closeout.

**Acceptance:**

- [x] `#register-menu` panel restyled; proxy items, leave-confirm, shell targets preserved
- [x] Overlay panels elevated; **no** workspace blur / pointer-events disable
- [x] Optional: `.pos-history` filters/table skin without query or link changes
- [x] README / implementation-plan status updated
- [ ] Frozen suites green; manual F10 + overlay smoke recorded
