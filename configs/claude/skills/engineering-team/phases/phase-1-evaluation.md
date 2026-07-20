# Phase 1: Evaluation

> This file is loaded by the lead engineer at the start of Phase 1, when no
> evaluation report exists yet and the user's request begins with
> evaluation/assessment.

## Announce the phase

Before any other action in this phase, tell the user in one plain-prose
line that you are entering Phase 1 (evaluation).

## Create a worktree first

Evaluation runs in a worktree too, not the main checkout — see "Always work
in a worktree" in `../SKILL.md` and the full discipline in
`../references/worktree.md`. An evaluation that turns up a one-line fix
becomes a code change, and by then it is too late to be on a branch.

`$RUN_DIR` is the exception and stays in the **main checkout** (below): the
worktree holds code; the run holds artifacts that must outlive it.

## File persistence mandate

The evaluation report MUST be written to `$RUN_DIR/evaluation-report.md`
on disk using the Write tool — not produced inline in the chat, not embedded
in a commit message, not described in prose. The file on disk is the
contract — the chat message is only an announcement that the file exists. If
`$RUN_DIR` does not exist, `mkdir -p` it first. After writing, open it in the
user's default viewer if a GUI opener exists (`open` on macOS,
`xdg-open` on Linux) — skip this on headless hosts. Do not proceed past Phase 1 to Phase 2 until the file
exists on disk.

When you create `$RUN_DIR`, also write `$RUN_DIR/run.yaml` with `phase: 1` and
the `scope:` implied by the user's verb (`evaluate` / `plan` / `full` — see "The
run directory" in `../SKILL.md`). Set `scope` now, while the user's request is
in front of you: it is the only record of what they actually asked for, and
Phase 4 reads it to decide whether it may merge anything.

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
- **Image publishing:** If the repo contains a `Dockerfile` or `docker-compose.yml`/`docker-compose.yaml`
  **and the project publishes images**, exactly one workflow should own that publish. Read where it
  actually points rather than asserting a destination — see "Project configuration" in `../SKILL.md`. On a
  personal repo with no existing publisher, `ghcr.io/<owner>/<repo-name>` on push to `main` authenticating
  with `GITHUB_TOKEN` is the sensible default, and its absence is a **High** priority gap. On a repo owned
  by someone else, or one that publishes to its own registry, "it doesn't push to my registry" is not a
  finding — it is an assumption. Do not raise it as one.
- **Images built only at deploy time:** if a Dockerfile is built only by a `workflow_dispatch`-only or
  deploy-time workflow, **nothing exercises it on the way to `main`** and a break stays latent until
  someone deploys. Flag a build-only CI job as a gap. This is one instance of the un-gated-code
  inventory in Step 2.5 — check there for the others.
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
- **Assess the documentation model** against `../references/documentation-model.md`:
  is there a greppable record of *why* things are the way they are (an ADR log or
  equivalent), or does the reasoning live only in commit messages and someone's
  memory? Is anything load-bearing undiscoverable — a correct doc that nothing links
  to is still a failure. Do living docs carry a status stamp, and — the question that
  matters — does any stamp's stated method actually support the kind of claim it
  certifies? A doc that says "verified against the other docs" has verified nothing
  about the running system.
- **Measure the stamps, don't only judge them.** Print every living doc's stamp
  length and sort descending — the stamp paragraph, i.e. the contiguous non-blank
  lines from the `**Status:**` line. It takes a minute and the distribution is the
  whole tell: a handful of multi-thousand-character stamps means narrative has been
  accumulating in a field meant to hold state, and that content is almost always
  restatement of documents that already own it — copies with no gate keeping them
  honest, so they drift and then contradict their sources. Report the total, the
  median, and the worst offender. Judging honesty catches a bad stamp; measuring
  catches the pattern, and much earlier.
- **Check the docs against reality, not against each other.** Doc-to-doc consistency
  proves only that the documents agree. Where a doc claims something about runtime
  behaviour ("deployed", "live", "the worker calls X"), the evidence is a run, a log,
  or the code — never another document.

### Step 2.5: Non-functional requirements — stated vs enforced

Functional bugs get found because something breaks. Quality requirements don't:
they get **stated**, and then nothing ever checks them again. So ask the question
that makes them falsifiable:

> For every quality requirement this project states — which check enforces it?

Produce an **NFR register** for the report: one row per stated requirement,
three columns — *requirement | where it's stated | how it's enforced*. Where
nothing enforces it, write **"prose only"**. That is not automatically a defect
(some NFRs genuinely can't be gated), but it is always a finding: a claim the
project cannot back.

Use this checklist to prompt the register. It is not a demand that every project
have all of them — it's a list of the places NFRs usually hide:

| NFR | The enforceable form |
| --- | --- |
| Secrets never in VCS, logs, or traces | Push protection + secret scan; a logging wrapper accepting no content field |
| Test data is synthetic / no real PII | A scanner over fixture paths — described by what it actually checks |
| Coverage floor | `fail_under` in config, in a required check; reporting-only steps explicitly non-gating |
| Reproducible dependencies | Lockfile + frozen install + pinned CI action versions |
| Migrations apply and don't drift | Apply to a fresh DB in CI + a drift check |
| Docs are accurate | Stamp check **with a parsed date window** + link/anchor check |
| Everything that ships is exercised before `main` | See the inventory below |
| Accessibility (any UI) | A lint plugin + assertions in the browser test |
| Observability | Structured events with an explicit no-content contract |
| Performance / availability | A load smoke, or an SLO — most projects have neither, and that's often fine |

Two specific sweeps, because they find things nothing else does:

**1. Inventory the code that ships but that no gate reads.** Dispatch-only
workflows, Dockerfiles built only at deploy, scripts embedded in workflow
heredocs, IaC, cron jobs, migration hooks. **A green PR is not evidence about the
deploy path** — every defect in that code is latent until someone deploys. Also
name any invariant that **only holds in the deployed environment** (a role split
that exists only in prod, a grant local tests can't see), so a green local suite
isn't mistaken for coverage it doesn't have.

**2. Note the NFRs that are absent rather than unenforced.** A missing NFR is
harder to see than a broken one, because nothing points at it. The commonest by
far: **a browser UI with no accessibility requirement at all** — no lint plugin,
no assertions, nothing. If the project has a UI and no a11y anywhere, say so.

**3. Probe what each gate actually detects — don't read it off the workflow.**
For every gate the project claims to have, establish its real capability by
**reading the gate's own source, or feeding it a known-bad input and watching
it**. That a workflow invokes it proves only that it runs
(`../references/general-guidelines.md` rule 2). The gap is invisible from the
caller and routine in practice: a docs-freshness gate that only greps for field
labels and does no date arithmetic; one that measures staleness in calendar days
and so cannot tell an accurate doc in a dormant repo from a rotten one in a busy
repo; a scanner whose pattern matches nothing; a step piped into `tail`, so the
suite's exit code is discarded. Report each as
*claimed capability | actual capability | what would have to break for it to go
red* — and where a doc asserts a capability the gate doesn't have, that is a
false claim in a living doc, not merely a weak gate.

### Step 2.6: The onboarding bar — you are the measurement

If the project states an onboarding or "understandability" bar — *"a new engineer
should be productive in a day"*, *"a cold engineer should be able to deploy this
in two hours"* — it is almost certainly never measured. Such bars are usually
invoked to justify real tradeoffs (keeping an ADR log, writing explainers,
structuring the README) while nothing ever tests them.

**You are the test.** This session just read this project cold, from its docs,
for the first time — which is exactly the experiment the bar describes, and it
already happened. Report against it from your own experience:

1. What you could **not** determine from the docs alone, and had to read code to
   learn.
2. Any documented claim you had to verify against code because you didn't trust
   it — and whether it held.
3. Where you got lost, or what you looked for and couldn't find.
4. Whether the setup/deploy path in the docs would actually work, and how you know
   (executed it? read it? — say which; see verification integrity in
   `../references/general-guidelines.md`).

This is a real measurement of the real bar, produced free by a run that was
happening anyway. Include it even when the project states no bar — a project
without one still has an onboarding cost, and nobody else is positioned to see it
this clearly. Once you know the codebase, this evidence is gone.

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

**NFR Register:** The table from Step 2.5 — *requirement | where stated | how
enforced (or "prose only")* — plus the un-gated-code inventory and any NFR that is
**absent** rather than unenforced. Every "prose only" row is a finding and needs a
line in the Findings Index.

**Onboarding Assessment:** The report from Step 2.6 — what you couldn't learn from
the docs, what you had to verify against code, where you got lost. Measured against
the project's stated bar if it has one.

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
- Observability: When this breaks in production, can you tell what happened? Are there
  structured logs/metrics/traces, and is there an explicit rule about what must never be
  logged (secrets, user content)?
- Enforcement: Of the quality rules this project states, how many are backed by a check
  that can actually fail? This is the NFR register expressed as a score. A project with
  excellent prose and no gates rates low here regardless of how good the prose is.
- Accessibility (**only when the project serves browser pages** — same trigger as
  Engineer 5; omit the dimension entirely otherwise): keyboard navigation, semantics,
  contrast, and whether anything automated checks any of it.

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
