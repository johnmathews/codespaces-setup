# design-system triggering — baseline result

**Recorded:** 2026-10-24.
**Command:** `python3 run.py` (defaults: `--model claude-opus-5-5 --runs 5 --threshold 0.5`), from this directory.
**Description under test:** the `description:` in
`configs/claude/skills/design-system/SKILL.md`, `sha256[:12] = c6da1846c4b8`,
1019 chars. If that hash changes, the description was edited: re-run.

## Headline

**20/20 correct, every prompt unanimous** (positives 5/5, negatives 0/5). Clear
anchors all correct.

This baseline is the second run of the day. The first, against the description
before it named "palette, typeface", was also 20/20 but P10 ("Pick a typeface and
a colour palette for the new landing page") fired only 3/5; the other two runs went
to FRONTEND-DESIGN. Adding "(palette, typeface)" after "a visual identity" moved P10
to 5/5 and changed nothing else.

| ID | Label | Category | Rate | Correct |
|----|-------|----------|------|:-------:|
| N1 | no-fire | negative-clear | 0/5 | yes |
| N2 | no-fire | negative-clear | 0/5 | yes |
| N3 | no-fire | negative-clear | 0/5 | yes |
| N4 | no-fire | negative-near-miss | 0/5 | yes |
| N5 | no-fire | negative-near-miss | 0/5 | yes |
| N6 | no-fire | negative-near-miss | 0/5 | yes |
| N7 | no-fire | negative-near-miss | 0/5 | yes |
| N8 | no-fire | negative-near-miss | 0/5 | yes |
| N9 | no-fire | negative-near-miss | 0/5 | yes |
| N10 | no-fire | negative-near-miss | 0/5 | yes |
| P1 | FIRE | positive-clear | 5/5 | yes |
| P2 | FIRE | positive-clear | 5/5 | yes |
| P3 | FIRE | positive-clear | 5/5 | yes |
| P4 | FIRE | positive-near-miss | 5/5 | yes |
| P5 | FIRE | positive-near-miss | 5/5 | yes |
| P6 | FIRE | positive-near-miss | 5/5 | yes |
| P7 | FIRE | positive-near-miss | 5/5 | yes |
| P8 | FIRE | positive-near-miss | 5/5 | yes |
| P9 | FIRE | positive-near-miss | 5/5 | yes |
| P10 | FIRE | positive-near-miss | 5/5 | yes |

## Limitations

- **Foils backstop the negatives.** N2 and N5 go to DATAVIZ and N6 to
  FRONTEND-DESIGN partly because those routes exist. That matches real use, where
  those skills are installed, but it means the test is more sensitive to the
  description over-claiming than to it losing an exclusion.
- **Not the full in-vivo decision**, and it doesn't see the global `CLAUDE.md` line
  that also points UI work at this skill. It measures the description alone.
- **Prompts without a repo.** The router sees only the message, so "in a project
  with brand/design-system" has to be said in the prompt (P4).
