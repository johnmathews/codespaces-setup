# Sitrep: a one-line goal, one Status line, and Done / Doing / Need to do

A real sitrep from a finished task showed the problems with the eleven-section
shape. It said "done" three times (Stage, Status, Finished?), listed the merge in
both the DoD and "Shipped", and spread progress over four sections (Shipped,
Doing now, Still to do, Also done) in an order nobody could predict. Nothing said
in one line what the session was for.

The new shape has seven sections, defined in `status-updates.md` §3:

- **Goal**: one sentence, the feature being shipped or the problem being solved.
  In a run it is a new `goal:` line in `run.yaml`, so every sitrep uses the same
  words and the user can tell parallel sessions apart. `check_run.py` warns (W4)
  when a live run has none, the same way W3 covers `done_when:`.
- **Status**: the state word (`Done` is new and comes first), then the stage,
  then the finish time. It replaces Stage, Status and Finished?.
- **Needs from you** and **Heads-up**, unchanged.
- **Done, Doing, Need to do**: every DoD item, unit and shipping step appears in
  exactly one of them, and moves from right to left as work happens. "Shipped",
  "Still to do" and "Also done" are gone. Side work is the last line of Done
  ("Also: …"), and extras outside the task are the last block of Need to do
  ("Optional follow-ups").
- **Session**, unchanged.

Two decisions, agreed with the user before the change:

- **The DoD is not its own checklist any more.** Its items sit in the three
  progress sections. A separate checklist was the source of the duplication.
  The cost is that the full definition of done is no longer in one block.
- **No ✅ or ⬜ marks.** The section already says whether an item is done. ❌
  stays, for a blocked or failed item in Need to do.

The evidence rules did not change: an item reaches Done only on evidence read for
that sitrep, and an environment only through its `Check:` command.
