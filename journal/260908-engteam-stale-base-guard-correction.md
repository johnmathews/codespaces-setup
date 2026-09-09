# 260908 — engineering-team: correcting the stale-base push guard

> Purpose
>
> Record why PR #62's stale-base push guard was rewritten one commit after it
> merged: which of its executable claims are false, the reproductions that
> establish that, and the reversion shape the replacement still cannot see.
> Point-in-time record; authoritative for nothing. The rule itself lives in
> `references/worktree.md`.

## 1. What was wrong

PR #62 shipped two rules. S1, the shared-singleton doc rule
(`documentation-model.md` §9), is prose with no commands and stands unchanged.
S2, the stale-base push guard, describes a real failure and then got every
executable part of it wrong. Nothing in the repo runs either one, so the merged
state was safe to leave standing while this was written — but a guard that
misfires on the correct action is worse than no guard, because the first thing
it teaches is how to switch it off.

Four defects, each reproduced in a throwaway repo before being written down.

## 2. The direction of the diff was inverted

S2 mandated the two-endpoint diff (`origin/main HEAD`) and argued that three-dot
(`origin/main...HEAD`) is blind to a file a peer merged after the fork point.
The opposite holds. Three-dot diffs from the merge base, and the merge base is
exactly what a merge or a squash applies to `main`, so three-dot **is** the set
of changes that can revert a peer. Two-endpoint adds every file `main` gained or
changed since the fork point, as `D` and `M` lines nobody on the branch
authored:

```
$ git diff --name-status origin/main HEAD     # branch merely behind
A  f.txt
D  peer1.py
D  peer2.py
$ git diff --name-status origin/main...HEAD
A  f.txt
$ git merge feat && ls                        # both peer files survive
base.txt  f.txt  peer1.py  peer2.py
```

Both `D` lines are noise. Under disjoint lanes (`multi-session.md` §3) PRs merge
in any order with no rebases, so being behind is the normal state and the noise
appears on essentially every push. S2's prescribed response to an unexplained
`D` was "your base is stale — rebase onto the fresh `origin/main`", which turns
routine behind-ness into routine rewriting of already-pushed history: the one
operation in the section that can actually destroy a peer's work.

S2's own reproduction demonstrated the noise rather than a reversion. Its
`sessionA` was merely behind, and merging it preserved `peer-merged.py`.

## 3. `grep '^D'` discarded half the failure mode

The incident S2 cites reverted a peer's *edit*, not an addition. Seeded:

```
$ git diff --name-status origin/main HEAD | grep '^D'
(no output, exit 1)
$ git merge sessionA && cat shared.txt
v1                                  # the peer's v2 is gone
```

The `M shared.txt` line was in the diff and the documented pipeline threw it
away. Deletions and modifications are the same hazard, so the replacement rule
reads both letters and judges them against the unit's declared file footprint,
which is what makes the judgement mechanical: without a footprint an intended
change and a reversion are identical on the diff.

## 4. The soft-reset story blamed the wrong ref

S2 attributed the incident to `git reset --soft origin/main` "against an
unfetched (stale) local ref". Reset onto a stale ref is not the bug — the merge
base is then the stale commit, and a merge preserves everything added after it.
The destructive variant is the *fresh* one, because `--soft` moves the parent
and leaves the worktree alone, so the next commit claims main's tip as its
parent while carrying a tree that predates it:

```
reset --soft onto stale base -> peer.py present? YES-safe
reset --soft onto fresh base -> peer.py present? NO-REVERTED
```

A fresh parent over a stale tree is the shape. Naming it correctly is what keeps
the check pointed at the real thing.

## 5. The hook hard-blocked the remedy the rule prescribed

Run against a real remote: fetch, rebase onto fresh `origin/main` exactly as
instructed, then push.

```
$ git push --force-with-lease origin feat
pre-push: this discards commits already on the remote branch.
If another session pushed there, rebase — do not force.
FORCE PUSH exit=1
```

The rebase had just happened. The only way through is `--no-verify`, which
disables the whole hook, and `/merge-push` step 6 tells a session to rebase and
push for an out-of-date PR, so this fires on a documented flow. A pre-push hook
cannot see `--force-with-lease`, which is the flag that already makes the
operation safe.

Four smaller defects came out of the same session:

- **No `origin/main`.** In a repo whose base branch is `master`, every push
  printed two `fatal:` lines and a spurious warning.
- **The null oid was hardcoded to 40 zeros.** In a SHA-256 repo the remote sha
  is 64 zeros, so the guard treated a new branch as a rewrite and blocked both a
  first push and a delete. Same null-oid class the PR had just fixed for the
  local sha.
- **The fetch's exit status went unchecked.** With the fetch failing, the stale
  `origin/main` was still an ancestor, nothing printed, and the push proceeded
  looking checked — `general-guidelines.md` rule 1's "check that cannot fail",
  inside the file that cites it.
- **`git config core.hooksPath .githooks` disables `.git/hooks/`.** Confirmed by
  installing a `.git/hooks/pre-push` beside it and watching it never fire. The
  one-line activation instruction silently turns off husky or `pre-commit`.

## 6. What the replacement blocks, and what it cannot see

The hook now hard-blocks exactly one thing: a push discarding remote commits
this clone has never seen, detected with `git cat-file -e` on the remote sha.
That is another session's push and is unrecoverable locally. A rebase leaves its
old tip in this clone's object store, so the prescribed remedy passes with one
informational line. Everything else prints and proceeds, because every stricter
block reaches the rebase flow.

**The blind spot, stated because it is real:** when the branch already contains
the base tip and rewinds a file's *content* rather than deleting it, git holds
nothing that says which version was meant, and the hook prints nothing. That is
case C6 below. The footprint comparison names the file immediately, which is why
the rule is ranked first and the hook second.

## 7. Evidence

Twelve cases, each run against a real remote, against the snippet extracted from
the shipped markdown rather than a copy:

| Case | Expected | Result |
|---|---|---|
| C1 first push to an empty remote | pass, silent | pass |
| C2 new branch, disjoint footprint | pass, silent | pass |
| C3 push while merely behind | pass, silent | pass |
| C4 force-with-lease after a rebase | pass, one notice | pass |
| C5 stale-tree push deleting a peer's file | pass, file listed | pass |
| C6 content rewind, base tip already in branch | pass, nothing printed | pass (blind spot, §6) |
| C7 force over an unseen remote tip | **block** | pass |
| C8 branch delete | pass, silent | pass |
| C9 base branch is `master`, remote HEAD set | pass, silent | pass |
| C10 base branch unresolvable | **block**, loud | pass |
| C11 remote unreachable | non-zero, never silent | pass (git aborts first) |
| C12 SHA-256 repo, new branch and delete | pass, silent | pass |

`shellcheck -s sh` is clean on the extracted snippet. It also caught
`tr '[0-9a-f]' '0'` (SC2021), the bracket form git's own sample hook uses, where
the brackets are literal.

## 8. Enforcement

No new `drift_scan.py` signature: `stale-base-push` already homes this rule in
`worktree.md`, and its regex still matches. The `rule-ownership.md` row changed
with the rule, so check B keeps proving the cited heading resolves and check C
reds if the home loses the statement. `SKILL.md` §"Always work in a worktree"
carried the old `two-endpoint-diff` phrasing and now carries the command a
reader should actually run.
