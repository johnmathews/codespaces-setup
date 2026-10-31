# Pin tests and the two unit fields Phase 3 acts on

A role-play of a Phase 3 dispatch turned up two gaps in the engineering-team skill.

## Pin tests

Phase 3 requires every behavioural test to be seen failing before its fix. A pin
test, which guards behaviour that already works (the safety net before a refactor),
passes before the change by design, and the rule gave no way to report that. The
skill now names it:

- the report calls it a pin;
- it is seen red once by breaking the behaviour it pins by hand, then undone;
- it never replaces the test of the change itself. A pure refactor may have only pins.

## Acceptance criteria and dependencies

The Phase 2 template already asks every unit for **Dependencies** and
**Acceptance criteria**, but nothing checked them, and the test plan left both out.
The lead then made the criteria up in the subagent's brief, where a hand-over loses
them. Now:

- `check_plan.py` warns (W3, W4) about a unit section missing either field. Only
  presence is checked, never quality, in keeping with the gate's rule that prose
  fields are not hard-checked. A verification unit's "How it goes red" counts as its
  acceptance criteria.
- Before each dispatch, Phase 3 checks the unit's hard dependencies are `done` in
  `run.yaml`, writes missing criteria into the plan first, quotes them in the brief,
  and reviews against them.

The section parser ends a unit's section at the next heading of the same or higher
level, so a closing section such as "Constraints the user set" is not read as part
of the last unit. Two fixtures put the field names in a closing section to keep that
boundary tested; removing the boundary turns both red.
