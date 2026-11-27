# Issue labels

**Status:** active. **Last updated:** 2026-11-27. **Last verified:** 2026-11-27 (`issue_labels.py --selftest`, `tests/engineering-team-issue-labels/run.py`, and `check-body` on `codespaces-setup#112`, which fails as an old-shape body should; `apply --dry-run` against `johnmathews/home-server` 2026-11-08). **Covers:** `configs/claude/skills/engineering-team/references/issues.md`, `configs/claude/skills/engineering-team/scripts/issue_labels.py`, `tests/engineering-team-issue-labels/**`.

> Purpose
>
> How the skills and commands in `configs/claude/` file and update issues, on
> GitHub or Linear, with one label scheme and one body shape: where the rules are
> defined and how to apply them to a repo. The rules themselves live in the
> engineering-team skill. This page says where they are and how the pieces fit.

## 1. Where things live

| Piece | Path | Role |
|---|---|---|
| The rules and the canonical label list | `configs/claude/skills/engineering-team/references/issues.md` | The only definition. When to file, which tracker, what is not an issue, the label scheme, the 13 labels with colours and descriptions, the title, the body, updating, and the filing steps for GitHub and Linear |
| The script | `configs/claude/skills/engineering-team/scripts/issue_labels.py` | Parses the table in `issues.md` and holds no copy of it. Applies the labels to a repo, checks a label set and body before and after filing, and checks an update comment |
| Its tests | `tests/engineering-team-issue-labels/` | End-to-end tests against a fake `gh`, run in CI |
| Pointers | phases 1 to 4 of the skill, `commands/done.md` Phase 7a | Say when to file and link `issues.md`. None of them restates a rule |

`references/rule-ownership.md` maps each rule to `issues.md`, and five
drift-scan signatures fail CI if the core rules leave that file: the two label
counts, `investigation` for a [SUSPECTED] finding, the evidence labels, the
TL;DR-first body and the update rule.

## 2. The scheme in brief

Each issue carries one type label, one severity label, any concern labels, and
any area labels the repo already has:

- **Type:** `bug`, `enhancement`, `maintenance`, `investigation`,
  `documentation`, `dependencies`
- **Severity:** `severity: critical`, `severity: high`, `severity: medium`,
  `severity: low`, mapped 1:1 from the skill's severity rubric
- **Concern:** `security`, `reliability`, `performance`
- **Area:** the project's own labels, never invented

A [SUSPECTED] finding is filed as `investigation`. On Linear, severity maps to
the priority field, and only labels the workspace already has are used; the
skill never creates one there.

The names match `johnmathews/home-server`. Its severity descriptions were
rewritten from the rubric on 2026-11-08, and `security` moved to purple
(`#5319e7`) so it no longer looks like `severity: critical`.

## 3. The title and the body

- **Title:** a `Titles:` line in the project's `CLAUDE.md`, else the pattern
  most of the last 30 titles share (such as home-server's `Immich: ...`), else
  the claim alone.
- **Body:** `## TL;DR` first, 2 to 5 bullets that say what is wrong, the impact
  with severity, and the next step. Then `## Evidence`, each claim labelled
  "Verified live", "Read in repo" or "Inferred". Then an optional
  `## Appendix`, last, with `### A.1` subsections, and a one-line footer.
- **Updates:** a comment opens with a `**TL;DR:**` line. When it changes what
  the TL;DR says, the body is edited too. Only a body the flow wrote is edited.

A project's `CLAUDE.md` can hold an `## Issues` section with five optional
lines: `Tracker:` (`GitHub`, the default, or `Linear`), `Team:` and `Project:`
for Linear, `Areas:` for area labels, and `Titles:` for the title convention.
`issues.md` §1 defines them.

## 4. Applying the labels to a repo

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
it. Both check the labels and the body: the TL;DR first, labelled evidence, and
an appendix that is exactly `## Appendix` and last. An update uses
`check-comment`. On Linear, where the label checks do not apply, `check-body`
checks the body alone, and `--type investigation` also requires an `Inferred:`
claim. `issues.md` §8 and §9 give the steps. `check` and `verify` take labels
as a comma list (`--labels`, `--expect`) or one at a time (`--label`,
`--expect-label`), and a name that holds a comma needs the one-at-a-time form.

## 5. Changing the scheme

1. Edit the table in `references/issues.md` §4. The script reads it directly.
2. Run `python3 configs/claude/skills/engineering-team/scripts/issue_labels.py --selftest`
   and `python3 tests/engineering-team-issue-labels/run.py`. The selftest
   expects six type, four severity and three concern labels, so it needs
   updating with any change to those counts.
3. Ask before renaming a label. A changed name creates a new label beside the
   old one in every repo, and issues keep the old one.

Exit codes are 0 for clean, 1 for a failed check, and 2 for a usage, table or
`gh` error.
