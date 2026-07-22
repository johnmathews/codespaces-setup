# engineering-team triggering — baseline result

**Recorded:** 2026-07-22.
**Command:** `python3 run.py` (defaults: `--model claude-opus-4-8 --runs 5 --threshold 0.5`), from this directory.
**Description under test:** the `description:` frontmatter shipped in
`configs/claude/skills/engineering-team/SKILL.md`, `sha256[:12] = 6de46db193d8`,
958 chars. If that hash changes, the description was edited and this baseline may
be stale — re-run.

## Headline

**18/18 correct**, with every prompt cleanly separated — negatives fired 0/5,
positives 5/5. The current description draws all nine boundaries **decisively**:
there is no borderline case, so the whole eval set has maximum regression
headroom (any boundary an edit weakens will show up as a prompt sliding off its
0/5 or 5/5 corner). Clear anchors all correct.

| ID | Label | Category | Rate (fires/runs) | Correct |
|----|-------|----------|-------------------|:-------:|
| N1 | no-fire | negative-clear | 0/5 | yes |
| N2 | no-fire | negative-clear | 0/5 | yes |
| N3 | no-fire | negative-clear | 0/5 | yes |
| N4 | no-fire | negative-near-miss | 0/5 | yes |
| N5 | no-fire | negative-near-miss | 0/5 | yes |
| N6 | no-fire | negative-near-miss | 0/5 | yes |
| N7 | no-fire | negative-near-miss | 0/5 | yes |
| N8 | no-fire | negative-near-miss | 0/5 | yes |
| N9 | no-fire | negative-near-miss | 0/5 | yes |
| P1 | FIRE | positive-clear | 5/5 | yes |
| P2 | FIRE | positive-clear | 5/5 | yes |
| P3 | FIRE | positive-clear | 5/5 | yes |
| P4 | FIRE | positive-near-miss | 5/5 | yes |
| P5 | FIRE | positive-near-miss | 5/5 | yes |
| P6 | FIRE | positive-near-miss | 5/5 | yes |
| P7 | FIRE | positive-near-miss | 5/5 | yes |
| P8 | FIRE | positive-near-miss | 5/5 | yes |
| P9 | FIRE | positive-near-miss | 5/5 | yes |

## What this establishes

- **The eval set is valid.** The shipped description classifies all 18 prompts as
  labelled, so a future FAIL is the edit's fault, not a bad prompt — the same
  logic as the probe test's baseline-before-edit rule.
- **The description is well-drawn.** Even the near-miss pairs (e.g. "security
  review of *this service*" vs "is *this function* vulnerable?"; "Postgres vs
  DynamoDB *for our data layer*" vs "Postgres vs MySQL *in general*") separate
  5/5 vs 0/5. The explicit `Do NOT use for …` clause and the grounded-in-a-codebase
  qualifier are doing real work.

## Method notes (why these defaults)

- **Router with a frozen foil roster, not an isolated yes/no.** The router picks
  among the engineering-team description, a `DEEP-RESEARCH` foil, and `NONE`. An
  isolated "would you use this skill?" classifier over-fires on the
  route-elsewhere negatives (with nowhere else to send "state of the art in X",
  the model reluctantly claims it). See README for why this stays sensitive to
  the regressions that matter.
- **Decision read from the last `ROUTE:` line.** Opus often reasons out loud and
  self-corrects ("ENGINEERING-TEAM … wait, this is a quick fix → NONE"). An
  earlier first-token parser scored the *false start* and flipped every negative;
  reading the final `ROUTE:` sentinel fixed it. (Recorded here because it is the
  kind of harness bug that reports a confident, wrong number.)
- **Opus 4.8, N=5.** Opus is the model that actually routes in this Claude Code;
  five runs damp the probabilistic noise. **Cross-checked on Sonnet 5, same
  method, same N: also 18/18.** So for *this* description the model choice is not
  load-bearing — the clean separation holds on both. Do not over-read that: it is
  a property of a decisive description, and a weaker one could split the models.

## Known limitations (the method must match the claim)

- **Not the full in-vivo decision.** This measures the description as a router
  *with foils present*, not against every installed skill. The `skill-creator`
  `run_eval.py` does the in-vivo version; the README explains the trade and its
  installed-skill confound.
- **Foils backstop the negatives.** N3 routes to `NONE` partly because the foil
  roster offers "quick fix → NONE", not by engineering-team's exclusion alone. So
  the suite is sensitive to the description **over-claiming** (a broadened
  description grabs foil prompts → caught) but only weakly sensitive to *removing*
  a redundant exclusion a foil already covers. That mirrors real risk: in vivo
  those other skills exist too, so a removed-but-backstopped exclusion is genuinely
  lower-stakes.
- **Point-in-time.** Re-baseline after any deliberate boundary change and note
  what moved and why.
