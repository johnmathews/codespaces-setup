# General guidelines and triage

> Cross-cutting rules and the triage entry point. Loaded by the router when
> the user reports something urgent or when phase docs reference a guideline
> by name.

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
