# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

Same date-prefix Kind as `good_reservations_backtick_escape`, but without the
backtick escape. Unescaped, `08-2026` and `09-2026` still parse per §4.2's
plain-hyphen range grammar — as (8, 2026) and (9, 2026) — and those intervals
do overlap. This is the documented, intended behaviour of the escape being
opt-in: an unescaped two-part numeric cell is a range. This must be E5.

## 1. Tracking contract
Single-writer per artifact.

## 2. Status board

| Unit | Lane | Owns (file footprint) | Branch | Status | PR | Blocker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | a | `src/api/**` | eng-demo-a | in-progress | — | — | — |
| W2 | b | `src/reports/**` | eng-demo-b | not-started | — | — | — |

## 3. Contract register

| Kind | Lane | Reserved |
| --- | --- | --- |
| Migration prefix | a | 08-2026 |
| Migration prefix | b | 09-2026 |
