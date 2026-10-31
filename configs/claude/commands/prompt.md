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
   looking for `.engineering-team/current.txt` **in the main checkout** — the run dir lives there,
   not in a worktree, so resolve it with
   `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"` (keep
   `--path-format=absolute`, or you get a path relative to your cwd that the next session cannot
   use) — and the run directory it names under `.engineering-team/runs/`. If present, read the run's artifacts (`evaluation-report.md`,
   `improvement-plan.md`, and `progress.md` / `status-*.md` if the run has lanes) to determine the
   exact phase, which work units are done, and which remain. **Reference these files by absolute path
   in the generated prompt rather than pasting their full contents** — the new session can read them.
4. **Other plan/docs:** Note any other plan files, design docs, journals, or READMEs the work depends
   on so they can be linked in the prompt.

## Step 2 — Ask if anything is unclear

(When a sitrep triggered the hand-over, don't stop to ask. Write the prompt, and list what is
uncertain in Step 5, so the user can correct it before starting the new session.)


If, after gathering state, the aims, plan, phase, or next steps are ambiguous — or you are unsure what
to include — **ask the user clarifying questions before generating the prompt.** Do not guess or
fabricate context.

## Step 3 — Decide the audience

- If the current session **used the `engineering-team` skill** (a `.engineering-team/` run
  directory exists, or the skill was active in this conversation), **the new session must use it
  too.** This is not a judgement call. A new session that starts without the skill skips the
  worktree, `run.yaml` and the gates, and does the work outside the run it was meant to continue.
  So:
  1. **Start the prompt with `/engineering-team`** as its first word. Pasted as a message, that
     loads the skill before anything else is read; an instruction later in the prompt to "use the
     skill" can be missed.
  2. Name the run to resume: its id and the absolute path of its `$RUN_DIR`.
  3. Address the rest of the prompt to the engineering-team.
- **If you are writing a lane hand-off** (the run has `progress.md` and you are the coordinator
  dispatching a parallel lane), see Step 4b — the shape is different.
- Otherwise, address it as an ordinary continuation prompt with no skill assumption.

## Step 4 — Write the prompt

Write the prompt to a markdown file, then show it. The file is the hand-over; the code block is a
convenience. A long block copied out of a terminal can pick up wrapped lines, while a file can be
read whole.

**Where the file goes:**

- In an engineering-team run: `$RUN_DIR/handover-<utc-timestamp>.md`, in the main checkout, next to
  the run's other state.
- Otherwise: `~/.claude/handovers/<repo-or-directory-name>-<utc-timestamp>.md`. Create the directory
  if needed.

Use absolute paths everywhere in it. The prompt must be self-contained and include, as applicable:

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
6. **Gotchas & things to remember** — pitfalls, non-obvious decisions, dead ends already ruled out
   and why, preferences the user stated in this conversation, anything the user said not to do, and
   conventions the new session must respect. This is the section a new session cannot rebuild from
   the files, so spend the effort here.
7. **Links to relevant documentation** — paths to plan/design/reference docs and any external links.
8. **Concrete next action** — the first thing the new session should do.

Keep it complete but not bloated: prefer pointing to on-disk artifacts over duplicating them.

**Then show it in two forms**, so the user can pick whichever pastes more easily:

1. **A one-line version** in a fenced code block, which tells the new session to read the file.
   It is the safer paste, so it comes first:
   - engineering-team: `/engineering-team Resume run <run-id>. Read <absolute path of the handover file> first and follow it.`
   - otherwise: `Read <absolute path of the handover file> first and follow it.`
2. **The full prompt** in a single fenced code block, with nothing else inside the block. It is
   for a session that can't read the file, such as one on another machine. **When a sitrep
   triggered the hand-over, leave this block out**: the sitrep stays one screen, and the file holds
   the full text.

If the machine has a clipboard command (`pbcopy` on macOS, `wl-copy` or `xclip` on Linux), copy the
one-line version to the clipboard and say so. In a Codespace there usually isn't one; skip it
silently.

## Step 4b — Lane hand-off prompts (multi-session runs)

When the coordinator is dispatching parallel lanes, generate **one prompt per lane**, each in its
own fenced code block, ready to paste into a fresh session. These are not continuation prompts —
the receiving session has no history to continue. Each must state:

1. **The role and the lane, explicitly.** "You are a **worker** on lane B of run `<run-id>`." The
   receiving session's router reads its role off this plus `progress.md`, so if the lane isn't
   named it will assume it is the coordinator and start writing the plan.
2. **The footprint it owns**, as paths, and that it owns nothing else. Touching a file outside it
   is a surprise to be reported, not a decision to be made.
3. **Absolute paths** to the plan, the dashboard, and its own `status-<lane>.md`.
4. **Its branch and worktree name — explicitly, and distinct per lane.** Use
   `eng-<plan-short-name>-<lane>`. A worker that isn't given a name falls back to deriving one
   from the plan, and every lane reads the *same* plan — so they all compute the same name and
   every session after the first collides on an existing branch. This field is the only thing
   preventing that; do not omit it.
5. **The contract, in one line:** read the plan, never write it; keep your status file and PR
   updated; run `/done` when finished; never touch another lane's worktree.
6. **Any scope fence** — "do NOT execute X", "do NOT touch Y, lane C owns it".
7. **The coordination protocol, inlined in full** — not a pointer to it. The receiving
   session is fresh and loads only the skill's router, so it learns about the blocking
   pre-PR gate only if it happens to route to the phase doc that mentions one; a worker
   that never gets there opens an ungated PR believing it followed the plan. The block
   to paste is given verbatim in the engineering-team skill's
   `~/.claude/skills/engineering-team/phases/phase-2-planning.md`, Step 3.6 item 5 —
   copy it from there rather than paraphrasing, so all lanes get the same rules. It
   covers: message only the coordinator and only in the six types; every message
   carries a `ref`; push the branch with **no PR** and send `GATE-REQUEST`; open the PR
   only once every non-merged unit on the lane has `Verdict PASS`; never self-clear a
   stalled gate; never change a frozen seam unilaterally.

**The same-machine caveat.** `$RUN_DIR` is git-untracked, so this only works when the new session
shares a filesystem with the coordinator. If it won't (a different host, a cloud session),
**inline the context** the prompt would otherwise reference by path — that is the one case where
pasting contents beats pointing at them.

**Read each prompt before handing it over.** The paste step is a human gate, and a prompt you read
before pasting is a prompt that gets caught when it's wrong — a lane briefed from a stale plan will
cheerfully implement the stale plan.

## Step 5 — Confirm

After the code blocks, briefly (numbered list) tell the user:

1. the path of the handover file
2. what you included
3. anything you were uncertain about, in case they want to adjust it before starting the new session
4. the steps: open a new Claude Code session in the same directory, then paste one of the two
   blocks
