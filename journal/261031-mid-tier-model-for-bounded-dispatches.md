# Mid-tier model for bounded dispatches, with a floor

The engineering-team skill made no model choices, so every subagent inherited the
lead's model (Opus). It now names five dispatches that run on the mid tier
(`sonnet` today) and keeps everything else on the lead's model.

## The five dispatches

- the wide-survey surveyors (Stage 1); the consolidators inherit;
- the footprint check and the acceptance-criteria check in the pre-PR gate;
- `/done`'s docs cross-check subagent;
- implementing a unit sized S, with risk below High and with acceptance criteria.

Each is bounded or mechanical, or the lead checks its output again. Phase 1's
standard engineers, Phase 2 planning, disconfirmation, the conditional reviewers,
and units sized M or L stay on the lead's model, because the run rests on their
judgement. The rule lives in `team-structure.md` §"Choosing a model" (PR #93).

## The floor

The first wording said "the cheaper tier the tool lists". The Agent tool also lists
`haiku`, so that wording allowed it. PR #94 made the floor explicit and structural:

- `team-structure.md` says never go below the mid tier, and names `haiku` as the
  smallest tier today;
- the wide-survey script allowlists `surveyModel`. Any other value, including
  `haiku` or a typo, falls back to the lead's model and logs a line. A newer
  mid-tier name is ignored until the allowlist learns it, which costs more and
  never weakens the survey;
- the drift scan carries the floor as a signature, so CI fails if the rule is
  removed from its home.

## Verified

A probe Agent dispatched with `model: "sonnet"` ran on `claude-sonnet-5-5`, read
from its transcript. The allowlist was run against `sonnet`, `haiku`, `Sonnet` and
no value. A real Workflow run with `surveyModel` has not happened yet.
