# Thermal visual system (D1 + D2)

Status: **Accepted**

Reference mockup: [receipt.html](../../drafts/receipts_and_reports_revamp/receipt.html)

Typography authority: [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md) (amended).

## Scope

Applies to:

- `.pos-receipt__print` (customer receipt)
- `.pos-gift-card-voucher` (credential voucher)

Does **not** apply to:

- `.pos-report-print` (X/Z/session reports — Inconsolata until later packet)
- `.pos-shift-end-tape`
- Register screen chrome (Warm Parchment / Source Sans 3)

## Typography

| Role | Face | Weight |
|---|---|---|
| Store name, total banner, savings box, section emphasis | Plus Jakarta Sans | 700–800 |
| Body, money, meta, tax rows | Noto Sans Mono | 400–700 |

CSS variables:

```text
--font-thermal-body: "Noto Sans Mono", "Cascadia Code", "Consolas", "SF Mono", "Segoe UI Mono", sans-serif
--font-thermal-display: "Plus Jakarta Sans", "Source Sans 3", system-ui, sans-serif
```

Load from Google Fonts in print-capable layouts only. Print waits for `document.fonts.ready`. Fallback stack prints when CDN is unavailable.

## Layout

- Primary target: 80 mm thermal roll
- Printable content width: ~72 mm (`@page` margin 4mm 3mm; body width 72mm in print)
- Screen preview: 80 mm paper simulation with shadow (Register print preview uses hidden print block)

## Primitives

Shared BEM-style classes under thermal scope:

| Primitive | Class | Use |
|---|---|---|
| Solid divider | `.pos-thermal__divider-solid` | After store header |
| Dashed divider | `.pos-thermal__divider-dashed` | Section breaks |
| Label/value row | `.pos-thermal__row` | Meta, totals, payments |
| Section title | `.pos-thermal__section-title` | Uppercase section headers |
| Item block | `.pos-thermal__item-block` | Merchandise / issuance line group |
| Item title | `.pos-thermal__item-title` | Primary description |
| Item meta | `.pos-thermal__item-meta` | SKU, discount detail, indented |
| Badge | `.pos-thermal__badge` | `[UNLINKED RETURN]` |
| Total banner | `.pos-thermal__total-banner` | TOTAL DUE / REFUND TOTAL |
| Savings box | `.pos-thermal__savings-box` | YOU SAVED |
| Barcode container | `.pos-thermal__barcode` | Code 128 + human reference |
| Status banner | `.pos-thermal__status` | REPRINT, POST-VOID, replacement |
| Store header | `.pos-thermal__store-name` | Legal name |
| Center | `.pos-thermal__center` | Header/footer centering |

## Print behavior

- Screen controls (`.pos-no-print`, `.pos-receipt__actions`) hidden in `@media print`
- Long content wraps; money column stays right-aligned with `font-variant-numeric: tabular-nums slashed-zero`
- Barcodes from approved Code 128 encoder (`Pos::Code128`)
- Black-and-white legible; meaning never depends on color
- Multiple voucher cards: page break between cards

## Voucher alignment

Voucher reuses store header, dividers, typography, and barcode container. Amount remains prominent (display face, larger size). Voucher is centered; receipt is left-aligned body with flex rows.

Recovery designation uses `.pos-thermal__status` centered above store block when `credential.recovery?`.
