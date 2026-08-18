# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

A migration-prefix Kind that happens to look like a two-part numeric range
(a month-year date prefix). Backticks force token interpretation
(`coordination-protocol.md` §4.2), so `` `08-2026` `` and `` `09-2026` `` are
two different opaque tokens, not the overlapping intervals (8, 2026) and
(9, 2026). This must be clean.

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
| Migration prefix | a | `08-2026` |
| Migration prefix | b | `09-2026` |
