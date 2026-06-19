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
   understanding. No code changes, no worktrees, no commits. See `discussion.md`.

**Which workflow to use:**
- If the user says "discuss", "brainstorm", "help me think about", "what are the tradeoffs",
  "should I use X or Y", "teach me about", "walk me through", "what are my options", "explore
  approaches", "pros and cons", or is clearly seeking understanding rather than action → **Discussion workflow**
- If the user says "evaluate", "plan", "develop", "improve", "fix", "assess", "review", or is
  clearly seeking work done on the codebase → **Build workflow**
- If ambiguous, ask the user: "Do you want to discuss and explore options, or do you want me
  to evaluate/plan/implement changes?"

### Build Workflow Phases

The build workflow proceeds through four phases: evaluation, planning, development, and wrap-up.
The user can invoke a single phase or run the full cycle. When multiple phases run, each phase
must complete before the next begins. Phase 4 (wrap-up) is not separately invoked — it runs
automatically whenever Phase 3 has run.

If the user says "evaluate", run only Phase 1. If they say "plan", run Phases 1-2. If they say
"develop", "improve", or give a general instruction, run the full cycle (Phases 1-4).
