# Gate: W1 / lane a — round 1
_Requested 2026-08-18T09:12Z · Verdict PASS · Coordinator-owned_

## Claim
Account resolution lands behind the frozen C1 signature.

## Acceptance criteria
| # | Criterion | Met | Evidence |
| 1 | `resolve_account` returns None for unknown ids | yes | `pytest -k resolve` green |

## Blocking findings
none

## Non-blocking notes
- Consider a docstring on the None branch. Rides along to the PR.

## Footprint
Declared: `src/accounts/**` / Actual: `src/accounts/**` / Breach: none
