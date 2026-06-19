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
  - Check whether the repo has a remote on GitHub under the `johnmathews` account. If not, ask the user to confirm
    before creating a new repo on the `johnmathews` GitHub account and pushing the local repo to it.
- Run `git status` and `git diff` to understand the current state of the working tree.
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
- If either exists, the repo **must** have a GitHub Actions workflow that builds the Docker image and pushes it to
  `ghcr.io`. Check for this using **`git ls-tree -r HEAD --name-only .github/workflows/`** (not filesystem globs or
  `ls`) to list all tracked workflow files, then **read the contents of each one**. Using `git ls-tree` is critical
  because filesystem tools (glob, ls, find) can miss tracked files if the working tree is stale, sparse, or if files
  were checked in by another branch. Do not just check for a specific filename — a workflow named `build-and-push.yml`,
  `ci.yml`, or anything else could already handle Docker publishing. Look for steps that use
  `docker/build-push-action` or push to `ghcr.io`.
- **If an existing workflow already builds and pushes to `ghcr.io`:** verify it looks correct (targets the right
  registry and image name). Fix any obvious issues. **Do not create a second workflow.**
- **If no existing workflow handles Docker publishing:** before creating anything, double-check by running
  `grep -r "ghcr.io" .github/ 2>/dev/null` and `grep -r "build-push-action" .github/ 2>/dev/null` to confirm
  no workflow references Docker publishing. Only after both return empty should you create one in
  `.github/workflows/` (and the `.github/` directory if needed) with a workflow that:
  - Triggers on push to `main` (and optionally on tags)
  - Logs in to `ghcr.io` using `GITHUB_TOKEN`
  - Builds the image and pushes it to `ghcr.io/johnmathews/<repo-name>`
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

**Important:** The journal must cover all meaningful work from this session, including work done by earlier /done phases.
If any of these were set up or significantly changed during this wrap-up, they belong in the journal:
- Test suite or test runner setup (e.g., adding vitest, pytest, configuring coverage)
- CI/CD workflows (e.g., creating GitHub Actions for Docker builds)
- Linter setup or configuration changes
- Dependency additions that change the project's tooling
- Infrastructure or config fixes (e.g., Dockerfile changes, docker-compose fixes)

If a journal entry already exists for today's session (written earlier in the conversation before /done ran), update it
to include any additional work done during the wrap-up phases rather than creating a duplicate entry.

## Phase 8 — Commit & Push

- **Pre-commit check:** Before committing, verify that Phase 7b (Journal) was completed. If the journal entry has not
  been written or updated yet, do it now before proceeding.
- **Squash into logical groups.** Each commit should be meaningful and self-contained — not one per file, but not one
  monolithic commit either. A commit should make sense on its own when read in `git log`.
- Write clear commit messages that explain the _why_, not just the _what_.
- After committing, run `/merge-push` to handle merging into main, pushing, worktree cleanup,
  and CI monitoring. `/merge-push` will assess the branch state, check for conflicts, ask for
  explicit confirmation before merging and before pushing, then monitor any triggered GitHub
  Actions workflows and fix failures automatically (up to 3 attempts).

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
| Commit & Push       | ...    | ...                                                  |
| CI Monitoring       | ...    | ...                                                  |
+---------------------+--------+------------------------------------------------------+
```

**Status** column values:
- `OK` — phase passed with no changes needed
- `Fixed` — issues were found and resolved
- `Warned` — issues flagged but not blocking
- `N/A` — phase did not apply (e.g., no test suite, no Dockerfile)

**Details** column: one-line summary of what happened. Examples:
- Documentation: must cite the freshness audit — `"Audited 4 changed modules + new env var vs docs/README/CLAUDE.md; fixed 1 stale default, added 1 README link"` or, when genuinely clean, `"Audited N changed surfaces vs docs — all current"` (never a bare `"No changes needed"`, which signals the audit was skipped)
- Security & Privacy: `"Added .env to .gitignore, moved API key to vault"` or `"No secrets found"`
- Code Review: `"Simplified error handling in deploy.yml"` or `"No issues found"`
- Commit & Push: `"2 commits pushed to main"` or `"PR #42 created on feature/xyz"`
- CI Monitoring: `"CI passed on first run"` or `"CI failed, fixed lint error, passed on retry"` or `"No workflows"`

If any phase had `Fixed` or `Warned` status, add a **Notable Changes** section below the table with brief details
about what was changed and why, grouped by phase.
