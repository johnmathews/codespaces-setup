# Worktree and linter setup

> Loaded by phase docs (especially Phase 3) when worktree creation, linter
> detection, or working-directory invariants are relevant.

## Working Directory

The target repo is the current working directory unless the user specifies another path.

**Git repo check:** Before starting any work, check whether the project is a git repo.

- **If it IS a git repo:** Check whether it has a remote on GitHub under the `johnmathews` account. If not,
  ask the user to confirm before creating one.
- **If it is NOT a git repo:** Ask the user before initializing one. Some projects (notes, config directories,
  documentation collections) may not need git. If they decline, skip worktree isolation and work directly
  in the directory — Phase 4's merge/push steps become simple "ask the user if they want to commit" instead.
- **If the repo has zero commits** (freshly initialized): Create an initial commit (e.g., `git add -A &&
  git commit -m "Initial commit"`) before attempting worktree setup, since git worktrees require at least
  one commit.

### Worktree Isolation

Worktree isolation enables multiple engineering-team sessions to work on different features simultaneously
without interfering with each other or with the main branch.

**When to use a worktree:**
- **Phase 3 (Development) will run** — code changes are being made → worktree is REQUIRED.
- **Only Phase 1 (Evaluate) or Phase 1-2 (Evaluate + Plan)** — no code is modified, only reports are
  written to `$RUN_DIR/` → worktree is OPTIONAL. Work directly in the repo unless the user
  asks for isolation.
- **Not a git repo** (and user declined `git init`) → worktree is NOT POSSIBLE. Work directly in the directory.

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
3. **Note the branch name.** The `EnterWorktree` tool will report the branch name it created. You MUST
   remember this — you will need it later for the merge step.

When in a worktree: all work (evaluation reports, code changes, tests, docs, journal entries) happens
inside the worktree. The main branch remains untouched until the final merge in Phase 4.

When NOT in a worktree: work happens directly in the project directory. Phase 4 simplifies to
committing and optionally pushing (no merge or worktree cleanup needed).

**Important:** The `$RUN_DIR/`, `/docs/`, and `/journal/` paths referenced below are
all relative to the project root (or worktree root if using a worktree). `$RUN_DIR` is the
per-run subtree under `.engineering-team/runs/` — `mkdir -p .engineering-team/runs/manual-<utc>/`
on first write and use that path for the rest of the run (see the router's "The run directory"
section).

Write internal working documents (reports, notes, intermediate analysis) under `$RUN_DIR/`.
The `.engineering-team/` parent directory is for the team's use — it can be gitignored by the user
if they prefer.

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

- **Link check** — a CI job (e.g. `lychee`) that fails on broken internal or
  external links across `*.md`.
- **Freshness / status-stamp check** — a CI job that asserts every living doc
  (README, `/docs/` reference docs, runbooks) carries the status stamp (see the
  router's "Living-document status stamp" section) with `Last updated` and
  `Last verified` fields present, and optionally flags ones gone stale past a
  window. Point-in-time docs (`/docs/adr/`, `/docs/rfc/`, `/journal/`) are
  excluded.
- **Runbook-executed-in-CI** — where a local-parity/setup runbook exists, make
  its steps the same steps CI runs, so a stale step turns CI red.

Register each of these as a required status check in branch protection so it
actually blocks merges. These complement the wrap-up living-docs reconciliation
step (Phase 4) and the per-unit "docs touched?" check (Phase 3): the gates are
the machine enforcement, those steps are the human judgement.

**Existing projects:** Check for a linter during Phase 1 (see `../phases/phase-1-evaluation.md`). If none is found, ask the user
whether they'd like one set up before proceeding with the evaluation.
