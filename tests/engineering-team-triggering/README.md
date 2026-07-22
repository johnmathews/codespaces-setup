# engineering-team skill — triggering eval

A regression test for the `engineering-team` skill's **`description:` frontmatter**
(`configs/claude/skills/engineering-team/SKILL.md`). It answers one question:
**does the description still fire on the prompts it should, and stay quiet on the
ones it shouldn't?**

The description does heavy boundary-drawing — it must fire on "evaluate this repo
/ assess this project / audit / improve this codebase end-to-end / architecture
discussion grounded in a codebase", and must **not** fire on a standalone
research question (that is the deep-research skill), a single-diff/PR review, or a
quick targeted fix. That description is load-bearing and gets edited. Nothing else
catches a regression that makes it mis-fire; this does, by measuring the trigger
decision on a frozen, labelled prompt set.

## Why this is not in CI

The test is **LLM-in-the-loop**: each prompt is routed by a `claude -p` model
call, so there is no non-model way to run it. It cannot live in the headless
`shellcheck`/`shfmt`/gate CI. It is a **manual, on-demand check**, run by an agent
(e.g. Claude Code) when the description changes — the same shape as the
[router probe test](../engineering-team-probes/) next door. That is a deliberate
limitation, not an oversight: a triggering test wired into CI would need API
access and would be flaky. An on-demand check a human triggers on description
edits is the honest shape.

**One part does run in CI:** `run.py`'s deterministic parsers — verdict parsing
and folded-description extraction — are not LLM-dependent, and a silent bug there
would turn a correct routing decision into a wrong number. `python3 run.py
--selftest` exercises them (and validates the eval set) headlessly, and CI runs
it. Only the `claude -p` measurement is on-demand.

## What it is

- [`eval-set.json`](eval-set.json) — the **frozen** labelled prompt set: 18
  prompts, each with `should_trigger` (the label / rubric) and a `category` +
  `boundary` note. Nine should fire, nine should not. Most are **near-miss** pairs
  that sit right on a boundary the description draws — e.g. "Do a security review
  of this service" (fires) vs a single-snippet "is this function vulnerable?" (does
  not); "walk me through Postgres vs DynamoDB *for our data layer*" (fires,
  grounded) vs "should I use Postgres or MySQL *in general*?" (does not). The
  near-misses are the point: the clear cases would pass almost any description.
- [`run.py`](run.py) — the runner. Stdlib-only; needs the `claude` CLI on PATH and
  authenticated (it reuses the session's Claude Code auth — no separate API key).
- [`baseline.md`](baseline.md) — the recorded baseline result: the reference a
  future edit is compared against.

## How it scores

Trigger decisions are **probabilistic**, so scoring is a rate against a threshold,
not all-or-nothing:

- Each prompt is routed `--runs` times (default 5) → a **trigger rate**.
- A prompt is **correct** when the rate lands on the labelled side of
  `--threshold` (default 0.5): a `should_trigger: true` prompt must fire on ≥ half
  its runs; a `false` prompt must fire on < half.
- **Suite acceptance** (what a description edit must not regress):
  1. **Every clear anchor** (the `*-clear` categories — 3 positive, 3 negative)
     must be correct. A miss there means the description is broken, not borderline.
  2. **Overall accuracy** must not drop more than one prompt below the recorded
     baseline. Near-miss cases flip probabilistically; a single flip is noise, a
     cluster is a regression.

Both halves matter: the anchors prove the description isn't broken outright; the
near-miss accuracy is the sensitive part that a boundary-shifting edit moves.

## How to run it (before/after a description edit)

A before/after comparison, like the probe test. Run the baseline **before** you
edit, so a later change can only be attributed to the edit.

1. **Baseline.** `python3 run.py --json before.json` (from this directory). This
   reads the *current* description straight out of `SKILL.md`, routes every prompt,
   and prints per-prompt rates + accuracy. Confirm it matches
   [`baseline.md`](baseline.md) (allowing for near-miss noise). If a **clear
   anchor** fails here, the eval set is stale, not the router — fix the label.
2. **Edit** the description in `SKILL.md`.
3. **After.** `python3 run.py --json after.json` again — same prompts, now against
   the edited description.
4. **Compare.** Apply the suite-acceptance rules above. Any clear-anchor
   regression, or a near-miss accuracy drop beyond one prompt, names a boundary the
   edit moved — restore it or re-baseline deliberately (and update `baseline.md`
   with the reason).

The committed defaults (`--model claude-opus-4-8 --runs 5`) are chosen to
**reproduce `baseline.md`** — Opus is the model that actually routes in this
Claude Code, and five runs damps the near-miss noise. Under this method the
choice of model is not load-bearing for the *current* description: Sonnet 5
scores identically (both 18/18 — see `baseline.md`), so `--model
claude-sonnet-5` is a fine cheaper option. That agreement is a property of a
description this decisive; a weaker future description may split the two models,
so re-baseline on the model you intend to compare against.

### What `run.py` actually measures (and the frozen foil roster)

`run.py` gives the router a realistic, minimal routing choice: the
**engineering-team description** (the only part that varies between runs), one
**foil route** — `DEEP-RESEARCH` — and `NONE` (handle it directly). The foil
roster is **frozen harness context**, drawn straight from the boundaries the
engineering-team description itself names ("that is the deep-research skill",
"reviewing a single diff/PR", "a quick targeted fix").

The foils exist because an *isolated* single-description classifier (asking "would
you use this skill?" with no alternative) systematically **over-fires on the
"should route elsewhere" negatives** — with nowhere else to send "what's the state
of the art in X", the model reluctantly claims it. Giving it the real alternatives
makes those negatives well-posed. It does not blunt the test: a description edited
*broader* still over-grabs foil prompts (caught), and one edited *narrower* still
drops positives to `NONE` (caught). Only the engineering-team text moves the
score.

What this is **not** is the full in-vivo routing decision against *every* installed
skill. The `skill-creator` skill's `scripts/run_eval.py` does that version: it
registers the description as a synthetic skill and runs `claude -p` on the raw
prompt, detecting whether the model invokes it. Reach for it when you want the
description to fight for the trigger against the whole real skill set. **Caveat:**
on a machine where `engineering-team` is already installed in `~/.claude/skills/`,
the model may fire the *real* skill instead of the synthetic one, which
`run_eval.py` records as a non-trigger — so its positive-case numbers are only
trustworthy where the skill is **not** installed. `run.py` has no such confound,
which is why it is the primary procedure here.

## Maintaining the prompt set

- **Add a prompt when you change what the description covers.** A new boundary
  needs a new near-miss pair (one that should fire, one that shouldn't), or the
  edit that moves it goes unmeasured.
- **A prompt is only valid if the *current* description classifies it as labelled.**
  If a clear anchor can't be classified correctly by the shipped description, the
  prompt is wrong, not the description.
- **Keep it balanced.** Roughly half fire, half don't; a set skewed one way lets a
  description that just says "yes" (or "no") to everything score well.
- **Re-baseline deliberately.** When you intentionally shift a boundary, re-run and
  overwrite `baseline.md`, noting what moved and why.
