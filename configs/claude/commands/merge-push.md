# Merge & Push

Land the current branch on `main`. This command is focused and fast — no tests, no
linting, no documentation review. Use `/done` for the full wrap-up workflow.

There are two ways to land, and **Step 0 decides which**. Do not skip it: on a repo with a
remote, merging into local `main` and pushing bypasses review and pre-merge CI, and on a
protected repo it simply fails.

## Step 0 — Which path?

```bash
git remote -v                                          # is there a remote at all?
gh pr view --json number,state,url 2>/dev/null         # does this branch already have a PR?
```

- **A remote exists → the PR path (Step 2A).** Merge happens on the platform, after CI has
  passed on the PR. This is the default whenever there is a remote, protections or not: it is
  how `main` stays green and how the change gets a reviewable record.
- **No remote → the local path (Step 2B).** A scratch repo with no remote has no PR to open
  and no CI to wait for; a local merge is the whole ceremony.

Protections (`gh api repos/{owner}/{repo}/rulesets`, `gh api repos/{owner}/{repo}/branches/main/protection`
— a 404 from either is an answer, not an error) don't change the path; they tell you what the
PR must satisfy before it can merge, and whether an admin bypass will be needed.

## Step 1 — Assess

Gather information before doing anything. Run these in parallel:

1. **Current branch:** `git branch --show-current` — if already on `main`, skip to the push
   assessment (Step 1c).
2. **Worktree check:** Compare `git rev-parse --git-dir` and `git rev-parse --git-common-dir`.
   If they differ, you are in a worktree. Note this — it affects cleanup later.
3. **Working tree status:** `git status --short` — if there are uncommitted changes, warn the
   user and ask how to proceed (stash, commit first, or abort). Do not merge with a dirty tree.

### Step 1a — Branch comparison

Show the user what will be merged:

1. **Commits on this branch not in main:**
   `git log --oneline main..HEAD`
   Display these — this is what will be merged.

2. **Commits on main not in this branch:**
   `git log --oneline HEAD..main`
   Display these if any exist — this is what has landed on main since the branch diverged.

3. **Fast-forward check:** If there are no commits on main that aren't in this branch
   (i.e., `git log --oneline HEAD..main` is empty), a fast-forward merge is possible.
   Tell the user: "Fast-forward merge is possible (main hasn't diverged)."

### Step 1b — Conflict risk assessment

Check whether the merge is likely to have conflicts:

1. **Files changed on both sides:**
   - `git diff --name-only main...HEAD` (files changed on this branch)
   - `git diff --name-only HEAD...main` (files changed on main since divergence)
   - If any files appear in both lists, warn the user: "These files were modified on both
     branches and may have conflicts: [list files]"

2. **Dry-run merge:** Run `git merge --no-commit --no-ff main` to test the merge, then
   immediately `git merge --abort` to undo it. If the dry-run fails with conflicts, report
   which files conflict. If it succeeds cleanly, tell the user: "Dry-run merge succeeded —
   no conflicts detected."

### Step 1c — Push assessment (also runs when already on main)

1. **Remote tracking:** Check if the branch tracks a remote (`git rev-parse --abbrev-ref @{upstream} 2>/dev/null`).
   If no remote is configured, warn the user.
2. **Unpushed commits on main:** `git log --oneline @{upstream}..main 2>/dev/null` — show
   how many commits will be pushed. If upstream doesn't exist, note that.

### Step 1d — Present summary

Present a clear summary to the user:

```
Path:             PR (remote exists) / local (no remote)
Branch:           feature/xyz
Commits to merge: 5 (list them)
Main has diverged: yes/no (N commits)
Conflict risk:    none detected / likely in [files]
PR:               #42 open / none yet / already MERGED (stop — see Step 2A.1)
```

## Step 2A — The PR path (a remote exists)

**Never merge into local `main` and push.** That bypasses review and pre-merge CI, and on a
protected repo the push is rejected anyway. The merge happens on the platform.

1. **Push the branch** if it isn't pushed: `git push -u origin <branch>`.
   - **First check the PR isn't already merged** (`gh pr view --json state`). Pushing to a
     **merged** PR's branch **succeeds silently**, is never merged, and runs no CI — the commits
     are stranded with no error to tell you. If it's `MERGED` or `CLOSED`, stop: the work needs a
     fresh branch off `main` with the commits cherry-picked. Say so; don't push into the void.
2. **Open the PR** if there isn't one: `gh pr create --fill` (fill in any template rather than
   around it). If one is already open, the push updated it.
3. **Wait for CI on the PR:** `gh pr checks <pr> --watch`.
   - On failure: `gh run view <id> --log-failed`, diagnose, fix **on the branch**, push,
     re-watch. Max 3 cycles, then report and stop. Flaky/infra failures can be retried with
     `gh run rerun <id> --failed`.
   - A required check stuck at "Expected — Waiting for status" is almost certainly a
     path-filtered workflow that never started — a repo config bug, not something to wait out.
     See "Making a check required" in the engineering-team skill's `references/worktree.md`.
4. **Ask the user for explicit confirmation before merging.** Do not proceed without a clear
   "yes". Merge is the irreversible step; a green PR is a fact about the PR, not permission.
5. **Merge:** `gh pr merge <pr> --squash` (match the repo's rules — some require rebase; if the
   repo forbids squash, use what it allows). Add `--admin` **only** when the user says to: a
   solo author on a repo requiring last-push-approval cannot satisfy it any other way, and that
   is their call to make, not yours.
6. **If the PR is out of date or conflicts:** rebase the branch onto `main`, push, and re-watch
   CI. Resolve conflicts on the branch and ask the user to review the resolutions.

## Step 2B — The local path (no remote)

**Ask the user for explicit confirmation before merging.** Do not proceed without a clear "yes."

1. **If in a worktree:** Exit the worktree first using `ExitWorktree` with `action: "keep"`.
   Then continue from the main working directory.
2. **Merge:**
   - If fast-forward is possible and the branch is simple, use `git merge --ff-only <branch>`.
   - Otherwise, use `git merge <branch> --no-ff -m "Merge <branch>: <summary>"` where
     `<summary>` is a one-line description based on the branch commits.
3. **If conflicts occur:** List the conflicting files, resolve them, and ask the user to
   review the resolutions before completing the merge with `git commit`.
4. If the user later wants a remote, ask before creating one.

## Step 4 — Cleanup

Once the work is actually merged (PR shows `MERGED`, or the local merge is done):

1. **Remove the worktree** at the path it actually occupies — take it from `git worktree list`,
   don't assume `.claude/worktrees/<name>`. `git worktree remove <path>` (`--force` only if you
   know why it's refusing).
2. **Delete the branch:** `git branch -d <branch>`.
   - **Under squash merges `-d` will refuse**, and it is right to: the squashed commit is a new
     object, so the branch tip is *not* an ancestor of `main` and git cannot see it as merged.
     Confirm via the PR (`gh pr view --json state` → `MERGED`) and only then `git branch -D`.
     Verifying with `git log --oneline main | head` does **not** prove it — the branch's commits
     are not there under any squash.
   - Delete the remote branch too if the platform didn't: `git push origin --delete <branch>`.
3. **Never remove a worktree that is dirty, has unpushed commits, has a rebase in progress
   (`.git/rebase-merge`, `.git/rebase-apply`, `MERGE_HEAD`), or that another session is using.**
   Report and skip instead. A clean `git status -sb` can be one instant stale.
4. **Verify:** `git worktree list`, `git branch`, and `git worktree prune` for directories that
   are already gone.

If not in a worktree, no cleanup is needed.

## Step 5 — Summary

Brief one-liner: what was merged, via which path (PR #N squash-merged, or local merge), the
resulting commit hash on `main`, and what was cleaned up. Name the CI checks that were green
before the merge — "CI passed" is not a result; "`lint-types-test` + `docs-check` green on #42"
is.
