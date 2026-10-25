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

The risk in reversing the direction is a sync that reverts a change made in the repo. The first
version guarded against it with history alone: stop if the local copy matched an older repo
version, or if a file existed only in the repo. That missed the case that matters most. If the repo
gained a change and the same file was then edited locally without installing it, the local copy
matched no repo version, so it looked newer and the repo's change would have been overwritten.

The sync is now three-way, and it pulls before it pushes. The base is the repo commit the machine
last synced with, kept as `refs/sync-skills/base` in the checkout (a ref, so the commit survives its
squash-merged branch being deleted). For each file: only local changed, push; only the repo changed,
pull into `~/.claude` with a backup in `~/.local/state/sync-skills/backups/`; both changed, `git
merge-file`, and an overlapping change stops the sync with nothing written and the attempt, with
conflict markers, saved under `~/.local/state/sync-skills/conflicts/`. After a push the base is the
synced branch's commit, not `main`, because `main` may gain another change while CI runs, and the
next sync must see that change as the repo's.

With no recorded base the sync decides only what history settles (an older repo version locally,
or a file only the repo has, both pulls) and stops on anything else, asking for `--base <commit>`.

A sandbox test covered six cases against a bare clone standing in for GitHub: no base stops;
push, pull, merge and a pushed deletion in one plan; an overlapping edit stops with nothing
changed; a pull-only run moves the base without a worktree; an in-sync run uses the recorded base;
and a push run merges into `~/.claude`, passes every check and pushes its branch. Writing the test
found a real bug: `git merge-file` reads `<(...)` pipes as empty files, so every merge came out
"clean" against nothing. It now reads temporary files.

The first sync with the history-only guard ran as #72 before the three-way version, which was safe
because nothing under `configs/claude/` had changed in the repo since #70. Its result, `cac33fc`, is
the first recorded base.

The sync also refuses an asset that `scripts/17-claude-skills.sh` doesn't deploy, because a
Codespace would never install it.
