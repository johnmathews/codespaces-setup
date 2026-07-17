# The backup that loaded as a second skill

**Date:** 2026-07-17. **PR:** fix/claude-assets-no-bak. Follows [260717-engineering-team-horizons-lessons.md](260717-engineering-team-horizons-lessons.md), which is what surfaced it. Point-in-time record; authoritative for nothing.

`17-claude-skills.sh` backed up a changed target to `.bak` before overwriting it. For `~/.zshrc` that is correct and has been for years. For `~/.claude/skills/engineering-team/` it created a **duplicate skill**.

## Why a backup is not inert here

`~/.claude/skills/` is **scanned**: Claude Code registers every subdirectory containing a `SKILL.md`. `engineering-team.bak/` has one — including `name: engineering-team` and a byte-identical description. So the backup did not sit quietly beside the original; it loaded as a second, indistinguishable skill holding the version we had just deliberately replaced. Selection between them is arbitrary.

**A backup of a scanned directory is not a backup. It is a fork.**

It was visible the whole time — `engineering-team.bak` was in the session's skill list from the first system prompt of the day, next to the real one, and read as noise until someone asked what it was.

## The convention prescribed it

The interesting part is not the bug, it is why deleting the code would not have fixed it. `CLAUDE.md` stated the `.bak` convention as a blanket per-script rule:

> **Idempotent**: … skip-if-unchanged (configs deploy via `diff -q`, backing up to `.bak`).

and then, explicitly, that `17-claude-skills.sh` uses the "same diff/`.bak` convention as `11-dotfiles.sh`". The bug was not an oversight — **it was the documented house style, correctly followed.** Remove the code and leave the doc, and the next person re-adds it on purpose, citing the convention. So the fix had to land in three places: the code, the comment at the point of temptation (a future editor copying from `11-dotfiles.sh` reads the top of *this* file first), and the rule in `CLAUDE.md` that generated it.

The rule now carries its own boundary: back up only a target that may hold edits existing nowhere else (`~/.zshrc` does; a repo-vendored asset does not, because git holds every version), and never write a `.bak` into a directory another tool scans.

## The trade-off this accepts

Removing the backup means **a hand-edit to `~/.claude` is silently destroyed by the next deploy**. Previously the `.bak` would have held it — at the cost of the fork.

That is the right trade for this repo, because the repo is the source of truth, but it inverts something `CLAUDE.md` had backwards: it described the vendored files as "copies of the user's local `~/.claude` assets — when the originals change, re-vendor them". That framing makes `~/.claude` the original and the repo the copy, which was survivable while a `.bak` existed and is a data-loss instruction now. Corrected: edit in `configs/claude/`, deploy outward, never hand-edit the deployed copy.

Demonstrated rather than assumed — appending a line to the live `SKILL.md` and re-running the script overwrote it without complaint. That is the intended behaviour, and it is worth having seen it once.

If the safety net is ever wanted back, the shape that does not fork is a backup **outside** the scanned tree (`~/.cache/`, where this repo already writes its logs). Not done: it protects a workflow the docs now tell you not to use.

## Verified

Not reasoned about — run:

- The stale `engineering-team.bak` plus three `commands/*.md.bak` were all reaped on first run of the fixed script; `~/.claude/skills/` now contains exactly one entry.
- A second run is a clean no-op (idempotent).
- Dirtying the live `SKILL.md` forces a redeploy that creates **no** `.bak` — the actual regression test, since the reap alone would pass even if the creation were still there.
- Live and repo `diff -rq` clean afterwards.

## What is deliberately not done

- **No automated check that a `.bak` never reappears.** The defence is a comment at the point of temptation and a corrected rule in `CLAUDE.md` — both prose, both enforced by a reader. The structural fix would be a CI assertion that `~/.claude/skills/` contains only vendored directories, but CI has no `~/.claude` to inspect, and asserting against the *source* cannot catch a runtime artifact. Recording the gap rather than pretending prose is a control.
- **The reap is narrow on purpose** — only `${SKILLS_DIR}/*.bak` and `${COMMANDS_DIR}/*.bak`, which are unambiguously this script's own leftovers. Anything else under `~/.claude` belongs to the user. A script that deletes broadly to be helpful is worse than the bug it fixes.
