# 2026-06-19 — Deploy personal Claude skills/commands into Codespaces

## What changed

Make three personal Claude Code assets available in every Codespace after
`setup.sh` finishes:

- `/engineering-team` — a skill (`SKILL.md` + `phases/` + `references/`).
- `/done` — a slash command (wrap-up workflow).
- `/merge-push` — a slash command (fast merge-into-main + push).

### How

- **Vendored the source files** into `configs/claude/`:
  - `configs/claude/skills/engineering-team/` (copy of `~/.claude/skills/engineering-team`,
    excluding the `evals/` harness — not needed at runtime).
  - `configs/claude/commands/done.md` and `configs/claude/commands/merge-push.md`
    (copies of `~/.claude/commands/*.md`).
  - All three were verified to contain no machine-specific absolute paths.
- **New deploy step `scripts/17-claude-skills.sh`** copies them into
  `~/.claude/skills/` and `~/.claude/commands/`. Idempotent, matching the
  `11-dotfiles.sh` convention: skip-if-identical (`diff -q` for files,
  `diff -rq` for the skill dir), back up a changed target to `.bak` before
  overwriting.
- **Wired into `STEPS`** in `setup.sh` right after `12-claude-code.sh`
  (`ci/lint-steps.sh` requires every `scripts/NN-*.sh` be in `STEPS`).
- **Verification summary** in `setup.sh` now reports a ✅/❌ line for the Claude
  skills (checks the three deployed files exist).
- Docs updated: `README.md` ("What it installs" table, Structure tree,
  Customisation) and project `CLAUDE.md` (configs/ conventions).

## Decisions / rationale

- **Vendor, not clone.** These assets live only in the user's local `~/.claude`
  with no dedicated remote, and the repo already follows a "source in `configs/`,
  deploy via a wired script" pattern. Vendoring keeps the kit self-contained.
- **Excluded `engineering-team-sentinels` and `engineering-team-workspace`.**
  The user asked for exactly these three. `engineering-team-workspace` is eval
  run-state (1.8M), not a skill. The `engineering-team` SKILL.md mentions
  `engineering-team-sentinels` only as the automation/relay-driven alternative;
  the interactive skill works fine without it.

## Sync caveat

`configs/claude/` is a point-in-time copy. When the local `~/.claude` originals
change, re-vendor into `configs/claude/` and re-run `scripts/17-claude-skills.sh`.

## Verification

- `shellcheck setup.sh scripts/*.sh ci/*.sh` — clean.
- `shfmt -i 2 -ci -kp -d` — clean (no diff).
- `bash ci/lint-steps.sh` — 16 steps wired, 1 exempt, no orphans.
- Ran `17-claude-skills.sh` against a temp `HOME`: fresh deploy lands all files;
  re-run reports "already up-to-date" with no `.bak`; mutating a deployed file
  and re-running backs it up to `.bak` and restores the vendored copy.
