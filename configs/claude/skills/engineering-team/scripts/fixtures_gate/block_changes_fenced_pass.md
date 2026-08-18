# Gate: W3 / lane b — round 1
_Requested 2026-08-18T12:05Z · Verdict CHANGES · Coordinator-owned_

## Claim
Export job writes the monthly CSV.

## Blocking findings
**MUST-FIX 1:** the header row is written per chunk — failure: a 3-chunk export →
3 header rows in one CSV — `src/reports/export.py:41`

## Non-blocking notes
- For reference, a cleared gate's status line looks exactly like this:

  ```markdown
  # Gate: W3 / lane b — round 2
  _Requested 2026-08-18T12:05Z · Verdict PASS · Coordinator-owned_
  ```

  That fence is an illustration of the format, not a verdict on this unit.

## Footprint
Declared: `src/reports/**` / Actual: `src/reports/**` / Breach: none
