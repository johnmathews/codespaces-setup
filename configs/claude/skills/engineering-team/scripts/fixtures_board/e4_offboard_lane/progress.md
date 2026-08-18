# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

The interfaces table names a consumer lane `c` that no board row owns. Both
register tables are present, so this also proves the reservations table stays
ignored while the interfaces table still drives E4.

## 1. Tracking contract
Single-writer per artifact. Lanes record ticks in their own status file.

## 2. Status board

| Unit | Lane | Owns (file footprint) | Branch | Status | PR | Blocker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| U0 | a | `src/api/types.py` | eng-demo-a | merged | 1 | — | contract stubs |
| W1 | a | `src/api/**` | eng-demo-a | in-progress | — | — | — |
| W2 | b | `src/reports/**` | eng-demo-b | not-started | — | — | — |

## 3. Contract register

**Interfaces**

| ID | Producer | Consumers | Contract | Frozen at |
| --- | --- | --- | --- | --- |
| C1 | a | b, c | `def resolve(id: str) -> Account \| None` in `src/api/types.py` | plan approval |

**Reservations**

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
