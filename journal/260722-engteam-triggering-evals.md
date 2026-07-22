# A triggering eval for the skill's own description

**Date:** 2026-07-22. **PR:** feat/engteam-triggering-evals. The fifth of a menu
of five engineering-team improvements (after the router shrink #37, the `run.yaml`
gate #38, and the plan gate). Point-in-time record; authoritative for nothing.

The skill's `description:` frontmatter does heavy boundary-drawing — it must fire
on "evaluate / assess / audit / improve this codebase" and the grounded-in-a-repo
Discussion cases, and must *not* fire on a standalone research question (→
deep-research), a single diff/PR review, or a quick targeted fix. It is
load-bearing and it gets edited, and until now nothing caught a regression that
made it mis-fire. This adds a kept, versioned way to measure that.

## What shipped

`tests/engineering-team-triggering/`, hosted at repo level (not in the skill) for
the same reason the router probe test is: its value is skill-*editing*, not
skill-*use*, so it must not deploy to `~/.claude`.

- `eval-set.json` — 18 frozen labelled prompts (9 fire / 9 no-fire), in
  skill-creator's `{query, should_trigger}` shape (so its `run_eval.py` can also
  consume it) plus `category`/`boundary` metadata. Weighted toward **near-miss
  pairs**: "security review of *this service*" (fire) vs "is *this function*
  vulnerable?" (no); "Postgres vs DynamoDB *for our data layer*" (fire) vs the
  same question *in general* (no); "review the changes on my current branch" (no)
  vs "evaluate this repo" (fire). The clear cases pass almost any description; the
  near-misses are the sensitive part.
- `run.py` — stdlib runner. Routes each prompt through `claude -p` N times against
  the description + a frozen foil roster, rate-vs-threshold scoring. Defaults
  (`--model claude-opus-4-8 --runs 5`) reproduce the baseline.
- `README.md` + `baseline.md` — what/why-not-CI/how-to-run/limitations, and the
  recorded result.

## The design decision that mattered: foils, not an isolated classifier

The first instinct — hand the model *only* the engineering-team description and
ask "would you use this skill?" — is wrong, and measuring proved it. With no
alternative to route to, the model **over-fires on the route-elsewhere
negatives**: asked whether engineering-team handles "what's the state of the art
in X" with nowhere else to send it, Opus said yes 4/5 (a *clear anchor* negative,
wrong). The fix is to give the router the realistic choice the description itself
names — `ENGINEERING-TEAM` vs a `DEEP-RESEARCH` foil vs `NONE` — as frozen harness
context. That makes the negatives well-posed without blunting the test: a
description edited *broader* still over-grabs foil prompts (caught), one edited
*narrower* still drops positives to `NONE` (caught). Only the engineering-team
text varies between runs.

## Two harness bugs, both caught by measuring, not reasoning (confirmed)

1. **First-token parsing scored the model's false start.** Opus reasons out loud:
   `"ENGINEERING-TEAM\nNONE\nWait — this is a quick fix → NONE"`. Reading the first
   token line scored `ENGINEERING-TEAM` and **flipped every negative to a spurious
   5/5 fire** — a confident, completely wrong 9/18. Reproduced by dumping the raw
   reply for N3. Fixed by requiring a final `ROUTE: <token>` sentinel and reading
   the **last** one (the concluded answer).
2. **The isolated classifier (bug #0 above) was the conservative-vs-eager swing.**
   Sonnet under the isolated method missed four *positives*; Opus missed a
   *negative*. That instability is what sent me to the foil design.

I also **falsified my own draft claim.** The README first asserted Opus and Sonnet
"draw the boundary differently" (from the isolated-method numbers). Under the
*same* foil method they agree — both **18/18**. Ran it rather than assert it, and
corrected the doc. A claim may not be stronger than the check behind it, including
the claims a test's own docs make.

## The review bug, and the CI selftest it motivated (confirmed)

The code-review subagent (run on `run.py` before shipping, as the last two gates'
reviews were) caught a **silent** one: `parse_description()` stopped collecting the
folded `>` scalar at the first blank line. It doesn't fire on today's
single-paragraph description (still 958 chars, `sha256[:12]=6de46db193d8`, so the
baseline stands), but the README explicitly anticipates the description being
edited — and splitting it into two paragraphs for readability (valid YAML folding)
would have made the test silently score a *truncated prefix* while claiming
"byte-for-byte what the skill ships." Reproduced with a two-paragraph fixture,
fixed to treat a blank line as a folded paragraph break.

That is the third consecutive gate/harness where the pre-merge review caught a
real defect my own construction missed — so this time I added
`run.py --selftest`: headless checks for the two deterministic parsers (verdict +
description) and the eval set, **wired into CI**. The LLM routing can't run
headless, but the parsers — the exact place a silent bug yields a confident wrong
number — can, and the repo's own rule is that a gate whose tests never run is
decoration. Verified the selftest is not vacuous: monkeypatching `_verdict` to a
constant makes it exit non-zero.

## Baseline

18/18, decisive separation — negatives 0/5, positives 5/5, clear anchors all
correct (Opus 4.8, N=5; Sonnet 5 same method also 18/18). The current description
draws every boundary cleanly, which means maximum regression headroom: any
boundary a future edit weakens shows as a prompt sliding off its corner.

## Verified

- `run.py --selftest` green (7 verdict cases + parser + 18-prompt set), and a
  negative control confirms it catches a broken parser. `ruff` + `py_compile`
  clean.
- Full baseline actually run (not reasoned): `18/18`, printed per-prompt rates in
  `baseline.md`. Cross-model check (Sonnet, same method) also run: `18/18`.
- Shell CI parity green (`shellcheck`/`shfmt`/`lint-steps`), both skill gates
  green, `ci.yml` is valid YAML with the new step.
- Description hash recorded so a future reader knows if the baseline went stale.

## What is deliberately not done

- **`run_eval.py` (the in-vivo harness) is documented, not used for the baseline.**
  On a machine where engineering-team is already installed, it can fire the *real*
  skill instead of its synthetic one and record a non-trigger — a positive-side
  confound. `run.py` has none, so it is primary; the README explains the trade.
- **The foils backstop the negatives.** The suite is sensitive to the description
  *over-claiming*, only weakly to *removing a redundant exclusion* a foil already
  covers. That mirrors real risk (those other skills exist in vivo too), but it is
  a real limitation, stated in `baseline.md`.
- **N8 ("add a dark-mode toggle") is the fuzziest label** — a single scoped feature
  is feature-dev territory, labelled no-fire. Defensible, and it separated cleanly
  5/5→0/5, but it is the one case a reasonable person could argue.
- **The measurement is not auto-run.** Like the probe test and the gates, CI runs
  the parser selftest but nothing forces a real triggering run on a description
  edit — that is prose in the README, not a harness hook.
- **#4 (the rule-ownership index) is the remaining improvement**, a separate PR. It
  needs a systematic full-skill read and is deliberately not started here.
