# Continuation Prompt

Generate a self-contained prompt the user can copy and paste into a **new** Claude Code session to
continue the current work with zero loss of context. The output is a prompt for a future session —
not a summary for the user, and not an action to perform now. This command is project and stack
agnostic.

## Output Formatting Rule

When presenting recommendations, questions, or conclusions to the user, always use **numbered lists**
(1, 2, 3...) instead of bullet points, so the user can refer to items by number.

## Step 1 — Gather state before writing anything

Do not rely on memory alone. Reconstruct the state-of-the-world from the current conversation *and*
from on-disk artifacts, running these in parallel where possible:

1. **Session context:** Review this conversation to determine what we are doing, the project aims,
   the plan being followed (if any), the current phase (if the work is phased), and what was learned,
   decided, or discovered this session.
2. **Git state:** `git branch --show-current`, `git status --short`, and `git log --oneline -10` to
   capture the branch, uncommitted work, and recent commits.
3. **engineering-team run state:** Check whether this project uses the `engineering-team` skill by
   looking for `.engineering-team/current.txt` and the run directory it names under
   `.engineering-team/runs/`. If present, read the run's artifacts (`evaluation-report.md`,
   `improvement-plan.md`, and anything under `discussions/`) to determine the exact phase, which work
   units are done, and which remain. **Reference these files by path in the generated prompt rather
   than pasting their full contents** — the new session can read them.
4. **Other plan/docs:** Note any other plan files, design docs, journals, or READMEs the work depends
   on so they can be linked in the prompt.

## Step 2 — Ask if anything is unclear

If, after gathering state, the aims, plan, phase, or next steps are ambiguous — or you are unsure what
to include — **ask the user clarifying questions before generating the prompt.** Do not guess or
fabricate context.

## Step 3 — Decide the audience

- If the current session **used the `engineering-team` skill** (e.g. a `.engineering-team/` run
  directory exists, or the skill was clearly active), the next phase very likely uses it too.
  **Address the generated prompt to the engineering-team** and instruct the new session to invoke the
  `engineering-team` skill and resume the in-flight run.
- Otherwise, address it as an ordinary continuation prompt with no skill assumption.

## Step 4 — Emit the prompt

Output the continuation prompt inside a single fenced code block so it is trivial to copy and paste.
Nothing else should be inside that block. The prompt must be self-contained and include, as
applicable:

1. **Purpose & aims** — what we are building and why; the goal of the project.
2. **Skill directive** — if applicable, an explicit instruction to use the `engineering-team` skill,
   addressed to the engineering-team.
3. **Plan & phase** — the plan being followed and which phase we are in, with a pointer to the plan
   file (e.g. `improvement-plan.md`) rather than the full text. State which work units are complete and
   which are next.
4. **State of the world** — current branch, whether there is uncommitted work, and where the code
   stands relative to the plan.
5. **What we learned/discovered this session** — either stated inline (if concise) or a pointer to
   where it is documented (journal entry, discussion file, commit messages).
6. **Gotchas & constraints** — pitfalls, non-obvious decisions, dead ends already ruled out, and any
   conventions the new session must respect.
7. **Links to relevant documentation** — paths to plan/design/reference docs and any external links.
8. **Concrete next action** — the first thing the new session should do.

Keep it complete but not bloated: prefer pointing to on-disk artifacts over duplicating them.

## Step 5 — Confirm

After the code block, briefly (numbered list) tell the user what you included and note anything you
were uncertain about, in case they want to adjust before copying it.
