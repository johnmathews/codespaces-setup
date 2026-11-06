---
name: sitrep
description: Give a situation report on this session's work in a fixed shape — a one-sentence goal, a status line (on track or not, the stage, when it will finish), what's needed from the user, then Done, Doing and Need to do (each item of the definition of done, each unit, and each shipping step — pushed, merged, live in each environment — in exactly one of them), and whether to continue in a new session. Use when the user types /sitrep, or asks for a status update in any wording — "how is it going", "do you need anything from me", "what have we done and what's left", "is it done yet", "is it merged", "is it deployed", "when will it be finished", "do we need a new session", "where are we", "give me an update".
---

# Sitrep

Give the user a situation report on this session's work, in the fixed shape the engineering-team
skill defines. The user runs several sessions at once and types `/sitrep`, or asks in words, to find out, at a glance,
what this one is for, where it is, and whether it needs them. The same shape every time is the point:
the user's eye lands in the same place in every session.

Report only. Don't start, stop or change any work to produce it. Two exceptions, both about keeping
state safe:

- A decision, user preference or open question that exists only in this conversation gets written
  down (the plan, in a run) while you build the report. That protects it whatever the Session line
  says.
- When the report says to move to a new session, prepare the hand-over (Step 4).

## Step 1 — Load the shape

Read `~/.claude/skills/engineering-team/references/status-updates.md`. §3 owns the sections, their
order and the rule for each one. §4 owns the Session line. Follow them exactly; this skill does not
restate them, so the two cannot drift.

## Step 2 — Read the state, never recall it

Gather these in parallel. The report is built from what they say, not from what the conversation
remembers:

1. `date`, for times in the user's local timezone.
2. **An engineering-team run, if there is one.** Resolve the main checkout with
   `dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`, then read
   `.engineering-team/current.txt` there and the run's `run.yaml`: `goal:`, `done_when:`, `phase:`,
   `scope:` and each unit's status. With lanes, read `progress.md` too.
3. **What is running:** background agents, Workflows and shells from this session, and
   `gh pr checks` for any open PR this session made.
4. **Git:** the branch, uncommitted changes, and commits not yet pushed.
5. **Shipping:** the `## Shipping` section of the project's `CLAUDE.md`, whether `main` holds the
   work (`gh pr view --json state` for a PR), and each environment's `Check:` command. When the
   section is missing, work out the path as
   `~/.claude/skills/engineering-team/references/shipping.md` §2 says, and show it as worked out.
   Don't write the section: that is for `/merge-push` and `/done`.
6. **Size:** `python3 ~/.claude/skills/engineering-team/scripts/context_usage.py`. If it prints
   "unknown", judge size as §4.3 says.

## Step 3 — Fill the gaps when there is no run

Outside an engineering-team run, nothing on disk holds the goal or the units. Then:

- **Goal:** one sentence from the user's request in this conversation: the feature being shipped
  or the problem being solved. Add "(from your request; correct me if it's wrong)" the first time.
  Use the same sentence in every later sitrep of this session.
- **DoD items:** split the end state the user asked for into checkable items.
- **The stage in Status:** use §3.1's list, picking the closest word.
- **Done, Doing, Need to do:** place each DoD item, and each step of the task as this
  conversation has defined it, in exactly one of the three.

## Step 4 — Send it

Send the sitrep exactly in the §3 shape: every section, in order, one screen, plain words. If the
user asked a specific question, answer it in one line first.

**If the Session line says to move now**, prepare the hand-over in the same reply by following §4.4
steps 2 to 5. That runs the `/prompt` procedure, which writes the prompt to a file and copies the
one-line paste version to the clipboard. After the sitrep, show `/prompt`'s Step 5 report without the
full prompt block: the file path, the new session's name, its start command, the paste line, whether
it was copied, and last, whether this session can be closed. The full text stays in the file. If this
session uses the engineering-team skill, the hand-over prompt must start with `/engineering-team`.

After it is sent, carry on with any work that was in progress, unless the report raised something the
user has to answer first.
