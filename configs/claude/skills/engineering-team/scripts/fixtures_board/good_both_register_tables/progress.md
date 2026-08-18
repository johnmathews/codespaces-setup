# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

Both register tables present. The interfaces table drives E4 (lanes must be on
the board) and E6 (a U0 is required); the reservations table beside it is
ignored — its `Config keys / env vars` row must not be read as contract "C…".

## 1. Tracking contract
Single-writer per artifact. Lanes record ticks in their own status file.

## 2. Status board

| Unit | Lane | Owns (file footprint) | Branch | Status | PR | Blocker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| U0 | a | `src/api/types.py` | eng-demo-a | merged | 1 | — | contract stubs |
| W1 | a | `src/api/**` | eng-demo-a | in-progress | — | — | — |
| W2 | b | `src/reports/**` | eng-demo-b | not-started | — | — | — |

## 3. Contract register

**Interfaces** — anything one lane produces and another consumes:

| ID | Producer | Consumers | Contract | Frozen at |
| --- | --- | --- | --- | --- |
| C1 | a | b | `def resolve(id: str) -> Account \| None` in `src/api/types.py` | plan approval |

**Reservations** — things that collide *without sharing a file*:

| Kind | Lane | Reserved |
| --- | --- | --- |
| Migration numbers | a | 0007-0009 |
| Migration numbers | b | 0010-0012 |
| Ports | a | 8080 |
| Ports | b | 8081 |

## 4. Proposals
none

## 5. Cross-session facts
none

## 6. Coordinator log
- 2026-08-18 board created
