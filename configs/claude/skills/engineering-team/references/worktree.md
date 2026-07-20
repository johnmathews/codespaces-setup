# Worktree and linter setup

> Loaded by phase docs (especially Phase 3) when worktree creation, linter
> detection, or working-directory invariants are relevant.

## Working Directory

The target repo is the current working directory unless the user specifies another path.

**Git repo check:** Before starting any work, check whether the project is a git repo.

- **If it IS a git repo:** Note its owner (`git remote get-url origin`) — see "Project
  configuration" in `../SKILL.md`. If there is no remote at all, ask the user to confirm
  before creating one under the default owner. Do not assume a repo belongs to
  `johnmathews`; on a work project it does not, and guidance derived from that
  assumption is wrong.
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
change no code. There is one exception: a project that is not a git repo (and where the user
declined `git init`), where a worktree is not possible and you work in place.

The rule is unconditional on purpose. "Worktree only when Phase 3 runs" sounds like a
sensible economy, and it isn't:

- **Work grows.** An evaluation that turns up a one-line fix becomes a code change, and the
  session is now editing the main checkout with no branch to put it on.
- **Sessions overlap.** Another session may be working while yours runs. The main checkout is
  shared state; a worktree is not.
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

1. **Ensure main is clean.** Check `git status` — if there are uncommitted changes on the current branch,
   ask the user how to handle them before proceeding (stash, commit, or abort).
2. **Enter a worktree.** Use the `EnterWorktree` tool with a descriptive name based on what the user asked
   for (e.g., `eng-security-fixes`, `eng-test-coverage`, `eng-docs-update`). When an improvement plan
   exists, use `eng-<plan-short-name>` (the `plan:` value from the plan frontmatter) so the worktree is
   traceable to the plan — this is the form Phase 3 specifies. Worktrees always live under
   `<repo>/.claude/worktrees/<name>/` (this is where `EnterWorktree` places them — never use ad-hoc
   sibling paths). Prefix the name with `eng-` so engineering-team worktrees are identifiable, and choose
   a kebab-case name that describes the work (e.g., `eng-fitness-tier-plan`, not `eng-work-1`). The tool
   creates a new branch and switches the session into the worktree directory.

   **On a multi-lane run, append the lane:** `eng-<plan-short-name>-<lane>`, and use the name your
   hand-off prompt gave you. Every lane reads the same plan, so a name derived from the plan alone is
   identical across all of them and every session after the first collides on an existing branch. See the
   table in `../phases/phase-3-development.md`.
3. **Note the branch name.** The `EnterWorktree` tool will report the branch name it created. You MUST
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
  carries the status stamp (see the router's "Living-document status stamp"),
  **and that parses the `Last verified` date and fails past a staleness window**
  (~90 days to start; rules below). Point-in-time docs (`/docs/adr/`, `/docs/rfc/`,
  `/journal/`) are excluded **by path**, not by judgement.
- **Stamp size check** — a CI job that fails when a status stamp exceeds a
  character budget (~600 to start; see the router's "Living-document status
  stamp"). Measure the stamp **paragraph** — the contiguous non-blank lines
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

Build it to these four rules:

- **A concrete window, ratcheted.** ~90 days is a sane starting target. Land it
  wide enough that one honest re-verification pass can get the repo green, then
  tighten. Same law as the size budget: **never widen the window to turn a red
  doc green** — that red is the gate reporting that nobody has checked the doc.
- **Unparseable is red, never skipped.** The hole is a regex that doesn't match
  and a gate that shrugs. A malformed date, a missing field, and `banana` must
  all fail: absence of a parse is not a pass.
- **`not yet — <reason>` has to expire.** The stamp convention permits it before
  first verification, so the gate must accept it — but bounded against `Last
  updated`, or it becomes a permanent parking space that is a legal value
  forever. An exemption must expire by itself (`general-guidelines.md` rule 4).
- **Ship a test per hole, not one happy path**: stale date red, unparseable red,
  aged-out `not yet` red. A scanner that matches nothing passes loudest when it
  is blind.

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
