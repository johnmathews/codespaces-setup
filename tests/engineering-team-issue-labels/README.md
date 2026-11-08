# engineering-team issue labels: script tests

End-to-end tests for `configs/claude/skills/engineering-team/scripts/issue_labels.py`,
the script that applies and checks the issue label scheme defined in the skill's
`references/issues.md`.

## 1. How it works

`run.py` runs the real script against a fake `gh` (`fake_gh.py`), which it puts
first on `PATH`. The fake keeps one repo's labels and issues in a temporary JSON
file and logs every call. Each test then asserts on the exit code, the output,
the calls made and the labels left behind. The tests read the canonical list
through `issue_labels.py list --json`, so they hold no copy of it.

No network, no GitHub login, no model, stdlib only. It runs in CI beside the
script's own `--selftest`, which covers the table parser and the label and body
checks without `gh`.

## 2. What it covers

- `apply --dry-run` writes nothing.
- `apply` creates all 13 labels with `--force` on an empty repo.
- A second `apply` makes no write calls.
- A drifted colour or description is reset, and the repo's spelling of a name
  is kept, so `Bug` is never renamed to `bug`.
- Labels outside the scheme, such as an area or `wontfix`, are left alone.
- `--repo` reaches every `gh` call.
- A `gh` failure and a malformed table both exit 2.
- `check` rejects zero or two types, zero or two severities, a GitHub triage
  label and an invented area. It rejects a body with an unlabelled evidence
  claim, prose under Evidence, no Evidence or Judgement section, or an
  `investigation` issue with no `Inferred:` claim.
- A scheme-only label set is checked without calling `gh`.
- `verify` passes when the expected labels landed, and fails when one is
  missing, when the issue breaks the scheme, or when the issue does not exist.

## 3. Running it

```bash
python3 tests/engineering-team-issue-labels/run.py
python3 configs/claude/skills/engineering-team/scripts/issue_labels.py --selftest
```

`run.py` prints one line per test and exits 1 if any test fails.
