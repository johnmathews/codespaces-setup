# General guidelines and triage

> Cross-cutting rules and the triage entry point. Loaded by the router when
> the user reports something urgent or when phase docs reference a guideline
> by name.

## Verification integrity

These four rules govern what you are allowed to claim. They exist because
the failure mode they prevent is **confidence**, not carelessness: the
same author, in the same session, will run a check to disprove an
assumption they doubt and leave unchecked the assumption they want to be
true. A rule that only fires when you doubt yourself never fires when it
matters — so these are mechanical, with triggers, not reminders to be
careful.

**1. A check that cannot fail is not evidence.** Before citing any check
as proof — a CI job, a test run, a smoke step, a log line — ask: *what
would this show if the thing it tests were completely broken?* If the
answer is "exactly what it shows now", the check is decoration and nothing
may cite it. This catches:

- `|| true` or `continue-on-error: true` on a command whose result is the evidence.
- A polling loop that prints a `STATUS` it never asserts on.
- Code that swallows an exception and exits 0.
- **A pipe after a test command.** `pytest -q | tail -25` reports **`tail`'s**
  exit code, not pytest's — the suite fails, the step passes, and the summary
  says green. Use `set -o pipefail`, or don't pipe. This one is not
  hypothetical: it reported "exit code 0" with two tests failing.

Corollary: **a new gate ships with a test proving it goes red.** Seed the
violation, assert the gate catches it. A scanner that matches nothing
passes loudest when it is blind.

**2. A claim may not be stronger than the check behind it.** A runtime
claim — "live", "deployed", "verified", "proven", "working" — requires a
runtime observation, and must name the check it rests on: a run id, a job
name, a log line. **A document may never be the verification source for a
runtime claim.** Read the container log, not the job's exit status: a job
can exit `Succeeded` having done nothing, and evidence has been read
successfully out of runs whose overall status was `failure`.

The compression step is where this breaks. "The job exited 0" becomes "the
job worked" becomes "the feature is live", with no new evidence entering
between the steps. **When summarising a source claim, the summary may not
be stronger than the source.** A sentence that looks like a summary and is
actually an inference is the hardest kind to catch, because it reads as
though someone checked.

**Reading the caller cannot verify a claim about the callee's behaviour.**
A claim about what a gate, scanner, or check *detects* is verified by
reading the gate's own source, or by feeding it a known-bad input and
watching it go red — never by reading the workflow that invokes it. The
caller establishes that the thing runs; only the callee establishes what it
would catch. This is how a real project's doc claimed its freshness gate
"flags docs gone stale past a window" while the gate did no date arithmetic
at all: the claim carried a "verified against `.github/workflows/`" stamp,
which was true, and proved the wrong proposition.

**A check run in the wrong environment is not the check.** Name the
invocation, not just the command — the interpreter, the lockfile, the
working directory, the environment it resolved. A real evaluation reported
`uv run pip-audit` exiting 1 with "12 known vulnerabilities in 2 packages",
labelled it verified, and built a work unit on it. Neither package had ever
been in the lockfile: a stale local virtualenv was on `$VIRTUAL_ENV`, and
CI printed `No known vulnerabilities found` on the same commit. The command
really was executed and the output really was its output. **Re-running it
reproduces the falsehood faithfully** — this is the specific reason a
second agent asked to "verify this finding" does not catch it, and the
reason the disconfirming observation has to differ from the original.

**3. "Green" means an executed check that passed, and the check is named.**
Nothing else. The word drifts: it comes to mean a suite passed, a workflow
succeeded, a job exited zero, a file compiled, or — in one real README — a
Makefile still contained the target. **If you cannot name the check and say
what would have turned it red, do not call it green.**

**4. An exemption must expire by itself.** "Advisory until X exists" is
acceptable only when the pipeline can evaluate X — put the condition in
the step, so the exemption lifts the moment its justification does. An
exemption whose expiry depends on someone remembering will outlive its
reason.

### Grade every finding, and name what earned the grade

Every finding carries one of three grades. The grade is not a confidence
score — it is a statement about **how the finding was established**, and
it must name that thing, so a reader can go and repeat it:

| Grade | Means | Must name |
| --- | --- | --- |
| **[VERIFIED]** | You executed something and it showed this | The command **and its actual output** |
| **[SUPPORTED]** | You read a primary source — code, a log, a config, a run | `file:line`, or a run id and the log line |
| **[SUSPECTED]** | Inference. It fits, and nothing contradicts it | What would settle it |

**[SUSPECTED] is the default.** A finding is only promoted by naming the
thing that promoted it. "I am confident" is not a grade, and neither is
the length of the reasoning behind it.

A grade with nothing named is worth less than no grade at all, because it
reads as though someone checked. This is rule 3 turned on your own output:
*if you cannot name the check and say what would have turned it red, do
not call it green.* The same standard the skill applies to a project's CI
applies to the skill's own findings.

Two failure modes this exists to catch, both observed in real runs of this
skill:

1. **[VERIFIED] applied to something unrunnable.** A table mapping
   requirements to owners, or an argument that a definition-of-done is
   unfalsifiable, are conclusions from *reading* — [SUPPORTED] at best.
   Marking them [VERIFIED] is not a stricter claim, it is a false one.
2. **The grades going unused entirely.** Across 20 run directories in one
   project, `[VERIFIED]` appeared 16 times in a single report and
   `[SUSPECTED]` appeared **zero times anywhere**. A vocabulary that is
   only ever used to promote is doing no work. If nothing in your report
   is [SUSPECTED], that is a signal to re-read it, not a sign it went well.

Writing up a [SUPPORTED] root cause as [VERIFIED] is the same error as any
other overclaim — it just feels different because it's a conclusion rather
than a fact. Apply this to a diagnosis of a verification failure too, or
you reproduce the failure inside its own post-mortem.

### Severity: what it would cost if it is true

Grade says whether a finding is known to be true. **Severity says what it
would cost if it were** — and the two are independent, which is why both
sit on the same index line. Assign severity from consequence, not from how
much work the fix is and not from how annoying the code looks:

| Severity | The consequence that earns it |
| --- | --- |
| **Critical** | Data loss or corruption, a security hole, secret exposure, or a break in a path users depend on right now. Also: silent wrongness — output that looks right and is not. Act before shipping anything else |
| **High** | A real defect or a live risk of one, but bounded — it degrades a path rather than breaking it, or the failure is loud. Also a quality requirement the project states and nothing enforces, where the requirement is load-bearing |
| **Medium** | Correct today, fragile tomorrow: missing tests on a path that changes, a doc that is wrong in a way that costs a reader time, duplication that will drift |
| **Low** | Cosmetic, stylistic, or a genuine nice-to-have. Nothing breaks and nobody is misled |

Two rules that stop the scale drifting:

1. **Severity is about the consequence, not the confidence.** A Critical
   [SUSPECTED] is a normal and useful finding — "if this is true it is very
   bad, and here is what would settle it". Downgrading it to Medium because
   you are unsure is grading twice on the same axis and hides the thing most
   worth checking.
2. **Name the consequence in the detail section.** "High" with no stated
   cost is the severity equivalent of a grade with nothing named — it reads
   as though someone weighed it. If you cannot say what it would cost, it is
   Low or it is not a finding.

Phase 2 orders the fixes by these same four words
(`../phases/phase-2-planning.md`, Step 1) — it does not redefine them.

### Name what would refute it, then go and look

For any finding that is **load-bearing** (a recommendation depends on it)
**and non-obvious** (it would surprise someone who knows the code), write
down what you would expect to observe if it were **false** — then make
that observation.

This is not a review step and it is not a second opinion. It is one
executed check chosen specifically to disconfirm, and it exists because of
what wrong findings actually look like:

> A detailed causal story is exactly what a wrong claim looks like when you
> are being thorough. Diligence *produces* the claim; only a mechanical
> check refutes it.

That is from a real post-mortem in a project this skill was run on. The
finding in question was specific, mechanistic, and read as the session's
highest-value result: that a spreadsheet ingest took row 0 as the header
and so silently broke on real input. It was false — the parser one layer
down already trimmed leading blank rows. What caught it was a
pre-committed rule that **every behavioural test must be confirmed to fail
with its fix reverted**. The author reverted the fix expecting red, got
green, and chased it. Nothing else in that project's record has ever
caught a confident false finding *before* it shipped.

So, concretely:

- **Before claiming a module misbehaves, run the layer beneath it.**
  Reading a call site is not evidence about what its dependency returns.
- **Revert the fix and watch the test fail.** A test that passes either way
  proves nothing — and *why* it passes either way is often the real finding.
- **A defect in code that has been in production and working deserves more
  suspicion, not less.** If it were really broken that way, something
  would likely have shown by now.
- **Re-running the same check is not disconfirmation.** It reproduces the
  original observation, including its mistakes — see the environment trap
  in rule 2 above.

When you genuinely cannot make the disconfirming observation, the finding
stays **[SUSPECTED]** and you say what would settle it. That is an honest
result and a useful one. Promoting it because the reasoning felt airtight
is the exact move this rule exists to block.

### Describe a gate by what it checks, not what it's for

A gate's name and description state its **actual scope**, so nobody
downstream cites it for more than it does. A scanner that greps six PII
regexes over files in `fixtures/` enforces "no obvious PII regex in files
that look like data" — not "test data is synthetic", however much the
latter is the reason it exists. Both descriptions are honest about intent;
only one is honest about coverage, and the gap between them is where false
confidence lives.

## Prefer structural enforcement to policy

When an invariant is "never do X", ask whether X can be made
**unrepresentable** before writing a rule that says not to. A rule in a
doc is enforced by memory; a rule in a constructor signature is enforced
by the compiler.

This is a long-established design principle, not a local invention — it
travels under "make illegal states unrepresentable" (Yaron Minsky, 2010),
"parse, don't validate" (Alexis King, 2019), *poka-yoke* in manufacturing,
and, applied to authority rather than types, the principle of least
privilege. Its most familiar instance is one nobody thinks of as a policy
at all: **parameterized SQL queries**. The driver API won't take a
concatenated string where a value goes, so injection isn't forbidden — it's
unrepresentable.

| "Never do X" | The unrepresentable form |
| --- | --- |
| Never concatenate user input into SQL | Parameterized queries — the API takes values, not fragments |
| Never let input reach a shell | `subprocess(args_list)`, `shell=False` — no string to inject into |
| Never let a unit test hit the network | Inject the client; a test constructs a fake, so there's no global to reach for |
| Never log secrets or user content | A logging wrapper that accepts no content field — the safe path is the only path |
| Never confuse a `UserId` with an `OrderId` | Distinct types, not two `str`s |
| Never let dev tooling write to prod | The dev credential lacks the grant — not a flag that can be flipped |
| Never accept a half-built object | One validating constructor; no setters to leave it half-built |

**This is a question to ask, not a mandate.** Sometimes the type system
won't carry it; sometimes the refactor costs more than the risk. But ask it
before falling back to a rule — and when planning a work unit whose
acceptance criterion is "never do X", ask it there, where the design is
still cheap to change.

**Know its limit:** structural enforcement protects the path it covers, not
the paths someone adds later. A wrapper that cannot log content does
nothing about a new direct SDK call that bypasses it. Pair it with a check
that the bypass doesn't exist.

## General Guidelines

**Subagent coordination:**
- Launch independent subagents in parallel; give each a complete, autonomous brief.
- Cross-check findings between subagents before incorporating them — investigate
  contradictions, don't pass them through unchallenged.
- **Subagents share priors.** They are sub-instances of the same model with the same
  training data, so consensus across subagents is weaker evidence than consensus across
  genuinely independent reviewers — they can share a blind spot. Apply extra skepticism
  to surprising-but-unanimous findings: "all four agreed" is not by itself an argument.
  When a non-obvious conclusion is load-bearing for a recommendation, verify it against
  code or external sources, not against agreement. If you find yourself relying on
  subagent consensus to justify a finding, that is a signal to do the verification
  yourself before passing it on.
- **More subagents is not more independence.** The obvious fix for the point above is
  to spawn N skeptics per finding and count how many refute it. It does not work, and
  it is worse than doing nothing, because it converts a shared blind spot into a
  *number* — "3 of 3 verifiers confirmed" reads as far stronger evidence than the four
  agreeing agents it replaced, while resting on the same priors. Rule 1 applies: if the
  refuters would ratify a wrong finding just as readily as a right one, the verification
  pass is a check that cannot fail.

  This is why the answer here is **not** to hand the problem to a fan-out/verify
  orchestrator — Claude Code exposes one as the `Workflow` tool, and its adversarial
  pattern is exactly "spawn N independent skeptics per finding". Those skeptics are
  sub-instances of the same model. Such a tool is the right instrument for *coverage* —
  sweeping more files, more angles, more search modalities than one context can hold —
  and the wrong one for **independence**, which it cannot manufacture. Where it is
  unavailable, nothing here changes; the reason it is not the answer is the shared
  priors, not the tooling.

  What does work is narrower and cheaper: a subagent with a **restricted scope and a
  mandate to re-run the check itself** rather than accept a fact handed down in its
  brief. In one audited session, four of the lead's six false claims were caught by
  agents it had personally misinformed — every one of them refused the handed-down fact
  and went to the log. So when a brief passes a finding downstream, pass the evidence
  with it and say the agent may reject it, rather than stating it as settled.
- Verify any URL, GitHub issue, or CVE a subagent cites. Don't fabricate citations
  yourself — if a fact came from training data rather than a fetched page, say so.
- If a subagent's output is insufficient, give specific feedback and redo it.

**Quality bar:**
- No claims you can't ground in code, tests, or a fetched page. Cite file paths and
  line numbers; quote actual output.
- Be specific. "The `parse_config()` function on `config.py:23` doesn't handle
  malformed YAML — it throws an unhandled exception" beats "the code could be more
  robust."
- Grade every finding **[VERIFIED]** / **[SUPPORTED]** / **[SUSPECTED]** and name what
  earned the grade — see "Grade every finding, and name what earned the grade" above.
  The distinction tells the user what to act on now vs. investigate, and the named
  evidence is what lets them check it without asking you.
- Describe what tests **cover**, not just that they pass. For changes touching
  persistent data, IO, or unexercised code paths, name what's covered AND what isn't.
  "All tests pass" is verification of the destination, not the journey.

**Visual / UI verification (Playwright):** Use Playwright MCP tools when the project
serves browser pages (frontend framework or server-side templates). Engineer 5's
brief and the Phase 3 implementation step have the specifics — start the backend
too if the frontend depends on one, navigate the key pages, click through the
changed flows, check `browser_console_messages` and `browser_network_requests` for
errors. Don't mark a UI work unit complete until you've visually confirmed it
behaves correctly. Skip for pure backend, CLI, or library projects.

**If the Playwright MCP tools are not connected, the verification did not happen.**
Say so, and treat any UI work unit as unverified rather than done. There is no
fallback that produces the same evidence — `curl` tells you the server responded,
not that the page renders, and a work unit closed on that basis is closed on a
claim stronger than its check (rule 2).

**Stable element ids:** When building or modifying browser UI, give meaningful
DOM elements a stable, descriptive `id` (cards, panels, key containers,
interactive controls) — kebab-case and area-prefixed, e.g. `document-actions-card`,
`header-search-button`. This lets the user and reviewers point at a specific
element unambiguously ("the actions card", `#document-actions-card`) instead of
describing it by position or appearance, and gives Playwright/tests a durable
handle. Match whatever convention the project already uses; don't disturb
existing `id`s or test hooks (`data-testid`, etc.).

**Scope:**
- Stay focused on what the project actually needs. Don't recommend rewrites just
  because you'd write it differently. Prioritize risk (bugs, security) over style.
- If the project is small and working fine, say so — not everything needs improvement.

## Triage (when the user reports something urgent)

If the clarifying questions surface something urgent — broken feature, prod bug,
deployment that doesn't work — do focused triage **before** the full evaluation.
You don't do a comprehensive review while production is down.

1. **Reproduce.** Run the failing code, hit the broken endpoint, read the real
   error or stack trace. If you can't reproduce, ask the user for the exact
   error. A diagnosis without seeing the real error is guessing.
2. **Check what changed.** `git log` around when it broke; the working→broken
   diff is often the fastest path to the root cause.
3. **Investigate the code path.** Trace from entry point to failure. Use
   `WebSearch` / `WebFetch` for context on the APIs involved, but the diagnosis
   must come from matching the code against the error you observed.
4. **Verify before reporting.** Don't present a hypothesis as a root cause.
   Confirm X actually explains the reproduced error before telling the user
   "the problem is X" — confident-but-wrong wastes time and erodes trust.
5. **Report:** what error, what root cause, what evidence, what fix. Note any
   architectural concern briefly — Phase 1 will examine it properly.
6. **Then proceed to Phase 1.** The triage fix becomes Work Unit 1 (Critical)
   in the Phase 2 plan; the full evaluation may surface additional context
   that changes the fix.

If nothing urgent, skip triage and go to Phase 1.
