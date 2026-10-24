# design-system skill — triggering eval

A regression test for the `design-system` skill's **`description:` frontmatter**
(`configs/claude/skills/design-system/SKILL.md`): does it still fire on the prompts
it should, and stay quiet on the ones it shouldn't?

The description has to cover brand work, design systems, reskins, component-library
choices and any page, screen or email in a project with a design system, without
grabbing charts (the dataviz skill), one-off pages with no product behind them (the
frontend-design skill), quick CSS fixes or general CSS questions.

This is the same method as [`../engineering-team-triggering/`](../engineering-team-triggering/README.md);
read that README for the full reasoning (why a frozen foil roster, why the last
`ROUTE:` line, why this is not in CI). `run.py` is a copy of that runner with a
different route roster.

## What it is

- [`eval-set.json`](eval-set.json): 20 labelled prompts, 10 that should fire and 10
  that shouldn't, 3 clear anchors on each side and the rest near misses (an email's
  copy vs its look; a data dashboard vs a component-library choice for a dashboard;
  a Tailwind upgrade vs "should we add Tailwind to get shadcn-vue").
- [`run.py`](run.py): routes each prompt `--runs` times (default 5) through
  `claude -p`, choosing among DESIGN-SYSTEM (the description under test),
  FRONTEND-DESIGN, DATAVIZ and NONE. Stdlib only; needs the `claude` CLI, logged in.
- [`baseline.md`](baseline.md): the recorded result to compare an edit against.

## Running it

Before you edit the description, from this directory:

```bash
python3 run.py --json before.json   # ~100 claude -p calls, a few minutes
```

Edit the description, run it again (`--json after.json`), and compare. An edit must
keep every clear anchor correct and must not drop overall accuracy by more than one
prompt below the baseline. `python3 run.py --selftest` checks only the parsers and
the eval set, without model calls; CI runs that.
