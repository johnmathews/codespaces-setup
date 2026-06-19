# Merge & Push

Merge the current branch into main and push. This command is focused and fast — no tests, no
linting, no documentation review. Use `/done` for the full wrap-up workflow.

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
Branch:          feature/xyz
Commits to merge: 5 (list them)
Main has diverged: yes/no (N commits)
Fast-forward:    possible / not possible
Conflict risk:   none detected / likely in [files]
Unpushed after merge: N commits to push
```

## Step 2 — Merge

**Ask the user for explicit confirmation before merging.** Do not proceed without a clear "yes."

If confirmed:

1. **If in a worktree:** Exit the worktree first using `ExitWorktree` with `action: "keep"`.
   Then continue from the main working directory.
2. **Pull latest main:** `git pull --ff-only` (fall back to `git pull --rebase` if that fails).
3. **Merge:**
   - If fast-forward is possible and the branch is simple, use `git merge --ff-only <branch>`.
   - Otherwise, use `git merge <branch> --no-ff -m "Merge <branch>: <summary>"` where
     `<summary>` is a one-line description based on the branch commits.
4. **If conflicts occur:** List the conflicting files, resolve them, and ask the user to
   review the resolutions before completing the merge with `git commit`.

## Step 3 — Push

**Ask the user for explicit confirmation before pushing.** Do not proceed without a clear "yes."

If confirmed:

1. Run `git push`.
2. If the push fails because the remote has new commits, run `git pull --rebase && git push`.
3. If there is no remote configured, ask the user before creating one.

## Step 3b — Monitor CI

After a successful push, check whether the repo has GitHub Actions workflows that would be triggered
by this push. Only monitor if workflows exist — do not block on repos without CI.

1. **Detect workflows:** Run `gh run list --branch main --limit 1 --json databaseId,status,conclusion,name,event,createdAt`
   to see if a run was triggered by this push. If `gh` is not available or the command fails, skip this step.

2. **Wait for completion:** If a run is in progress, poll with `gh run watch <run-id> --exit-status` (this blocks
   until the run completes and exits non-zero if the run fails). If `gh run watch` is not available, fall back to
   polling `gh run view <run-id> --json status,conclusion` every 30 seconds, up to a maximum of 10 minutes.

3. **On success:** Report "CI passed" and continue to cleanup.

4. **On failure:**
   - Run `gh run view <run-id> --log-failed` to fetch the failed step logs.
   - Analyze the failure. Common categories:
     - **Test failure:** A test broke — investigate and fix locally, then commit and push the fix. Re-monitor.
     - **Lint/format failure:** Fix locally, commit, push. Re-monitor.
     - **Build failure:** Missing dependency, syntax error, Docker build issue — fix locally, commit, push. Re-monitor.
     - **Flaky/infra failure:** Rate limits, runner issues, transient network errors — retry with
       `gh run rerun <run-id> --failed`. Re-monitor.
     - **Unknown/unresolvable:** If the failure cannot be diagnosed or fixed after 2 attempts, report the failure
       details to the user and ask how to proceed. Do not loop indefinitely.
   - **Maximum 3 fix-and-push cycles.** If CI still fails after 3 attempts, stop and report the full failure
     context to the user.

## Step 4 — Cleanup

If the session started in a worktree:

1. Remove the worktree: `git worktree remove .claude/worktrees/<name>` (use `--force` if needed).
2. Delete the feature branch: `git branch -d <branch>`. If it refuses, verify the merge happened
   with `git log --oneline main | head -5`, then use `git branch -D <branch>`.
3. Verify: `git worktree list` and `git branch` to confirm cleanup.

If not in a worktree, no cleanup is needed.

## Step 5 — Summary

Brief one-liner: what was merged, the merge commit hash, and whether it was pushed.
