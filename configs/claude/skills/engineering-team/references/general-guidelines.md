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

### Grade your own conclusions

Say which of these a claim is, especially when it's yours: **confirmed**
(observed), **strongly supported** (the evidence fits and nothing
contradicts it), or **suspected** (it's a hypothesis). Writing up a
strongly-supported root cause as proven is the same error as any other
overclaim — it just feels different because it's a conclusion rather than
a fact. Apply this to a diagnosis of a verification failure too, or you
reproduce the failure inside its own post-mortem.

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
- Verify any URL, GitHub issue, or CVE a subagent cites. Don't fabricate citations
  yourself — if a fact came from training data rather than a fetched page, say so.
- If a subagent's output is insufficient, give specific feedback and redo it.

**Quality bar:**
- No claims you can't ground in code, tests, or a fetched page. Cite file paths and
  line numbers; quote actual output.
- Be specific. "The `parse_config()` function on `config.py:23` doesn't handle
  malformed YAML — it throws an unhandled exception" beats "the code could be more
  robust."
- Label findings **[VERIFIED]** (you ran the code) or **[SUSPECTED]** (inferred from
  reading) — the distinction tells the user what to act on now vs. investigate.
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
