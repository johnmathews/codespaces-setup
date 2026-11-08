# Filing issues

> Purpose
>
> The one place that says when a skill or command files a GitHub issue, which
> labels it carries, what its body says, and the checks before and after filing.
> Every other file that files issues points here. The canonical label list in §4
> is also read by `scripts/issue_labels.py`, so it exists only here.

## 1. When to file an issue

File an issue for work this run leaves undone, at the moment it is left undone:

1. **A finding the plan leaves out of scope** (Phase 2). List these at the Phase 2
   gate. Approving the plan approves them, so file them right after the user says
   go. In a `plan`-scope run there is no gate, so list them when the run closes
   and file them on a yes.
2. **A unit abandoned with a `why`** (Phase 3). File it when the unit is marked
   abandoned, then add `issue: <n>` to that unit in `run.yaml`, such as
   `{ id: W3, status: abandoned, why: <one line>, issue: 57 }`. A unit the user
   dropped on purpose is a decision, so it is not filed (§2).
3. **A follow-up found during Phase 3, Phase 4 or `/done` that this run does not
   fix.** That covers a defect seen in passing, a review finding left unfixed, a
   security or documentation warning, and a [SUSPECTED] finding still unsettled
   at Phase 4. Write each one to `$RUN_DIR/follow-ups.md` when it is found, with
   its severity and grade. A lane worker writes them in its own `status-<lane>.md`
   instead. `/done` files them in its follow-up issues phase. Outside an
   engineering-team run, `/done` files the follow-ups it finds itself.

File in the repo whose code the issue concerns. If that is not the repo this
session works in, ask the user first.

## 2. What is not an issue

- **Anything fixed in this run**, in the same PR or in another PR of the run.
- **A unit still pending in this run's plan.** `run.yaml` tracks it, and it
  becomes an issue only if it is abandoned.
- **Something an open issue already covers.** Comment on that issue with the new
  evidence instead (§6 step 1).
- **Something the user decided against**, such as "not a problem" or "won't do".
  Record the decision in the plan.
- **A question for the user.** Ask it.
- **The findings of an evaluate-only run.** The report is that run's
  deliverable, so offer to file its findings and file only on a yes.
- **Anything in a project that tracks work elsewhere.** If the project's
  `CLAUDE.md` names another tracker or says not to file issues, or the repo has
  issues turned off, list the follow-ups in the summary instead.

**Batch Low findings.** Out-of-scope findings graded Low that share a type go in
one issue with a checklist, labelled `severity: low`. Medium and above always get
an issue each.

## 3. The label scheme

Every issue carries:

1. **Exactly one type label.** Pick it from the table below.
2. **Exactly one severity label**, mapped 1:1 from the finding's severity in
   `general-guidelines.md` §"Severity: what it would cost if it is true".
   Critical is `severity: critical`, High is `severity: high`, Medium is
   `severity: medium` and Low is `severity: low`. For an `enhancement` or
   `maintenance` issue, the severity is the cost of leaving it undone. Grade a
   follow-up that has no severity yet with the same rubric before filing it.
3. **Zero or more concern labels**: `security`, `reliability`, `performance`.
4. **Zero or more area labels.** Take areas from an `Areas:` line under a
   `## Issues` section of the project's `CLAUDE.md`. If there is none, take them
   from the repo's existing labels (`gh label list`) that are neither scheme
   labels nor GitHub's triage defaults (`duplicate`, `good first issue`,
   `help wanted`, `invalid`, `question`, `wontfix`). Never invent an area. If an
   issue needs one that does not exist yet, ask the user.
5. **Nothing else.** GitHub's triage defaults are for the user to apply.

A **[SUSPECTED] finding is filed as `investigation`**, whatever its type would be
if it were true. Its severity is still the cost if it is true. The body states
the unverified claim and what would settle it (§5). Whoever settles it swaps
`investigation` for the real type, or closes the issue if the claim was false.

| Type | Use it when |
|---|---|
| `bug` | Behaviour is wrong today, including a doc that misleads about behaviour |
| `enhancement` | A new capability, or an improvement to something that works |
| `maintenance` | Upkeep with no behaviour change: refactor, retire, migrate, clean up, tests, CI |
| `investigation` | A [SUSPECTED] finding, or anything to measure before deciding |
| `documentation` | A change to documentation only |
| `dependencies` | Updating, pinning or replacing a dependency |

A vulnerable dependency is `dependencies` plus `security`. A security hole in the
project's own code is `bug` plus `security`.

## 4. The canonical labels

`scripts/issue_labels.py` parses this table. Keep its four columns and their
order, and keep each colour as six hex digits after `#`. A description may be at
most 100 characters, which is GitHub's limit.

| Group | Name | Colour | Description |
|---|---|---|---|
| type | `bug` | `#d73a4a` | Something isn't working |
| type | `enhancement` | `#a2eeef` | New capability, or an improvement to something that works |
| type | `maintenance` | `#bfd4f2` | Upkeep with no behaviour change: retire, migrate, refactor, clean up |
| type | `investigation` | `#d4c5f9` | Unverified: measure or test something, then decide |
| type | `documentation` | `#0075ca` | Improvements or additions to documentation |
| type | `dependencies` | `#0366d6` | Update, pin or replace a dependency |
| severity | `severity: critical` | `#b60205` | Data loss, a security hole, silent wrong output, or a break users hit now |
| severity | `severity: high` | `#d93f0b` | A real defect, but bounded: degrades a path or fails loudly |
| severity | `severity: medium` | `#fbca04` | Correct today, fragile tomorrow: untested paths, misleading docs, drift |
| severity | `severity: low` | `#c2e0c6` | Cosmetic or nice-to-have: nothing breaks and nobody is misled |
| concern | `security` | `#5319e7` | Security hardening or a security gap |
| concern | `reliability` | `#006b75` | Behaviour under crashes, timeouts or failures |
| concern | `performance` | `#1d76db` | Speed, latency or resource use |

Changing a name here renames nothing in any repo. The script would create a new
label beside the old one, so ask the user before changing a name.

## 5. The issue body

The body keeps evidence and judgement apart. Every claim under **Evidence** is a
list item that starts with exactly one of three labels, matching the grades in
`general-guidelines.md` §"Grade every finding, and name what earned the grade":

| Label | Grade | What the claim names |
|---|---|---|
| `Verified live:` | [VERIFIED] | The command that ran and its actual output |
| `Read in repo:` | [SUPPORTED] | The primary source read but not run, such as `file:line`, a config or a CI log |
| `Inferred:` | [SUSPECTED] | The inference, and what would settle it |

An `investigation` issue has at least one `Inferred:` claim, which is the
unverified claim itself. Opinions go under **Judgement**, never under Evidence.

```markdown
<One or two sentences: what is wrong or missing, and what it costs.>

## Evidence

- Verified live: `<command>` printed `<output>`
- Read in repo: `<path>:<line>` <what it shows>
- Inferred: <the claim>. Settled by: <the check that would settle it>

## Judgement

- Severity: <Critical|High|Medium|Low>, because <the consequence if true>
- Type: <type>, because <reason>
- Suggested fix: <one or two lines, or "none yet">

## Why it is not fixed now

<Out of scope in the plan for <run>, unit W<n> abandoned (<why>), or found
during /done and left for later.>

Found by: <engineering-team run <run-id> | /done on <branch>>, <YYYY-MM-DD>
```

The title states the claim in a few words, such as "Backup job skips the
`/etc` snapshot when the pool is degraded".

## 6. Filing, step by step

Run these from the repo's checkout, or add `--repo <owner>/<name>` to each
command. `L` is the deployed script:

```bash
L=~/.claude/skills/engineering-team/scripts/issue_labels.py
```

1. **Look for an existing issue.** Run
   `gh issue list --state open --search "<key words>"`. If one covers it, then
   add the new evidence with `gh issue comment <n> --body-file <file>` and stop.
2. **Write the body** to a file, in the shape of §5.
3. **Make sure the scheme's labels exist.** Run `python3 $L apply`. It reads
   `gh label list`, then creates each missing scheme label and resets any
   drifted colour or description with `gh label create --force`. It never
   renames a label and never creates one outside §4. Run it with `--dry-run`
   first to see what it would change.
4. **Check the labels and the body.** Run
   `python3 $L check --labels "bug,severity: high,security" --body-file <file>`.
   It must exit 0. If it reports an area that does not exist, ask the user. For
   an area whose name holds a comma, pass it with `--label "<name>"` instead.
5. **File it.** Run
   `gh issue create --title "<title>" --body-file <file> --label bug --label "severity: high" --label security`.
6. **Confirm what landed.** Run
   `python3 $L verify --issue <n> --expect "bug,severity: high,security"`. It
   reads `gh issue view <n> --json labels,body` and repeats the checks. If it
   fails, fix the issue with `gh issue edit <n>`, then verify again.
7. **Record the number**: on the abandoned unit in `run.yaml`, beside the finding
   in the plan's out-of-scope list, and in the summary.

A PR that later fixes the issue says `Closes #<n>` in its body.
