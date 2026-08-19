# Phase 1: Evaluation

> This file is loaded by the lead engineer at the start of Phase 1, when no
> evaluation report exists yet and the user's request begins with
> evaluation/assessment.

## Announce the phase

Before any other action in this phase, tell the user in one plain-prose
line that you are entering Phase 1 (evaluation). This is the per-phase
instance of the announce-every-transition rule, whose home is `../SKILL.md`
§"Announce phase transitions".

## Create a worktree first

Evaluation runs in a worktree too, not the main checkout — see "Always work
in a worktree" in `../SKILL.md` and the full discipline in
`../references/worktree.md`. Two reasons, and the first is the skill's
standing premise: **assume another session is working this repo right now**
(`../SKILL.md` §"You are never the only session"), which makes the main
checkout shared state you may read but not write. The second: an evaluation
that turns up a one-line fix becomes a code change, and by then it is too
late to be on a branch.

`$RUN_DIR` is the exception and stays in the **main checkout** (below): the
worktree holds code; the run holds artifacts that must outlive it.

## File persistence mandate

The evaluation report MUST be written to `$RUN_DIR/evaluation-report.md`
on disk using the Write tool — not produced inline in the chat, not embedded
in a commit message, not included in a tool output, not summarised in your
reply. The file on disk is the deliverable — the chat message is only an
announcement that the file exists, and later phases and future sessions read
the file, not this conversation. If `$RUN_DIR` does not exist, `mkdir -p` it
first. After writing, open it in the user's default viewer if a GUI opener
exists (`open` on macOS, `xdg-open` on Linux) — skip this on headless hosts.
Do not proceed past Phase 1 to Phase 2 until the file exists on disk **and
passes `../scripts/check_report.py`** (Step 3.5). The report is written by
filling `../templates/evaluation-report.md`, which is the single definition of
its structure.

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
- **Wide (a Workflow fan-out over lenses × areas)** for projects too large
  for one agent per lens to cover — see below. **Never chosen without
  asking.**

When in doubt, go standard — over-investigating is cheaper than missing
something important. Launch subagents in parallel (dispatch mechanics:
"Dispatch mechanics" in `../references/team-structure.md`, loaded in
Step 0):

#### When to offer a wide survey

A standard run gives each lens the whole codebase. On a large project that
agent samples — it reads what looks promising and reports on that, and the
report reads the same either way. **The problem is not depth, it is that
coverage is invisible.** A wide survey gives each agent one lens and one
bounded area, so what was covered becomes something the report can state.

Offer it only when all three hold:

1. **`Workflow` is available.** If not, run standard. That is the normal
   method and needs no apology — just don't describe a standard run as if
   it had the coverage of a wide one.
2. **The project actually has areas** — your recon in this step found
   roughly six or more distinct packages, services, apps, or subsystems. If
   the repo is one coherent thing, splitting it invents boundaries and buys
   nothing.
3. **The machine can run it.** Concurrency is `min(16, cores - 2)`. Check
   `nproc`: on a 4-core box that is 2 at a time, so 80 agents is 40
   sequential rounds. Often a reason to decline, and to say so.

**Do not ask on a small or simple project.** The question itself has a
cost, and the answer is obviously no.

When all three hold, put the shape and the number in front of the user and
wait. Something like: *"This has 12 distinct areas. I can run a wide survey
— 6 lenses × 12 areas, about 84 agents, versus 6 on the standard path. It
covers far more and costs proportionally more. Standard, or wide?"*

Name the agent count. "A more thorough evaluation" is not informed consent
about someone else's tokens.

On a yes, load `../references/wide-survey.md` — it has the script, the
sizing table, and what stays with you rather than going into the fan-out
(Steps 0, 1, 2.5, 2.6, the UI walk, and all of Step 3). On a no, or on any
of the three conditions failing, run the standard team below.

**A wide survey buys coverage, not independence.** Its agents are
sub-instances of the same model, so a hundred agreeing is worth no more
than four agreeing. Findings still come back graded, you still regrade
them, and you still disconfirm the load-bearing ones in Step 3.

#### Before you dispatch the standard team

Two things, both one line of work.

**1. Say what it will cost.** Name the shape and the agent count before
dispatching — *"Standard evaluation: 5 subagents (structure, tests,
security, deployment, docs), each doing web research on the dependencies
recon turned up."* This is the same discipline the wide-survey question
applies, and it belongs on this path too: the wide survey asks permission
for ~84 agents while the standard path quietly spends a comparable amount
on 4–6 agents each briefed to research every dependency. Asking on the
expensive path and not on the ordinary one is the governance inverted. You
are not asking permission here — a standard run is the normal method — but
the user should be able to see the bill coming and say "keep it small".

**2. Put the findings contract in every brief.** Load
`../references/team-structure.md` ("The findings contract") and give each
brief the field list and the grading paragraph **verbatim**. A brief that
does not demand a grade gets ungraded findings back, and the lead cannot
grade them afterwards — grading is a statement about how the observation
was made, and the lead did not make it. A report that comes back ungraded
goes back to the agent.

**Engineer 1 — Codebase structure, quality, and problem space research:**

The team's primary web researcher — findings on dependencies, APIs, and best
practices are shared with all other engineers via synthesis, so they don't duplicate
this research.

- Map the project structure, languages, frameworks, dependencies.
- **Web research is essential, not optional — and it is scoped.** Research the
  dependencies, SDKs, and APIs that **your recon actually implicated**: the ones
  the project's own code calls, the ones pinned to something old, and the ones
  behind a finding you are forming. For each, fetch current official docs
  (`WebSearch` / `WebFetch`): latest stable version, migration guide, deprecation
  notices, breaking changes, documented anti-patterns. Also research the problem
  space — established approaches, well-known libraries that handle parts of this,
  common pitfalls. Training data goes stale; don't rely on it.

  Name the list in your report so the lead can see what was and was not looked
  at. "Every dependency in the lockfile" is not the list — it is an unbounded
  brief, and on a project with 400 transitive packages it is the single largest
  uncapped cost in this phase. Within the list, err on the side of
  over-researching: discovering the project is already doing it right is cheaper
  than missing a deprecated API.
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
  **and the project publishes images**, exactly one workflow should own that publish, and it should be
  reachable from `main` rather than only by hand. Read where it actually points rather than asserting a
  destination — see "Project configuration" in `../SKILL.md`. "It doesn't publish where I would have
  published it" is an assumption, not a finding.
- **Images built only at deploy time:** if a Dockerfile is built only by a `workflow_dispatch`-only or
  deploy-time workflow, **nothing exercises it on the way to `main`** and a break stays latent until
  someone deploys. Flag a build-only CI job as a gap. This is one instance of the un-gated-code
  inventory in Step 2.5 — check there for the others.

#### Known gotchas — an opt-in sweep, not part of the brief

These are specific checks that came out of specific incidents on specific
projects. Each is cheap and each has genuinely caught something. Each also
**mints a predictable low-value finding on any project it does not fit**,
which is the failure mode of a checklist that grows by accretion: the report
fills with items nobody asked about and the real findings lose the top of the
page.

So run them when the project's shape fits, deliberately, and say you did. Do
not paste them into Engineer 4's brief as standing requirements.

1. **`workflow_dispatch:` on every GitHub Actions workflow.** A one-line
   addition under `on:` that enables manual re-runs when webhook delivery
   fails or when debugging CI without pushing a commit. *Fits* a repo whose
   CI is actively debugged. *Does not fit* a repo with two stable workflows
   and no history of manual re-runs — there, its absence is not a defect.
2. **Docker healthcheck commands that aren't in the image.** If a compose
   file has a `healthcheck`, confirm the command exists inside the container
   — `curl` is routinely missing from slim images. Check with
   `docker exec <container> <command> --version` or by reading the base
   image. A healthcheck that can never succeed is a check that cannot pass,
   the mirror of the "check that cannot fail" in
   `../references/general-guidelines.md`. *Fits* any project with compose
   healthchecks; skip otherwise.
3. **`ghcr.io/<owner>/<repo-name>` as the publish target.** On a **personal**
   repo that builds an image and publishes nowhere, publishing to GHCR on
   push to `main` authenticating with `GITHUB_TOKEN` is a sensible default,
   and its absence is a **High** gap worth raising. *Does not fit* a repo
   owned by someone else or one that already publishes to its own registry —
   there it is an assumption wearing a finding's clothes. Confirm the owner
   (`../SKILL.md`, "Project configuration") before this one is even eligible.

**Engineer 5 — Visual / UI verification** (only when the project serves browser pages):

Include for frontend frameworks (React, Next.js, Svelte, Vue, Astro, etc.) or
server-rendered HTML (Jinja, Django, EJS, etc.). Skip for pure backend, CLI, or
library projects.

- **First, check the Playwright MCP tools are actually available** (`browser_navigate`
  and friends). This brief depends on them and they are not always connected. If they
  are missing, say so in the report as a **limitation of this evaluation** — "no visual
  verification was performed, Playwright MCP unavailable" — and skip the rest of this
  brief. Do not substitute `curl` or a fetched HTML body and describe the result as
  visual verification: that answers "did the server respond", not "does the page work",
  and reporting one as the other is exactly the overclaim
  `../references/general-guidelines.md` rule 2 forbids.
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

The report goes to `$RUN_DIR/evaluation-report.md` on disk — see "File
persistence mandate" at the top of this file, which is the one statement of
that rule.

**Before writing the report:** cross-check findings between subagents. If two
disagree about the same code, investigate and resolve. Verify any URL / GitHub
issue / CVE a subagent cited — `WebFetch` it before including it.

**Agreement between subagents is not a finding's evidence, and it never
promotes a grade.** Disagreement is the easy case — it announces itself and you
go and look. The failure mode that actually ships is the opposite one: several
sub-instances of the same model, with the same training data, reaching the same
wrong conclusion and sounding certain about it
(`../references/general-guidelines.md`, "Subagent coordination"). Nothing about
that is visible in the output. So the synthesis step cannot wait to be
triggered by a contradiction — it has to run on findings that look settled.

Three things to do here, and none of them is "ask another agent":

1. **Regrade every finding yourself, from what the subagent named.** A
   subagent's grade is a claim like any other. If its brief said [VERIFIED] and
   the report quotes no command and no output, it is [SUSPECTED] until you
   establish otherwise — regrade it down and say so. Grading down is the normal
   outcome and is not a criticism of the subagent.
2. **Pick the load-bearing, non-obvious findings and try to disconfirm each
   one.** These are the ones a recommendation rests on and that would surprise
   someone who knows the code. Apply "Name what would refute it, then go and
   look". Do this yourself: the check has to differ from the one that produced
   the finding, and re-running a subagent's command in your own session
   reproduces its environment mistakes along with its result.
3. **Ask what no engineer was tasked to look at.** Unanimity is sometimes just
   a gap in the briefs. If every subagent was pointed at the same subsystem,
   their agreement about it says nothing about the parts nobody read — say so
   in the report as a limitation rather than letting silence read as coverage.

If a load-bearing finding survives all of this without a disconfirming
observation being possible, it ships as **[SUSPECTED]** with what would settle
it. That is a good outcome. Reporting it as verified because four agents and
you all believed it is the outcome this step exists to prevent.

**Two audiences, one file.** The report is read by a human deciding what
to do next AND by agents (Phase 2, future runs) that need full detail.
Serve the human first: everything decision-relevant must be on the first
page — the Executive Summary plus the Findings Index. Full evidence,
reasoning, and per-dimension analysis live in the numbered detail
sections below; they exist for agents and future reference, and a human
should never need to read them to know what to do. Don't pad: if a
detail section adds nothing beyond its index line, delete it.

**Fill `../templates/evaluation-report.md`.** Copy it to
`$RUN_DIR/evaluation-report.md` and fill it in. The template is the single
definition of the report's structure — which sections exist, in what order,
and what belongs in each. It carries the section list, the index row format,
and the required fields on a finding's detail block, and it is what
`../scripts/check_report.py` checks against.

Two rules the template encodes and this file explains:

1. **Every index row has a detail block and every detail block has an index
   row.** The index is the layer a human acts on; the detail block is where
   the evidence lives. A finding in one and not the other is either invisible
   or unsupported.
2. **Don't pad.** If a detail block adds nothing beyond its index row, the
   finding did not need a block — shorten the report, don't pad the template.
   A section with nothing to say says "none, and here is how I checked".

What follows is the judgement the template cannot carry.

**Exactly one severity and exactly one grade per line, from those two closed
sets.** `[VERIFIED]/[SUPPORTED]` is not a grade — a finding established two
ways takes the stronger one, and a finding you cannot place takes the weaker;
a slash is the absence of a decision. `Informational`, `N/A`, and
`Low (informational)` are not severities: something worth a line in the index
is at least **Low**, and something that isn't goes in a detail section or
gets deleted. A row that opts out of the vocabulary cannot be sorted, cannot
be counted, and cannot be compared against the next run — which is the entire
purpose of an index. Both were emitted by real runs of this skill.

**Both words on that line are defined in
`../references/general-guidelines.md`, and neither is a judgement call you
make fresh each time:** severity is **Critical** / **High** / **Medium** /
**Low** per "Severity: what it would cost if it is true"; the grade is
**[VERIFIED]** / **[SUPPORTED]** / **[SUSPECTED]** per "Grade every finding,
and name what earned the grade". Read both rubrics before you write the
index — a scale applied from memory drifts between runs, and two runs of
this skill on the same repo disagreeing about what "High" means is a defect
in the skill, not a difference of opinion.

They belong together on the index line because this is the layer that gets
acted on: severity says how much it would cost, grade says whether it is
known to be true, and they are independent. A Critical [SUSPECTED] and a
Critical [VERIFIED] call for different next actions, and a reader who only
sees the index cannot tell them apart otherwise. The evidence that earned
the grade, and the consequence that earned the severity, are named in the
detail block — not here.

**Every "prose only" row in the NFR register is a finding** and needs a row in
the index. A stated quality requirement that nothing enforces is a claim the
project cannot back, which is the whole reason Step 2.5 produces the register.

**Assessment dimensions.** These are the dimensions, and this list is the only
place they are defined — the template carries the shape, this carries the
meaning. Rate each as `X/5` where 5 is best, always written as `X/5` so the
scale is unambiguous.

**Anchor the number or it is a mood.** Use one scale across every dimension:

| Score | What it means, on any dimension below |
| --- | --- |
| **1** | Absent, or present and actively misleading |
| **2** | Attempted and unreliable — there where it was easy, missing where it matters |
| **3** | Adequate for the project as it is today, with a **named** weakness you would fix before it grows |
| **4** | Good. The weaknesses you can name are ones a reasonable engineer would accept |
| **5** | You went looking for a problem on this axis and could not construct one. Rare, and it needs the same kind of evidence a [VERIFIED] finding does |

Each justification names the observation behind the score — a file, a
measurement, a gate that does or doesn't exist. "3/5, could be better" is not
a rating; it is the absence of one. If every dimension lands on 3 or 4, you
have described a mood rather than measured anything — go back and find the
observation that would move one of them.

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

**The dependency audit is the section evaluations most often silently drop.**
Name the manifest or lockfile you actually inspected, and either list what is
outdated or vulnerable, or state that none was found **and how you checked**.
"No issues" with no named check is not an audit. Mandatory for a
security-scoped evaluation; expected in every other kind.

**Bug candidates are findings like any other** — they go in the index and get
a detail block, not a section of their own. But they are the case the
disconfirming-check rule exists for, which is why every detail block has a
**Disconfirming check** field. Before promoting a suspected bug above
[SUSPECTED], say what you would see if the bug did *not* exist, and go look —
most often by running the layer beneath the code you read.

**Be most suspicious of the finding you like best.** A specific, mechanistic
story about code that has been in production and working is more likely to be
a misreading than a live defect: if it were really broken that way, something
would probably have shown by now.

Be honest and direct. "This works but could be better" is less useful than "This error handler on
line 45 of auth.py silently swallows database connection failures, which means users will see
a generic 500 error instead of a retry prompt."

### Step 3.5: Run the gate before you announce the report

**`../scripts/check_report.py` is the only control in this skill that can go
red.** Run it on the report and do not announce that the report exists, and do
not move to Phase 2, until it exits 0:

```bash
python3 <skill-dir>/scripts/check_report.py "$RUN_DIR/evaluation-report.md"
```

`<skill-dir>` is the directory you loaded `SKILL.md` from — commonly
`~/.claude/skills/engineering-team`, but read it off the path of the file you
actually loaded rather than assuming. If `python3` is genuinely unavailable,
say so in the run summary and check the report against the template's section
list by hand — an unrun gate is not a passed gate, and reporting one as the
other is the overclaim this skill spends most of its length on.

**What it checks is structure and vocabulary, not quality.** It cannot tell
you a finding is wrong. It can tell you a finding is ungraded, has no id, has
no detail block, or is [VERIFIED] while quoting no output — and every one of
those was emitted by a real run of this skill before the gate existed.

Two rules about failures, and they are the point of having a gate at all:

1. **Fix the report, not the gate.** If a check reds an honest report, that is
   worth knowing and worth changing — but change it deliberately, in the
   script, with a fixture, not by skipping the step this time.
2. **A warning is not a failure, and `W1` especially is not.** `W1` fires when
   nothing in the report is [SUSPECTED]. The correct response is to re-read
   the report and ask which finding you promoted without naming what promoted
   it. The cheapest response — relabelling a real finding as [SUSPECTED] to
   silence it — corrupts the exact vocabulary the warning exists to protect,
   and is worse than ignoring it.

The script's own fixtures (`../scripts/fixtures/`) are its test: one per hard
failure, plus two good reports that must stay green. Run
`python3 <skill-dir>/scripts/check_report.py --selftest` if you change it.

### Step 4: Close the run, or hand off to Phase 2

Read `scope:` from `$RUN_DIR/run.yaml` — the value you set when you created
the run dir, not what the conversation now feels like it is about.

- **`scope: evaluate`** — the report is the deliverable and this run is
  finished. **Close it now: follow "Closing a run" in `../SKILL.md`** —
  remove the (empty) worktree, set `phase: complete`, clear
  `current.txt` — then say in one line that the scope was evaluation, where
  the report is, and that Phase 2 (planning) is the next phase if they want
  it. Offer; do not start.

  This is the step that used to not exist. Phase 4 is the only other place
  that closes a run and it runs **only after Phase 3**, so an
  evaluation-only run left its worktree and branch behind and left
  `current.txt` naming a run that was over. That is not a deduction from
  reading these files: two evaluation-only runs on identical repos, one
  before this step existed and one after, differed in exactly those
  artifacts.

  What the same test did **not** show is the resume hijack. The earlier run
  set `phase: complete` anyway — a step no doc asked it for, volunteered by
  the agent — and the resume rule skips a run marked complete, so the stale
  pointer sat there harmlessly. Read that the right way round: the rule held
  because one agent happened to do more than it was told, which is the
  arrangement this step exists to replace. The next agent volunteers
  something else, and the pointer is live.

- **`scope: plan` or `scope: full`** — do not close anything. Announce
  Phase 2 and continue.
