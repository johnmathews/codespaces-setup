# Handover Prompt

Generate a self-contained prompt that hands the current work over to a **new** Claude Code session
with zero loss of context, so this session can be closed. The output is a prompt for a future
session: not a summary for the user, and not an action to perform now. This command is project and
stack agnostic.

Almost every use is a **handover**: this session stops and a new one carries on. The rare case is a
coordinator dispatching **parallel lanes** in an engineering-team run. Those prompts have a different
shape, in "Step 4b — Lane hand-off prompts" at the end of this file.

## Output Formatting Rule

When presenting recommendations, questions, or conclusions to the user, always use **numbered lists**
(1, 2, 3...) instead of bullet points, so the user can refer to items by number.

## Step 1 — Gather state before writing anything

Do not rely on memory alone. Reconstruct the state of the world from the current conversation *and*
from on-disk artifacts, running these in parallel where possible:

1. **Session context:** Review this conversation to determine what we are doing, the project aims,
   the plan being followed (if any), the current phase (if the work is phased), and what was learned,
   decided, or discovered this session.
2. **Where the work happens:** `git rev-parse --show-toplevel` (the worktree or checkout this session
   works in, as an absolute path), `git branch --show-current`, `git status --short`, and
   `git log --oneline -10`. If the session moved into a worktree after it started, the worktree is
   where the new session must work, not the directory the session was launched from.
3. **Open PR and CI:** if `gh` is available, `gh pr view --json number,url,state,statusCheckRollup`
   for the current branch. Skip silently when there is no PR or no `gh`.
4. **engineering-team run state:** Check whether this project uses the `engineering-team` skill by
   looking for `.engineering-team/current.txt` **in the main checkout**. The run dir lives there,
   not in a worktree, so resolve it with
   `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"` (keep
   `--path-format=absolute`, or you get a path relative to your cwd that the next session cannot
   use), then the run directory it names under `.engineering-team/runs/`. If present, read the
   run's artifacts (`run.yaml`, `request.md`, `evaluation-report.md`, `improvement-plan.md`, and
   `progress.md` / `status-*.md` if the run has lanes) to determine the exact phase, the definition
   of done (`done_when:` in `run.yaml`), which work units are done, and which remain. **Reference
   these files by absolute path in the generated prompt rather than pasting their contents.** The
   new session can read them.
5. **Other plan/docs:** Note any other plan files, design docs, journals, or READMEs the work depends
   on so they can be linked in the prompt.
6. **Anything still running:** background shells, dev servers, subagents, Workflows, monitors, and
   session-only scheduled tasks this session started. Step 5's close verdict depends on them.

## Step 2 — Ask if anything is unclear

If, after gathering state, the aims, plan, phase, or next steps are ambiguous, or you are unsure what
to include, **ask the user clarifying questions before generating the prompt.** Do not guess or
fabricate context.

The exception is a hand-over triggered by a sitrep: don't stop to ask. Write the prompt, and list
what is uncertain in Step 5, so the user can correct it before starting the new session.

## Step 2b — Save what exists only in chat

A new session reads files, not this conversation. Before writing the prompt, put on disk anything
it would otherwise lose:

1. **In an engineering-team run:** bring `run.yaml` up to date (each unit's `status:`), and write
   every decision, open question and lesson that exists only in chat into the plan, under sections
   at the end such as "Constraints the user set", "Open questions" and "Lessons so far". Then run
   `python3 ~/.claude/skills/engineering-team/scripts/check_run.py "$RUN_DIR"`. When a sitrep
   triggered this hand-over, §4.4 of the skill's `references/status-updates.md` has already done
   this; don't repeat it.
2. **Otherwise:** those things go into the prompt itself, under "Gotchas & things to remember".

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
- **If you are dispatching parallel lanes** (the run has `progress.md` and you are the coordinator),
  use "Step 4b — Lane hand-off prompts" at the end of this file instead of Step 4.
- Otherwise, write an ordinary handover prompt with no skill assumption.

## Step 4 — Write the prompt

Write the prompt to a markdown file. The file is the hand-over; anything shown in chat is a
convenience. A long block copied out of a terminal can pick up wrapped lines, while a file can be
read whole.

**Where the file goes:**

- In an engineering-team run: `$RUN_DIR/handover-<utc-timestamp>.md`, in the main checkout, next to
  the run's other state.
- Otherwise: `~/.claude/handovers/<repo-or-directory-name>-<utc-timestamp>.md`. Create the directory
  if needed.

Use absolute paths everywhere in it. The prompt must be self-contained and include, as applicable:

1. **Purpose & aims:** what we are building and why. In an engineering-team run, point to
   `request.md`, which holds the user's own words.
2. **Where to work:** the absolute path of the worktree (or checkout) and its branch, with the
   instruction to work there and **not create another worktree**. A session that starts in the main
   checkout of an engineering-team project otherwise creates a fresh worktree and splits the work
   across two branches.
3. **Definition of done:** the end state that finishes the work, as checkable items. In a run, quote
   `done_when:` from `run.yaml`.
4. **Plan & phase:** the plan being followed and which phase we are in, with a pointer to the plan
   file (e.g. `improvement-plan.md`) rather than the full text. State which work units are complete
   and which are next.
5. **State of the world:** uncommitted work, the open PR and its CI status, and where the code stands
   relative to the plan.
6. **What we learned/discovered this session:** stated inline (if concise) or a pointer to where it
   is documented (the plan, a journal entry, commit messages).
7. **Gotchas & things to remember:** pitfalls, non-obvious decisions, dead ends already ruled out
   and why, preferences the user stated in this conversation, anything the user said not to do, and
   conventions the new session must respect. This is the section a new session cannot rebuild from
   the files, so spend the effort here.
8. **Links to relevant documentation:** paths to plan/design/reference docs and any external links.
9. **Concrete next action:** the first thing the new session should do.

Keep it complete but not bloated: prefer pointing to on-disk artifacts over duplicating them.
**Read the file back once before showing it.** The paste step is a human gate only if what the user
pastes is right.

**Name the new session.** 2 to 4 lowercase words joined by hyphens, at most 30 characters, naming
the work the new session will do rather than the work already done: `billing-export-w4`, not
`session-2`. In a run, build it from the plan name and the next unit. The user often runs several
sessions at once and tells them apart by this name, so don't reuse the current session's name.

**Then produce the two forms:**

1. **The paste line:** a one-line prompt that tells the new session to read the file. It is the
   safer paste, so it comes first:
   - engineering-team: `/engineering-team Resume run <run-id>. Read <absolute path of the handover file> first and follow it.`
   - otherwise: `Read <absolute path of the handover file> first and follow it.`
2. **The full prompt** in a single fenced code block, with nothing else inside the block. It is
   for a session that can't read the file, such as one on another machine. **When a sitrep
   triggered the hand-over, leave this block out**: the sitrep stays one screen, and the file holds
   the full text.

**Copy the paste line to the clipboard, every time.** Use the first clipboard command that exists:
`pbcopy` (macOS), `wl-copy` (Wayland), `xclip -selection clipboard`, `xsel --clipboard --input`, or
`clip.exe` (WSL). Pipe it with `printf '%s'` so no trailing newline is copied (a newline would send
the paste the moment it lands). If none exists, as in most Codespaces, don't copy; Step 5 says so.

## Step 5 — Report

Show the result in this order, so the last thing on screen is the answer to "can I close this?":

1. **Handover file:** its absolute path.
2. **Session name:** the name from Step 4.
3. **Start it:** a command for a terminal, followed by "then paste":

   ```bash
   cd <absolute worktree path> && claude -n "<session name>"
   ```

   In a session that is already open (the IDE or desktop app), paste first, then run
   `/rename <session name>`.
4. **The paste line** in a fenced code block, and then either "Copied to the clipboard." or "Not
   copied: no clipboard command here. Copy the line above."
5. **The full prompt** block (left out when a sitrep triggered the hand-over).
6. **What you included**, in a few numbered lines, and **anything you were uncertain about**, in case
   the user wants to adjust it before starting the new session.
7. **Can this session be closed?** The last line, in one of two forms:
   - **"This session can be closed once the new session has read the handover file. Don't keep
     working here after that."** Use it only when the file is written and read back, Step 2b is
     done, nothing this session started is still running, and nothing is half applied (a rebase or
     merge in progress, a multi-file edit stopped midway). Two sessions working one worktree undo
     each other's edits, which is why the old one must stop.
   - **"Not yet: <the one thing blocking it>. <What clears it>."** For example: "Not yet: the review
     Workflow is still writing its reports. Close this session when it finishes, in about 10
     minutes; the new session reads the reports from the run directory."

   Uncommitted changes, an open PR and a running CI job do **not** block closing: they live on disk
   or on GitHub, and the prompt lists them. If closing would stop something minor, such as a dev
   server this session started, say so in the verdict and that the new session can restart it.

## Step 4b — Lane hand-off prompts (multi-session runs)

Only for a coordinator dispatching parallel lanes. It replaces Step 4 and changes Step 5.

Generate **one prompt per lane**, each in its own fenced code block, ready to paste into a fresh
session. These are not continuation prompts: the receiving session has no history to continue. Each
must state:

1. **The role and the lane, explicitly.** "You are a **worker** on lane B of run `<run-id>`." The
   receiving session's router reads its role off this plus `progress.md`, so if the lane isn't
   named it will assume it is the coordinator and start writing the plan.
2. **The footprint it owns**, as paths, and that it owns nothing else. Touching a file outside it
   is a surprise to be reported, not a decision to be made.
3. **Absolute paths** to `request.md`, the plan, the dashboard, and its own `status-<lane>.md`.
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

**Read each prompt before handing it over.** A lane briefed from a stale plan will cheerfully
implement the stale plan.

**In Step 5,** give each lane its own session name (`<plan-short-name>-lane-<x>`), show each lane's
start command and prompt, and don't copy anything to the clipboard: there is more than one prompt.
The close verdict is always "Keep this session open: it is the coordinator for these lanes."
