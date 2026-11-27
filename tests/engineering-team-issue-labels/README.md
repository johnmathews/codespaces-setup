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
  claim, prose under Evidence, no Evidence section, or an `investigation` issue
  with no `Inferred:` claim. Each body case also asserts the reason it failed.
- The TL;DR: a body fails with no `## TL;DR`, text or another section before
  it, fewer than 2 or more than 5 items, prose instead of bullets, more than 90
  words, or a "see below".
- The appendix: a body fails when an appendix heading is not exactly
  `## Appendix`, sits under another section, appears twice, or is not last. A
  body with no appendix passes.
- Evidence accepts checklist items, a screenshot line (bare, linked or as a list
  item), a mermaid block, `~~~` fences, raw output inside `<details>`, a
  hard-wrapped item and CRLF line endings. A four-backtick fence holding three
  backticks stays open, and an inline ```` ```x``` ```` is not a fence.
- Indented prose with no item above it, and a `* * *` break, cannot pad or hide
  in the TL;DR; an indented continuation counts toward its words.
- `check-body` checks a body without calling `gh`, and needs an `Inferred:`
  claim with `--type investigation`.
- `check-comment` passes a comment that opens with `**TL;DR:**` (or
  `**TL;DR**:`), and fails one with no TL;DR line, text before it, an empty
  one, a `## TL;DR` heading instead, or an unlabelled claim.
- A scheme-only label set is checked without calling `gh`.
- A label name holding a comma survives the repeatable `--label` flag.
- Labels match case-insensitively, and one label in two spellings is a
  duplicate.
- The body check ignores `## ` lines inside a code fence, so a fenced
  `## TL;DR` does not count as the section. It accepts a bold label and a
  sub-heading under Evidence.
- `gh` output that is not JSON exits 2, as does a label list of 1000 or more,
  which may be cut off. A missing body file exits 2.
- `verify` passes when the expected labels landed. It fails (exit 1) when one is
  missing, an unexpected one is on the issue, or the issue breaks the scheme. It
  exits 2 when the issue does not exist.

- A tracking issue (a body with `## Plan`) needs no Evidence, but fails with no
  `Status:` item in its TL;DR, a Plan item that is not a checklist item, a bare
  ID with no meaning, or prose in the Plan.
- `--linear` fails an internal reference or a file path (in code or bare) in the
  TL;DR, a `W<n>` or `ADR-<n>` (any case) with no meaning at its first use (the
  appendix is exempt), and an Evidence claim that is only code. Without the
  flag, none of these apply.
- A struck Evidence claim (`- ~~Inferred: ...~~`) passes when it keeps its
  label, and never counts as an open `Inferred:` claim.
- A link-wrapped plan ID with no meaning fails; a struck plan item that keeps
  its meaning passes.

## 3. Running it

```bash
python3 tests/engineering-team-issue-labels/run.py
python3 configs/claude/skills/engineering-team/scripts/issue_labels.py --selftest
```

`run.py` prints one line per test and exits 1 if any test fails.
