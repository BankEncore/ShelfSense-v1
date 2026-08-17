# Phase 5 Slice 3 — Close / Z wireframes

**Status:** Low-fidelity frames for Slice 3 print, blind close, closed Session, and finalized Z. HTTP/domain contract stays in [close-z-screens.md](close-z-screens.md).

Do not reuse admin chrome. Money display uses `format_money_cents`; money entry uses decimal strings parsed by `Money::ParseCents`.

---

## Frame 1 — Completed receipt

On-screen confirmation. Printed header format is **not** required here.

```text
Store 1 · Register 2 · Cashier
Business date 2026-08-17

SALE COMPLETE
S001-R02-T0000123

Total             $41.99
Cash presented    $50.00
Change              $8.01

[ Print receipt ] [ New sale ] [ Close register ]
```

| Annotation | Meaning |
|---|---|
| Focused element | Heading / first action in tab order. Document Enter is a no-op |
| Next Enter | Nothing. Scanner must not print, start a new sale, or close |
| Visible equivalents | Print receipt, New sale, Close register |
| Print | `window.print()` only; `@media print` hides these actions and POS chrome |
| Printed identity | `Store: 001   Reg: 02   Trans: 0000123` from transaction snapshots |

---

## Frame 2 — Blind close

```text
Store 1 · Register 2
Business date 2026-08-17

CLOSE REGISTER

Count all Cash currently in the register.

Closing Cash count
[____________________]   [FOCUS]

[ Close session ]
[ Return to sales ]
```

No expected amount, variance, opening float, Cash sales, or tender/period totals may appear anywhere — including hidden fields and `data-*` attributes.

| Annotation | Meaning |
|---|---|
| Focused element | Closing Cash count |
| Next Enter | Submit count |
| Escape / Return to sales | `ResumeOrStartTransaction` → workspace `SALE_ENTRY` |
| Hidden fields | Session `lock_version` only |

---

## Frame 3 — Closed Session

```text
SESSION CLOSED

Transactions               14
Sales total            $241.99
Cash payments          $241.99

Opening float          $100.00
Expected Cash          $341.99
Counted Cash           $340.99
Variance                -$1.00

[ Finalize Z ]
[ Leave period open ]
```

Cash figures are persisted `closing_*` snapshots. Leave period open returns to the enter gate for this Register.

---

## Frame 4 — Finalized Z

```text
Z REPORT
Store 001 · Register 02
Business date 2026-08-17

Transactions               42
Subtotal             $1,125.00
Tax                     $72.44
Total                $1,197.44
Cash payments        $1,197.44

Sessions                   2
Opening floats total  $200.00
Expected closing Cash $1,397.44
Counted closing Cash  $1,395.44
Variance                -$2.00

Finalized 18:42
Finalized by Alex Rivera
```

Store and Register numbers are the period's identity, not editable names. Session-custody lines are sums of independent Session intervals, not one drawer. Values are persisted `finalized_*` fields. No `Z #123`.
