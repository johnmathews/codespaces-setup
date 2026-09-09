# Worktree and linter setup

> Loaded by phase docs (especially Phase 3) when worktree creation, linter
> detection, or working-directory invariants are relevant.

## Working Directory

The target repo is the current working directory unless the user specifies another path.

### The project's own conventions outrank this skill's defaults

This skill carries defaults for things every repo does differently: where
worktrees live (`<repo>/.claude/worktrees/`), how branches are named
(`eng-<plan-short-name>`), where the journal goes (`/journal/`), where docs go
(`/docs/`). They are **defaults, not law.**

**If the project states its own convention — in `CLAUDE.md`, `CONTRIBUTING.md`,
or a visibly established pattern in the repo — follow the project and say that
you are.** Check before creating the first worktree, not after.

This is not hypothetical. One repo this skill is used on daily mandates
worktrees at `/workspaces/<repo>-wt/<short-desc>` in its own `CLAUDE.md`, while
this file said "never use ad-hoc sibling paths" — so following the skill meant
breaking the project, and following the project meant breaking the skill. There
was no rule saying which wins. There is now: **the project wins**, because the
convention is shared with humans and other agents who never read this skill,
and a repo with worktrees in two places is worse off than one with them in the
"wrong" place consistently.

The same applies to the repo owner — see "Project configuration" in
`../SKILL.md`. There is no default owner: read it from the remote, and ask
when there isn't one. A work repo is not a personal repo.

**Git repo check:** Before starting any work, check whether the project is a git repo.

- **If it IS a git repo:** Note its owner (`git remote get-url origin`) — see "Project
  configuration" in `../SKILL.md`. If there is no remote at all, **ask who owns it**;
  do not assume, and do not create one under a guessed owner. Any guidance or finding
  derived from a guessed owner is wrong for the same reason any other ungrounded claim
  is.
- **If it is NOT a git repo:** Ask the user before initializing one. Some projects (notes, config directories,
  documentation collections) may not need git. If they decline, skip worktree isolation and work directly
  in the directory — Phase 4's merge/push steps become simple "ask the user if they want to commit" instead.
- **If the repo has zero commits** (freshly initialized): Create an initial commit (e.g., `git add -A &&
  git commit -m "Initial commit"`) before attempting worktree setup, since git worktrees require at least
  one commit.

### Worktree Isolation

Worktree isolation enables multiple engineering-team sessions to work on different features simultaneously
without interfering with each other or with the main branch.

**Always work in a worktree.** Every phase, every run — including evaluation-only runs that
change no code. There is one exception, and it is physical rather than discretionary: a project
that is not a git repo (and where the user declined `git init`), where a worktree cannot exist
and you work in place. The Discussion workflow is not a second exception — it is exempt only
while it stays read-only, and the exemption lapses at its first edit (`discussion.md`).

The rule is unconditional on purpose. "Worktree only when Phase 3 runs" sounds like a
sensible economy, and it isn't:

- **Other sessions are already running.** Not "may be" — *assume they are*. This is the
  premise the whole rule rests on rather than one consideration among three, and it is
  stated in full at `../SKILL.md` §"You are never the only session". The main checkout is
  shared state; a worktree is not. You cannot check whether the repo is quiet, because the
  session that collides with yours may not have started yet.
- **Work grows.** An evaluation that turns up a one-line fix becomes a code change, and the
  session is now editing the main checkout with no branch to put it on.
- **Never work on `main`.** The main checkout usually has `main` checked out. Work that lands
  there directly has skipped review, CI, and the PR entirely.

**Where things live — do not mix these up:**

| | Location | Why |
| --- | --- | --- |
| Code | the worktree | isolated per session, merged via a PR |
| `$RUN_DIR` | the **main checkout** | survives worktree cleanup; shared by parallel sessions |

Resolve the main checkout with:

```bash
MAIN_CHECKOUT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
```

**Keep `--path-format=absolute`.** Without it the path comes back *relative to the current
directory* — correct where you computed it, silently wrong after any `cd`, and unusable by
another session. A `$RUN_DIR` placed inside a worktree is **deleted by wrap-up**, taking the
evaluation report and the plan with it, and it is invisible to every other session. See "The run
directory" in `../SKILL.md`.

**Are you already in a worktree?** `--git-dir` and `--git-common-dir` point at different places
when you are. Compare them **with `--path-format=absolute` on both sides**:

```bash
[ "$(git rev-parse --path-format=absolute --git-dir)" \
  != "$(git rev-parse --path-format=absolute --git-common-dir)" ] && echo "in a worktree"
```

Comparing the bare forms is a real bug, not a style nit: from a subdirectory of the main
checkout, `--git-dir` renders **absolute** and `--git-common-dir` renders **relative**. Same
location, different strings — so the naive comparison decides you are in a worktree whenever you
happen to be standing one directory down. Normalise both sides.

If you already are in one: **work in it; never nest a second worktree inside it.** The inner tree
is orphaned when the outer is removed, and the work splits across two branches so the PR ships
half of it.

**Setup (when using a worktree):**

1. **Look at the main checkout — but do not tidy it.** `git status` tells you what is there;
   it does not tell you *whose* it is. Under the concurrent-sessions premise, uncommitted
   changes in the main checkout belong to another session or to the user until they say
   otherwise, so **report what you found and ask** — never stash, commit, revert, or check
   out on your own initiative. Most of the time the answer is "leave it and carry on": the
   worktree branches from `HEAD`, not from the dirt, so a dirty main checkout does not block
   you. It is a signal, not a chore.
2. **Choose the name — and check it is free before you take it.** Prefix it with `eng-` so
   engineering-team worktrees are identifiable, and pick a kebab-case name that describes the
   work (e.g. `eng-security-fixes`, `eng-fitness-tier-plan` — not `eng-work-1`). When an
   improvement plan exists, use `eng-<plan-short-name>` (the `plan:` value from the plan
   frontmatter) so the worktree is traceable to the plan — this is the form Phase 3 specifies.

   **On a multi-lane run, append the lane:** `eng-<plan-short-name>-<lane>`, and use the name your
   hand-off prompt gave you. Every lane reads the same plan, so a name derived from the plan alone is
   identical across all of them and every session after the first collides on an existing branch. See the
   table in `../phases/phase-3-development.md`.

   Then check it, **before** creating anything: `git branch --list '<name>'` and
   `git worktree list`. The lane suffix is what makes a multi-lane name unique; a solo run has
   no suffix, so its plan-derived name is exactly the one another session would have picked
   too. If the name is taken, append a short discriminator — do **not** reuse or delete it. An
   existing `eng-*` branch is someone's live work until proven otherwise.
3. **Enter the worktree.** Use the `EnterWorktree` tool with the name you just cleared. Worktrees
   always live under `<repo>/.claude/worktrees/<name>/` (this is where `EnterWorktree` places them
   — never use ad-hoc sibling paths). The tool creates the branch and switches the session into the
   worktree directory.
4. **Note the branch name.** The `EnterWorktree` tool will report the branch name it created. You MUST
   remember this — you will need it later for the merge step.

When in a worktree: all **code, docs, tests, and journal entries** are written inside the
worktree and merged via a PR. `main` stays untouched until that PR merges.

When NOT in a worktree (non-git project only): work happens directly in the project directory,
and Phase 4 simplifies to committing and optionally pushing.

**Important — two different roots.** `/docs/` and `/journal/` are relative to the **worktree**
(they are committed content, and belong in the branch). `$RUN_DIR` is **not**: it lives under
`.engineering-team/runs/manual-<utc>/` in the **main checkout**, and is referenced by absolute
path. Do not create a second `.engineering-team/` inside the worktree.

Write internal working documents (reports, notes, intermediate analysis) under `$RUN_DIR/`.
The `.engineering-team/` parent is working state, not a deliverable — add it to the project's
`.gitignore` if it isn't there already.

All project-facing documentation goes in `/docs/`. The development journal goes in `/journal/` with filenames
like `250321-descriptive-name.md` (YYMMDD format). Create these directories if they don't exist.

### Stale-base pushes silently revert merged work

Worktrees isolate files completely — parallel sessions do not clobber each
other's edits. The one thing they cannot isolate is **shared history**, and
there is exactly one way concurrent sessions actively damage each other through
it: a commit whose **parent already contains** what `origin/main` gained while
its **tree does not**. Merging or squashing that commit **deletes another
session's merged files**, and every check passes on the reverting tree, so
nothing downstream catches it. This has bitten a real repo: a soft-reset
reverted another PR's files with all checks green.

`git reset --soft` is the sharp edge, because it moves the parent and leaves the
worktree alone. Reset onto a *freshly-fetched* `origin/main` from a stale tree
and the next commit claims main's tip as its parent while carrying a tree that
predates it — reproduced, and the peer's file is gone after the merge. Reset
onto a *stale* ref is not this bug: the merge base is then the stale commit, so
a merge preserves everything added after it (also reproduced). The hazard is a
fresh parent over a stale tree, not a stale ref, and knowing which is which is
what keeps the check below pointed at the real thing.

**The rule, and it is the load-bearing part:** branch from a freshly-fetched
`origin/main`, and before every push read what the push actually changes and
compare it against the unit's declared file footprint (`multi-session.md` §3).

```bash
git fetch origin main
git diff --name-status origin/main...HEAD    # exactly what this branch changes
```

Every path outside the footprint is a candidate silent reversion, whichever
letter precedes it: a `D` drops a file, and an `M` on a file the unit never
claimed rewinds someone else's edit. The footprint is what makes the judgement
mechanical — without it there is no way to tell an intended change from a
reversion, because on the diff they look identical.

**Use the three-dot diff (`origin/main...HEAD`), not two-endpoint
(`origin/main HEAD`).** Three-dot diffs from the merge base, which is exactly
what a merge or a squash applies to `main`, so it is the set of changes that can
revert a peer. Two-endpoint additionally lists every file `main` gained or
changed since your fork point, as `D` and `M` lines you never authored:

```
$ git diff --name-status origin/main HEAD      # two-endpoint, on a branch merely behind
A  f.txt
D  peer1.py                                    # merged by a peer after the fork point
D  peer2.py                                    # both survive the merge untouched
$ git diff --name-status origin/main...HEAD    # three-dot: this branch's one change
A  f.txt
```

Both `D` lines above are noise. Verified by merging that branch: `peer1.py` and
`peer2.py` survive, because a merge and a squash both work from the merge base.
**Being behind `origin/main` is the normal state** under disjoint lanes, where
PRs merge in any order with no rebases, so reading those `D` lines as reversions
turns every push into a rebase of already-pushed history — which discards the
remote tip, and discards a peer's commits outright if one has pushed to that
branch. Three-dot still sees every real reversion: a branch can only revert
content that existed at the merge base, and content merged after it is
preserved.

**Optional backstop — a committed `pre-push` hook.** The footprint comparison
above catches what the hook cannot, so the hook is a backstop, not a
replacement. Ship it in the project as `.githooks/pre-push` and **prove each
branch of it before relying on it** (`general-guidelines.md` rule 1: a gate
ships with a test proving it goes red).

Activate it per clone with `git config core.hooksPath .githooks`. **That setting
replaces `.git/hooks/` wholesale**, so in a repo running husky or `pre-commit` it
silently stops the existing hooks from firing — confirmed by installing a
`.git/hooks/pre-push` alongside it and watching it never run. In such a repo,
register this script through the framework already in place instead.

```sh
#!/bin/sh
# Warn before a push whose tree reverts work already on the base branch, and
# block a push that discards remote commits this clone has never seen.
remote="$1"
# Derive the null oid rather than writing 40 zeros: a SHA-256 repo uses 64, and
# a hardcoded 40 makes every comparison below miss.
zero=$(git hash-object --stdin </dev/null | tr '0-9a-f' '0')

branch=$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null)
branch=${branch#"$remote"/}
base="$remote/${branch:=main}"
git fetch -q "$remote" "$branch" 2>/dev/null || stale=1
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  # Name which it is. A guard that could not run must never read as one that ran.
  heads=$(git ls-remote --heads "$remote" 2>/dev/null) || {
    echo "pre-push: $remote is unreachable, so the stale-base guard did NOT run." >&2
    exit 1
  }
  [ -n "$heads" ] || exit 0 # empty remote: the first push can revert nothing
  echo "pre-push: $base does not exist, so the stale-base guard did NOT run." >&2
  echo "Name the base branch with: git remote set-head $remote -a" >&2
  exit 1
fi
[ -n "$stale" ] && echo "pre-push: could not fetch $base; comparing against a stale copy." >&2

status=0
while read -r _local_ref local_sha _remote_ref remote_sha; do
  # A branch deletion sends an all-zero local sha. It rewrites no tree, and the
  # ancestry test below errors on the null oid, so skip the ref.
  [ "$local_sha" = "$zero" ] && continue

  # Rewriting the remote tip. Discarding commits this clone does not have means
  # another session pushed them, so block. Discarding commits it does have is
  # the rebase-then-force-with-lease flow this section prescribes, so pass it.
  if [ "$remote_sha" != "$zero" ] &&
    ! git merge-base --is-ancestor "$remote_sha" "$local_sha" 2>/dev/null; then
    if git cat-file -e "$remote_sha^{commit}" 2>/dev/null; then
      echo "pre-push: this drops $(git rev-list --count "$local_sha..$remote_sha") commit(s) from the remote tip." >&2
      echo "Expected after a rebase. Push with --force-with-lease, never plain --force." >&2
    else
      echo "pre-push: the remote tip $remote_sha is not in this clone." >&2
      echo "Another session pushed there. Fetch, rebase onto it, and do not force." >&2
      status=1
    fi
  fi

  # A merge or a squash applies the three-dot diff, so what it can drop is what
  # this push deletes relative to the merge base, plus what both sides touched
  # since it. Both sets are empty on a lane whose footprint is disjoint.
  deleted=$(git diff --name-only --diff-filter=D "$base...$local_sha")
  contended=$(
    git diff --name-only "$base...$local_sha"
    git diff --name-only "$local_sha...$base"
  )
  contended=$(printf '%s\n' "$contended" | sed '/^$/d' | sort | uniq -d)
  overlap=$(printf '%s\n%s\n' "$deleted" "$contended" | sed '/^$/d' | sort -u)
  if [ -n "$overlap" ]; then
    echo "pre-push: files this push rewrites that $base already carries:" >&2
    echo "$overlap" | sed 's/^/  /' >&2
    echo "Any one outside this unit's file footprint is a silent reversion." >&2
  fi
done

exit "$status"
```

**Be honest about the hook's reach.** It hard-blocks exactly one thing: a push
that discards remote commits this clone has never seen, which is another
session's push and is unrecoverable from here. Everything else prints and
proceeds, and that is deliberate — a hook cannot see `--force-with-lease`, so
every stricter block fires on the rebase this section prescribes and teaches
`--no-verify`, which disables the whole hook.

**One reversion shape stays invisible to it.** When the branch already contains
the base tip and rewinds a file's *content* rather than deleting it, the diff is
indistinguishable from an ordinary edit: nothing in git says which version was
meant. Reproduced — a session soft-reset onto a fresh `main` from a stale tree,
reverting a peer's edit to a shared file, and the hook printed nothing while the
footprint comparison named the file immediately. The hook is also bypassable and
opt-in per clone. Rank them accordingly: footprint comparison first, hook
second.

### Linter Setup

**New projects (you just ran `git init`):** Set up a linter as part of project initialization. Choose the
appropriate linter for the project's primary language:
- **Python:** `ruff` (configure in `pyproject.toml` with `[tool.ruff]` section)
- **JavaScript/TypeScript:** `eslint` (with a flat config `eslint.config.js`)
- **Go:** `golangci-lint` (with `.golangci.yml`)
- **Rust:** `clippy` is built-in, but add a `clippy.toml` if custom rules are needed
- **Ansible/YAML:** `ansible-lint` (with `.ansible-lint`)

Use sensible defaults — don't over-configure. The goal is a working linter with reasonable rules that the
user can customize later. Add a lint command to the `Makefile` if one exists (or create a simple one).

### Documentation gates (new projects)

When scaffolding a new project, also set up the machine half of the
anti-doc-rot strategy — so living docs cannot silently drift:

- **Link check** — a CI job (e.g. `lychee --offline --include-fragments`) that
  fails on broken internal links **and broken `#anchors`** across `*.md`.
- **Freshness / status-stamp check** — a CI job that asserts every living doc
  carries the status stamp (see `documentation-model.md` §8),
  **parses the `Last verified` date, and fails when the doc is due.** Due is
  driven by **change, not by the calendar** (rules below). Point-in-time docs
  (`/docs/adr/`, `/docs/rfc/`, `/journal/`) are excluded **by path**, not by
  judgement.
- **Stamp size check** — a CI job that fails when a status stamp exceeds a
  character budget (~600 to start; see `documentation-model.md` §8). Measure the stamp **paragraph** — the contiguous non-blank lines
  beginning at the `**Status:**` line — not the single line, or soft-wrapping
  dodges the budget. A genuine blank line ends it, so body prose under a heading
  stays uncharged; that is correct. The goal is not shorter documents, it is that
  narrative stops masquerading as verified current state.

  **Ratchet, never raise.** Land the threshold where it reds documents that
  already exist, so the migration lands in the same change and the gate is real
  from its first run; tighten it later. Raising the budget to turn a red doc
  green converts the gate back into decoration — the overflow is content that
  belongs in another document, and moving it is the fix.
- **Runbook-executed-in-CI** — where a local-parity/setup runbook exists, make
  its steps the same steps CI runs, so a stale step turns CI red.

**Parse the date. A presence-only stamp check is decoration.** The obvious
implementation greps for the three field labels and stops there — at which point
`Last verified: 2019-01-01` passes forever, and so does `Last verified: banana`.
A gate against staleness that cannot detect staleness is precisely the "check
that cannot fail" that `general-guidelines.md` warns about, and it fails in the
one place it was built for.

That is not hypothetical, and it survived months in a repo this skill drove: the
gate asserted three literal field labels appeared in a doc's first 15 lines and
did **no date arithmetic at all**, while the project's own testing doc claimed it
"flags ones gone stale past a window" — a claim stamped as verified *against the
workflow that calls the gate*, which establishes that CI invokes it and never
what it detects (`general-guidelines.md` rule 2).

Build it to these rules:

- **Stale means changed, not old.** Elapsed time is a proxy for drift and a poor
  one. A fixed window reds accurate docs in a dormant repo and passes rotten ones
  in a busy one — and worse, it teaches re-stamping on a schedule, where the
  cheapest way to clear a due list is to bump the date without re-checking
  anything. That is the false-verification failure this whole convention exists
  to prevent, manufactured by the gate meant to stop it. Drive it off the repo:

  ```bash
  git log --since="<Last verified>" -- <paths the doc covers>
  ```

  Empty means the doc cannot have drifted from code change, at any age.
  Non-empty means it is due however recent the stamp. It self-scales: no commits,
  nothing due; forty commits a week and the runbooks come due in days.
- **A doc declares what it covers.** Add an optional
  `**Covers:** <paths-or-globs>` field to the stamp so the gate knows what to
  diff against. It has to be declared because it is not derivable — unlike
  `Path`, which was, and which is why that field was removed. Omitting it is
  allowed and costs the precise signal: an undeclared doc falls back to the
  backstop below.
- **Keep a long clock only for what git cannot see.** Runtime claims rot with no
  commit at all — a SKU retired, an API version sunset, a model deprecated,
  a service decommissioned. So a doc making runtime claims is *also* due after a
  long fixed period: **6–12 months, not 90 days.** That is the only legitimate
  use of wall-clock here. Note that the two signals land exactly on the two claim
  kinds this skill already separates: **doc- and code-derived claims go stale on
  change; runtime claims go stale on a clock**, because only one of them has a
  commit to hang off.
- **Unparseable is red, never skipped.** The hole is a regex that doesn't match
  and a gate that shrugs. A malformed date, a missing field, and `banana` must
  all fail: absence of a parse is not a pass.
- **`not yet — <reason>` has to expire.** The stamp convention permits it before
  first verification, so the gate must accept it — but bounded against `Last
  updated`, or it becomes a permanent parking space that is a legal value
  forever. An exemption must expire by itself (`general-guidelines.md` rule 4).
- **Ship a test per hole, not one happy path**: a doc whose covered paths changed
  since `Last verified` goes red, an unparseable date goes red, an aged-out
  `not yet` goes red, and a doc in an untouched repo stays **green** however old
  it is — that last one is what pins the design, and a calendar-based gate fails
  it. A scanner that matches nothing passes loudest when it is blind.

**A shared-singleton runtime doc has no change signal — plan for it, don't gate
it.** A doc whose `Covers:` is a runtime fact (`runtime:azure-dev`) matches no
path, so the change-driven query above never marks it due, and the long runtime
clock is too coarse for a value that turns over every deploy. Neither signal
fits, so the gate degrades to "the stamp exists." Do not read that as covered:
such a doc is taken out of per-feature-session hands and automated or
single-owned instead — `documentation-model.md` §9. The gate is not the backstop
here; the writer model is.

These complement the wrap-up living-docs reconciliation step (Phase 4) and the
per-unit "docs touched?" check (Phase 3): the gates are the machine enforcement,
those steps are the human judgement. See `documentation-model.md` for what
counts as living.

### Making a check required (the laws that stop you wedging the repo)

A gate that isn't a required status check blocks nothing. But **promoting a
check to required is the step that can deadlock every open PR at once**, so it
has an order of operations, and it is not optional.

**1. Prove it reports, then require it.** Land the workflow change, watch a real
PR — specifically one that does **not** touch the paths the job cares about —
and confirm the check actually appears and reports. Only then add it to the
ruleset. Requiring first and verifying after risks blocking every PR
simultaneously, *including the one that would fix it*.

**2. Path-filtered ⇒ un-requirable.** A workflow filtered by
`on.pull_request.paths` never *starts* on a PR that misses the filter. No check
by that name is created, so a required context waits at "Expected — Waiting for
status" **forever**. The trap is asymmetric: everything looks fine on PRs that do
touch the path, and only unrelated PRs hang.

> The companion rule, which looks identical and behaves oppositely: a **job**
> skipped by an `if:` still reports (as `skipped`, which counts as success). A
> **workflow** skipped by a path filter reports nothing and blocks forever.
> Keep the trigger unfiltered and make the expensive **steps** conditional —
> never the trigger, never the job.

**3. The check's name is the job's `name:`, or its key when absent — never the
workflow's name.** Two workflows with a same-named job produce two
indistinguishable contexts. Keep job keys unique repo-wide for anything running
on `pull_request`.

**4. Promote an aggregator, not the legs.** Where jobs run in parallel or in a
matrix, add one aggregator job that passes iff the legs did, and require *that*.
Its name stays stable across parallelisation and matrix changes; requiring
`test (3.12)` directly means a ruleset edit every time the matrix moves.

**5. Never require a check that doesn't exist yet** — it deadlocks every merge,
including the PR that would create it.

**6. Required ≠ enabled. Re-read the ruleset; don't trust the write.** A red
check looks identical whether or not it is required — the ruleset is the only
source of truth. This is how a real repo ran lint, types, and tests
red-but-advisory for six days without noticing: a ruleset edit was reverted, and
the required check went with it. When reverting a ruleset change, check what else
was in the same edit. Verify by re-reading the remote (`gh api
repos/{owner}/{repo}/rulesets`), never by trusting the response to the write.

### Gate the code that no other gate reads

When scaffolding or evaluating CI, inventory the code that **ships but that no
gate executes**, and gate it. The usual suspects:

- Dockerfiles built only at deploy time (add a build-only CI job).
- `workflow_dispatch`-only workflows — nothing runs them on the way to `main`.
- Scripts embedded in workflow YAML (heredocs): no linter reads them, no type
  checker types them.
- IaC, cron jobs, migration hooks.

The rule to hold onto: **a green PR is not evidence about the deploy path.**
Every defect in dispatch-only code is latent until an operator deploys, which is
a slow and expensive way to find out. Related: name any invariant that **only
holds in the deployed environment** (a role split that exists only in prod, a
grant that local tests can't see), so that a green local suite is not mistaken
for coverage it doesn't have.

**Existing projects:** Check for a linter during Phase 1 (see `../phases/phase-1-evaluation.md`). If none is found, ask the user
whether they'd like one set up before proceeding with the evaluation.
