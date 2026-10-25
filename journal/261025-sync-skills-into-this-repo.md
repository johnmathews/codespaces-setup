# Skills are edited in ~/.claude and synced into this repo

Until now this repo was the source of truth for `configs/claude/`: edit here, deploy to
`~/.claude`. In practice the skills are edited in `~/.claude` on the main machine, where they are
used, and the repo fell behind. On 2026-10-25 the design-system skill gained
`references/voice.md` and the engineering-team skill's writing style changed, both in `~/.claude`
only.

The `/sync-skills` command used to scp skills to an `agent` host. It now keeps this repo correct
instead, and no longer copies anything to other machines. Its script
(`~/.claude/scripts/sync-skills.sh`, outside this repo) works in a fresh worktree from
`origin/main`, mirrors each asset into `configs/claude/`, runs the skill checks CI runs, then opens
a PR, waits for CI and squash-merges it.

The risk in reversing the direction is a sync that reverts a change made in the repo. The guard
handles it:

- a differing file whose local copy matches an older version in the repo's history means the repo
  is ahead, so the sync stops;
- a file only the repo has is a deletion here or an addition there, and only a person can tell, so
  the sync stops unless run with `--allow-deletes`.

Both were tested against this repo with a fake home holding an older `SKILL.md` and a missing
template, and both stopped with exit 2. `--allow-deletes` then let the deletion through.

The sync also refuses an asset that `scripts/17-claude-skills.sh` doesn't deploy, because a
Codespace would never install it.
