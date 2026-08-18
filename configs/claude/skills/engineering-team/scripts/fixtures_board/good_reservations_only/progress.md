# demo run — progress dashboard

_Run: r1 · Plan: `improvement-plan.md` (same dir) · Coordinator session owns this file._

Honest board: the lanes share no interface, but they do share a migration
sequence and a port. So the register carries reservations and no interfaces —
and therefore needs no U0 (`coordination-protocol.md` §4.4: U0 lands seams "as
stubs and types", which a port range is not). This must be clean.

## 1. Tracking contract
Single-writer per artifact. Lanes record ticks in their own status file.

## 2. Status board

| Unit | Lane | Owns (file footprint) | Branch | Status | PR | Blocker | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | a | `src/api/**` | eng-demo-a | in-progress | — | — | — |
| W2 | b | `src/reports/**` | eng-demo-b | not-started | — | — | — |

## 3. Contract register

**Interfaces** — anything one lane produces and another consumes:

| ID | Producer | Consumers | Contract | Frozen at |
| --- | --- | --- | --- | --- |

none

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
