# Hand-over prompts name a tracking issue; Linear issues read without the repo

> Purpose
>
> Why every prompt a skill writes to hand work on now names an issue that tracks the work, why Linear issues must make sense to a product owner without the GitHub repo, and what was decided.

## 1. Why

The user asked for two things, the same day as the TL;DR change (`261127-issue-tldr-shape.md`):

- **Prompts:** a prompt that hands work to another session should refer to the issue for that work, or create one and keep it current as the work moves.
- **Linear:** a Linear issue may use internal references such as `W2` or an ADR number, but a product owner without the repo must still understand it.

Three places write such prompts: `/prompt` (the hand-over), its Step 4b (lane hand-offs), and Phase 4's next-unit prompt.

## 2. Decisions (the user's, 2026-11-27)

- **The reader-without-the-repo rule applies to Linear only.** GitHub issues on a personal repo are read by people who have the repo.
- **One tracking issue per plan, never one per unit.** Its TL;DR carries a `Status:` line, and a `## Plan` checklist has one plain-language line per unit.
- **Updates at milestones:** work starts, a unit is done or abandoned, the work is blocked on someone, a PR merges, and the work ends.

## 3. What changed

1. `references/issues.md`:
   - **§1 item 4:** a hand-over prompt now needs an issue.
   - **§9.4 (Linear):** the TL;DR names no internal reference or path; each `W<n>`/`F<n>`/ADR/RFC carries its meaning at first use; Evidence claims are in plain words.
   - **§10 (tracking issues):** when to file one, its shape, milestone updates, and the rule that only the coordinator edits its body in a lane run.
2. `issue_labels.py`:
   - A body with `## Plan` is checked as a tracking issue. It needs no Evidence, but must have a `Status:` item, and each Plan item must be a checklist item that explains its ID.
   - `--linear` on `check-body` and `check-comment` adds the §9.4 checks.
   - 32 tests; the 2 new ones failed before the change (observed).
3. **Pointers:**
   - `/prompt`: Step 1 item 7, a new Step 3b, the prompt's item 10, lane item 7, and the report.
   - Phase 4 Step 5b item 9, the router's progress rules, `run.yaml`'s optional `tracking_issue:`, and the single-writer table in `multi-session.md`.
   - `/done` Phase 7a, rule-ownership rows, and two drift signatures.

## 4. Observations

- `check_run.py` already accepts an unknown top-level key, so `tracking_issue:` needed no schema change (confirmed with a scratch `run.yaml`).
- The internal-reference pattern is deliberately narrow: `W<n>`, `F<n>`, `ADR-<n>` and `RFC-<n>`. References inside inline code and the appendix are ignored. A wider pattern would flag product names and versions.
- **Review findings.** Review found nine gaps, all fixed:
  - Linear update steps were missing `--linear`.
  - A hand-over could edit the body of an issue a person wrote. It now comments instead.
  - Lower-case `adr-7` refs, bare paths and link-wrapped plan IDs slipped through.
  - The struck-item form needed an example.
  - The checker took any `## Plan` heading to mean a tracking issue, so `## Plan` is now reserved for tracking issues.
  - Comments are now stated to explain their own references.

## 5. What is deliberately not done

- **No PO rule on GitHub issues**, at the user's choice.
- **No sub-issues per unit.**
- **No automatic milestone posting.** The skills tell each session when to post; nothing enforces that it does. Only the shape of what it posts is checked.
- **No real Linear run yet.** As with the first Linear change, the path has not run against a real workspace (unverified).
