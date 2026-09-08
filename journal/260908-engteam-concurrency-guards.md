# 260908 — engineering-team: shared-singleton docs and the stale-base push guard

> Purpose
>
> Record which of PR #45's three proposed concurrency guards shipped, why the
> third was held back rather than rebased, and the reproduction that changed the
> stale-base check before it landed. Point-in-time record; authoritative for
> nothing.

## 1. Where this came from

PR #45 (`feat/engteam-concurrency-guards`, opened 2026-07-24) implemented a
design note that lived only in the deployed `~/.claude` copy of the skill. The
note named three gaps found while running the skill on a real project with two
independent sessions active at once. The PR sat unmerged while `main` advanced
sixteen commits, and by the time it was evaluated it conflicted in three files.

The evaluation split it. Two of the three guards were still correct, still
absent from `main`, and merged cleanly into today's text. The third had been
overtaken by a rule that landed after it.

## 2. What shipped

**S1 — shared-singleton docs (`documentation-model.md` §9).** A living doc that
records one global fact every merge changes (deployed image tag, migration head,
a version, a counter) is contended by every session at once. The session that
refreshes it to its own state is made stale the instant another session's merge
deploys. The rule homed here: give such a doc one writer, either automated from
the deploy job's own log or single-owned, and never let a per-feature PR touch
it. The freshness gate cannot detect the defect, because a `Covers:` naming a
runtime fact matches no path and the long runtime clock is far too coarse for a
value that turns over every deploy. That blind spot is noted at the gate's own
home in `worktree.md`, so a reader arriving at the gate learns it does not cover
this case.

**S2 — the stale-base push guard (`worktree.md`).** Worktrees isolate files
completely, so the one way concurrent sessions still damage each other is
through shared history: a push whose tree is missing what `origin/main` gained
deletes a peer's merged files, and every check passes on the reverting tree. The
rule is to fetch and then diff before every push.

## 3. The reproduction that changed S2 before it shipped

The design note proposed checking with `git diff --name-status origin/main...HEAD`.
Three-dot diffs from the merge-base, so it reports only what the branch added and
is blind to a file another session merged *after* the fork point. That file is
precisely the one being reverted. Seeded in a throwaway repo, where `sessionA`
forks, `main` then gains `peer-merged.py`:

```
THREE-DOT (main...HEAD):
M	bar.py
TWO-ENDPOINT (main HEAD):
M	bar.py
D	peer-merged.py
```

The proposed form reports the reverting branch as a clean one-file edit. The
shipped rule uses the two-endpoint form, and the reason is written next to the
command so a later editor cannot "simplify" it back.

## 4. Two fixes to the optional pre-push hook

The hook ships as a documented backstop, and `general-guidelines.md` rule 1
requires proving a gate goes red before relying on it. Running the snippet
exactly as written surfaced two defects in the version PR #45 proposed:

- **A branch deletion was blocked with a misleading message.** `git push --delete`
  sends an all-zero local sha, `git merge-base --is-ancestor` errors on the null
  oid with exit 128, the negation reads that as true, and the push is rejected
  saying it "discards commits already on the remote branch." Confirmed against
  the original snippet, which does block a delete. The shipped version skips a
  ref whose local sha is all zeros.
- **The advanced-base warning tested `HEAD` instead of the ref being pushed.**
  The two differ whenever the push is not the branch currently checked out.

Behaviour of the shipped snippet, each case run against a real remote: a normal
push of a new branch passes silently, a branch delete passes silently, a
force-push discarding the remote tip is blocked, and an advanced base prints the
warning and lets the push proceed.

## 5. What did not ship, and why it is not a rebase

The note's third proposal was a peer-session survey, and PR #45 had already
rejected the note's `sessions/` registry as specified, rebuilding it around the
observation that `git worktree list` is itself an authoritative, self-cleaning
peer registry. That argument still holds.

What changed underneath it is `main`. PR #49 added `SKILL.md` §"You are never the
only session", which states that no probe settles whether peers exist: `git
worktree list` shows the trees that exist this instant and says nothing about the
session a user opens thirty seconds later. A startup survey built on `git
worktree list` reads as exactly the probe that section rules out. The two are
reconcilable — a survey that picks a disjoint lane is a footprint question, not
an existence test — but reconciling them means writing the rule underneath the
premise and homing it there, not replaying the original diff. PR #49's third
consequence also already covers the name-collision half of the original
proposal, so what remains is narrower than what was written.

That is a rewrite with a design question inside it, so it was separated rather
than allowed to hold up two guards that are ready.

## 6. Enforcement

`drift_scan.py` gains `shared-singleton-doc` and `stale-base-push`, added to the
sixteen signatures already on `main` rather than replacing them. PR #45's copy of
the file predated six of those signatures and the `design/` corpus exclusion, so
taking its version wholesale would have deleted them — the S2 failure mode, in
the file that enforces S2. Resolving additively is the point.

Both rules also carry a row in `rule-ownership.md`, so check B proves each cited
heading resolves and check C reds if a home loses its canonical statement.
