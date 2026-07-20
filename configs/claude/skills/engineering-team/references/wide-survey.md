# The wide survey — Phase 1 reconnaissance as a Workflow fan-out

> Loaded on demand, only when Phase 1's Step 2 has decided the project is
> large enough for a wide survey **and the user has said yes**. Runs that
> stay on the standard path never pay for this file.

## What this replaces, and what it does not

The wide survey replaces **one thing**: Step 2's reconnaissance fan-out,
where 4–6 subagents each examine the whole codebase through one lens.
Everything else in Phase 1 stays with the lead engineer and is not
delegated:

| Stays with the lead | Why |
| --- | --- |
| Step 0 clarifying questions | The user is in the room with you, not with a subagent |
| Step 1 test suite and linter | Runs once for the project, not once per area |
| Step 2.5 NFR register | Cross-cutting by construction — an NFR is a property of the project, not of a directory |
| Step 2.6 onboarding bar | *You* are the measurement. An agent that read one module cold has not had the experience being measured |
| Engineer 5 / UI verification | One browser session, walked once. Fanning it out gets you N logins and no journey |
| Step 3 synthesis, regrading, disconfirmation | The judgement the whole phase exists to produce |

**Read that table before writing the script.** The temptation is to push
the whole phase into the workflow because the workflow is the exciting
part. Step 2.6 in particular is destroyed by delegation and cannot be
recovered afterwards — once the lead knows the codebase, the cold-read
evidence is gone.

## Why fan out on two axes

The standard path fans out on **lenses**: security, tests, deployment,
structure, docs. Each of those agents then has the entire codebase to
cover alone, so on a large project it samples — it reads what looks
promising and reports on that. The report reads identically whether the
agent covered everything or a tenth of it. **Coverage is invisible, and
that is the actual defect**, not the depth of any single agent.

The wide survey fans out on **lenses × areas**. Each agent gets one lens
and one bounded area, which is a job it can actually finish, and the set of
(lens, area) pairs that ran is a fact the report can state. Coverage stops
being a property of what each agent had room for and becomes a property of
how the run was set up.

That is the entire benefit, and it is worth being precise about what it is
**not**:

> **The wide survey buys coverage. It does not buy independence.** Every
> agent in it is a sub-instance of the same model with the same priors, so
> a hundred of them agreeing is worth no more than four of them agreeing
> (`general-guidelines.md`, "Subagent coordination"). The findings come
> back **graded**, and the lead still regrades and disconfirms them in
> Step 3. A wider net does not lower the evidence bar; if anything it
> raises the volume of [SUSPECTED] material the lead has to be disciplined
> about.

## Before you run it

**1. Check the tool exists.** `Workflow` is not present in every
environment. If it is absent, go back to the standard path — that is the
normal, previously-only method and needs no apology. Unlike the Playwright
case in Engineer 5's brief, there is no claim being lost here, so this is
not a "limitation of the evaluation". What you must not do is describe a
standard run *as if* it had the coverage of a wide one.

**2. Check the machine.** Concurrency is capped at `min(16, cores - 2)`.
On a 4-core box that is **2 agents at a time**, so a 100-agent survey is
fifty sequential rounds. Run `nproc` and do the arithmetic before
proposing it. On a small machine, declining the wide survey is often the
right call and you should say why.

**3. Scout inline first.** The workflow needs an area list, and the area
list comes from reading the repository — top-level packages, services,
apps, or directories, each with a one-line description of what it holds.
Do this yourself in Step 2 before calling `Workflow`. Deriving the
work-list inline and then fanning out over it is the intended shape; a
workflow that has to discover its own scope wastes its first stage on
something you can do in one pass.

**4. Get the user's yes**, with the shape and the number in front of them.
Phase 1's Step 2 has the wording.

## Sizing

Agent count is `areas × lenses + areas` — one surveyor per pair, plus one
consolidator per area.

| Areas | Lenses | Agents | Verdict |
| --- | --- | --- | --- |
| 6 | 5 | 36 | Comfortable |
| 12 | 6 | 84 | The intended shape of a large run |
| 15 | 6 | 105 | At the ceiling |
| 30 | 6 | 210 | Too many — merge areas first |

**The ceiling for one evaluation is about 100 agents.** Past that, merge
related areas rather than raising the number: twenty areas usually means
the area list is at the wrong altitude, not that the project is enormous.

**If you cap or drop anything, say so in the report.** A survey that
silently skipped four areas reads exactly like one that covered
everything — which is the defect this whole mechanism exists to remove,
reintroduced one level up.

## The script

Adapt this; do not rewrite it from memory. The footguns below are real and
each one has a way of failing that looks like something else.

```js
export const meta = {
  name: 'phase-1-wide-survey',
  description: 'Survey a codebase across review lenses x areas, then consolidate per area',
  phases: [
    { title: 'Survey', detail: 'one agent per (lens, area) pair' },
    { title: 'Consolidate', detail: 'one agent per area folds its lens reports together' },
  ],
}

const { projectRoot, areas, lenses } = args

const FINDINGS = {
  type: 'object',
  additionalProperties: false,
  required: ['covered', 'findings'],
  properties: {
    covered: {
      type: 'string',
      description: 'What you actually read: files or globs. If you could not cover the area, say what you skipped.',
    },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'grade', 'title', 'location', 'evidence', 'detail'],
        properties: {
          severity: { type: 'string', enum: ['Critical', 'High', 'Medium', 'Low'] },
          grade: { type: 'string', enum: ['VERIFIED', 'SUPPORTED', 'SUSPECTED'] },
          title: { type: 'string' },
          location: { type: 'string', description: 'file:line' },
          evidence: {
            type: 'string',
            description: 'VERIFIED: the command and its actual output. SUPPORTED: the file:line you read. SUSPECTED: what would settle it.',
          },
          detail: { type: 'string' },
        },
      },
    },
  },
}

const AREA = {
  type: 'object',
  additionalProperties: false,
  required: ['area', 'covered', 'findings'],
  properties: {
    area: { type: 'string' },
    covered: { type: 'string' },
    findings: FINDINGS.properties.findings,
  },
}

const results = await pipeline(
  areas,

  // Stage 1: every lens looks at this area. The barrier is per-area and
  // deliberate — the consolidator needs all of its own lens reports, and
  // none of any other area's.
  (area) =>
    parallel(
      lenses.map((lens) => () =>
        agent(
          [
            `Project root: ${projectRoot}`,
            `Area: ${area.key} — ${area.description}`,
            `Paths: ${area.paths.join(', ')}`,
            ``,
            `Review this area, and only this area, through one lens:`,
            lens.brief,
            ``,
            `Grade every finding VERIFIED (you ran something — quote the command and its`,
            `output), SUPPORTED (you read the code — cite file:line), or SUSPECTED (you`,
            `inferred it — say what would settle it). SUSPECTED is the default; promote`,
            `only by naming evidence. Do not report a finding whose location you cannot cite.`,
            ``,
            `In "covered", say what you actually read. If you ran out of room, say so —`,
            `an honest partial answer is useful and a silent one is not.`,
          ].join('\n'),
          { label: `${lens.key}:${area.key}`, phase: 'Survey', schema: FINDINGS },
        ),
      ),
    ),

  // Stage 2: fold this area's lens reports into one. Starts as soon as
  // THIS area's surveyors are done — it does not wait for other areas.
  (lensReports, area) => {
    const live = lensReports.filter(Boolean)
    if (!live.length) return null
    return agent(
      [
        `Project root: ${projectRoot}`,
        `Consolidate these ${live.length} lens reports for area "${area.key}".`,
        ``,
        `Merge findings that are the same underlying issue seen through different`,
        `lenses. Keep the STRONGEST evidence and the HIGHEST severity of any copy —`,
        `but never raise a grade during a merge: two SUSPECTED reports of the same`,
        `thing are still SUSPECTED, however much they agree. Agreement is not evidence.`,
        ``,
        `Drop nothing silently. If you merge or discard a finding, it must be`,
        `traceable in what you return.`,
        ``,
        JSON.stringify({ area: area.key, reports: live }),
      ].join('\n'),
      { label: `fold:${area.key}`, phase: 'Consolidate', schema: AREA },
    )
  },
)

const areaReports = results.filter(Boolean)

log(`surveyed ${areaReports.length}/${areas.length} areas`)

return {
  areas: areaReports,
  coverage: {
    areasRequested: areas.length,
    areasReturned: areaReports.length,
    lenses: lenses.map((l) => l.key),
    // Non-empty means agents died or were skipped. It belongs in the report.
    areasMissing: areas.filter((a) => !areaReports.some((r) => r.area === a.key)).map((a) => a.key),
  },
}
```

Pass `args` as a real JSON value — `{projectRoot, areas, lenses}` — not a
JSON-encoded string. A stringified object arrives as one string and every
`.map` in the script throws.

### Footguns

- **`meta` must be a pure literal.** No variables, calls, spreads, or
  template interpolation. It is read before the script runs.
- **These are plain JS files, not TypeScript.** Type annotations,
  interfaces, and generics fail to parse.
- **`Date.now()`, `new Date()`, and `Math.random()` throw.** They would
  break resume. If you need a timestamp, pass it in through `args`.
- **`parallel()` returns `null` for any agent that failed** — it never
  rejects. `.filter(Boolean)` before using results, or a dead agent
  becomes a `TypeError` three lines later that reads like a schema bug.
- **`pipeline()` has no barrier between stages, and that is the point.**
  Use `parallel()` only where you genuinely need every result at once —
  here, one area's lens reports before folding them.
- **The script's return value is what you get back.** Anything only
  `log()`-ged is progress output, not data.

### If a run comes back wrong

The tool result names a `runId` and a transcript directory. `journal.jsonl`
in that directory records what each agent actually returned — read it
before theorising about why the output looks empty. Re-invoking with
`{scriptPath, resumeFromRunId}` replays the unchanged prefix from cache and
only re-runs from your first edit, so fixing stage 2 does not pay for stage
1 twice.

## Bringing it back into the report

The workflow returns data, not an evaluation. Step 3 proceeds exactly as
written — synthesis, regrading, disconfirming the load-bearing findings —
with two additions.

**1. State the coverage.** The report gets a line the standard path cannot
honestly write:

> Surveyed 12 of 12 areas across 6 lenses (72 agents). Not covered:
> `vendor/`, `docs/archive/` — excluded as third-party and historical.

If `areasMissing` is non-empty, it goes in that line. An area that silently
vanished is worse than one that was never attempted.

**2. Regrade at volume, and expect to grade down.** A wide survey returns
far more [SUSPECTED] findings than a standard one, simply because there are
more agents inferring things. That is the mechanism working. Do not promote
a finding because several areas reported something similar — cross-area
agreement is the same shared-priors agreement as cross-lens agreement, and
it promotes nothing. Pick the load-bearing ones and disconfirm them
yourself, per `general-guidelines.md`.
