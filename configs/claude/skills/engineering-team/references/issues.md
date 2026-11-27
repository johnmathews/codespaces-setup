# Filing issues

> Purpose
>
> The one place that says when a skill or command files or updates an issue,
> on GitHub or Linear: which labels it carries, how its title and body read, and
> the checks before and after filing. Every other file that files issues points
> here. The canonical label list in §4 is also read by
> `scripts/issue_labels.py`, so it exists only here.

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
4. **Work that a generated prompt hands to another session**, from `/prompt`, a
   lane hand-off, or Phase 4's next-unit prompt. The prompt names the open
   issue that covers the work, or a tracking issue filed for it before the
   prompt is written (§10).

File in the repo whose code the issue concerns. If that is not the repo this
session works in, ask the user first.

**Which tracker.** Read the `## Issues` section of the project's `CLAUDE.md`.
Every line in it is optional:

```markdown
## Issues

- Tracker: Linear
- Team: ENG
- Project: Billing
- Areas: api, ui, infra
- Titles: `Area: claim`
```

- `Tracker:` is `GitHub` (the default) or `Linear`. On Linear, follow §9.
- `Team:` and `Project:` are Linear's team key and an optional project.
- `Areas:` lists the area labels (§3).
- `Titles:` states the title convention (§5).

With no `Tracker:` line, file on GitHub. If the repo has no GitHub remote or has
issues turned off, ask the user where follow-ups go, and offer to write the
`## Issues` section with the answer.

## 2. What is not an issue

- **Anything fixed in this run**, in the same PR or in another PR of the run.
- **A unit still pending in this run's plan.** `run.yaml` tracks it, and it
  becomes an issue only if it is abandoned.
- **Something an open issue already covers.** Update that issue with the new
  evidence instead (§7).
- **Something the user decided against**, such as "not a problem" or "won't do".
  Record the decision in the plan.
- **A question for the user.** Ask it.
- **The findings of an evaluate-only run.** The report is that run's
  deliverable, so offer to file its findings and file only on a yes.
- **Anything in a project that says not to file issues**, or whose `Tracker:` is
  neither GitHub nor Linear. Write the follow-ups in the summary instead, each in
  the shape of §6, so the user can paste it.

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
4. **Zero or more area labels.** Take areas from the `Areas:` line of the
   project's `CLAUDE.md` (§1). If there is none, take them
   from the repo's existing labels (`gh label list`) that are neither scheme
   labels nor GitHub's triage defaults (`duplicate`, `good first issue`,
   `help wanted`, `invalid`, `question`, `wontfix`). Never invent an area. If an
   issue needs one that does not exist yet, ask the user.
5. **Nothing else.** GitHub's triage defaults are for the user to apply.

A **[SUSPECTED] finding is filed as `investigation`**, whatever its type would be
if it were true. Its severity is still the cost if it is true. The body states
the unverified claim and what would settle it (§6). Whoever settles it swaps
`investigation` for the real type, or closes the issue if the claim was false
(§7).

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

On Linear, §9.2 maps this scheme to Linear's priority and labels.

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

## 5. The title

Follow the convention the tracker already uses:

1. **A `Titles:` line** in the project's `CLAUDE.md` (§1) wins.
2. **Otherwise read the last 30 titles**: on GitHub
   `gh issue list --state all --limit 30 --json title -q '.[].title'`, on Linear
   the team's recent issues. If at least half share a pattern, follow it, and
   spell its area names the way those titles do. Common patterns are
   `Area: claim`, `[Area] claim` and `type(scope): claim`.
3. **Otherwise** write the claim alone.

Whatever the pattern:

- **State the claim, not the topic**: "Backup job skips `/etc` when the pool is
  degraded", not "Backup issue".
- **At most about 80 characters**, with no full stop at the end.
- **No severity or type in the title**, such as `[Bug]` or `HIGH:`. The labels
  carry them. The one exception is a convention that puts them there.
- **No run-internal IDs** such as `F3` or `W2`. Nobody reading the tracker can
  see the run.

## 6. The issue body

Write for a reader who reads the TL;DR and stops. Everything under it is the
record, for the reader who has to check the claim or act on it.

The sections, in this order:

1. `## TL;DR`, always first.
2. `## Evidence`. A tracking issue (§10) has `## Plan` here instead, and adds
   Evidence only once there is a claim to record.
3. Any other section only when it earns its place, such as a numbered
   `## Steps to reproduce`. `## Plan` is reserved for tracking issues, so a
   bug's fix steps go under another heading, such as `## Suggested fix`.
4. `## Appendix`, optional, always last.
5. The footer, after a `---` line, with or without an appendix.

### 6.1 The TL;DR

A TL;DR is adequate when a reader who stops there knows:

1. **What** is wrong or missing.
2. **The impact**: who or what it hits, and the severity with its reason.
3. **The next step**: the fix, or for an `investigation`, the check that settles
   it.

Write it as 2 to 5 bullets, one fact each, in about 60 words; the check fails
a TL;DR over 90. It must
stand alone: no "see below", no term that only the Evidence defines, and no run
IDs. An `investigation` TL;DR says that the claim is unverified.

The judgement lives here: the severity and its reason, and the suggested fix.
The type needs no reason, because its label says it.

### 6.2 Evidence

The Evidence section holds only claims, never opinion. Every claim is a list item
that starts with exactly one of three labels, matching the grades in
`general-guidelines.md` §"Grade every finding, and name what earned the grade":

| Label | Grade | What the claim names |
|---|---|---|
| `Verified live:` | [VERIFIED] | The command that ran and the line of output that matters |
| `Read in repo:` | [SUPPORTED] | The primary source read but not run, such as `file:line`, a config or a CI log |
| `Inferred:` | [SUSPECTED] | The inference, and what would settle it |

An `investigation` issue has at least one `Inferred:` claim, which is the
unverified claim itself. A batched Low issue (§2) writes each finding as a
checklist item, such as `- [ ] Read in repo: ...`.

Quote only the line of output that matters. When the full output is longer than
about 10 lines, put it in the appendix and point to it, such as
"(full output: A.1)". A screenshot line, and anything folded in `<details>`, may
sit between the claims.

### 6.3 Lists, diagrams and screenshots

- **Lists everywhere.** Use numbered lists when order matters, such as steps to
  reproduce or a sequence of events, and bullets otherwise. Give each item one
  fact.
- **A mermaid diagram** when the defect sits in a flow, in messages between
  components, or in a change of state that would take more than a few sentences
  to describe. GitHub and Linear both render a ```` ```mermaid ```` block. Keep
  it to about 10 nodes and put it after the claim it shows. The claim stays in
  words too, because a diagram is not evidence.
- **A screenshot** for anything a user sees: a UI defect, a dashboard reading or
  an error dialog. Put it under the Evidence item it supports, with alt text that
  says what it shows.
  - **Linear** uploads a markdown image to its own storage when the issue is
    created. The image can be a URL Linear can fetch, or a `data:` URI.
  - **GitHub:** `gh` cannot upload images. Link an image already in the repo
    (`https://github.com/<owner>/<repo>/blob/<sha>/<path>?raw=true`). Otherwise
    save it under `$RUN_DIR/screenshots/`, file the issue without it, and give
    the user the path in the summary so they can drag it in. Never leave a
    placeholder in the body.

### 6.4 The appendix

The appendix holds what a reader may need to check the record but not to act on
it: full command output, long logs, a full config, a script that reproduces the
defect, background, and options considered.

- **One heading, `## Appendix`**, spelled exactly that, after every other
  section. Only the footer comes after it.
- **Numbered subsections**, `### A.1 <what it holds>`, `### A.2 ...`, so an
  Evidence item can point to "A.1".
- **On GitHub, fold each long block** in `<details><summary>...</summary>`, so
  the page stays short. Linear's docs do not say that markdown can make a
  collapsible section, so leave the subsections open there.
- **No other heading may say "appendix"**, such as `### Appendix: logs` under
  Evidence.
- **Nothing above it depends on it.** An Evidence item quotes the line that
  matters and points to the subsection for the rest.

Move content to the appendix when the text above it would not fit on one screen,
which is about 30 lines.

### 6.5 The template

````markdown
## TL;DR

- <What is wrong or missing, in one line.>
- Impact: <who or what it hits>. Severity: <critical|high|medium|low>, because <the consequence if true>.
- Next: <the fix, or the check that settles it>.

## Evidence

- Verified live: `<command>` printed `<the line that matters>` (full output: A.1)
- Read in repo: `<path>:<line>` <what it shows>
- Inferred: <the claim>. Settled by: <the check that would settle it>

## Appendix

### A.1 <what it holds>

<details><summary><one line></summary>

```text
<the full output>
```

</details>

---

Not fixed now: <out of scope for run <run-id> | W<n> abandoned: <why> | found by /done, left for later> · Found by: <engineering-team run <run-id> | /done on <branch>>, <YYYY-MM-DD>
````

`issue_labels.py` checks the shape: a body fails if its first section is not
`## TL;DR`, if the TL;DR has fewer than 2 or more than 5 items or more than 90
words, if it points below, if an Evidence item has no label, or if an appendix
heading is not exactly `## Appendix` as the last section.

## 7. Updating an issue

Update an open issue when a run finds new evidence for it (§2), settles an
`investigation`, fixes part of it, changes its severity, or fixes it. A tracking
issue also gets milestone updates (§10.3).

1. **Comment on what happened.** The comment opens with one line,
   `**TL;DR:** <what changed, and what it means now>`, of at least three words,
   followed by labelled
   evidence items as in §6.2. Keep it short. On GitHub, fold long output in
   `<details>`.
2. **Keep the body true.** When the update changes anything the TL;DR says, such
   as the cause, the severity, the next step or the scope, edit the body as well.
   Rewrite the TL;DR, add the new claims to Evidence, and change the labels, or
   the priority on Linear, to match. The comment records what changed and the
   body says what is true now, because a reader opens the body, not the twelfth
   comment.
3. **Strike wrong evidence, never delete it.** Put `~~...~~` around a claim that
   turned out wrong, and add the claim that corrects it.
4. **Settle an `investigation`** by swapping its label for the real type (§3),
   turning its `Inferred:` claim into a `Verified live:` claim or striking it,
   and rewriting the TL;DR. If the claim was false, comment why and close the
   issue.
5. **Close it through the PR that fixes it**: `Closes #<n>` on GitHub,
   `Fixes <KEY-n>` on Linear (§9.3). An issue closed without a PR gets a comment
   whose TL;DR names what settled it.
6. **Edit only a body this flow wrote.** A body whose footer says `Found by:
   engineering-team run` or `Found by: /done` may be edited. On an issue a person
   wrote, comment only, unless the user says yes. At work, a teammate's ticket
   text is theirs.

`issue_labels.py check-comment` checks a comment before it is posted, and
`check` or `check-body` checks an edited body (§8, §9.3).

## 8. Filing on GitHub, step by step

Run these from the repo's checkout, or add `--repo <owner>/<name>` to each
command. `L` is the deployed script:

```bash
L=~/.claude/skills/engineering-team/scripts/issue_labels.py
```

1. **Look for an existing issue.** Run
   `gh issue list --state open --search "<key words>"`. If one covers it, update
   that issue as the end of this section shows, and stop.
2. **Pick the title** (§5).
3. **Write the body** to a file, in the shape of §6.
4. **Make sure the scheme's labels exist.** Run `python3 $L apply`. It reads
   `gh label list`, then creates each missing scheme label and resets any
   drifted colour or description with `gh label create --force`. It never
   renames a label and never creates one outside §4. Run it with `--dry-run`
   first to see what it would change.
5. **Check the labels and the body.** Run
   `python3 $L check --labels "bug,severity: high,security" --body-file <file>`.
   It must exit 0. If it reports an area that does not exist, ask the user. For
   an area whose name holds a comma, pass it with `--label "<name>"` instead.
6. **File it.** Run
   `gh issue create --title "<title>" --body-file <file> --label bug --label "severity: high" --label security`.
7. **Confirm what landed.** Run
   `python3 $L verify --issue <n> --expect "bug,severity: high,security"`. It
   reads `gh issue view <n> --json labels,body` and repeats the checks. If it
   fails, fix the issue with `gh issue edit <n>`, then verify again.
8. **Record the number**: on the abandoned unit in `run.yaml`, beside the finding
   in the plan's out-of-scope list, and in the summary.

**To update an issue** (§7):

1. Write the comment to a file, run `python3 $L check-comment --body-file <file>`,
   then `gh issue comment <n> --body-file <file>`.
2. If the body has to change, run
   `gh issue view <n> --json body -q .body > <file>`, edit the file, check it
   with `check --labels ... --body-file <file>`, then run
   `gh issue edit <n> --body-file <file>` with any `--add-label` or
   `--remove-label` the update needs. Finish with `verify`.

A PR that later fixes the issue says `Closes #<n>` in its body.

## 9. Filing on Linear

### 9.1 The tools

Use the Linear MCP server's tools. Find them with ToolSearch (`linear`). Linear's
docs do not list the tool names, so pick each by what it does: list or search
issues, get an issue, create an issue, update an issue, create a comment, list
teams and list labels. If no Linear tools are connected, or they need signing
in, ask the user to connect them. Do not fall back to the API with a token.
Until they are connected, write the follow-ups in the summary in the shape of
§6.

### 9.2 Mapping the scheme

| The scheme (§3) | On Linear |
|---|---|
| Severity label | The priority field: critical is Urgent, high is High, medium is Medium and low is Low |
| Type label | The existing team or workspace label with that meaning, such as Bug, Feature or Improvement. If none matches, file with no type label and say so in the summary |
| Concern labels | Only a label of that name that already exists |
| Area labels | Existing labels only, or the `Project:` from §1 |
| `investigation` | An existing label with that meaning, if there is one. The TL;DR says the claim is unverified either way |

**Never create, rename or recolour a label in a Linear workspace.** The
workspace is shared with a team. `issue_labels.py apply` is for GitHub only. If
an issue needs a label that does not exist, ask the user.

### 9.3 Steps

`L` is the script, as in §8.

`--linear` on `check-body` and `check-comment` adds the checks of §9.4.

1. **Find the team** from the `Team:` line (§1). Without one, list the teams and
   ask the user.
2. **Look for an existing issue.** Search the team's open issues for the key
   words. If one covers it, update it (§7) and stop.
3. **Pick the title** (§5) from the team's recent issues.
4. **Write the body** to a file (§6), then run
   `python3 $L check-body --linear --body-file <file>`, adding
   `--type investigation` for an investigation. It must exit 0.
5. **File it** with the create tool: the title, the file's text as the
   description, the team, the priority, the labels and any project.
6. **Confirm what landed.** Fetch the issue, write its description to a file and
   run `check-body` on it again. Check that the priority and labels match. If
   anything is off, fix it with the update tool and check again.
7. **Record the identifier**, such as `ENG-123`, where §8 step 8 records a
   number.

**To update an issue** (§7), run `check-comment --linear` on the comment before
posting it with the comment tool, and `check-body --linear` on an edited
description before saving it with the update tool.

A PR that later fixes the issue says `Fixes <KEY-n>` in its body. With Linear's
GitHub integration, that links the PR and closes the issue when it merges.

### 9.4 Written for a reader without the repo

A product owner reads a Linear issue, and may have no access to the GitHub repo.
They must understand the issue at their level without it. Internal references
are welcome, because engineers use them, but each must explain itself:

- **The TL;DR names no internal reference and no file path.** It says in product
  words what is wrong or planned, the impact, and the next step.
- **Every internal reference carries its meaning at its first use**: a work unit
  as "W2 (retry failed exports)", a finding as "F3 (exports drop rows over
  10 MB)", a decision as "ADR-7 (the job queue moved to Postgres)". A link to the
  document may follow, but never replaces the words.
- **Every Evidence claim says what it means in plain words.** The `file:line` or
  command comes after the meaning, for the engineer who checks it. Long output
  and repo-only detail go in the appendix.

A comment is read on its own, so it explains its own references, even ones the
body already explains. Its `**TL;DR:**` line may name a unit only with its
meaning, such as "W2 (retry failed exports) is done".

`check-body --linear` and `check-comment --linear` fail an internal reference
(`W<n>`, `F<n>`, `ADR-<n>`, `RFC-<n>`) in the TL;DR or with no meaning at its
first use, a file path in the TL;DR, and an Evidence claim with fewer than four
plain words outside code.

## 10. Tracking work across sessions

### 10.1 When

Whenever a skill or command writes a prompt that hands work to another session
(§1 item 4), the work has an issue:

1. **An open issue already covers it**: the prompt names it. Look in `run.yaml`
   (`tracking_issue:`, and `issue:` on units), the PR body, and the tracker
   (§8 step 1, §9.3 step 2). If a person wrote that issue, its body is theirs
   (§7 item 6): post the status and the plan's checklist in comments instead of
   editing it.
2. **None does**: file a tracking issue before writing the prompt. In an
   engineering-team run, write its number or identifier to `run.yaml` as
   `tracking_issue:`.
3. **No work is handed over**, as in a discussion or a question, or the project
   takes no issues (§2): the prompt says "No issue:" and why.

A run files one tracking issue for its whole plan, never one per unit.

### 10.2 The tracking issue

It follows §6 with a `## Plan` section in place of Evidence:

- **TL;DR**: what the work delivers and why, a `Status:` line (how far along,
  and whether it is on track), and the next step.
- **`## Plan`**: one checklist item per unit, the ID followed by its meaning in
  plain words, such as `- [ ] W3 (cache customer totals)`. Tick an item when its
  unit is done. Strike an abandoned one, keeping its meaning, and say why:
  `- [ ] ~~W4 (page the invoice list)~~ dropped: not needed after W3`.
- **Title**: what the work delivers, in the repo's convention (§5).
- **Labels**: the type and severity of the work as a whole (§3), or the priority
  on Linear (§9.2).

````markdown
## TL;DR

- Invoice pages take 8 s to load; the goal is under 1 s.
- Status: 2 of 4 steps done, on track.
- Next: cache customer totals.

## Plan

- [x] W1 (add an index for invoice lookups)
- [x] W2 (stop loading every line item up front)
- [ ] W3 (cache customer totals)
- [ ] W4 (page the invoice list)

## Evidence

- Verified live: page load time fell from 8.2 s to 2.1 s after W1 and W2 (`k6 run load.js`, p95)
````

`issue_labels.py` checks it: a body with `## Plan` needs a `Status:` item in its
TL;DR, and each Plan item is a checklist item whose ID carries its meaning.

### 10.3 Milestone updates

The session doing the work updates the tracking issue at each milestone, with a
§7 comment and an edit that keeps the body's `Status:` line and checklist true.
Check each comment with `check-comment` and each edited body with `check` or
`check-body`, adding `--linear` on Linear (§9.4):

1. **Work starts**: which unit, and on which branch.
2. **A unit is done or abandoned**: tick or strike it, with the reason for an
   abandoned one.
3. **Blocked on someone**: what is needed, and from whom.
4. **A PR merges**: link it, and what it delivered.
5. **The work ends**: close it with a comment whose TL;DR says what was
   delivered, or say what remains and who picks it up.

A PR that finishes the plan says `Closes #<n>` or `Fixes <KEY-n>`. A PR that
delivers part of it names the issue with no closing word, so the issue stays
open.

In a run with lanes, the coordinator alone edits the tracking issue's body, as
it alone writes the dashboard (`multi-session.md`). A lane worker comments at
its own milestones and never edits the body.

Every prompt that hands the work on names the tracking issue and tells the next
session to keep these updates going.
