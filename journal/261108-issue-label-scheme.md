# One label scheme for every issue the skills file

> Purpose
>
> Why the engineering-team skill and `/done` now file GitHub issues, how the label scheme was chosen, and what was observed while building it.

## 1. Why

No shipped skill or command filed issues. Sessions filed them ad hoc when a project's `CLAUDE.md` asked, so the labels depended on the session. In `johnmathews/home-server`, 15 of 58 issues had no label at all, and severity was on some issues and not others (confirmed with `gh issue list`). Findings a plan left out of scope, and abandoned units, lived only in run artifacts that closeout deletes.

## 2. What changed

1. `references/issues.md` in the engineering-team skill is the one home for filing issues. It covers when to file, what is not an issue, the label scheme, the canonical table of 13 labels, the issue body, and the steps before and after filing. `rule-ownership.md` maps it, and three drift-scan signatures guard its core rules.
2. `scripts/issue_labels.py` parses that table, so the list exists once. `apply` creates missing labels and resets drifted colours and descriptions with `gh label create --force`. It keeps the repo's spelling of a name, so it never renames. `check` and `verify` hold a label set and body to the scheme before and after `gh issue create`.
3. Pointers, with no rules restated:
   - Phase 2 lists the out-of-scope findings at the gate and files them on approval.
   - Phase 3 files an abandoned unit, records `issue: <n>` in `run.yaml`, and collects follow-ups in `$RUN_DIR/follow-ups.md`.
   - Phase 4 names every filed issue in its summary.
   - `/done` gains Phase 7a and a twelfth summary row.
   - An evaluate-only run offers to file and files only on a yes.
4. Tests: `tests/engineering-team-issue-labels/run.py` runs the real script against a fake `gh`, with 26 cases. CI runs it and the script's `--selftest`, and so do `/sync-skills`'s pre-PR checks.

## 3. Decisions at the gate

The user decided these at the Phase 2 gate:

- Label names stay exactly as home-server had them.
- `apply` overwrites a drifted colour or description to canonical.
- Out-of-scope Low findings of one type are batched into one issue.
- Approving the plan approves filing its out-of-scope issues. Later follow-ups are filed without a further question.

Asked whether the table was "correct and excellent", the review found three faults, and the user approved all three fixes:

1. Home-server's `severity: medium` read "Real but contained harm", which is the rubric's High. `severity: low` read "Hardening, polish or a rare edge case", which can be Critical. All four severity descriptions were rewritten from the rubric.
2. `dependencies` used Dependabot's PR wording, and `enhancement` said "request". Both, plus `maintenance` and `investigation`, got descriptions written for issues.
3. `bug`, `severity: critical` and `security` were three similar reds, so `security` moved to purple `#5319e7`.

## 4. Observed

- Every new test and both selftests were seen red before passing. This includes two seeded script bugs: a dry run that writes, and an update that uses the scheme's spelling. The rename test first passed against the seeded bug, because GitHub and the fake both match names case-insensitively. It now asserts on the spelling passed to `gh` (confirmed).
- `apply --dry-run` against home-server, read-only, listed exactly the 9 changes agreed at the gate (confirmed).
- An independent review found real defects, all fixed with tests:
  - non-JSON `gh` output exited 1 ("check failed") instead of 2;
  - a `## ` line inside a code fence ended the Evidence section, and a fenced `## Judgement` passed as the section;
  - label names holding a comma could not be passed (a repeatable `--label` fixes this);
  - a label list cut off at the limit could make `apply` rename a label (it now refuses).
- The procedure was used once for real. It filed johnmathews/codespaces-setup#112, a stale deploy table in `docs/development.md` found during this run. The steps were `apply` (11 labels created or updated), `check`, `gh issue create`, then `verify`. A second dry run then reported 0 changes (confirmed).
- `tests/setup-resilience/run.sh` and `tests/claude-config-dir/run.sh` fail locally on macOS, in the same way on `origin/main` (confirmed). They are Linux tests, and CI is the check for them.

## 5. What is deliberately not done

- No existing issue in another repo was relabelled. The backfill command for home-server's 15 unlabelled issues went to the user, who decides whether to run it.
- home-server's labels were not touched. Its descriptions and the `security` colour change the next time a skill files an issue there, because `apply` runs first.
- Pull requests are outside the scheme. Dependabot keeps labelling its PRs `dependencies`.
- The stale deploy section of `docs/development.md` is #112, not fixed here.
