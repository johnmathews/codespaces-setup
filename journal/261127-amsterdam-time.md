# Times to the user are Amsterdam time

> Purpose
>
> Why sitreps, pulses and ETAs now give Amsterdam time instead of the machine's zone.

## 1. Why

The skills said "the user's local timezone, check `date`". That is right on the Mac and wrong in a
Codespace, whose clock runs on UTC. The global `CLAUDE.md` also pinned "CEST as of 2026-09-17", which
went stale when the clocks changed to CET.

## 2. What changed

1. `status-updates.md` gains §3.4 "Times": every clock time said to the user is `Europe/Amsterdam`,
   unless the user asks for another zone, and the zone name (CET or CEST) comes from the command,
   never from memory.
2. It gives the commands: `TZ=Europe/Amsterdam date '+%H:%M %Z'` for now, and a `zoneinfo`
   one-liner that adds an estimate to now in that zone, so an ETA across a CET/CEST change is right.
   It runs the same on macOS and Linux, where `date` arithmetic does not.
3. UTC times from logs, CI and GitHub are converted before they are said.
4. File names, run IDs and `run.yaml` stay in UTC: they sort, and nobody reads them as a time of day.
5. The finish-time rule (§3.1), the pulse rule (§2.1), §3.3 Sources and the `sitrep` skill's Step 2
   point at §3.4. `rule-ownership.md` records §3.4 as the home.
6. The global `~/.claude/CLAUDE.md` "Times" rule says the same. That file is not vendored in this
   repo, so it is changed on the main machine only.
