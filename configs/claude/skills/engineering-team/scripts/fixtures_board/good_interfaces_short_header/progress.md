# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

The Interfaces table header written with only three columns
(`| ID | Producer | Consumer |`) instead of the full five, and no rows under
it. It must not be misread as a Reservations row (Kind=ID, Lane=Producer,
Reserved=Consumer) — that used to yield a spurious
`W5 reservation ID/Producer: lane is not on the board`. This must be clean.

## 1. Tracking contract
Single-writer per artifact.

## 2. Status board

| Unit | Lane | Owns (file footprint) | Branch | Status | PR | Blocker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | a | `src/api/**` | eng-demo-a | in-progress | — | — | — |
| W2 | b | `src/reports/**` | eng-demo-b | not-started | — | — | — |

## 3. Contract register

| ID | Producer | Consumer |
| --- | --- | --- |

| Kind | Lane | Reserved |
| --- | --- | --- |
| Ports | a | 8080 |
| Ports | b | 8081 |
