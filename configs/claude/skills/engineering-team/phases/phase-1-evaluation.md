# Phase 1: Evaluation

> This file is loaded by the lead engineer at the start of Phase 1, when no
> evaluation report exists yet and the user's request begins with
> evaluation/assessment.

## Announce the phase

Before any other action in this phase, tell the user in one plain-prose
line that you are entering Phase 1 (evaluation).

## File persistence mandate

The evaluation report MUST be written to `$RUN_DIR/evaluation-report.md`
on disk using the Write tool — not produced inline in the chat, not embedded
in a commit message, not described in prose. The file on disk is the
contract — the chat message is only an announcement that the file exists. If
`$RUN_DIR` does not exist, `mkdir -p` it first. After writing, open it in the
user's default viewer if a GUI opener exists (`open` on macOS,
`xdg-open` on Linux) — skip this on headless hosts. Do not proceed past Phase 1 to Phase 2 until the file
exists on disk.

---

The goal is to produce a thorough, honest assessment of the project. This is not a rubber stamp — the team
should actively look for problems, not just describe what exists.

### Step 0: Clarifying questions (mandatory)

Before any analysis — before even the test suite — load
`../references/team-structure.md` and follow its "Asking Questions"
section. Batch the questions (immediate priorities and anything broken
right now, which parts of the codebase matter most, deployment
concerns, primary use case) and wait for the user's answers before
proceeding. This step is not optional — skipping it produces generic
evaluations that miss what actually matters. If an answer surfaces
something urgent, load `../references/general-guidelines.md` and run
its Triage flow before the full evaluation.

### Step 1: Run the test suite and check for a linter

**Linter check:** Check whether the project has a linter configured. Look for:
- `ruff.toml`, `pyproject.toml` with `[tool.ruff]` or `[tool.flake8]`, `.flake8` (Python)
- `eslint.config.js`, `.eslintrc.*`, `package.json` with an `eslint` dependency (JS/TS)
- `.golangci.yml` (Go)
- `clippy.toml` or clippy in CI config (Rust)
- `.ansible-lint` (Ansible/YAML)

If no linter is found, note the absence as a finding in the evaluation. Do not set up a linter
during evaluation — that's a development action. If Phase 3 runs, linter setup becomes a work
unit in the improvement plan.

**Test suite:** Before any analysis, detect the project's test runner and run the full test suite. Record
what passes, what fails, and any errors. This gives you concrete data immediately — failing
tests tell you where problems are, passing tests tell you what's working. Report the results
at the top of the evaluation.

**If the project contains code but has no tests, flag this as a serious issue** — at minimum
a **High** priority finding in the evaluation, potentially **Critical** if the code handles
user data, authentication, or other sensitive operations. A codebase without tests is a
codebase where bugs hide indefinitely.

**Coverage:** When running tests, record the coverage percentage (e.g., `coverage run -m pytest`
then `coverage report` for Python, `go test -cover` for Go, `npx c8` for JS/TS). Include the
percentage in the evaluation report. Do not generate HTML coverage reports during evaluation —
save that for the final Phase 3 test run, where it provides a meaningful before/after comparison.

### Step 2: Reconnaissance

Do not make assumptions about the codebase. Read the code, run the tests, check the docs.
If something is unclear, investigate — don't guess. Every finding must be backed by something
you actually observed in the code, not something you inferred or expected to find.

Do not rely on training knowledge for facts about external services, APIs, libraries, or
frameworks. Use `WebSearch` and `WebFetch` to look up current documentation. Libraries change,
APIs get deprecated, SDKs add new features — your training data may be stale. When the codebase
uses a third-party API or SDK, go read the current official documentation for it.

**When citing web sources, always include the actual URL you fetched.** Do not cite URLs you
didn't actually visit, GitHub issues you didn't actually read, or documentation pages you
didn't actually fetch. If you can't provide the real URL, say "based on training knowledge"
instead of fabricating a source.

**Team sizing:** Match the team to project complexity, not line count. Signals
that argue for a larger team: many external integrations, Docker / CI/CD,
ambitious roadmap vs. small implementation, multiple subsystems, broad
evaluation scope, browser UI to verify.

- **Lightweight (2-3 subagents)** for small, focused projects: collapse
  Engineers 1+2 (structure + quality + tests + web research) and 3+4
  (security + deployment). Keep the Product Owner if docs exist. Engineer 5
  only if there's a UI.
- **Standard (4-6 subagents)** for most projects: use the full team below.

When in doubt, go standard — over-investigating is cheaper than missing
something important. Launch subagents in parallel (dispatch mechanics:
"Dispatch mechanics" in `../references/team-structure.md`, loaded in
Step 0):

**Engineer 1 — Codebase structure, quality, and problem space research:**

The team's primary web researcher — findings on dependencies, APIs, and best
practices are shared with all other engineers via synthesis, so they don't duplicate
this research.

- Map the project structure, languages, frameworks, dependencies.
- **Web research is essential, not optional.** For every major dependency, SDK, and
  API the project uses, fetch current official docs (`WebSearch` / `WebFetch`):
  latest stable versions, migration guides, deprecation notices, breaking changes,
  documented anti-patterns. Also research the problem space — established approaches,
  well-known libraries that handle parts of this, common pitfalls. Training data
  goes stale; don't rely on it. Err on the side of over-researching — discovering
  the project is already doing it right is cheaper than missing a deprecated API.
- Assess code complexity, duplication, naming, anti-patterns, dead code, overly
  clever abstractions, error-handling patterns, hardcoded values, config drift.

**Engineer 2 — Tests and reliability:**
- Map test coverage: what's tested, what's not, what's poorly tested
- Assess test quality: are tests testing behavior or implementation details?
- Look for flaky test patterns, missing edge cases, untested error paths
- Identify which parts of the codebase would break silently if changed
- Check for integration vs unit test balance

**Engineer 3 — Security and robustness:**
- Look for common vulnerability patterns (injection, auth issues, data exposure)
- Check dependency versions for known vulnerabilities
- Assess input validation and sanitization
- Review secrets management (hardcoded keys, .env files in git, etc.)
- Evaluate error messages for information leakage

**Engineer 4 — Deployment and operations:**
- Assess Dockerfile, docker-compose, CI/CD pipelines, Makefile, build scripts
- Check that the deployment method actually works (build steps, dependencies, env vars)
- Look for missing or incorrect deployment documentation
- Evaluate whether deployment is reproducible and robust
- Check for environment-specific assumptions (hardcoded paths, platform assumptions)
- If there are multiple deployment methods, assess which is primary and whether it's solid
- **GHCR requirement:** If the repo contains a `Dockerfile` or `docker-compose.yml`/`docker-compose.yaml`,
  verify that a GitHub Actions workflow exists in `.github/workflows/` that builds the Docker image and
  pushes it to `ghcr.io/johnmathews/<repo-name>`. If this workflow is missing, flag it as a **High** priority
  gap in the evaluation. The workflow should trigger on push to `main`, authenticate with `GITHUB_TOKEN`,
  and push to `ghcr.io`.
- **workflow_dispatch trigger:** Every GitHub Actions workflow should include `workflow_dispatch:` in its `on:`
  triggers so it can be manually run from the Actions tab. If any workflow is missing this trigger, add it.
  This is a one-line addition (`workflow_dispatch:` under the `on:` block) that enables manual re-runs when
  webhook delivery fails or when debugging CI without pushing a new commit.
- **Docker healthcheck validation:** If any `docker-compose.yml`/`docker-compose.yaml` contains a `healthcheck`
  command, verify that the command is actually available inside the container image. For example, `curl` is often
  missing from slim images. Check by running `docker exec <container> <command> --version` or inspecting the base
  image. If the command is not available, flag it as a bug and replace it with an alternative that is (e.g., use
  `python -c "import urllib.request; ..."` instead of `curl`).

**Engineer 5 — Visual / UI verification** (only when the project serves browser pages):

Include for frontend frameworks (React, Next.js, Svelte, Vue, Astro, etc.) or
server-rendered HTML (Jinja, Django, EJS, etc.). Skip for pure backend, CLI, or
library projects.

- Start the app locally — and the backend too if the frontend fetches from one
  (check `.env`, vite/svelte proxy config, `/api/*` calls, docker-compose).
  Empty states / 401s / blank pages are usually a missing backend, not a UI bug.
- Use Playwright MCP tools (`browser_navigate`, `browser_snapshot`,
  `browser_take_screenshot`, `browser_click`, `browser_fill_form`, etc.) to walk
  the key pages, test real interactions, and check `browser_console_messages` /
  `browser_network_requests` for errors.
- Try edge cases: empty states, long text, invalid input, browser resize.
- Report visual bugs, broken interactions, and layout issues with screenshots.
- If the app can't be started locally, note what's blocking it and skip.

**Product Owner — Documentation and purpose:**
- Read all documentation, README, changelogs, development journals
- Compare documentation claims against actual code behavior
- Identify gaps: undocumented features, outdated instructions, missing setup steps
- Assess the project's stated goals and whether the code achieves them
- Research the problem space: are there better approaches, libraries, or patterns?

### Step 3: Synthesis

As Lead Engineer, you now synthesize all subagent findings into a structured evaluation report.

**File persistence is mandatory, not optional.** You MUST write the report to
`$RUN_DIR/evaluation-report.md` on disk using the Write tool — not
produce it inline in the chat, not include it in a tool output, not summarise
it in your reply. The file on disk is the deliverable; the chat message is only
an announcement that the file now exists. If `$RUN_DIR` does not
exist, `mkdir -p` it first. After writing, open it in the user's default
viewer if a GUI opener exists (`open` on macOS, `xdg-open` on Linux) —
skip this on headless hosts. Do not proceed past
Phase 1 until the file exists on disk — the file is the deliverable that later
phases and future sessions read from disk, not from chat content.

**Before writing the report:** cross-check findings between subagents. If two
disagree about the same code, investigate and resolve. Verify any URL / GitHub
issue / CVE a subagent cited — `WebFetch` it before including it.

**Two audiences, one file.** The report is read by a human deciding what
to do next AND by agents (Phase 2, future runs) that need full detail.
Serve the human first: everything decision-relevant must be on the first
page — the Executive Summary plus the Findings Index. Full evidence,
reasoning, and per-dimension analysis live in the numbered detail
sections below; they exist for agents and future reference, and a human
should never need to read them to know what to do. Don't pad: if a
detail section adds nothing beyond its index line, delete it.

The report should cover:

**Executive Summary:** 3-4 sentences at the very top: what the project does, what's working
well, and what needs attention first. This should be scannable in 10 seconds.

**Findings Index:** immediately after the summary, one line per finding:
`severity · short title · file:line (or doc section)`. Order by severity.
This is the layer a human actually reads — every finding in the detail
sections must have a line here.

**Test Suite Results:** Output from Step 1 — what passed, what failed, any errors.

**Project Overview:** What the project does, its architecture, key technologies

**Strengths:** What the project does well — be specific, cite code

**Weaknesses:** Where the project falls short — be specific, cite code, explain impact

**Assessment Dimensions** (rate each as "X/5" where 5 is best — always write the score
as "X/5" so the scale is unambiguous, with a justification for each rating):
- Simplicity: Is the code as simple as it could be? (5/5 = minimal unnecessary complexity)
- Robustness: How well does it handle edge cases, errors, unexpected input?
- Security: How well does it protect against common attack vectors?
- Flexibility: How easy is it to modify or extend?
- Test coverage: How well-tested is the code, and how good are the tests?
- Documentation accuracy: Does the documentation match the code?
- Documentation completeness: Is everything important documented?
- Deployment quality: Is the build/deploy pipeline (Dockerfile, docker-compose, CI/CD,
  Makefile, etc.) correct, tested, and well-documented? Can someone deploy this reliably?

**Dependency Audit:** name the manifest/lockfile inspected (`uv.lock`,
`package-lock.json`, `go.sum`, ...), and list outdated or known-vulnerable
dependencies found — or state explicitly that none were found and how you
checked (e.g. `uv pip list --outdated`, `npm audit`, an advisory search for
the pinned versions). Mandatory for security-scoped evaluations; expected in
general evaluations. A security review without a dependency audit is
incomplete — this is the section evaluations most often silently drop.

**Bug Candidates:** Specific code locations that look like they might be bugs, with reasoning.
Label each as **[VERIFIED]** (you ran the code and confirmed the bug) or **[SUSPECTED]**
(you inferred it from reading the code but did not reproduce it). This distinction matters —
a verified bug is a fact, a suspected bug is a hypothesis that needs confirmation.

**Gap Analysis:** What's missing — tests, docs, error handling, features

**Architectural Assessment:** For each major integration or subsystem, evaluate whether the
chosen approach is the right one — not just whether it's implemented correctly. Use web
research to check what the official docs recommend, how other projects handle the same
integration, and whether there are simpler or more robust alternatives. If the project uses
a CLI subprocess where a direct SDK call would work, or uses an unofficial auth method where
an official one exists, flag it. The question is not just "does this code work?" but "is this
the right way to solve this problem?"

Be honest and direct. "This works but could be better" is less useful than "This error handler on
line 45 of auth.py silently swallows database connection failures, which means users will see
a generic 500 error instead of a retry prompt."
