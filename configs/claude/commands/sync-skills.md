# Sync Skills & Commands with codespaces-setup

Run `~/.claude/scripts/sync-skills.sh` and report what it did, in the fixed shape under "The
report" below.

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

It waits only for the `ci` workflow's run on its commit. Other checks on the PR, such as the
container smoke test, need services outside GitHub, so they never hold up the merge; a failed one
is named in a "note:" line. Pass that note on in the report's Notes line.

## The report

Every run, whatever the outcome, is reported in this shape: every line, in this order, with
nothing before it. A line with nothing to say reads "none" rather than being left out, so two
reports can be compared line by line.

```
**Sync:** <result> — <one sentence on what happened>
**Pushed:** <files, or none>
**Pulled:** <files, or none>
**Merged:** <files changed on both sides and merged, or none>
**PR:** <link>, merged as <short commit>, or none
**Base:** <old short commit> → <new short commit>, or <short commit> (unchanged)
**Notes:** <each "note:" line the script printed, or none>
**Needs from you:** <the one question to answer, or nothing>
```

1. **`<result>`** is one of: `in sync`, `pushed`, `pulled`, `pushed and pulled`, `dry run`,
   `conflict`, `no base`, `failed`.
2. **Files** are paths under `configs/claude/`, as the script prints them (`commands/prompt.md`,
   `skills/sitrep/SKILL.md`). With more than three, give them as a nested list under the line.
3. **When anything was pulled**, end the Pulled line with "`~/.claude` changed; backups in
   `<backup path>`".
4. **In a dry run**, the lines read "Would push", "Would pull" and "Would merge", and PR and Base
   read "none (dry run)".
5. **Detail goes after the block**, never inside it: the conflicting hunks for a conflict, and the
   failing output for a failure. Nothing goes after the detail.

## Reading the result

What each exit means and what to do about it. The answers go into the report above.

- **Exit 0**: `in sync`, `pushed`, `pulled` or `pushed and pulled`. Needs from you: nothing.
- **Exit 2, "in conflict"** (`conflict`): nothing was changed. Both sides changed the listed files
  in overlapping places. The merge attempts, with conflict markers, are in
  `~/.local/state/sync-skills/conflicts/<time>/`. Show the conflicting hunks as the detail, and
  ask how to resolve them as Needs from you. Resolve in `~/.claude` (bring the repo's change into
  the file), then run the sync again. Never resolve by discarding the repo's side without asking.
- **Exit 2, "no recorded base"** (`no base`): this machine has never synced, so a file that
  differs on both sides can't be decided. Files whose local copy is an older repo version, or
  that only the repo has, are listed as pulls. Needs from you: which repo commit `~/.claude` was
  last installed from or synced to, so the sync can rerun with `--base <commit>`. If nobody knows,
  compare the files by hand.
- **Exit 1, a check or the `ci` workflow failed** (`failed`): show the failing output as the
  detail. The worktree (or PR) is left for inspection, and anything already pulled stays in
  `~/.claude` (report it on the Pulled line). The usual cause is `lint-skill-versions.sh`: a
  changed script under a skill's `scripts/` needs its `SCRIPT_VERSION` bumped. Fix it in
  `~/.claude`, close the failed PR (`gh pr close <url> --delete-branch`), remove the old worktree
  (`git -C ~/projects/codespaces worktree remove --force <path>`), and run the sync again. When the
  fix is yours to make, Needs from you is nothing; say in the Sync line that you are fixing it.

## Options

- `--dry-run`: print each file's action (push, pull, merge, conflict) and change nothing. Use it
  when the user wants to see what a sync would do.
- `--base <commit>`: use this repo commit as the base. Only for a first sync, or after a base is
  lost.

## Adding or removing an asset

Edit the `ASSETS` list in the script, and add or remove the matching `deploy_skill` /
`deploy_file` line in the repo's `scripts/17-claude-skills.sh`. The script refuses an asset that
line doesn't deploy, because a new Codespace would never install it.
