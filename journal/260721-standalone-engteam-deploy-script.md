# A standalone deploy for the engineering-team skill

**Date:** 2026-07-21. **PR:** feat/engteam-standalone-deploy-script. Follows [260717-claude-assets-no-bak.md](260717-claude-assets-no-bak.md), which established the "repo is source of truth, deploy outward, no `.bak`" rule this builds on. Point-in-time record; authoritative for nothing.

Two things happened this session: a cleanup of the machine's `~/.claude/skills/`, and a small new tool to make the common redeploy easy.

## The cleanup

`~/.claude/skills/` had accumulated three things that should not have been there next to the real `engineering-team`:

- `engineering-team-sentinels/` — the sentinel-emitting variant skill (not vendored in this repo; a separate asset).
- `engineering-team-workspace/` — **not a skill at all.** No `SKILL.md`; it held `iteration-1` … `iteration-8` plus `evals.json`, i.e. `skill-creator` benchmark/eval output from when the skill was being tuned (1.8M, last touched March/June). It sat inside the scanned skills dir but, lacking a `SKILL.md`, never registered — so it was inert clutter rather than a duplicate skill.
- Eight `~/.claude/skill-backups/engineering-team-*` snapshots.

All removed. The real skill was first redeployed from the repo via `scripts/17-claude-skills.sh` (which confirmed the `/done`, `/merge-push`, `/prompt` commands were already current), leaving exactly one `engineering-team` entry.

The distinction that mattered: `engineering-team-workspace` is neither a backup nor a variant, and the user's request ("remove sentinels and backups") did not name it — so it got surfaced and confirmed separately rather than swept in. A dir under `skills/` is not automatically a skill; the `SKILL.md` is what makes it one.

## The new tool

`deploy-engineering-team-skill.sh` at the repo root: copies `configs/claude/skills/engineering-team/` over `~/.claude/skills/engineering-team/`, unconditionally.

It deliberately is **not** `scripts/17-claude-skills.sh`:

- `17` is the setup-path deployer — runs inside `bash setup.sh`, also deploys the three slash commands, and **skips** when the trees already match (`diff -rq`).
- The new script does one thing (the skill), overwrites without a diff-check, so after an edit you *know* the bytes on disk are the repo's without reasoning about what diff detected.

It inherits the earlier ruling verbatim: **no `.bak`**, because `~/.claude/skills/` is scanned and a backup dir forks into a duplicate skill (see the predecessor entry). Same `cp -a` so `phases/`, `scripts/`, `templates/` and modes come along.

## Where it lives, and why not in `scripts/`

Root, beside `setup.sh` — not `scripts/`. `ci/lint-steps.sh` scans **every** `scripts/*.sh` and fails any that is neither wired into `setup.sh`'s `STEPS` array nor listed in `EXEMPT`, and separately requires each committed `100755`. A manual tool in `scripts/` would need an `EXEMPT` entry *and* the exec bit set correctly. Root scripts are outside that machinery (`setup.sh` itself is committed `644` and invoked as `bash setup.sh`), so root was the lower-friction, correct home.

The cost accepted: it is not `chmod +x`, so it is run as `bash deploy-engineering-team-skill.sh`, matching the repo's existing `bash setup.sh` / `bash scripts/11-dotfiles.sh` convention.

## The doc gap the freshness audit caught

The lint invocation (`shellcheck … / shfmt …`) is duplicated in **four** places: `.github/workflows/ci.yml`, `CLAUDE.md`, `README.md`, and `docs/development.md`. Adding the new root script to the lint scope meant all four had to change in lockstep, or a reader running the CLAUDE.md/README copy would silently under-lint. The first pass updated only CI + `docs/development.md`; the Phase-2 audit grepped every occurrence and surfaced the two stale copies, which were then fixed. Also tightened a CLAUDE.md parenthetical that claimed the lints are "scoped to `scripts/` and `ci/`" — already imprecise (it omitted `setup.sh`), now corrected to name the actual root scripts.

Grade: **confirmed** — every claim here was observed (the removals via `ls`/`diff`, the script via a real run that produced a `diff -rq` clean tree, the lints green locally at CI parity).

## What is deliberately not done

- **No consolidation of the four duplicated lint commands into one source.** The right structural fix is a single canonical list the others reference, but the docs are prose in different registers (a CI yaml, two human docs, a project-memory file) and there is no include mechanism; a `Makefile`/`lint.sh` that all four cite by name would do it. Recorded as the real fix rather than pretending the manual sync is one.
- **The new script duplicates `17`'s path logic** (source dir, dest dir, no-`.bak`) rather than sharing it. `17` is not structured to be sourced (it runs at file scope). Five lines of duplication was the cheaper correct choice over refactoring `17` into a sourceable library for one caller.
- **No CI coverage that the deploy actually produces a one-entry skills dir** — CI has no `~/.claude` to inspect, the same limitation noted in the predecessor entry. The script's source-guard (`SKILL.md` must exist) is the only automated check; the deploy correctness is verified by hand.
