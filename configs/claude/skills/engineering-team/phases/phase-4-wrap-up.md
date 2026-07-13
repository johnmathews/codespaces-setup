# Phase 4: Wrap up

> Loaded when the last work unit of the improvement plan has been
> reported done and no open units remain.

## Announce the phase

Before any other action in this phase, tell the user in one plain-prose
line that you are entering Phase 4 (wrap-up).

## How the phase ends

Phase 4 always ends with an explicit closing statement to the user:
either the cycle is complete (plan exhausted, work merged, CI green), or
work remains for a follow-up session — in which case produce the
copy-paste next-session prompt from Step 5b below.

---

After all engineering team phases are complete, this phase handles committing, merging, pushing,
and CI verification. Do not ask the user whether to run this phase — it runs automatically as
the final step of every engineering team invocation.

### Step 1: Run `/done` (mandatory)

Run the `/done` skill to get all quality checks: CI/CD verification, documentation updates, tests,
security scanning, code review, linting, journal entry, and committing.

**`/done` is mandatory and cannot be skipped.** Not running `/done` is a contract violation of the
wrap-up phase, even when work appears to be already committed and tested. `/done` runs many phases
(sanity → CI/CD config → docs → tests → security → code review → lint → journal → commit → push),
and several of them — security scan, code review, lint — typically have **not** been run by the
unit-by-unit development loop. Skipping `/done` silently skips those checks.

**"Don't push" does not mean "don't run /done".** If the user has told you not to push (e.g., they
want to review the merge before publishing), that constrains only the final push step inside `/done`.
Every other phase of `/done` still runs. The same applies to "don't merge", "don't open a PR", and
other narrow constraints — they constrain a single step, not the whole skill. Do not infer broader
permissions from narrow restrictions.

Adapt `/done` to the project type:
- **Non-coding projects** (documentation repos, config collections, Ansible playbooks, notes):
  skip tests if no executable code exists; only lint if a relevant linter exists.
- **Mixed projects** (e.g., some code + mostly config/docs):
  apply test/lint only to executable code portions.

After `/done` completes, verify:
1. `git status` shows a clean working tree (zero uncommitted changes).
2. `git log --oneline main..HEAD` shows clean, well-described commits.
3. The journal entry was written by `/done` (not by you manually before invoking it).

### Step 1.5: Living-docs reconciliation (mandatory before merge)

Before merging, do a forced reconciliation of the change against the project's
**living docs** — the docs that describe current truth and actively mislead when
stale: the README, the spec, runbooks, and any controls/security registers
(`/docs/`), plus CLAUDE.md.

1. Diff the branch against `main` (`git diff --stat main..HEAD`) and identify
   any change to public APIs, env vars, config, setup steps, deploy steps,
   commands, or documented behaviour.
2. For each such change, name **which living doc describes it** and confirm that
   doc was updated in this branch. List them explicitly, e.g.
   "changed deploy step → `docs/runbooks/deploy.md` updated ✓".
3. If a living doc was affected but **not** updated, update it now (in this
   branch, before merge) and bump its `Last verified` / `Last updated` stamp.
4. If nothing living was affected, say so explicitly — do not let it pass
   silently. "No living docs affected by this change" is a required statement,
   not an omission.

This is the human-side complement to the CI doc-freshness gate: the gate catches
broken links and missing stamps; this step catches a doc that is still
well-formed but no longer *true*.

### Step 2: Merge, Push & Cleanup

Run `/merge-push` to handle merging into main, pushing, and worktree cleanup. `/merge-push` will
assess the branch state, check for conflicts, and ask for explicit confirmation before merging
and before pushing.

### Step 3: Monitor CI

After pushing, **always watch the GitHub Actions CI workflow** to confirm it passes:

1. Run `gh run watch` to monitor the triggered workflow.
2. If CI passes, proceed to the summary.
3. If CI fails:
   a. Read the failure logs with `gh run view <id> --log-failed`.
   b. Diagnose the root cause.
   c. Write a failing test that reproduces the issue (when applicable).
   d. Fix the code, run the full test suite locally, commit, and push.
   e. Watch CI again. Repeat up to 3 times. If still failing, flag to the user.

Do not consider the work complete until CI is green. This is not optional.

### Step 4: Summary

Present a brief summary to the user:
- What was evaluated/planned/implemented
- The merge commit hash (from `git log -1 --oneline`)
- CI status (passed / failed + what was fixed)
- Any issues encountered during wrap-up

Then clear the run pointer: `rm -f .engineering-team/current.txt` (in
the project root, not the worktree). The cycle is complete — leaving the
pointer in place would make the next invocation "resume" this finished
run instead of starting fresh. Do NOT clear it when the run ends early
(partial cycle, or a pause still outstanding) — the pointer is what lets
a later session resume.

### Step 5: Next-unit handoff (when iterating through a plan)

This step fires when the user is executing **work units from a multi-unit plan** —
e.g. a tier plan, a roadmap, or a refactor plan with W1, W2, W3... — and there is
a clearly identifiable *next* unit. Skip this step for one-shot evaluations,
discussions, or open-ended improvements where there is no "next unit" to hand off.

**Trigger conditions (all must hold):**
1. The work just completed was scoped to a specific work unit (or contiguous
   units) of a persistent plan in `docs/`.
2. The plan has a next work unit that the user is likely to want done.
3. The user has not already indicated they're stopping for the day or moving
   to unrelated work.

**What to do, automatically — do not wait for the user to ask:**

#### 5a. Assess fresh-session vs continue

Make a deliberate call about whether the next unit should be done in **this**
session or a **fresh** one. State the recommendation and the reasoning to the
user. Be honest — if it's a close call, say so.

**Lean toward continue when:**
- The next unit is in the same module, layer, or pattern as what just shipped
  (e.g. REST routes → MCP tools that mirror them, repository → service that
  calls it).
- The mental model just used is directly load-bearing for the next unit
  (response shapes, recently-decided contracts, fresh dedup logic that the
  next unit reuses).
- Plan-drift patterns or gotchas just discovered are still warm and would
  speed up the next unit's reconnaissance.
- The session is still in its productive window — context is rich but not
  bloated, and the cache is hot.

**Lean toward fresh when:**
- The next unit is in a different module/layer/surface (data plane → CLI,
  backend → frontend, code → docs) — accumulated context becomes dead weight.
- The next unit requires reading a substantially different set of files than
  what's already in context.
- The next unit changes character (e.g. first unit that needs live
  credentials, first unit that touches production data, first unit with a
  user-visible UI to verify) — worth being deliberate with clear scope.
- The session is long enough that reasoning is degrading or the transcript
  is unwieldy.
- The next unit has a different "done" criterion than the cadence just
  established (e.g. "merged + CI green" → "deployed + smoke-tested").

When in doubt, recommend fresh. The cost of a fresh session with a good
prompt is low; the cost of carrying stale context into work it doesn't fit
is silent quality loss.

#### 5b. If recommending fresh — produce a copy-paste prompt

When recommending a fresh session, produce **a single distinct message**
containing the prompt the user can paste directly into the next session.
This is not a summary — it is the *input* to the next `/engineering-team`
invocation. Put the body in one fenced code block so the user can copy it
cleanly.

The prompt must be self-contained — fresh-session-Claude has no memory of
this conversation, only what the prompt says plus what it can read from
the codebase. Brief it like a smart colleague who just walked into the room.

**Required sections in the prompt** (omit any that genuinely don't apply):

1. **Header** — One sentence naming the work unit and the plan doc that
   defines it (with file path).
2. **State of the world** — Current commit hash on `main`, current test
   count, and a 2-3 sentence summary of what the pipeline / feature / system
   currently does end-to-end. What's wired up, what isn't.
3. **What this unit ships** — One paragraph or short list. The plan has the
   detail; this is the orientation.
4. **Pattern to mirror** — Reference the established cadence (worktree →
   doc → tests → code → suite + lint → journal → merge → push → CI watch →
   cleanup) so the next session doesn't relitigate process decisions.
5. **Recent journal entries to read for context** — Bullet list of the 2-4
   most relevant journal entries (with full paths). These are the onboarding
   pack — they encode the decisions, plan-drift patterns, and gotchas
   accumulated up to this point. Pick the ones that actually inform the
   *next* unit, not the ones nearest in time.
6. **Gotchas to watch for** — Carry forward any cross-unit patterns that
   would otherwise be re-discovered (recurring plan drift, schema
   constraints that keep biting, conventions that aren't in CLAUDE.md).
   When a pattern has happened N times in a row, say so explicitly —
   "this is now the third time" is a stronger signal than "watch for X."
7. **Open questions to think about before coding** — Things the unit's
   plan doesn't fully resolve, where the answer requires reading code that
   the previous session already has loaded but the new one doesn't. Phrase
   as questions, not directives — fresh-session-Claude should make the
   judgment call after reading the relevant code.
8. **Scope notes** — Any explicit out-of-scope items, credential / live-system
   warnings, or "don't bake X into this unit" guidance.

**Tone:** the prompt is operational, not narrative. No lessons-learned
preamble; no "great work last session" framing; no instructions about
how to be a good agent. The new session will read the full skill on
invocation. The prompt's job is to load *this specific unit's* context,
nothing more.

**After producing the prompt message:** end the session naturally. Do not
keep working in the current session unless the user explicitly says to.

#### 5c. If recommending continue — proceed

If you recommended continuing, briefly state the next unit you'd start on
and confirm with the user before launching into it. The user may still
prefer to stop for the day or to switch tasks — recommendation is not
permission.

#### 5d. When there is no next unit — close out

If the trigger conditions for Step 5 do not hold (the plan has no further
work units, the user has stopped for the day, or this run was a one-shot
that did not consume a multi-unit plan), do **not** produce a next-session
prompt. State plainly in the summary that the plan is exhausted and the
cycle is complete.

#### 5e. When user input is needed mid-run — ask and wait

If wrap-up hits a decision that genuinely needs user input (e.g. a merge
conflict resolution with real alternatives, a failing CI fix that changes
scope), stop, ask the user directly, and wait for the answer. Leave the
worktree intact while the question is outstanding so the work can resume
where it left off.

### Simple Wrap-Up (no worktree, no merge needed)

Use this path when no worktree was created (evaluation-only, non-git project, or user declined git).

1. **If this is a git repo:** Run the `/done` skill normally (it handles tests, lint, security scan,
   code review, docs, journal, commit, and push). Adapt it to the project type as described above.
   After pushing, watch CI and fix failures (same Step 3 loop as above).
2. **If this is NOT a git repo:**
   - Tell the user where the output files are (evaluation report, plan, etc.).
   - Ask if they'd like to initialize git and commit the results.
3. **Summary:** Present what was done and where the output files are. If the
   cycle is complete, clear the run pointer (`rm -f .engineering-team/current.txt`).
