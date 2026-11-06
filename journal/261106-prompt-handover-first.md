# /prompt becomes a handover tool first

> Purpose
>
> Why `/prompt` was reshaped around handovers, and what its output now promises.

## 1. Why

`/prompt` was written as if parallel lanes were as common as handovers. In practice almost every use
hands the work to a new session so the old one can be closed. Three things that matter for that were
missing:

1. **The worktree.** The prompt gave the branch but no path. A new session opened in the main
   checkout of an engineering-team project creates a second worktree and splits the work.
2. **A close verdict.** Nothing said whether closing the old session would lose anything.
3. **A session name.** The user runs several sessions at once and tells them apart by name.

## 2. What changed

1. Handover is the main path. The lane hand-off section moved to the end, with its "Step 4b" label
   kept, because `phase-2-planning.md` links to it by that label. "Step 3" also kept its label
   (`status-updates.md` links to it).
2. New Step 2b saves what exists only in chat (`run.yaml`, the plan's end sections) before the
   prompt is written. A direct `/prompt` used to skip this; only the sitrep route did it.
3. The prompt now carries the worktree path ("work here, don't create another"), the definition of
   done, and the open PR with its CI state.
4. Step 5 is a fixed report: file, session name, a `cd <worktree> && claude -n "<name>"` start
   command, the paste line, whether it was copied, and last, whether this session can be closed.
5. The paste line goes to the clipboard every time a clipboard command exists, through `printf '%s'`
   so no trailing newline auto-sends it. The report says whether it was copied.
6. The sitrep's handover shows the same report, minus the full prompt block.

## 3. Decisions

1. **The clipboard gets the paste line, not a combined launch command.** `claude -n "<name>"
   "/engineering-team …"` does work: checked in tmux on Claude Code 2.1.319, it names the session
   and runs the slash command as the first message. But a combined command only helps in a
   terminal. The paste line works in a terminal (after `claude -n`), in the IDE and in the desktop
   app, so it is the one copied.
2. **Uncommitted changes, open PRs and running CI don't block closing.** They live on disk or on
   GitHub and the prompt lists them. What blocks closing is work this session is still running
   (agents, Workflows, background shells) and operations left half applied.
3. **Lane hand-offs always say "keep this session open"**: the session dispatching them is the
   coordinator.
