# Issue labels

> Purpose
>
> How the skills and commands in `configs/claude/` file GitHub issues with one
> label scheme, where that scheme is defined, and how to apply it to a repo. The
> rules themselves live in the engineering-team skill. This page says where they
> are and how the pieces fit.

## 1. Where things live

| Piece | Path | Role |
|---|---|---|
| The rules and the canonical label list | `configs/claude/skills/engineering-team/references/issues.md` | The only definition. When to file, what is not an issue, the label scheme, the 13 labels with colours and descriptions, the body format, and the filing steps |
| The script | `configs/claude/skills/engineering-team/scripts/issue_labels.py` | Parses the table in `issues.md` and holds no copy of it. Applies the labels to a repo and checks a label set and body before and after filing |
| Its tests | `tests/engineering-team-issue-labels/` | End-to-end tests against a fake `gh`, run in CI |
| Pointers | phases 1 to 4 of the skill, `commands/done.md` Phase 7a | Say when to file and link `issues.md`. None of them restates a rule |

`references/rule-ownership.md` maps each rule to `issues.md`, and three
drift-scan signatures fail CI if the label scheme's core rules leave that file.

## 2. The scheme in brief

Each issue carries one type label, one severity label, any concern labels, and
any area labels the repo already has:

- **Type:** `bug`, `enhancement`, `maintenance`, `investigation`,
  `documentation`, `dependencies`
- **Severity:** `severity: critical`, `severity: high`, `severity: medium`,
  `severity: low`, mapped 1:1 from the skill's severity rubric
- **Concern:** `security`, `reliability`, `performance`
- **Area:** the project's own labels, never invented

A [SUSPECTED] finding is filed as `investigation`. The body labels each evidence
claim "Verified live", "Read in repo" or "Inferred", and keeps the judgement in
its own section. The names match `johnmathews/home-server`. Its severity
descriptions were rewritten from the rubric on 2026-11-08, and `security` moved
to purple (`#5319e7`) so it no longer looks like `severity: critical`.

## 3. Applying the labels to a repo

Run the script from the repo's checkout, or pass `--repo <owner>/<name>`:

```bash
L=~/.claude/skills/engineering-team/scripts/issue_labels.py
python3 $L list                     # the canonical labels
python3 $L apply --dry-run          # what would change, and nothing written
python3 $L apply                    # create missing labels, reset drifted ones
```

`apply` reads `gh label list`, then runs `gh label create --force` only for a
label that is missing or whose colour or description differs. A second run
makes no changes. It keeps the repo's spelling of a name, so it never renames,
and it never touches a label outside the scheme.

Filing an issue also uses `check` before `gh issue create` and `verify` after
it. `issues.md` §6 gives the steps.

## 4. Changing the scheme

1. Edit the table in `references/issues.md` §4. The script reads it directly.
2. Run `python3 configs/claude/skills/engineering-team/scripts/issue_labels.py --selftest`
   and `python3 tests/engineering-team-issue-labels/run.py`. The selftest
   expects six type, four severity and three concern labels, so it needs
   updating with any change to those counts.
3. Ask before renaming a label. A changed name creates a new label beside the
   old one in every repo, and issues keep the old one.

Exit codes are 0 for clean, 1 for a failed check, and 2 for a usage, table or
`gh` error.
