# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

A Lane cell holding a list (`a, b`) instead of the single lane id §4.2
requires. This row is neither a valid Interfaces row nor a valid Reservations
row (the Lane cell contains whitespace), so it must not vanish without a word.
This must be W5, not clean.

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
| Ports | a, b | 8080 |
