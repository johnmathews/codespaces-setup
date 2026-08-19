# 260819 — engineering-team: concurrency is the premise, not the edge case

> Purpose
>
> Record why the `engineering-team` skill was reworked so that every session
> assumes it is one of several running concurrently, what changed as a result,
> and which cases were deliberately left alone.

## 1. The ask

Make the skill "always assume it is working as one of several concurrent
sessions … therefore a worktree is always required."

## 2. What was already true, and what wasn't

The worktree rule was *already* unconditional for Build runs — `SKILL.md`
§"Always work in a worktree" and `references/worktree.md` both said "every
phase, every run, including evaluation-only." So the literal ask was mostly
satisfied. What was **not** satisfied was the reasoning behind it:

- Concurrency was listed as **one of three** justifications for the worktree
  ("Sessions overlap. Another session *may* be working while yours runs"),
  and a rule with three co-equal reasons is a rule that gets discounted when
  one of them looks inapplicable.
- `multi-session.md` §5.3 said solo meant "The default. Nothing changes." —
  which reads as *you are alone*, when it only ever meant *this run has one
  lane*.
- Worktree setup step 1 told the session to resolve a dirty main checkout by
  offering to **stash or commit** it. Under concurrency those changes may be
  another session's, and stashing them is the single most damaging thing this
  flow could do to a neighbour.
- The name-collision warning existed only for *workers*. A solo session
  derives `eng-<plan-short-name>` from the plan, which is exactly the name a
  second solo session on the same plan would pick.

So the change is a **premise change**, and the worktree requirement is one of
its consequences rather than the whole of it.

## 3. What changed

New canonical section: `SKILL.md` §"You are never the only session" — the home
for the premise and its five consequences (worktree required; main checkout is
read-only shared state; check names before taking them; touch only what you
created; "solo" describes the run, not the machine). It also states the
non-consequence explicitly: **assume concurrency for isolation, require
evidence on disk before assuming it for collaboration** — otherwise the natural
next move is to invent a dashboard and a coordinator for a run that has one lane.

Downstream, in pointer form (each cites the home, per `rule-ownership.md`):

| File | Change |
|---|---|
| `SKILL.md` §"Always work in a worktree" | concurrency promoted to the *first* reason; "work grows" stated as independently sufficient |
| `SKILL.md` §"Decide your role" | solo redefined as a fact about the run |
| `references/worktree.md` | premise-first bullet; setup step 1 no longer offers to stash/commit someone else's dirt; new step 2 clears the branch name **before** `EnterWorktree` (the old ordering checked after creating) |
| `references/multi-session.md` §5.3 | solo keeps the isolation half, drops only the coordination half |
| `references/discussion.md` | new §"The read-only exemption, and where it ends" |
| `references/workflows.md` | discussion→build crossing is not symmetric |
| `phases/phase-1`, `phase-3` | premise cited; solo name-collision check added |
| `references/rule-ownership.md` | new invariant row + `SKILL.md` home-family entry |
| `tests/engineering-team-drift/drift_scan.py` | new `concurrent-sessions` signature (home `SKILL.md`, `/never the only session/`) so the premise can't silently leave its home |

## 4. The two exceptions, and why they differ

Asked whether Discussion should also be forced into a worktree. Decision:
**no — with a hard boundary.**

1. **Non-git project** — a worktree cannot exist. Physical, not discretionary.
2. **Discussion** — exempt *only while it stays read-only*. It writes nothing,
   so it has nothing to isolate; the exemption is bought by that fact and lapses
   at the first edit. The moment a discussion would create or change a file it
   is a Build run: stop, enter a worktree, then edit.

The failure this closes is the "just this one small edit" path — a discussion
that produces a one-line fix straight into the main checkout, on `main`,
underneath another session. Stated in three places on purpose
(`discussion.md` twice, `workflows.md` once) because it is reachable from
either workflow's doc.

## 5. Verification

All shipped gates green after the change: `drift_scan.py` (selftest + real
scan, 14 signatures, 0 warnings), `check_command_links.py`, `check_report.py`,
`check_run.py`, `check_plan.py`, `check_board.py`, the triggering-eval
parsers, `ci/lint-steps.sh`, and `shellcheck`. The drift-scan's check B
matters most here: it proves every new `§"You are never the only session"`
citation resolves to a real heading, which is the failure mode a new
cross-file premise invites.

## 6. Deliberately not done

- **No change to `/done` or `/merge-push`.** `/done` §8c already proposes and
  confirms worktree reaping and already carries the "a `git status` can be one
  instant old" war story. It was consistent with the new premise before it was
  written down.
- **No new machinery.** No detection probe for other sessions (there isn't a
  sound one — the colliding session may not have started yet), no lock files,
  no registry.
