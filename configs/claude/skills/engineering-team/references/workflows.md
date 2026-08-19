# Workflows reference

> The engineering-team skill supports two workflows: Build (evaluate → plan →
> develop, the default) and Discussion (collaborative exploration without
> code). This file lists both at a high level. For Build phase details, see
> the per-phase docs in `../phases/`. For Discussion, see `discussion.md`.

## Workflows

The engineering team supports two distinct workflows:

1. **Build workflow** (evaluate → plan → develop → wrap-up): For doing work on the codebase.
   Proceeds through Phases 1-4, detailed in the per-phase docs in `../phases/`.
2. **Discussion workflow**: For brainstorming, exploring options, teaching, and building shared
   understanding. No code changes, no commits — and the only workflow that needs no
   worktree, an exemption bought by being read-only which lapses at its first edit.
   See `discussion.md`.

**Which workflow to use:**
- If the user says "evaluate", "plan", "develop", "improve", "fix", "assess", "review", or is
  clearly seeking work done on the codebase → **Build workflow**. This is the default and the
  common case.
- If the user says "discuss", "brainstorm", "help me think about", "what are the tradeoffs",
  "should I use X or Y", "teach me about", "walk me through", "what are my options", "explore
  approaches", "pros and cons", or is clearly seeking understanding rather than action →
  **Discussion workflow**. This holds whether the question opens the session or comes up
  mid-run: a Build run can pause into Discussion and resume. Crossing back the other way
  is not symmetric — a Discussion that starts changing files is a Build run, and the
  worktree comes **before** the first edit (`discussion.md`).
- If ambiguous, ask the user: "Do you want to discuss and explore options, or do you want me
  to evaluate/plan/implement changes?"

**The boundary that matters is the codebase, not the verb.** Discussion earns its place when
the question is grounded in *this* project — what exists today, what would have to change, what
it would cost here. A question with no codebase in play ("what is the state of the art in X",
"compare these three vendors") wants the **deep-research** skill instead: it needs sources and
fan-out, not an engineering team reading code that isn't relevant to the answer.

### Build Workflow Phases

The build workflow proceeds through four phases: evaluation, planning, development, and wrap-up.
The user can invoke a single phase or run the full cycle. When multiple phases run, each phase
must complete before the next begins. Phase 4 (wrap-up) is not separately invoked — it runs
automatically whenever Phase 3 has run.

If the user says "evaluate", run only Phase 1. If they say "plan", run Phases 1-2. If they say
"develop", "improve", or give a general instruction, run the full cycle (Phases 1-4).
