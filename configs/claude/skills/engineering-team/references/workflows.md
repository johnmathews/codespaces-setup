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
- If the user says "evaluate", "plan", "develop", "improve", "fix", "assess", "review", or is
  clearly seeking work done on the codebase → **Build workflow**. This is the default and the
  overwhelmingly common case.
- **Discussion workflow** only when the user has *already engaged this skill* and wants to
  explore before committing — "let's discuss the architecture before I commit to a plan", a
  tradeoff question raised mid-run, or an explicit ask for the engineering team to weigh
  options. It exists so a Build run can pause into exploration without losing the team framing.
- If ambiguous, ask the user: "Do you want to discuss and explore options, or do you want me
  to evaluate/plan/implement changes?"

**Do not enter this skill for a standalone brainstorming or "should I use X or Y" question.**
The skill's own trigger description excludes those, and it is right to: a cold tradeoff question
needs research, not an evaluate-plan-develop cycle. Those belong to the brainstorming and
research skills. Discussion is an *in-run* mode, not a front door — routing a cold question here
loads four phases of build machinery to answer something that needed none of it.

### Build Workflow Phases

The build workflow proceeds through four phases: evaluation, planning, development, and wrap-up.
The user can invoke a single phase or run the full cycle. When multiple phases run, each phase
must complete before the next begins. Phase 4 (wrap-up) is not separately invoked — it runs
automatically whenever Phase 3 has run.

If the user says "evaluate", run only Phase 1. If they say "plan", run Phases 1-2. If they say
"develop", "improve", or give a general instruction, run the full cycle (Phases 1-4).
