# Evaluation report — <project name>

> Purpose
>
> <One short paragraph: what was evaluated, when, at which commit, and what
> the reader should do with this. Name the scope of the run.>

<!-- FILL: delete every <!- - ... - -> comment in this file as you fill it.
     A leftover comment means the section was not filled, and the gate
     (scripts/check_report.py) treats it as a hard failure. -->

## 1. Executive summary

<!-- FILL: 3-4 sentences, scannable in 10 seconds. What the project does,
     what is working, what needs attention first. No findings detail here —
     that is what section 2 is for. -->

## 2. Findings index

<!-- FILL: one row per finding, ordered by severity (Critical first).
     Every row here has a matching `### F<n>` block in section 3, and every
     block in section 3 has a row here. The gate checks both directions.

     Exactly one severity and exactly one grade per row, each from its
     closed set — see "Severity: what it would cost if it is true" and
     "Grade every finding" in references/general-guidelines.md.
       severity : Critical | High | Medium | Low
       grade    : [VERIFIED] | [SUPPORTED] | [SUSPECTED]
     No `[VERIFIED]/[SUPPORTED]`, no `Informational`, no `N/A`. If two
     grades both seem to fit, the weaker one is the true one. If it is not
     worth a Low, it is not a finding — put it in prose or delete it. -->

| ID | Severity | Grade | Finding | Location |
| --- | --- | --- | --- | --- |
| F1 | Critical | [VERIFIED] | <one line, the claim itself> | `path/to/file.py:12` |
| F2 | High | [SUPPORTED] | <...> | `path/to/other.py:40-48` |
| F3 | Medium | [SUSPECTED] | <...> | `docs/README.md` §2 |

## 3. Findings in detail

<!-- FILL: one `### F<n>` block per index row, same order. This is where the
     evidence lives; the index is what a human reads.

     The four fields below are required on every block. "Disconfirming
     check" is the one people skip: it is what you would expect to observe
     if the finding were FALSE, and whether you went and looked. For a
     [SUSPECTED] finding it is what would settle it. A detailed causal story
     is what a wrong claim looks like when you are being thorough — see
     "Name what would refute it, then go and look" in
     references/general-guidelines.md.

     A [VERIFIED] block must contain a fenced code block holding the command
     and its actual output. The gate fails a [VERIFIED] finding that quotes
     nothing — that combination is the commonest overclaim in this skill's
     record. -->

### F1 <short title>

- **Severity:** Critical — <the consequence if true. Not "it is bad">
- **Grade:** [VERIFIED] — <what earned it>
- **Location:** `path/to/file.py:12`
- **Disconfirming check:** <what you would see if this were false, and
  whether you looked>

<what the defect is, and what it costs>

```console
$ <the command>
<its actual output>
```

### F2 <short title>

- **Severity:** High — <consequence>
- **Grade:** [SUPPORTED] — read `path/to/other.py:40-48`, did not run it
- **Location:** `path/to/other.py:40-48`
- **Disconfirming check:** <...>

<detail>

### F3 <short title>

- **Severity:** Medium — <consequence>
- **Grade:** [SUSPECTED] — inferred; not observed
- **Location:** `docs/README.md` §2
- **Disconfirming check:** <what would settle it — this is the whole content
  of a SUSPECTED grade, and Phase 2 turns it into a verification unit rather
  than a fix>

<detail>

## 4. Test suite results

<!-- FILL: from Step 1. The runner, the command, what passed, what failed,
     coverage percentage. Quote the actual output. If there are no tests,
     say so here as well as in the index. -->

## 5. Project overview

<!-- FILL: what it does, its architecture, key technologies. Short. -->

## 6. Strengths

<!-- FILL: specific, cited. "Well structured" is not a strength; a named
     module that does one thing with a test proving it is. -->

## 7. Weaknesses

<!-- FILL: narrative on where the project falls short, referencing findings
     by ID (F3, F7) rather than restating them. If a paragraph here adds
     nothing beyond its index line, delete it. -->

## 8. NFR register

<!-- FILL: from Step 2.5. Every "prose only" row is a finding and needs a
     row in section 2. -->

| Requirement | Where stated | How enforced |
| --- | --- | --- |
| <e.g. no secrets in VCS> | `docs/security.md` §3 | <the check, or **prose only**> |

**Un-gated code inventory:** <code that ships but no gate reads — dispatch-only
workflows, deploy-time Dockerfiles, IaC, cron, heredoc scripts. Or "none found",
and how you checked.>

**NFRs absent rather than unenforced:** <the ones nothing points at. A browser UI
with no accessibility requirement at all is the commonest.>

## 9. Onboarding assessment

<!-- FILL: from Step 2.6 — you are the measurement. What you could not
     determine from the docs alone; what you had to verify against code and
     whether it held; where you got lost; whether the setup path would
     actually work and how you know. Measured against the project's stated
     bar if it has one. This evidence is gone once you know the codebase. -->

## 10. Assessment dimensions

<!-- FILL: one bullet per dimension, in the order phase-1-evaluation.md lists
     them — that list is the single definition of which dimensions exist and
     what each one asks. Score against the shared 1-5 anchor table in the
     same file. Every score names the observation behind it — a file, a
     measurement, a gate that does or does not exist. "3/5, could be better"
     is the absence of a rating.

     Omit Accessibility entirely unless the project serves browser pages. -->

- **<Dimension>:** <X>/5 — <justification naming the observation>

## 11. Dependency audit

<!-- FILL: name the manifest/lockfile you inspected, and list outdated or
     known-vulnerable dependencies — or state explicitly that none were
     found AND how you checked. This is the section evaluations most often
     silently drop. If the project has no dependencies, say that. -->

## 12. Gap analysis

<!-- FILL: what is missing — tests, docs, error handling, features. -->

## 13. Architectural assessment

<!-- FILL: for each major integration or subsystem, whether the chosen
     approach is the right one, not just whether it is implemented
     correctly. Cite the official docs you actually fetched. -->

## 14. Methodology and limitations

<!-- FILL: how this evaluation was run, and — the part that matters — what
     it did NOT cover. Team shape and agent count. Anything capped, skipped
     or sampled. Any brief nobody was given, so silence is not read as
     coverage. If a tool was unavailable (Playwright, Workflow), say which
     claim was therefore not made. -->
