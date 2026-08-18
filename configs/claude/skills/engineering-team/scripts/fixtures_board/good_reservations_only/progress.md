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

| Kind | Example collision | Allocation |
| --- | --- | --- |
| Migration numbers | two lanes both add `0007_*` | a: 0007–0009, b: 0010–0012 |
| Ports | two dev servers on 8080 | a: 8080, b: 8081 |
| Config keys / env vars | same key, different meaning | namespaced per lane |
| Feature-flag names | duplicate flag | registered in advance |
| Enum / error-code values | same numeric code | ranges per lane |

## 4. Proposals
none

## 5. Cross-session facts
none

## 6. Coordinator log
- 2026-08-18 board created
