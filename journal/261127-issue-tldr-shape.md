# Issues open with a TL;DR, on GitHub and Linear

> Purpose
>
> Why the issues that engineering-team and `/done` file now open with a TL;DR, follow the repo's title convention and mark their appendix, how Linear joined GitHub, and what was observed while building it.

## 1. Why

The issue body built on 2026-11-08 was a record first: a dense opening paragraph, then Evidence, Judgement and "Why it is not fixed now". `codespaces-setup#112` and `home-server#481` show the cost: the fix sits two sections down. The title rule ignored conventions the repo already had, such as home-server's `Immich: ...` titles. Nothing said how to update an issue, so a body's summary went stale as comments added facts. Work is moving to Linear, which the skills never filed in.

## 2. What changed

1. `references/issues.md`:
   - **§1** names the tracker in a `## Issues` section of the project's `CLAUDE.md`: `Tracker:`, `Team:`, `Project:`, `Areas:` and `Titles:`.
   - **§5 (title):** the `Titles:` line, else the pattern most of the last 30 titles share, else the claim alone.
   - **§6 (body):** `## TL;DR` first, then Evidence, an optional `## Appendix` last, and a one-line footer. The Judgement and "not fixed now" sections are gone: severity and the fix move into the TL;DR, and the reason moves into the footer.
   - **§6 (diagrams and screenshots):** mermaid for flows. Screenshots are embedded on Linear and linked from the repo on GitHub, because `gh` cannot upload images.
   - **§7 (updates):** a comment opens with `**TL;DR:**`, and the body is edited when its TL;DR stops being true. Only a body the flow wrote is edited; a teammate's ticket gets a comment.
   - **§9 (Linear):** severity maps to priority. Labels are only ones the workspace has, and none is ever created there. The MCP tools are picked by capability.
2. `issue_labels.py`: `check` and `verify` enforce the TL;DR (first, 2 to 5 items, at most 90 words, no "see below") and the appendix (exactly `## Appendix`, once, last). They no longer require `## Judgement`. New `check-body` serves Linear and `check-comment` serves updates.
3. Tests grew from 26 to 30 cases. Every body violation now also asserts the reason it failed. Two drift signatures guard the TL;DR and update rules.

## 3. Decisions

The user chose these during the run:

- Linear at work, with no migration of existing tickets.
- The TL;DR, Evidence and Appendix shape over keeping Judgement.
- Enforcement in the script rather than prose only.

## 4. Observations

- Before the change, several of the new violation cases already failed, but only because the old rule rejected any body without `## Judgement`. A pass for the wrong reason, so each case now names its reason.
- Against the old script, the new suite (then 29 cases) failed 8. Against the new script, all passed. `check-body` on `#112`, which was filed in the old shape, fails for the missing TL;DR, as it should.
- Linear's docs (fetched 2026-11-27) confirm mermaid rendering and markdown image upload. They do not name the MCP tools or say whether `<details>` renders, which is why the rules avoid both.
- A `git checkout -- <file>` used to undo a seeded fault reverted the uncommitted rewrite of `issues.md`. It was restored from the session. Seed faults on a copy, or after a commit.

## 5. Found during wrap-up

- **Parsing gaps (confirmed by running each input).** The `/done` code review found real bodies the first parser misread:
  - `~~~` fences, and a four-backtick fence holding three backticks.
  - Raw output inside `<details>`.
  - Hard-wrapped list items.
  - Indented prose that escaped the TL;DR checks.
  - A `* * *` break counted as a bullet.

  The parser now follows the CommonMark fence rules, and one new test covers them all. It fails against the pre-review parser.
- **Footer bug (confirmed).** Filing the first issues in the new shape failed the checker: a footer under `---` counted as Evidence prose whenever the body had no appendix. The template only showed the footer after an appendix, so the tests had missed it. A top-level `---` now ends the last section.
- **Follow-up issues.** The first two filed in the new shape:
  - #116: `tests/claude-config-dir` uses GNU `stat -c`, which fails on macOS.
  - #117: scenario 13 of `tests/setup-resilience` fails on macOS, cause unverified.

  Both are red only on macOS. `ci.yml` on `main` at the same base was green.

## 6. What is deliberately not done

- No migration of existing GitHub issues or Linear tickets to the new shape, at the user's request. `verify` fails on old-shape bodies such as #112, so it is meant for issues filed from now on.
- No Linear label scheme, and no label creation in Linear: a work workspace is shared, so the skill uses the labels it finds.
- No hardcoded Linear MCP tool names, because Linear's docs do not publish them. The Linear path has not run against a real workspace yet (suspected to work, unverified).
- No HTML `<details>` on Linear, because its docs do not say it renders.
