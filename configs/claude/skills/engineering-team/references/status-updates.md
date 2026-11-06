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

The user can ask for a sitrep at any time by typing `/sitrep`. The `sitrep`
skill also answers status questions asked in words, in any session, using this
file's shape.

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
time:

1. **Goal**: what this session is for, in one sentence.
2. **Status**: whether the work is on track, where it is, and when it will finish.
3. **Needs from you**: the only section the user acts on, so it sits near the top.
4. **Heads-up**: only when needed.
5. **Done**, **Doing**, **Need to do**: the progress, in the order it happens.
6. **Session**: continue here, or move to a new session.

Every section except "Heads-up" appears every time. A section with nothing to
report says "Nothing."

The three progress sections hold every item exactly once: each item of the
definition of done (DoD), each unit, and each shipping step. An item starts in
"Need to do", moves to "Doing" while it is being worked on, and ends in
"Done". The same items appear in every sitrep, so the user sees what moved
since the last one. Nothing is said twice: the merge is one line in
"Done", not a DoD tick and a "Shipped" tick.

```markdown
**Goal:** Make the billing pages fast and correct again.

**Status:** Waiting on you. Implementing W4 of 7 (Phase 3 of 4); one question
holds up W5. Done around 15:30 CET if you answer by 14:45.

**Needs from you:**
1. Choose the cache size: 1 GB (faster pages, about €20 a month more) or
   256 MB (cheaper). W5 is paused until you answer. With no answer, we
   finish the other units and leave W5 for last.

**Heads-up:** Once W3 merges, production needs two new settings before the
next deploy, or the app won't start.

**Done:**
- W1: login no longer times out.
- W2: billing totals match the invoices.
- W1 and W2 merged to main by pull request. W1 is live on staging.
- Also: fixed a flaky export test that kept failing the automated checks (CI).

**Doing:**
- W2: deploying to staging, about 5 minutes.
- W3: CI is running on it, usually about 8 minutes. Staging picks it up
  about 5 minutes after it merges.
- W4: two agents are writing tests for the export feature, back in about 5 minutes.

**Need to do:**
- W6: the deploy guide covers the new settings.
- W5: set the cache size, once you answer.
- W7: remove the old export code.
- All seven fixes merged to main with CI green (2 of 7 so far).
- Wrap-up: journal entry, tidy-up.
- Optional follow-ups:
  - Production: a manual release, once all seven are merged.

**Session:** Fine to continue here. W5 to W7 are in the same billing code as
W1 to W4, and lean on what we learned there. About 90k tokens so far.
```

### 3.1 Rules for each section

- **Goal** — one sentence: the feature being shipped or the problem being
  solved, in words the user would use. A user switching between sessions reads
  it to recall which one this is, so it is the same sentence every time. In a
  run it is `goal:` in `run.yaml` (`SKILL.md` §"The run directory"); with none
  yet, write one from the user's request, show it, and save it. Outside a run,
  write it from the request.
  - The first time it is written from the request, add "(from your request;
    correct me if it's wrong)". That note covers the DoD items below it too.
  - When the DoD has changed since the last sitrep, add what changed and when
    on the next line: "DoD changed 14:10: W7 dropped, as you asked."
- **Status** — three parts, in this order:
  1. **The state**: the first matching word from this list, then the reason,
     with a number in it.
     1. `Done`: every DoD item is in "Done". Leave out the stage and the
        finish time; say in a few words what is now true.
     2. `Blocked`: something other than the user is stopping all progress,
        such as a red check or a missing credential.
     3. `Waiting on you`: "Needs from you" has an item. Use this word even
        while other work moves, and say what is still moving.
     4. `Slipping`: the work is going slower, or growing bigger, than the
        last estimate.
     5. `On track`.
  2. **The stage**: where the lead is right now, as a word or phrase from the
     table below, with the detail. In an engineering-team run, add the phase
     as "Phase N of 4". When several things run at once, name the lead's own
     stage; the rest are under "Doing". When the work is paused on the user,
     name the stage that's paused ("Implementing W5, paused").
  3. **The finish time**: an estimate with its basis.
     - Base it on the units left, how long the finished ones took, and waits
       already measured on this run, such as CI's usual time.
     - Give clock times in the user's local timezone and name it. Check `date`.
     - With no basis yet, for example before the first unit has finished,
       write "Can't estimate yet; will know after W1, in about 10 minutes."
     - Round. "About", "around" and a range are honest. A precise time with
       no measurement behind it is a claim stronger than its check
       (`general-guidelines.md` rule 2).
     - If a move to a new session is planned, include it in the estimate.

  | Stage | Means |
  | --- | --- |
  | Clarifying | asking the questions before work starts |
  | Evaluating | reading and assessing the project (Phase 1) |
  | Planning | turning findings into work units (Phase 2) |
  | Implementing | writing the change for a unit |
  | Testing | running the suite, or writing tests |
  | Reviewing | checking a finished unit before calling it done |
  | Waiting on CI | the change is pushed and the checks are running |
  | Merging | the checks passed and the change is going in |
  | Deploying | the merged change is going out |
  | Checking it live | looking at the running result, locally or deployed |
  | Wrapping up | journal, docs, removing the worktree (Phase 4) |
  | Handing over | saving state and writing the prompt for a new session |
- **Needs from you** — with no asks, write "Nothing." Number the asks, make
  each one answerable in a single reply, and for each say:
  - what is paused until it is answered
  - what each choice changes
  - what happens if the user doesn't answer
- **Heads-up** (only when needed) — a risk or consequence the user should know
  about but doesn't have to act on now. For example, a merge that changes what a
  deploy needs, or a unit that turned out bigger than planned. Keeping it out
  of "Needs from you" keeps the asks real.
- **The items in Done, Doing and Need to do** come from three sources:
  - **The DoD**: the entries of `done_when:` in `run.yaml`, which separates
    them with `;`. Each is an end state the user could check. Outside a run,
    split the end state the user asked for into such items. With no
    `done_when:` yet, write one from the request, show it, and save it.
  - **The units** in `run.yaml`: one line each, its ID and what it does in
    plain words. When a DoD item is exactly one unit, they share that line
    ("W6: the deploy guide covers the new settings"). A DoD item no single
    unit covers, such as "all seven merged", gets its own line.
  - **The shipping steps**, from the project's `## Shipping` section
    (`shipping.md`): pushed and merged for a `pull request` path, merged into
    `main` then pushed for `direct push`, merged for `local only`, then each
    environment in the order a change reaches it. The first shipping line
    names the path ("merged to main by pull request"). When the project has
    no `## Shipping` section, add "(path worked out, not confirmed)" and work
    it out as `shipping.md` §2 says; the sitrep never writes the section. A
    DoD item that is itself a shipping step ("merged to main with CI green")
    is one line, not two. With several units, count them ("2 of 7") and name
    them when the list is short.

  Work out where each item sits again for every sitrep, and never store it,
  because a stored answer goes stale.
- **Done** — in the order the work happened (unit order in a run), shipping
  steps after the work they ship. An item goes here only on evidence read for
  this sitrep: the unit is `done` in `run.yaml`, `gh pr view` says `MERGED`
  (or `main` contains the commits), the branch matches its remote, the
  environment's `Check:` command shows the change, or the result was seen
  running. A unit that is written but not yet reviewed and tested is not done.
  An environment with `Check: none` never goes here; it stays in "Need to do"
  as "not checked". Write outcomes the user would notice: "Login no longer
  times out" rather than "edited `auth.py`".
  - **Side work last**, as "Also: …": finished work that no DoD item covers,
    such as a side fix the user asked for or a bug found along the way. It
    counts as done by the same rule: review passed and the full suite is green.
- **Doing** — everything happening at this moment: the unit the lead is on,
  background agents, Workflows, CI and a local server, and when each should
  finish. With no measured duration for a step, give its start time ("review
  started 6 minutes ago") rather than invent a finish time. Written but
  unchecked work is "written, being checked". Something that finished but has
  not been read yet is "finished, reviewing the results". In a multi-lane run
  the coordinator gives each lane one line here; a worker covers its own lane.
- **Need to do** — what is left, in the order it will happen, so the first item
  is what comes next. A DoD item that is partly met sits here with a count
  ("2 of 7 so far"). A unit paused on the user goes after the ones that can
  run now. When a unit that could start now is waiting, say why ("W4 starts
  after W3 merges, because both edit the config"). The wrap-up steps come
  after the units, and only the optional follow-ups come after them. When the
  run's scope stops before Phase 3, say where it stops and what the next phase
  would be. With nothing left, write "Nothing for this task."
  - **Blocked items** start with ❌ and give the reason in a few words: "❌ The
    deploy guide covers the new settings: staging is down, so they can't be
    checked". A failed push, a red check on `main` and a failed deploy are ❌
    too. A ❌ always has a matching `Blocked` status, an ask under "Needs from
    you", or a Heads-up.
  - **Optional follow-ups last**, under that label: extras that are not part
    of this task, and environments past how far done goes (`shipping.md` §3).
    They never hold up `Done`. An environment past that point that the
    change has already reached goes in "Done" like any other step.
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
to act. The progress items are bullets. The asks are numbered, because the
user answers them by number.

Use no emoji or colour: the section an item sits in already says whether it is
done. The one mark is ❌, for a blocked or failed item in "Need to do", so it
stands out.

### 3.3 Sources

Before every sitrep, read the state from disk and from what is running now:

- `run.yaml` for phase and unit status
- `progress.md` and the lane status files in a multi-lane run
- the task list, the Workflow's status, and `gh pr checks` for anything running
- for the shipping steps: the project's `## Shipping` section, `git` (the branch against
  its remote, and whether `main` holds the work), `gh pr view` for the PR's
  state, and each environment's `Check:` command
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
   chat. In a run, that goes in the plan, under sections at the end such as
   "Constraints the user set", "Open questions" and "Lessons so far": the plan
   is what a resuming session reads first. Keep unit IDs out of those
   headings, or `check_plan.py` reads them as unit sections. A design decision
   that will outlive the run goes in an ADR instead. An open question left in
   chat gets asked again by the next session.
3. **Let running work land first.** Wait for background agents and Workflows
   to finish and for their results to be saved. CI and open PRs survive the
   switch, so the new session can pick those up.
4. **Prepare the hand-over prompt yourself; don't just offer it.** Run the
   `/prompt` command's procedure (the `prompt` skill, if the Skill tool lists
   it, or `~/.claude/commands/prompt.md`). It writes the prompt to a markdown
   file and shows it as a copyable block and as a one-line "read this file"
   version. **If this session uses the engineering-team skill, the hand-over
   must too**: the prompt starts with `/engineering-team` and names the run to
   resume. `prompt.md` Step 3 owns that rule. If `/prompt` isn't available,
   write the same file by hand to `$RUN_DIR/handover-<utc>.md` with the same
   contents.
5. **Tell the user what is being carried over.** List what existed only in chat
   and where it now lives, so the user can trust the hand-over.

When the break point is now, prepare the hand-over in the same reply that
recommends it. When it is later, say so, and prepare the hand-over when the
break point arrives, without waiting to be asked.

The Session line gives the decision, the main reason in one sentence (the
overlap, or a warning sign from §4.3), and the size, or "size unknown":

> **Session:** Move to a new session once W3 merges, in about 15 minutes. This
> session has been in the auth code; W4 and W5 are the reports queries and the
> deploy guide, which need none of it. It also holds about 170k tokens of Phase
> 1 survey reports. At that point we save the open question to the plan and
> write the hand-over prompt for you.

> **Session:** Fine to continue here. W4 is the next part of the same export
> code, and it depends on the edge cases we found in W3, which aren't written
> down anywhere else. About 120k tokens so far.

## 5. Mistakes to avoid

- **Silence during a long wait.** A Workflow running for twenty minutes with no
  word looks the same as a hung one.
- **A full sitrep after every small step.** Keep it for the triggers in §2.2.
  Between them a pulse is enough.
