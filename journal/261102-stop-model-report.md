# Stop printing the model report

The model report added in [261031-model-report-before-closing](261031-model-report-before-closing.md)
is switched off. Nothing runs `scripts/model_usage.py` automatically any more:

- `engineering-team` `SKILL.md` §"Closing a run" no longer runs it before the
  session verdict.
- The `sitrep` skill dropped its Step 2 "Models" item, and
  `references/status-updates.md` no longer ties a `Finished? Yes` or a
  closable Session line to the report.
- `/done` Phase 9 no longer prints it.
- `rule-ownership.md` lost the row for the rule, and the drift scan lost its
  `model-report-before-verdict` anchor.

The reason: the table at the end of every finished sitrep and `/done` was noise
for now. The script and its `--selftest` stay, so it can still be run by hand
and the rule can be restored by reverting this change.
