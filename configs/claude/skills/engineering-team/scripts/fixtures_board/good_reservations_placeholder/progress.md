# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

Both lanes are on the board for one Kind (`coordination-protocol.md` §4.2
requires one row per lane per kind), but neither lane needs a feature flag.
Placeholder Reserved cells (an em dash here) mean "this lane reserves nothing
of this Kind" — not a token, not a collision. This must be clean.

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
| Feature flags | a | — |
| Feature flags | b | — |
