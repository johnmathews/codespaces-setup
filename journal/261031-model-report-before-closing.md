# Model report before every "can be closed"

Follows [the footprint script](261031-footprint-check-as-a-script.md).

## Decision

The rule in `team-structure.md` §"Choosing a model" says which model runs where.
Nothing showed what actually ran, so the claim had no check behind it. A new
script, `scripts/model_usage.py` (PR #98), reads the session's transcripts and
lists, for each subagent, the model it asked for and the model it ran on.
`SKILL.md` §"Closing a run" runs it before any "this session can be closed" or
all-done verdict, and the reply shows its output above the verdict. The sitrep
shape, `/sitrep` and `/done` point at that rule. The drift scan now fails if
the rule leaves its home.

Exit 1 means an agent ran on the smallest tier, below the floor. The verdict
still stands, because the work is done, but the reply names the agent so the
dispatch can be fixed. Exit 2 means no transcript was found.

## What the transcripts showed

Across 744 subagents on this machine:

- a dispatch that passed `model: "sonnet"` always ran on Sonnet (158 of 158);
- one agent type ran on Haiku three times without being asked. Its own
  definition sets the model, and that beats inheriting;
- a code-review type always ran on Sonnet, again set by the type.

So inheriting is not a guarantee. `team-structure.md` now says to pass `model`
explicitly when the tier matters, because an explicit value overrides the type.
The script flags both cases: "pinned by its type" when an agent asked for
nothing and ran on a different family from the lead, and "BELOW FLOOR".

## Where it reads

`<config>/projects/<slug>/<session-id>.jsonl` for the lead, and
`<session-id>/subagents/agent-<id>.jsonl` with its `.meta.json` for each
subagent. No Workflow run on this machine has left transcripts in that layout
yet, so whether Workflow agents appear there is unverified.
