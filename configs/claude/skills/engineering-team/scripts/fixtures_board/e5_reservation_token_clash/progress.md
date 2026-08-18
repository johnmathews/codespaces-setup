# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

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
| Feature flag prefix | a | `beta_` |
| Feature flag prefix | b | `beta_` |
