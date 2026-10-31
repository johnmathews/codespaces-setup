# Status updates — keeping the user informed on a long run

> Purpose
>
> How the lead engineer tells the user where a run stands: a one-line **pulse**
> while work is moving, and a full **situation report** (sitrep) at checkpoints
> and whenever the user asks. This file owns the sitrep's shape, when each kind
> of update is sent, and how to judge whether the work should move to a fresh
> session.

## 1. Why this exists

On long and multi-agent runs, users keep asking how it is going, whether
anything is needed from them, what is done and what is left, when it will
finish, and whether the session has grown too long to continue. Each time, an
update arrived too late or in the wrong shape. One fixed shape answers all of
these at once, and it is sent before the user has to ask.

## 2. Two kinds of update

| Kind | Length | Sent when |
| --- | --- | --- |
| **Pulse** | one or two lines | work is moving and nothing needs the user |
| **Sitrep** | one screen at most | a checkpoint is reached, input is needed, or the user asks |

### 2.1 When to send a pulse

- **Immediately after dispatching subagents or starting a Workflow.** Say how
  many are running, what each is doing, and roughly when they report back.
- **When an agent, batch or Workflow returns.** One line: what came back.
- **Before any wait the user cannot see.** CI, a long test suite, a background
  build, a review round. Say what the wait is for and what happens after it.
- **During a long stretch of quiet work, at least every ten minutes.** Check
  `date` rather than guessing how long it has been.

A pulse reports outcomes and waits. It never narrates tool calls ("Now reading
`auth.py`, now running the tests").

> Three agents are reviewing the auth, billing and API code. They should report
> back in about five minutes, and then we merge their findings into the report.

### 2.2 When to send a sitrep

- **The user asks anything about status**, in any wording: "how is it going?",
  "do you need anything from me?", "what's done and what's left?", "when will it
  be finished?", "do we need a new session?", "where are we?", "sitrep". Open
  with a one-line direct answer to the question asked, then send the sitrep.
  A question about the session alone ("do we need a new session?") gets the
  direct answer and the §4 reasoning, without the rest of the sitrep.
- **A phase starts or ends.** The one-line phase announcement (`SKILL.md`
  §"Announce phase transitions") comes first, then the sitrep.
- **A multi-agent batch or Workflow finishes**, once its results are read.
- **The run pauses for user input.** The question goes under "Needs from you",
  so it is never buried in a paragraph.
- **The overlap test in §4 turns to "move".** Say so in the next update without
  waiting to be asked.
- **The session ends.** The final summary takes the sitrep shape, and the
  session verdict from `SKILL.md` §"Closing a run" is its last line.

**Don't repeat a full screen.** If a sitrep went out less than about ten minutes
ago and nothing in it has changed, answer the question in a line or two and add
"Everything else is as in the last update." Send the full sitrep again once
something has moved.

**A status reply always re-reads state** (§3.3), even for a casual "how's it
going". Answering from memory is how a finished agent gets reported as still
running.

## 3. The sitrep shape

Send the sections in this order, so the user's eye lands in the same place each
time. Every section except "Heads-up" appears every time. A section with nothing
to report says so in one word.

```markdown
**Status:** Waiting on you. One question holds up W5; everything else is moving.
4 of 7 fixes are done and the tests pass.

**Needs from you:**
1. Choose the cache size: 1 GB (faster pages, about €20 a month more) or
   256 MB (cheaper). W5 is paused until you answer. With no answer, we
   finish the other units and leave W5 for last.

**Heads-up:** Once W3 merges, production needs two new settings before the
next deploy, or the app won't start.

**Done:**
- Login no longer times out after five minutes (W1, merged).
- Billing totals now match the invoices (W2, merged).

**Doing now:**
- Two agents are writing tests for the export feature (W4), back in about 5 minutes.
- The automated checks (CI) are running on W3's change, usually about 8 minutes.

**Still to do:**
- W5: set the cache size (waiting on your answer).
- W6: update the deploy guide. W7: remove the old export code.
- Then the wrap-up: merge, journal entry, tidy-up.

**Finished?** No. 3 units are left, and each has taken about 30 minutes. Expect
it done around 15:30 CET if you answer by 14:45.

**Session:** Fine to continue here. W5 to W7 are in the same billing code as
W1 to W4, and lean on what we learned there. About 90k tokens so far.
```

### 3.1 Rules for each section

- **Status** — the first matching word from this list, then the reason, with a
  number in it:
  1. `Blocked`: something other than the user is stopping all progress, such as
     a red check or a missing credential.
  2. `Waiting on you`: "Needs from you" has an item. Use this word even while
     other work moves, and say what is still moving.
  3. `Slipping`: the work is going slower, or growing bigger, than the last
     estimate.
  4. `On track`.
- **Needs from you** — the only section the user has to act on, so it sits
  directly under the status line. With no asks, write "Nothing." Number the
  asks, make each one answerable in a single reply, and for each say:
  - what is paused until it is answered
  - what each choice changes
  - what happens if the user doesn't answer
- **Heads-up** (only when needed) — a risk or consequence the user should know
  about but doesn't have to act on now. For example, a merge that changes what a
  deploy needs, or a unit that turned out bigger than planned. Keeping it out
  of "Needs from you" keeps the asks real.
- **Done** — outcomes the user would notice. Write "Login no longer times out"
  rather than "edited `auth.py`". A unit is done only by the `run.yaml`
  definition: review passed and the full suite is green. Written but unchecked
  work goes under "Doing now" as "written, being checked". Add the `W<n>` ID in
  brackets so the line can be matched to the plan.
- **Doing now** — everything running at this moment, including background
  agents, Workflows, CI and a local server, and when each should finish. With no
  measured duration for a step, give its start time ("review started 6 minutes
  ago") rather than invent a finish time. Something that finished but has not
  been read yet is "finished, reviewing the results". When a unit that could run
  now is waiting, say why ("W4 starts after W3 merges, because both edit the
  config"). In a multi-lane run the coordinator gives each lane one line here; a
  worker covers its own lane.
- **Still to do** — the remaining units from `run.yaml`, each in plain words
  with its ID, then the wrap-up steps. When the run's scope stops before Phase 3,
  say where it stops and what the next phase would be.
- **Finished?** — `Yes` or `No`, then an estimate with its basis:
  - Base it on the units left, how long the finished ones took, and waits
    already measured on this run, such as CI's usual time.
  - Give clock times in the user's local timezone and name it. Check `date`.
  - With no basis yet, for example before the first unit has finished, write
    "Can't estimate yet. Will know after W1, in about 10 minutes."
  - Round. "About", "around" and a range are honest. A precise time with no
    measurement behind it is a claim stronger than its check
    (`general-guidelines.md` rule 2).
  - If a move to a new session is planned, include it in the estimate.
- **Session** — continue here, or move to a new session and when. §4 decides
  which.

### 3.2 Language

A sitrep is in the **Briefing register** (`voice-registers.md` §3):

- plain words
- every term explained in a few words the first time, or cut: "the automated
  checks (CI)", "the settings the app reads at start-up"
- "we" for the team, "you" for the user
- one screen

Leave out file paths, commit hashes and tool names unless the user needs them
to act. Status lines are bullets. The asks are numbered, because the user
answers them by number.

### 3.3 Sources

Before every sitrep, read the state from disk and from what is running now:

- `run.yaml` for phase and unit status
- `progress.md` and the lane status files in a multi-lane run
- the task list, the Workflow's status, and `gh pr checks` for anything running
- `date`, for the times

If the sitrep and `run.yaml` disagree, fix `run.yaml` before sending.

## 4. Continue here, or start a new session?

The question is how much of what this session holds the work ahead will use.
Context size alone cannot answer it. A large session whose remaining work uses
that context is better off continuing. A small one about to switch to unrelated
work is better off handing over.

### 4.1 When to ask it

At every unit boundary and every phase boundary, and whenever the user asks
("do we need a new session?", "would you like to continue in a new session?").
Those boundaries are where the overlap changes. Auto-compaction is far too late
a signal: on a 1M-token window it runs near the end of the window, long after
answers have started to suffer from carrying stale material.

### 4.2 The overlap test

1. **Name the work ahead.** The next units, or the next phase.
2. **Name what that work needs.** The parts of the code, the decisions and
   conventions, what the user has said they prefer, and what has already been
   tried and failed.
3. **Compare it with what this session holds.** Then decide:

| The work ahead | Decision |
| --- | --- |
| Continues the same thread: the same files or area, the same kind of task, and it leans on things learned in this conversation | **Stay.** A new session would have to relearn it, and a hand-over loses nuance |
| Moves somewhere else: another part of the code, another kind of task (for example from evaluating to building, or from code to docs), or a fresh question | **Move.** Most of this context is dead weight for that work |
| Mixed | **Move at the point where the overlap drops**, usually after the units that share this context |

The test asks two separate questions, and they can disagree:

- **Is the same knowledge needed?** That decides whether staying is worth it.
- **Is that knowledge on disk already?** That decides what a hand-over costs.
  Knowledge held in the code, the plan or an ADR moves for free. A preference
  the user states, or a decision settled in chat, goes into the plan or an ADR
  as soon as it is made, whatever this test says, because a compaction can lose
  it too. What remains is knowledge that is hard to write down: familiarity
  with the code, and why the dead ends were dead. That is a real reason to
  stay.

**A switch has a cost**: the new session re-reads `SKILL.md`, `run.yaml`, the
plan and the files it needs, and the user has to start it. So between units of
the same phase, with a context under about 100k tokens, low overlap alone is not
enough. Move at the next phase boundary instead. In Phase 3, subagents do most
of the reading, so the lead's own context carries less of the code than it
seems.

### 4.3 Size and warning signs

These change how urgent the answer is. Below the ceiling, they don't decide it
on their own.

- **Size.** `scripts/context_usage.py` reports the context size in tokens from
  the session's transcript. With low overlap and a large context, hand over at
  the next break point. With high overlap and a large context, stay, and keep
  state on disk at every unit so a compaction loses nothing. A manual `/compact`
  with a focus instruction ("keep the billing decisions, drop the survey") is
  an alternative to a switch. The script relies on an undocumented transcript
  format, so if it prints "unknown", judge by how much has passed through the
  session: whole-file reads, logs, subagent reports.
- **The ceiling.** Past about half the window, size decides on its own: hand
  over at the next break point whatever the overlap. That is about 500k tokens
  on a 1M window, or 100k on a 200k window. The model's documentation gives the
  window size.
- **Already summarised.** The session has been compacted. Anything learned
  before the summary counts as not held unless it is on disk, so redo the
  overlap test with that smaller set.
- **Repetition.** The lead re-reads an unchanged file because it no longer
  remembers what the file says, or asks about something the user settled.
  Re-reading after an edit doesn't count. Earlier context is being lost, so
  move at the next break point, whatever the overlap.

### 4.4 Handing over

Handing over is cheap by design. `run.yaml`, the plan and
`.engineering-team/current.txt` let a fresh session resume the run (`SKILL.md`
§"The run directory").

1. **Recommend a break point now.** The end of the current unit, or the merge of
   the open PR. Never in the middle of a unit with unrecorded changes.
2. **At the break point, put the state on disk.** Bring `run.yaml` up to date,
   and write down every decision, open question and lesson that exists only in
   chat: in the plan, an ADR, or a note in `$RUN_DIR`. An open question left in
   chat gets asked again by the next session.
3. **Let running work land first.** Wait for background agents and Workflows
   to finish and for their results to be saved. CI and open PRs survive the
   switch, so the new session can pick those up.
4. **Tell the user what is being carried over.** List what existed only in chat
   and where it now lives, so the user can trust the hand-over.
5. **Give the user the steps.** Run `/prompt` here if the session has it, open a
   new session in the same directory, and paste the prompt it wrote.

The Session line gives the decision, the main reason in one sentence (the
overlap, or a warning sign from §4.3), and the size, or "size unknown":

> **Session:** Move to a new session once W3 merges, in about 15 minutes. This
> session has been in the auth code; W4 and W5 are the reports queries and the
> deploy guide, which need none of it. It also holds about 170k tokens of Phase
> 1 survey reports. At that point we save the open question to the plan, and
> `/prompt` writes the hand-over.

> **Session:** Fine to continue here. W4 is the next part of the same export
> code, and it depends on the edge cases we found in W3, which aren't written
> down anywhere else. About 120k tokens so far.

## 5. Mistakes to avoid

- **Silence during a long wait.** A Workflow running for twenty minutes with no
  word looks the same as a hung one.
- **A full sitrep after every small step.** Keep it for the triggers in §2.2.
  Between them a pulse is enough.
