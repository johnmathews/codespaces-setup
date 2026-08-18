# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

A real interface seam is declared but the plan has no U0 to land it, so every
lane codes against an assumed signature (`coordination-protocol.md` §4.4).
Reservations are present too and must not be what triggers this.

## 1. Tracking contract
Single-writer per artifact. Lanes record ticks in their own status file.

## 2. Status board

| Unit | Lane | Owns (file footprint) | Branch | Status | PR | Blocker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | a | `src/api/**` | eng-demo-a | in-progress | — | — | — |
| W2 | b | `src/reports/**` | eng-demo-b | not-started | — | — | — |

## 3. Contract register

**Interfaces**

| ID | Producer | Consumers | Contract | Frozen at |
| --- | --- | --- | --- | --- |
| C1 | a | b | `def resolve(id: str) -> Account \| None` in `src/api/types.py` | plan approval |

**Reservations**

| Kind | Example collision | Allocation |
| --- | --- | --- |
| Ports | two dev servers on 8080 | a: 8080, b: 8081 |

## 4. Proposals
none

## 5. Cross-session facts
none

## 6. Coordinator log
- 2026-08-18 board created
