# Sync Skills & Commands with codespaces-setup

Run `~/.claude/scripts/sync-skills.sh` and report what it did.

The script keeps this machine's `~/.claude` and the codespaces-setup repo's copy
(`johnmathews/codespaces-setup`, `configs/claude/`, checked out at `~/projects/codespaces`) equal
for the skills and commands it lists. Every new Codespace installs from that copy. It does not copy
anything to other machines.

It **pulls before it pushes**. Each file is compared three ways against the base, the repo commit
this machine last synced with (`refs/sync-skills/base` in the checkout):

| This machine | Repo | Result |
| --- | --- | --- |
| changed | unchanged since the base | pushed to the repo |
| unchanged since the base | changed | pulled into `~/.claude` first (old copy backed up) |
| changed | changed | merged; an overlapping change stops the sync |

So a change merged into the repo from a Codespace or another machine is never overwritten: it
comes into `~/.claude` first. A deletion is pushed only when the base shows the file existed.
When there is something to push, the script works in a fresh worktree from `origin/main` (the
main checkout is never written, except a fast-forward when it is on a clean `main`), runs the
repo's skill checks, opens a PR, waits for CI, squash-merges it and records the new base. That
takes a few minutes, mostly CI, so run it in the background and wait for it to finish.

## Reading the result

- **Exit 0**: report what was pushed, pulled and merged, the PR link and merge commit if there
  was one, or "already in sync". If files were pulled, say so: `~/.claude` changed, and the
  backups are in `~/.local/state/sync-skills/backups/<time>/`.
- **Exit 2, "in conflict"**: nothing was changed. Both sides changed the listed files in
  overlapping places. The merge attempts, with conflict markers, are in
  `~/.local/state/sync-skills/conflicts/<time>/`. Show the user the conflicting hunks and ask how
  to resolve them. Resolve in `~/.claude` (bring the repo's change into the file), then run the
  sync again. Never resolve by discarding the repo's side without asking.
- **Exit 2, "no recorded base"**: this machine has never synced, so a file that differs on both
  sides can't be decided. Files whose local copy is an older repo version, or that only the repo
  has, are listed as pulls. Ask the user which repo commit `~/.claude` was last installed from or
  synced to, and rerun with `--base <commit>`. If nobody knows, compare the files by hand.
- **Exit 1, a check or CI failed**: show the failing output. The worktree (or PR) is left for
  inspection, and anything already pulled stays in `~/.claude`. The usual cause is
  `lint-skill-versions.sh`: a changed script under a skill's `scripts/` needs its
  `SCRIPT_VERSION` bumped. Fix it in `~/.claude`, close the failed PR
  (`gh pr close <url> --delete-branch`), remove the old worktree
  (`git -C ~/projects/codespaces worktree remove --force <path>`), and run the sync again.

## Options

- `--dry-run`: print each file's action (push, pull, merge, conflict) and change nothing. Use it
  when the user wants to see what a sync would do.
- `--base <commit>`: use this repo commit as the base. Only for a first sync, or after a base is
  lost.

## Adding or removing an asset

Edit the `ASSETS` list in the script, and add or remove the matching `deploy_skill` /
`deploy_file` line in the repo's `scripts/17-claude-skills.sh`. The script refuses an asset that
line doesn't deploy, because a new Codespace would never install it.
