# Wrap Up Session

Review, document, test, and ship all changes from this session. This command is project and stack agnostic — the project
might use Python, Bash, TypeScript, Ansible, or any other language/tooling. Prefer to progress through each phase rather
than getting stuck or aborting.

## Output Formatting Rule

When presenting recommendations, questions, conclusions, or advice to the user, always use **numbered lists**
(1, 2, 3...) instead of bullet points. This applies to all output — summary report notable changes, code review
findings, security findings, and any other actionable or notable points. The user refers to items by number,
so every such point must be numbered.

## Ground Rule — Research Before Acting

Do not rely on training data for technical details. API surfaces change, security best practices evolve, documentation
gets updated, and config formats shift between versions. Before writing or modifying any CI/CD workflow, GitHub Actions
config, Docker setup, linter config, or documentation that references a 3rd-party service, SDK, or API:

1. **Look it up.** Use whatever research tools are available to you (web search, documentation lookup, MCP tools, etc.)
   to verify the current correct syntax, options, and behavior. Do not assume you remember correctly — verify.
2. **Check versions.** If the project pins a tool or library version, look up docs for that specific version, not the
   latest.
3. **Never fabricate.** If you cannot verify a fact (e.g., a CLI flag exists, an API endpoint is correct, a config key
   is valid), say so and ask the user rather than guessing.

This applies throughout every phase below. When in doubt, search first.

## Phase 0 — Sanity Check

- **Git repo check:**
  - If the project is not a git repo, **ask the user** before initializing one with `git init`. Some projects
    (notes, config directories, documentation collections) may not need git.
  - Read the repo's owner from `git remote get-url origin`. If there is **no remote at all**, ask the user to
    confirm before creating one (default owner `johnmathews`) and pushing to it. Do **not** assume the repo
    belongs to `johnmathews` — on a work project it does not, and every downstream rule that assumes it
    (registry, PR target, review expectations) is then wrong.
- **Governance check.** Establish early whether `main` is protected, because it decides how Phase 8 ships:
  `gh api repos/{owner}/{repo}/rulesets` and `gh api repos/{owner}/{repo}/branches/main/protection` (either may
  404 — that's an answer, not an error). A repo with a remote gets the PR path regardless; protections just tell
  you what the PR must satisfy.
- Run `git status` and `git diff` to understand the current state of the working tree.
- **Worktree check.** Compare the two git dirs, **normalising both to absolute** — if they differ you are in a
  worktree, which is the expected state for engineering-team work:
  ```bash
  [ "$(git rev-parse --path-format=absolute --git-dir)" \
    != "$(git rev-parse --path-format=absolute --git-common-dir)" ] && echo "in a worktree"
  ```
  Do **not** compare the bare forms: from a subdirectory of the main checkout `--git-dir` renders absolute and
  `--git-common-dir` renders relative, so the naive comparison reports "worktree" for any main-checkout subdir.
  If you are **on `main` in the main checkout** with uncommitted changes, stop and tell the user: work should
  have started on a branch, and the fix (branch now, or move the changes) is theirs to choose.
- If the working tree is clean and there are no unpushed commits, use the current conversation context to understand what
  was worked on during this session. This context is sufficient to inform documentation and journal updates in later
  phases.
- **Detect project type.** Before proceeding, classify the project to inform which phases apply:
  - **Code project:** Contains executable source code (Python, JS/TS, Go, Rust, etc.) → all phases apply.
  - **Non-code project:** Contains only markdown, YAML config, documentation, notes, or similar non-executable
    content → skip Phases 3, 5, 6, 7 (tests, code review, lint). Phases 1 (CI/CD), 2 (docs), 4 (security),
    7b (journal), 8 (commit/push), and 9 (summary) still apply.
  - **Mixed project:** Some code + mostly config/docs (e.g., Ansible playbooks with a helper script) → apply
    test/lint/review phases only to the executable code portions. Do not demand full test coverage for YAML,
    markdown, or configuration files.
  - **Ansible/infrastructure project:** Playbooks, roles, inventories → treat as mixed. `ansible-lint` applies
    but pytest/unit tests are optional unless there are custom modules or plugins with Python code.

## Phase 1 — CI/CD for Docker Projects

- Check whether the repo contains a `Dockerfile` or `docker-compose.yml` (or `docker-compose.yaml`).
- If either exists **and the project publishes images**, exactly one workflow should own that publish. Check using
  **`git ls-tree -r HEAD --name-only .github/workflows/`** (not filesystem globs or `ls`) to list all tracked
  workflow files, then **read the contents of each one**. Using `git ls-tree` is critical because filesystem tools
  (glob, ls, find) can miss tracked files if the working tree is stale, sparse, or if files were checked in by
  another branch. Do not just check for a specific filename — a workflow named `build-and-push.yml`, `ci.yml`, or
  anything else could already handle Docker publishing. Look for steps that use `docker/build-push-action` or push
  to a registry.
- **Read where it publishes; don't assume where it should.** `ghcr.io/<owner>/<repo-name>` is the sensible default
  for a personal repo with no existing publisher. A repo owned by someone else, or one already publishing to its own
  registry, is not misconfigured for failing to match a personal default.
- **If an existing workflow already builds and pushes to `ghcr.io`:** verify it looks correct (targets the right
  registry and image name). Fix any obvious issues. **Do not create a second workflow.**
- **If no existing workflow handles Docker publishing:** before creating anything, double-check by running
  `grep -r "ghcr.io" .github/ 2>/dev/null` and `grep -r "build-push-action" .github/ 2>/dev/null` to confirm
  no workflow references Docker publishing. Only after both return empty should you create one in
  `.github/workflows/` (and the `.github/` directory if needed) with a workflow that:
  - Triggers on push to `main` (and optionally on tags)
  - Logs in to the registry using `GITHUB_TOKEN`
  - Builds the image and pushes it to `ghcr.io/<owner>/<repo-name>` (owner read from `git remote`, not assumed)
- **Duplicate workflow check:** After this phase, there must be exactly **one** workflow that pushes Docker images.
  If you find multiple workflows doing the same thing, consolidate them — keep the better one and delete the other.
- **Docker healthcheck validation:** If any `docker-compose.yml`/`docker-compose.yaml` contains a `healthcheck` command,
  verify that the command is actually available inside the container image. For example, `curl` is often missing from slim
  images. Check by running `docker exec <container> <command> --version` or inspecting the base image. If the command is
  not available, replace it with an alternative that is (e.g., use `python -c "import urllib.request; ..."` instead of `curl`).

## Phase 2 — Documentation

- **Documentation freshness audit (mandatory — do NOT self-certify).** Concluding "docs look fine" from a glance is
  the known failure mode of this phase: it produces a false `OK` while stale claims, missing structure entries, and
  undiscoverable new docs slip through. You must actively audit against the shipped code, not assume. Run these steps
  and produce evidence:
  1. **Derive the changed surfaces from the diff, not from memory.** From `git diff <base>...HEAD` plus session
     context, list every surface documentation could describe: new/renamed/deleted modules or packages; new or changed
     public functions/signatures; new env vars or config keys; new DB migrations; new/changed API routes or MCP tools;
     new features, commands, or flags; and any *behavior* that changed (not just code that moved). This list is the
     audit's checklist — if you skip it, you are self-certifying.
  2. **Audit each surface against the docs with fresh eyes.** If the session changed code, structure, config, or APIs,
     **dispatch a subagent whose sole job is to cross-check documentation claims against the SHIPPED code** and return
     concrete findings with `file:line`. (A dedicated adversarial pass is what reliably catches issues; the author who
     just wrote the code is blind to their own stale assumptions.) For trivial or doc-only sessions, run the same three
     checks inline. The audit MUST cover all three of:
     - **Accuracy / staleness:** Does any doc, top-level `README.md`, `CLAUDE.md`, or architecture/design doc describe
       OLD or REMOVED behavior as if current? Grep for now-wrong claims (old defaults, removed flags, "fixed top-N",
       renamed files/modules, outdated counts/ranges like a migration range). Verify any `path`/`path:line`/module
       reference in the docs still resolves to real code.
     - **Completeness:** Is the change reflected everywhere structure/config/API is documented? E.g. a new module in the
       `CLAUDE.md` project-structure tree, a new env var in the configuration doc, a new migration in the stated
       migration range, a new route in the API reference.
     - **Discoverability:** Is every new or substantially-changed doc reachable from the project's entry points — the
       top-level `README.md` documentation list and/or a `docs/` index? A correct doc nobody can find is still a
       failure. If nothing links it, add the link (and note if the project lacks a docs index at all).
  3. **Fix what the audit finds**, then update existing docs to reflect this session's changes and create new docs if a
     new service, feature, or concept warrants its own guide.
  3b. **The summary may not be stronger than the source.** This is the step where documentation rot is *created*,
     not merely missed. Compressing a session into a doc update means restating claims more briefly — and brevity is
     where "the job exited 0" quietly becomes "the job worked", and then "the feature is live", with no new evidence
     entering anywhere. **The sentence looks like a summary; it is an inference wearing a summary's clothes** — which
     is why re-reading the finished doc never catches it. Check each claim against the *source* you are compressing,
     not against how reasonable it sounds. If the source says a job exited zero, the doc may say the job exited zero.
  3c. **Match each stamp's method to its claim.** When bumping `Last verified` on a living doc, the method you write
     must support the *kind* of claim the doc makes. A runtime claim ("deployed", "live", "calls X") needs a runtime
     observation — a run id, a job name, a log line. "Re-derived from the other docs" verifies a doc-derived claim and
     nothing else. Where a doc mixes claim kinds, stamp the methods separately and name what was *not* re-verified.
  3d. **Classify what you write.** New or restructured docs follow the six-type documentation model — see
     `~/.claude/skills/engineering-team/references/documentation-model.md`. The load-bearing calls: a hard-to-reverse
     decision gets an ADR (a *new* one superseding the old — never edit the original); a **concept** with real
     onboarding load gets an explainer, not a README section; and anything under `docs/adr/`, `docs/rfc/`, or
     `journal/` is point-in-time and is **never** retro-edited to match what you learned later.
  4. **Evidence required — no bare `OK`.** You may record this phase as `OK` only after the audit actually ran. The
     Phase 9 summary must state WHAT was audited and WHAT was found/fixed (e.g. "audited 4 changed modules + new env var
     vs docs/README/CLAUDE.md — fixed 1 stale default, added 1 missing README link"), never an unsupported "no changes
     needed". Red flag: if you are about to write "documentation is fine" without having listed the changed surfaces and
     checked each one, STOP — you have not done the audit.
- **Markdown table review:** After creating or updating any markdown file that contains tables, review every table to
  ensure it is correctly formatted: columns must be properly aligned, column widths must be consistent, header separators
  must match column count, and cells must not overflow or break the table structure. Fix any issues before moving on.
- **Planning-doc hygiene.** If this session created or substantially modified a planning doc in `docs/` (roadmap,
  refactor plan, tier plan, architecture plan, feature design, anything that's intended to live and be referenced in
  future sessions — *not* per-session journal entries or reference docs like API guides):
  - **Status header at top.** Ensure the doc starts with
    `**Status:** active. **Last updated:** YYYY-MM-DD. **Supersedes:** <doc-or-none>.` Update `Last updated` if the
    doc already had a header. This makes the doc's lifecycle state visible without cross-referencing a roadmap.
  - **Mark and archive superseded plans.** If the new doc replaces an existing plan, or this wrap-up closes a plan
    (all work units shipped), add `**Status:** superseded by [<new-plan>](./<new-plan>.md) (YYYY-MM-DD).` or
    `**Status:** closed YYYY-MM-DD.` to the **top of the old plan**, then `git mv` it into `docs/archive/` and update
    inbound links from any active docs. Decisions and rationale stay accessible while the active `docs/` listing stays
    easy to scan. Do not just leave closed/superseded plans alongside active ones — that turns the listing into shadow
    inventory.
  - **Index from canonical roadmap.** If the project has a `docs/roadmap.md` (or equivalent canonical index), add
    a link to the new plan from the roadmap in this same wrap-up. Plans that aren't indexed turn into shadow
    inventory — discoverable only by readers who already know they exist.
  - **Prefer shorter docs, no hard cap.** If a planning doc has grown unwieldy, consider whether it could be split
    (decisions doc + execution doc) or trimmed of restated background — but do not reflow unprompted, and do not treat
    length itself as a problem if scope and detail genuinely warrant it.

  Skip these steps for non-planning docs — reference docs (API guides, architecture explainers, runbooks) live by
  different rules and don't need lifecycle headers.
- **Do not write the journal entry yet.** Later phases (Tests, CI/CD, Lint) may add significant infrastructure work
  (e.g., setting up a test runner, creating CI/CD workflows, fixing lint config). The journal entry must capture all
  meaningful work from the entire wrap-up, not just what existed before /done ran. The journal is written in Phase 7b.

## Phase 3 — Tests (pre-review)

**Skip this phase** if the project was classified as non-code in Phase 0 (markdown, notes, YAML config,
documentation-only repos). Do not demand tests for projects that have no executable code to test.

For code and mixed projects:
- **If the project contains code, it must have tests.** A project with code but no tests is a serious issue — do not
  proceed past this phase without either writing tests or getting explicit user acknowledgment that tests are being
  skipped. Create a test suite if none exists.
- If the project has a test suite, run it and fix any failures.
- **Never pipe a test command.** `pytest -q | tail -25` reports **`tail`'s** exit code, not pytest's: the suite
  fails, the step passes, and the summary says green. The same applies to any `| head`, `| grep`, or `| tee` after a
  command whose exit status is the evidence. Either don't pipe, or set `pipefail`
  (`set -o pipefail` in bash; `PIPESTATUS[0]` to inspect). If output is long, let it be long, or write it to a file
  and read the file — **do not trade the verdict for tidier output.** This is not hypothetical: a real project
  reported "exit code 0" with two tests failing this way, in a session whose whole subject was verification rigour.
- **Read the actual result, not the last line.** A summary line is a claim; the exit code is the check. If they
  disagree, believe the exit code and find out why.
- Write tests for new functionality. Tests turn uncertainty into boredom — be aggressive about coverage for new public
  interfaces and complex logic.
- **Coverage reporting:**
  - **Python (pytest):** Check whether `pytest-cov` is already configured (look for `--cov` in `addopts` in
    `pyproject.toml`, `pytest.ini`, or `setup.cfg`). If it is, just run `pytest` normally — it already collects
    coverage — then run `coverage html` to generate the HTML report from the `.coverage` file it produced. Do NOT
    wrap it with `coverage run -m pytest`, as that creates two competing coverage collectors (the outer `coverage run`
    and the inner `pytest-cov`), causing sqlite3 `ResourceWarning` errors and inaccurate results.
    If `pytest-cov` is NOT already configured, use `coverage run -m pytest && coverage html`. Generate an HTML
    coverage report in `htmlcov/`. If neither `coverage` nor `pytest-cov` is installed, install one first.
  - **Other languages:** If the test framework has a coverage equivalent (e.g., `nyc`/`c8` for JS/TS, `go test -cover`
    with `go tool cover -html`, `cargo-tarpaulin` for Rust, `JaCoCo` for Java), use it to generate an HTML coverage
    report. If no coverage tool is readily available, note the gap but do not block on it.
- Do not proceed until all tests pass.

## Phase 4 — Security & Privacy

Scan the repo for secrets, credentials, and sensitive data that should not be committed. This phase exists because
leaking secrets to a public repo is one of the highest-impact mistakes — catching it here is far cheaper than rotating
credentials later.

- **Secrets scan:** Search tracked files and staged changes for patterns that look like API keys, tokens, passwords,
  private keys, or connection strings. Common patterns:
  - Hardcoded passwords or tokens (e.g., `password = "..."`, `token = "..."`, `SECRET_KEY = "..."`)
  - AWS keys (`AKIA...`), GitHub tokens (`ghp_...`, `gho_...`), Slack tokens (`xoxb-...`, `xoxp-...`)
  - Private keys (`-----BEGIN.*PRIVATE KEY-----`)
  - `.env` files with real values, `credentials.json`, `*.pem`, `*.key` files
- **PII check:** Look for hardcoded email addresses, IP addresses, or personal data that should be parameterized or
  vaulted rather than committed in plaintext.
- **.gitignore audit:** Verify `.gitignore` exists and covers common sensitive patterns: `.env`, `*.key`, `*.pem`,
  `credentials.json`, `vault_password`, `*.secret`. If `.gitignore` is missing or inadequate, update it.
- **Ansible vault check** (if applicable): Ensure vault-encrypted files (`vault.yml`, etc.) are not being committed in
  plaintext. Verify any new secrets are added to vault rather than plaintext vars.
- If any issues are found, fix them (remove secrets, add to `.gitignore`, move to vault) before proceeding. If a secret
  was already committed in git history, flag it to the user — it may need to be rotated.

Record findings for the summary report in Phase 9.

## Phase 5 — Code Review

**Skip this phase** for non-code projects. For mixed projects, review only the code portions.

Review all changes made in this session (use `git diff` and conversation context) for:

- **Architecture:** Are abstractions appropriate? Is complexity justified? Are there simpler alternatives?
- **Robustness:** Edge cases, error handling at system boundaries, failure modes.
- **Security:** No injection vectors, no leaked secrets, no unsafe defaults.
- **Duplication:** Is there repeated logic that should be consolidated?
- **Naming and clarity:** Would another developer understand this without explanation?

If issues are found, fix them and loop back to Phase 0. **Maximum 2 iterations** — if issues persist after two passes,
flag them to the user and proceed.

## Phase 6 — Tests (post-review)

**Skip this phase** if Phase 3 and 5 were skipped (non-code project).

Run the full test suite again to validate any fixes made during code review. Do not proceed until all tests pass.

## Phase 7 — Lint

**Skip this phase** for non-code projects unless a relevant linter exists (e.g., `ansible-lint` for playbooks,
`markdownlint` for docs). Do not install a linter just because one is missing on a non-code project.

For code and mixed projects: detect the project's linter (check for Makefile targets, config files, `package.json`
scripts, `pyproject.toml`, etc.) and run it. If no linter is found, recommend that the project adopt one, then proceed.
If the linter fails, attempt to fix the issues. If fixes are not straightforward, proceed anyway — pre-commit hooks
will catch remaining problems. This phase should not block shipping.

## Phase 7b — Development Journal

Now that all phases that produce meaningful work are complete, write the journal entry. The project should have a
`/journal` directory at the repo root.

Add a journal entry for meaningful work — features, fixes, explorations, architectural decisions, and significant
discussions. Skip entries for trivial chores or mechanical changes (linting, formatting, dependency bumps). Use freeform
markdown. Filename format: `yymmdd-descriptive-title.md` (e.g., `260317-fix-slack-unread-notifications.md`).

**The journal is point-in-time and authoritative for nothing.** That is not a demotion — it is the source of its
value, and it is worth understanding why before writing one:

- **Record what was observed, and no more.** Precisely-scoped weak claims ("the job ran, status=Succeeded") are the
  point. When a real project's living docs rotted into a false claim about what was deployed, the journal was the
  only document that stayed true — and the true, weak claim it held is what made the false, strong one *detectable*.
  Its accuracy came from never being a summary.
- **Never retro-edit it** to match what you later learned. It is a record of a moment, not of the truth. If you
  discover an earlier entry was wrong, **append a new entry saying so** — the correction is itself history worth
  keeping. (Updating *today's* entry with work done later in *this* session is not retro-editing; that's still the
  same moment.)
- **Grade your conclusions**: `confirmed` (observed), `strongly supported` (fits the evidence, nothing contradicts),
  or `suspected` (a hypothesis). Writing a strongly-supported root cause as proven is the same overclaim as any
  other; it just feels different because it's a conclusion.
- **Include `## What is deliberately not done`.** Scope you chose not to take, and why. This is the section future
  readers thank you for, because it distinguishes "not thought of" from "decided against".

**Important:** The journal must cover all meaningful work from this session, including work done by earlier /done phases.
If any of these were set up or significantly changed during this wrap-up, they belong in the journal:
- Test suite or test runner setup (e.g., adding vitest, pytest, configuring coverage)
- CI/CD workflows (e.g., creating GitHub Actions for Docker builds)
- Linter setup or configuration changes
- Dependency additions that change the project's tooling
- Infrastructure or config fixes (e.g., Dockerfile changes, docker-compose fixes)

If a journal entry already exists for today's session (written earlier in the conversation before /done ran), update it
to include any additional work done during the wrap-up phases rather than creating a duplicate entry.

## Phase 8 — Commit & Open a PR

**This phase never pushes to `main`.** It ships the work to a pull request and watches CI *there*, so a red commit
can't reach `main` in the first place. Fix-forward happens on the branch, where it belongs.

- **Pre-commit check:** Before committing, verify that Phase 7b (Journal) was completed. If the journal entry has not
  been written or updated yet, do it now before proceeding.
- **Squash into logical groups.** Each commit should be meaningful and self-contained — not one per file, but not one
  monolithic commit either. A commit should make sense on its own when read in `git log`.
- Write clear commit messages that explain the _why_, not just the _what_.

Then branch on what Phase 0's governance check found:

### 8a — Remote exists (the normal path)

1. **Check you're not on `main`.** If you are, stop and ask the user — the work needs a branch, and which one is
   their call.
2. **Check the PR isn't already merged**, if a PR exists for this branch: `gh pr view --json state,number`. A push to
   a **merged** PR's branch **succeeds silently**, is never merged, and runs no CI — the commits are stranded and
   nothing tells you. If the PR is `MERGED` or `CLOSED`, stop: the fix is a fresh branch off `main` with the commits
   cherry-picked, and you should say so rather than pushing into the void.
3. **Push the branch:** `git push -u origin <branch>`.
4. **Open the PR:** `gh pr create --fill` (respect any PR template — fill it in rather than around it). If a PR
   already exists and is open, the push updated it; say so instead of opening a second.
5. **Watch CI on the PR:** `gh pr checks <pr> --watch`. On failure: read the logs (`gh run view <id> --log-failed`),
   diagnose, fix **on the branch**, commit, push, re-watch. Up to 3 cycles, then report and stop.
   - A required check stuck at "Expected — Waiting for status" is almost always a path-filtered workflow that never
     started. That's a repo config bug, not something to wait out — see "Making a check required" in the
     engineering-team skill's `references/worktree.md`.
6. **Do not merge.** Merging is a separate, explicitly-confirmed act (`/merge-push`). A green PR is a fact about the
   PR, not permission to merge.

**"Don't push" narrows this to step 1 only** — commit, and report that the branch is ready. It does not cancel the
phase, and it does not license skipping Phase 9.

### 8b — No remote (scratch repo)

Commit, and tell the user the work is committed locally. Offer `/merge-push` if they want it merged. Do not create a
remote without asking.

## Phase 8c — Housekeeping (worktrees & branches)

Reap what has already landed, so stale worktrees and branches don't accumulate. **Propose, then confirm — never
reap silently.**

1. **Enumerate:** `git worktree list`, `git branch --merged main`, and `git worktree prune --dry-run`.
2. **Find what's really merged.** `git branch --merged main` is necessary but **not sufficient**: under
   **squash merges the branch tip is never an ancestor of `main`**, so a squash-merged branch is *not* listed and the
   naive check reaps nothing. The authority is the PR: `gh pr list --state merged --json headRefName,number`. Use
   both — locally-merged *or* PR-merged counts.
3. **Never reap when any of these hold** — report and skip:
   - The working tree is dirty (`git status --porcelain` in that worktree is non-empty).
   - It has unpushed commits.
   - A rebase or merge is in progress (`.git/rebase-merge`, `.git/rebase-apply`, `MERGE_HEAD`).
   - It is the worktree this session is running in.
   - Its PR is still open, or it has no PR and isn't merged.
4. **List what you propose to remove and ask.** Another session may own that tree, and a clean `git status -sb` can
   be one instant old — a real coordinator once entered an "idle" worktree and found a rebase in flight. Removing
   another session's work is not recoverable by apologising.
5. **On confirmation:** `git worktree remove <path>`, then `git branch -d <branch>` (use `-D` only for a
   squash-merged branch, after confirming via the PR state — `-d` will refuse it, correctly, because the tip isn't an
   ancestor). Finish with `git worktree prune` for directories that are already gone.

Record what was reaped for the Phase 9 summary.

## Phase 9 — Session Summary Report

Print a plain ASCII table summarizing what each phase found and did. This gives the user a quick at-a-glance record of
the session wrap-up. Use the following structure:

```
+---------------------+--------+------------------------------------------------------+
| Phase               | Status | Details                                              |
+---------------------+--------+------------------------------------------------------+
| CI/CD               | ...    | ...                                                  |
| Documentation       | ...    | ...                                                  |
| Journal (Phase 7b)  | ...    | ...                                                  |
| Tests (pre-review)  | ...    | ...                                                  |
| Security & Privacy  | ...    | ...                                                  |
| Code Review         | ...    | ...                                                  |
| Tests (post-review) | ...    | ...                                                  |
| Lint                | ...    | ...                                                  |
| Commit & PR         | ...    | ...                                                  |
| CI (on the PR)      | ...    | ...                                                  |
| Housekeeping (8c)   | ...    | ...                                                  |
+---------------------+--------+------------------------------------------------------+
```

**Status** column values:
- `OK` — phase ran and passed with no changes needed
- `Fixed` — issues were found and resolved
- `Warned` — issues flagged but not blocking
- `N/A` — phase did not apply (e.g., no test suite, no Dockerfile)

**This table is a set of claims, so the claim rules apply to it.** Ten verdicts get written here in one go, which
makes it the easiest place in the whole workflow to assert more than you checked:

- **`OK` means the phase ran and passed — not that it looked fine.** A phase you skipped is `N/A` with the reason,
  never `OK`. If you cannot say what the phase actually did, it did not happen.
- **Name the check.** "CI passed" is not a result; "`lint-types-test`, `docs-check`, `security-scans` green on
  PR #42" is. If you cannot name the check and say what would have turned it red, do not report it as green.
- **A claim may not be stronger than its evidence.** "Tests pass" says the suite exited zero. It does not say the
  change works, and it says nothing at all about code no gate executes (dispatch-only workflows, Dockerfiles built
  only at deploy, scripts embedded in YAML).
- **Report failures as failures.** A phase that hit something unresolved is `Warned` with the specifics, even when
  the rest went well. A tidy table is worth nothing if it's wrong.

**Details** column: one-line summary of what happened. Examples:
- Documentation: must cite the freshness audit — `"Audited 4 changed modules + new env var vs docs/README/CLAUDE.md; fixed 1 stale default, added 1 README link"` or, when genuinely clean, `"Audited N changed surfaces vs docs — all current"` (never a bare `"No changes needed"`, which signals the audit was skipped)
- Security & Privacy: `"Added .env to .gitignore, moved API key to vault"` or `"No secrets found"`
- Code Review: `"Simplified error handling in deploy.yml"` or `"No issues found"`
- Commit & PR: `"2 commits, PR #42 opened on feat/xyz"` or `"2 commits, no remote — committed locally"`
- CI (on the PR): `"lint-types-test + docs-check green on #42"` or `"lint failed on #42, fixed, green on retry"` or `"No workflows configured"` (name the checks — `"CI passed"` alone is not a result)
- Housekeeping: `"Reaped 2 merged worktrees (feat/a, feat/b); skipped feat/c — uncommitted changes"` or `"No stale worktrees"`

If any phase had `Fixed` or `Warned` status, add a **Notable Changes** section below the table with brief details
about what was changed and why, grouped by phase.
