# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

A Reservations table with a fourth `Notes` column — not the fixed §4.2 shape.
Both rows genuinely collide on port 8080, but a 4-cell row is neither a valid
5-cell Interfaces row nor a valid 3-cell Reservations row, so it must not pass
silently: the dropped row is the payload E5 exists to catch. This must be W5,
not clean.

## 1. Tracking contract
Single-writer per artifact.

## 2. Status board

| Unit | Lane | Owns (file footprint) | Branch | Status | PR | Blocker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | a | `src/api/**` | eng-demo-a | in-progress | — | — | — |
| W2 | b | `src/reports/**` | eng-demo-b | not-started | — | — | — |

## 3. Contract register

| Kind | Lane | Reserved | Notes |
| --- | --- | --- | --- |
| Ports | a | 8080 | dev server |
| Ports | b | 8080 | dev server |
