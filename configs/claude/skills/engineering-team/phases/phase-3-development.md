# Phase 3: Development

> Loaded when an improvement plan exists with at least one open work unit.

## Announce the phase

Before any other action in this phase, tell the user in one plain-prose
line that you are entering Phase 3 (development).

## Create a worktree before your first edit

Phase 3 work happens inside a git worktree, not the project's main checkout.
The worktree gives the whole cycle a single mergeable unit and protects
`main` from half-finished states between unit boundaries. The full
discipline lives in `../references/worktree.md` — **load it before your
first edit, not when you remember.**

The short version: use the `EnterWorktree` tool with the name
`eng-<plan-short-name>`, where `<plan-short-name>` is the `plan:` value
from the improvement-plan.md frontmatter. The tool creates the branch,
places the worktree under `.claude/worktrees/`, and switches the session
into it. Only if `EnterWorktree` is unavailable in your environment, fall
back to the manual equivalent:

```bash
git worktree add .claude/worktrees/eng-<plan-short-name> -b eng-<plan-short-name>
cd .claude/worktrees/eng-<plan-short-name>
```

Then (either way) mirror the project's run pointer into the worktree so
tooling and future sessions can find the in-flight artifacts (`<run-id>`
is the basename of `$RUN_DIR`):

```bash
mkdir -p .engineering-team
printf '%s' "<run-id>" > .engineering-team/current.txt
```

If you find yourself running `pytest` or editing files in the
project root rather than under `.claude/worktrees/`, you have skipped this
step — stop, back out, set up the worktree, and start over. Phase 4
wrap-up assumes a worktree exists; without one, the merge step has
nothing to merge and the cycle ends in an uncommitted state.

## Progress reporting (read first)

Phase 3 reports every work-unit transition to the user in plain prose:

- Announce "Starting W<n>: <title>" immediately BEFORE dispatching the
  first subagent for that unit (or, if you handle it yourself,
  immediately before the first edit).
- Announce "W<n> done: <title>" AFTER your lead-engineer review step
  passes and the full test suite is green.
- Announce "W<n> abandoned: <reason>" instead of "done" if the unit
  cannot complete in this session.
- Every started unit must be reported as either done or abandoned before
  the session ends — never leave a unit's status unaccounted for.

## Pausing for user input

If during Phase 3 you encounter a decision that genuinely needs user
input, stop work on the current unit and ask the user directly (use the
AskUserQuestion tool or a plain question), then wait for the answer. Do
not pick on the user's behalf and do not silently continue. Ask when:

1. Architecturally distinct alternatives both have merit and the choice
   has downstream consequences.
2. A change would alter the user's stated non-goals.
3. Anything is irreversible (data deletion, schema migrations not
   authorized by the plan, force-pushes).
4. A public-API change the plan didn't explicitly mandate is needed.

Do NOT pause for: naming/formatting/comment style; two implementations
with identical observable behavior; minor refactors inside a unit that
don't change scope; anything the plan already implicitly authorizes.

## When the LAST unit completes

Completing the final unit in the plan is your cue to enter Phase 4
wrap-up, not your cue to stop. The cycle hasn't ended yet — the worktree
still needs to be merged, the cumulative commit still needs to land on
`main`, and the run needs a summary.

Announce the transition, load `phase-4-wrap-up.md`, and follow its steps.
**Step 1 is to run `/done` — that step is mandatory regardless of how
light wrap-up looks.** Writing a journal entry manually and merging
without `/done` is a contract violation, even if the work is fully
committed and tested. `/done` runs security scan, code review, and lint
that the unit-by-unit dev loop skips.

Stopping directly after the final unit is a bug: it skips the merge, the
commit, and the summary the cycle is supposed to end with, and leaves
uncommitted work stranded in the worktree.

---

The goal is to implement the improvement plan using a test-driven development approach.
Only begin this phase when the plan from Phase 2 is complete and coherent.

### Approach: Documentation First, Then Tests, Then Code

For each work unit in the plan, follow the order appropriate to the work unit's content:

**Code work units** (the work unit modifies or creates executable code):
1. **Documentation:** Write or update the relevant documentation first. This forces
   clarity about what the change should accomplish before writing any code.
2. **Tests:** Write the tests that will verify the change. These tests should fail
   initially (red phase of TDD). For existing test modifications, update tests to
   reflect the new expected behavior.
3. **Code:** Implement the change to make the tests pass. Keep changes minimal —
   make the tests green, nothing more.
4. **Verify:** Run the **full** test suite. All tests must pass before moving to the next unit.

**Bug fix work units** (the work unit fixes a bug found during evaluation or triage):
1. **Reproduce:** Write a failing test that reproduces the exact bug. The test must
   fail before the fix and pass after. This proves the bug exists and prevents regressions.
2. **Fix:** Implement the minimal code change to make the test pass.
3. **Verify:** Run the **full** test suite to confirm no regressions.

**State-transforming work units** (DB migrations, data backfills, file-format
upgrades — anything that reshapes existing persistent data):

The failure mode here is **data-shape, not code-shape** — standard tests verify
the resulting schema, but the real bugs live in data shapes synthetic fixtures
don't reproduce. Apply two extra disciplines on top of normal tests:

1. **Probe the real data first.** Before designing the transform, query the
   actual store (or a snapshot) for anomalies the transform assumes away —
   orphan FK references, NULLs in "populated" columns, duplicates that would
   violate a planned UNIQUE, CHECK violations, encoding oddities, mixed-type
   columns. Real stores accumulate these; synthetic data omits them. If the
   store is untouchable, ask the user to run the probe queries.
2. **Re-runnable from any partial state.** If the runtime doesn't roll back
   mid-transform on failure (SQLite `executescript`, shell scripts, ad-hoc
   fixers), an aborted run leaves leftover state that breaks the next attempt.
   Drop intermediates at the top, use idempotent operations
   (`DROP IF EXISTS`, `INSERT OR IGNORE`), assume any step might fail.

Tests must include at least one "dirty" prod-shaped fixture (orphans, dupes,
partial-failure leftovers) and assert the transform completes. Schema-only
tests on a fresh DB cover the destination, not the journey — say so explicitly
when reporting status.

**Non-code work units** (documentation fixes, config changes, YAML/markdown updates,
CI/CD workflow creation, .gitignore updates, etc.):
1. Make the changes directly.
2. If the change affects something testable (e.g., a CI workflow), validate it where
   possible (e.g., lint the YAML, dry-run the workflow).
3. No TDD cycle needed — do not write tests for markdown or configuration.

### Test Runner Detection

Automatically detect the project's test framework(s):
- Look for `pytest.ini`, `setup.cfg [tool:pytest]`, `pyproject.toml [tool.pytest]` → pytest
- Look for `package.json` with test script, `jest.config.*`, `vitest.config.*` → npm test / jest / vitest
- Look for `go.mod` → go test
- Look for `Cargo.toml` → cargo test
- Look for `Makefile` with test target → make test
- Multiple test runners may coexist (e.g., Python backend + JS frontend)

Run the full test suite after each work unit completes. If tests fail, fix before proceeding.

When running the final test suite after all work units are complete, generate an HTML coverage
report. This is the only time an HTML report is generated (Phase 1 only records the percentage):
- **Python (pytest):** `coverage run -m pytest && coverage html` → `htmlcov/`
- **JS/TS:** `npx c8 --reporter=html` or `nyc --reporter=html`
- **Go:** `go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out -o coverage.html`
- **Rust:** `cargo tarpaulin --out html`

Include the final coverage percentage in the report alongside the Phase 1 baseline for comparison.

### Implementation

Launch subagents to implement work units (dispatch mechanics:
`../references/team-structure.md`). Units without dependencies can run in parallel
using subagents that work on different files. Units with dependencies must run sequentially.
(Note: since the session is already in a worktree, do NOT create nested worktrees for
parallel work units — use subagent parallelism within the single worktree instead.)

Each implementing subagent should:
- Read the specific work unit from the improvement plan
- Follow the doc → test → code order strictly
- Do not assume how existing code works — read it before modifying it
- Do not assume tests will pass — run them and check the actual output
- For browser UI, give meaningful DOM elements stable, descriptive `id`s
  (see the "Stable element ids" rule in `../references/general-guidelines.md`)
  so elements can be discussed and tested precisely
- Run tests after implementation
- Report back: what was done, what tests pass/fail, any issues encountered

As Lead Engineer, review each completed unit before marking it done. Check:
- Does the implementation match the plan?
- Are the tests meaningful (testing behavior, not implementation)?
- Is the documentation accurate and clear?
- Were any unnecessary changes introduced?

**Progress cadence (recap).** For every work unit you touch in this phase:
announce "Starting W<n>: <title>" before dispatching the first subagent (or first
edit), then "W<n> done: <title>" after your review confirms the unit is green, or
"W<n> abandoned: <reason>" if you give up on it. Never leave a started unit
unaccounted for at the end of a session.

### Journal Entry

**Do not write the journal entry here.** The `/done` skill in Phase 4 handles journal writing
(its Phase 7b). Writing it here would create a duplicate. Instead, ensure the work done during
Phase 3 is captured in the conversation context so `/done` can include it in the journal.

If NOT using `/done` (e.g., non-git project with Simple Wrap-Up), write the journal entry here:

Filename format: `YYMMDD-descriptive-name.md` (e.g., `250321-security-fixes-and-test-coverage.md`)

The journal entry should document:
- What was changed and why
- Key decisions made during implementation
- Issues discovered during development that weren't in the original plan
- Test coverage changes
- Infrastructure and tooling changes
- Any remaining concerns or follow-up items
