# Specialists — conditional roles, default off

> Purpose
>
> The standing team (`team-structure.md`) covers every project. These three do
> not, so each one stays off until a fact on disk turns it on. This file holds
> the roster, the triggers, and the boundary each specialist must respect against
> the standing lens next to it.
>
> Loaded on demand by Phase 1 Step 2 when a trigger fires. Runs that trigger
> nothing never pay for this file.

## 1. Why they are off by default

A checklist that grows by accretion **mints a predictable low-value finding on
every project it does not fit**, and the report fills with items nobody asked
about while the real findings lose the top of the page. Phase 1's "Known gotchas"
section says this already and it is the governing concern here.

The defence is not restraint, it is a trigger. A specialist with a fact on disk
behind it costs nothing on the projects it does not suit, so **niche is fine and
vague is the problem.** Every entry below names the fact that turns it on and the
case that keeps it off.

**Three rules bind all of them:**

1. **Announce the specialist with its trigger.** Phase 1 already requires naming
   the shape and agent count before dispatch. Extend that line: *"plus the
   database engineer, triggered by `migrations/` and 23 model files."* A mis-fire
   becomes visible at dispatch rather than at report time.
2. **A specialist is an addition, not a resize.** The Lightweight / Standard /
   Wide bands in Phase 1 Step 2 do not move. "Standard, 5 subagents" quietly
   becoming 8 is how sizing guidance stops meaning anything.
3. **They do not fan out in a wide survey.** Each is one pass over one concern,
   not a lens crossed with every area. `wide-survey.md` lists them among what
   stays with the lead.

**Evaluation only.** These are Phase 1 lenses. Their findings reach Phase 3
through the evaluation report and the plan, exactly like every other finding.
None of them reviews an implementation.

## 2. The shape every entry has

| Field | What it holds |
| --- | --- |
| **Trigger** | a fact on disk, plus the case that keeps it off |
| **Pre-check** | the tool it needs, and what to report when the tool is absent |
| **Looks for** | the brief body |
| **Boundary** | the standing lens that owns the adjacent ground |
| **Evidence ceiling** | the grade it cannot exceed without the measurement it may not get |

**Every brief carries the findings contract verbatim** (`team-structure.md`).
Specialists are not exempt, and a report that comes back ungraded goes back.

**The pre-check follows Engineer 5's Playwright rule.** When the tool is missing,
say so as a limitation of the evaluation and skip. Never substitute a weaker
check and describe the result as the stronger one.

## 3. Test engineer — suite speed

**Trigger:** the project has a test suite. Phase 1 Step 1 already runs it, so the
trigger is satisfied on nearly every project with code. **Off** when there are no
tests, where the absence is already a High finding and speed is beside the point.

**Pre-check:** none beyond a suite that runs. A suite that fails to start is
Step 1's finding, not this one's.

**Why it is cheap:** Step 1 runs the suite and records pass, fail and coverage. It
does not record wall clock. The first measurement here is a number already on
screen and currently discarded, so a fast suite reports "4 seconds" and the role
costs nothing.

**Looks for:**

- **Wall clock, recorded.** The headline number, and the slowest tests behind it
  (`--durations=10`, `go test -json`, Vitest reporters). A suite is usually held
  up by a handful of tests.
- **Intra-suite parallelism left on the table.** `pytest-xdist` absent or `-n`
  unset, `t.Parallel()` unused, Jest or Vitest workers pinned to one,
  `cargo-nextest` not in use.
- **Suites running concurrently.** A CI matrix or job set where two suites share
  one database, one fixed port or one temp directory. **This is the finding the
  role exists for.** The runner controls sharding and fixtures inside a suite, so
  parallelism there is a speedup. Two processes that know nothing about each
  other racing for the same resource is how flakiness gets manufactured. Serialise
  the suites, parallelise inside them.
- **Why parallelism is off, where it is off.** It is often disabled to paper over
  shared mutable state. Then the finding is the shared state, and recommending
  `-n auto` on top of it makes things worse. Check the history before
  recommending the flag.
- **Feedback loop length.** Whether a developer can run a meaningful subset in
  seconds, or whether the only option is everything.

**Boundary:** Engineer 2 owns whether the tests are **good** — coverage, behaviour
versus implementation, flaky patterns. This role owns whether the suite is
**fast**. The overlap is flakiness and it has an owner: a flaky test is Engineer
2's, a test made flaky by the parallelism configuration is this role's.

**Evidence ceiling:** none. Everything here is measurable by running something,
so a finding graded below VERIFIED usually means the measurement was skipped.

## 4. Database engineer — schema, indexing and query shape

**Trigger:** a migrations directory, ORM model definitions, `.sql` files, or a
schema in the repo. **Off** when the project has no database of its own, and a
project that only calls someone else's API does not qualify.

**Pre-check:** a reachable local or disposable database for `EXPLAIN`. Without
one the role still works from schema and migrations, states that no query plans
were taken, and respects the ceiling below.

**Connecting is allowed, with two conditions.** A connection string in `.env` can
point anywhere, so **establish which database answered before running anything**
and say so in the report. Read-only queries and `EXPLAIN` are the permitted set.
`EXPLAIN ANALYZE` executes the query, so it is for local and disposable databases
only, never for anything that might be shared or live.

**Looks for:**

- **Missing and unused indexes**, with the query that wants them. An index
  recommendation with no query behind it is a guess.
- **Query shape at the call sites.** N+1 patterns, `SELECT *` on wide tables,
  missing pagination, filtering in application code that belongs in the query.
- **Schema design.** Normalisation that went too far or not far enough, nullable
  columns that encode state, missing constraints and foreign keys, types that
  cannot hold what the code puts in them.
- **Migration safety.** Irreversible migrations, no down path, a lock that blocks
  writes on a large table, and whether the migration and the code that needs it
  can deploy in either order.
- **Connection handling.** Pool sizing against the server's own limit, leaked
  connections, transactions held open across network calls.

**Row counts are part of every finding.** A missing index on a 50-row table is
not a finding, and a query plan alone does not say which case applies. Report
cardinality next to the plan, and where no count is available, say so.

**Boundary:** Engineer 3 owns injection, credentials and access control, which
are security findings that happen to involve a database. This role owns
performance and design. The hot-path analyst hands over any query-shape problem
it finds from the code side rather than reporting it twice.

**Evidence ceiling:** **SUPPORTED** without a query plan. Index and performance
claims need a plan or a row count to reach VERIFIED, and the reasoning that a
query "must be slow" is the mechanistic story Phase 1 warns is usually a
misreading.

## 5. Hot-path analyst — the code that runs most

**Trigger:** the user names speed or cost as a concern, or recon finds existing
benchmarks, profiling configuration, or a service handling repeated requests.
**Off** on a project with no performance question in play, where every nested loop
becomes a Medium and the report fills with items nobody asked about.

**The name is the rule.** This role is not called a profiler, because "profiler"
claims a profile was taken and usually none was. A claim may not be stronger than
the check behind it (`general-guidelines.md`), and that starts with what the role
is called.

**Pre-check:** none required. The analysis is mostly static, and the one dynamic
measurement it can nearly always take is described below.

**Looks for:**

- **The hot paths, structurally.** Call-site counts, loop nesting, the functions
  every request or invocation passes through, recursion, and repeated work inside
  iteration. "Called a lot" is largely a static property.
- **The expensive shapes.** Work inside a loop that could be hoisted, repeated
  serialisation, synchronous I/O on a hot path, unbounded in-memory accumulation,
  a pure expensive function with no memoisation, a regex compiled per call.
- **Algorithmic cost where the input grows.** A quadratic pass over something
  user-sized is a finding. A quadratic pass over a fixed list of six is not.

**Take the one measurement that is always available: the test suite.**
`cProfile` on a pytest run, `go test -cpuprofile`, `--cpu-prof` on Vitest. **Say
plainly what it is not.** A test suite exercises setup and fixtures far more than
real traffic, so its profile names the hot functions *in the suite*, which
overlaps production unevenly. It is still a real measurement, and it is the
difference between a guess and evidence.

**Boundary:** Engineer 1 owns complexity, duplication and abstraction quality,
which are readability findings. This role owns cost at runtime. Anything needing
a query plan goes to the database engineer. Where both apply to one defect, the
primary report belongs to whoever can measure it.

**Evidence ceiling:** **SUPPORTED** for anything not covered by a profile taken
during the run. The report's limitations section states that no production
profile was taken.

## 6. What the report says

**No new sections.** Specialist findings go in the findings index and get detail
blocks like everything else. `scripts/check_report.py` enforces a fixed section
list, so a specialist minting its own section would break the gate or force a
gate change on every roster addition.

**A specialist may own one conditional dimension** in the report's assessment
dimensions, following the Accessibility precedent: `phase-1-evaluation.md`
remains the single definition of which dimensions exist, and the entry carries
its own "omit entirely unless" trigger.

**Methodology names which specialists ran and which were skipped.** Without it, a
reader cannot tell "no database findings" from "no database specialist ran", and
those mean opposite things.
