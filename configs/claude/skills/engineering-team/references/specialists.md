# Specialists — conditional roles, default off

> Loaded on demand, only when Phase 1's Step 2 finds a trigger on disk. Runs
> that trigger nothing never pay for this file. The standing team
> (`team-structure.md`) covers every project; these three do not.

## 1. Why they are off by default

An accreted checklist **mints a predictable low-value finding on every project it
does not fit**, which is Phase 1's "Known gotchas" concern and the governing one
here. The defence is a trigger, not restraint: **niche is fine, vague is the
problem.**

1. **Announce the specialist with its trigger**, on the line that already names
   the shape and agent count: *"plus the database engineer, triggered by
   `migrations/` and 23 model files."* A mis-fire shows up at dispatch, not at
   report time.
2. **A specialist is an addition, not a resize.** The Lightweight / Standard /
   Wide bands do not move.
3. **They do not fan out in a wide survey.** One pass over one concern, not a
   lens crossed with every area.

**Evaluation only.** These are Phase 1 lenses. Their findings reach Phase 3
through the report and the plan, like every other finding.

## 2. The shape every entry has

Trigger, pre-check, what it looks for, the **boundary** against the standing lens
beside it, and an **evidence ceiling** it cannot exceed without the measurement it
may not get. Every brief also carries the findings contract verbatim
(`team-structure.md`).

The pre-check follows Engineer 5's Playwright rule: when the tool is missing,
report that as a limitation and skip. Never substitute a weaker check and
describe the result as the stronger one.

## 3. Test engineer — suite speed

**Trigger:** a test suite exists, which Phase 1 Step 1 has already run. **Off**
with no tests, where the absence is the finding and speed is beside the point.

**Pre-check:** none. A suite that fails to start is Step 1's finding.

**Cheap because** Step 1 records pass, fail and coverage but discards wall clock.
The first measurement is a number already on screen, so a fast suite reports "4
seconds" and the role costs nothing.

**Looks for:**

- **Wall clock, and the slowest tests behind it** (`--durations=10`, `go test
  -json`, Vitest reporters). A suite is usually held up by a handful of tests.
- **Intra-suite parallelism left on the table**: `pytest-xdist` absent or `-n`
  unset, `t.Parallel()` unused, Jest or Vitest workers pinned to one.
- **Suites running concurrently** — a CI matrix where two suites share a
  database, a fixed port or a temp directory. **The finding the role exists
  for.** A runner controls sharding and fixtures inside its own suite, so
  parallelism there is a speedup; two processes that know nothing about each
  other racing for one resource manufactures flakiness. Serialise the suites,
  parallelise inside them.
- **Why parallelism is off, where it is off.** It is often disabled to paper over
  shared mutable state. Then the shared state is the finding, and `-n auto` on
  top of it makes things worse.
- **Feedback loop length:** whether a developer can run a meaningful subset in
  seconds.

**Boundary:** Engineer 2 owns whether tests are **good**, this role whether the
suite is **fast**. Flakiness splits on cause: a flaky test is Engineer 2's, a
test made flaky by the parallelism config is this role's.

**Evidence ceiling:** none — everything here is measurable, so a grade below
VERIFIED usually means the measurement was skipped.

## 4. Database engineer — schema, indexing and query shape

**Trigger:** a migrations directory, ORM models, `.sql` files, or a schema in the
repo. **Off** when the project has no database of its own; calling someone else's
API does not qualify.

**Pre-check:** a reachable local or disposable database for `EXPLAIN`. Without
one, work from schema and migrations, state that no query plans were taken, and
respect the ceiling below.

**Connecting is allowed, with two conditions.** A connection string in `.env` can
point anywhere, so **establish which database answered before running anything**
and say so in the report. Read-only queries and `EXPLAIN` are the permitted set;
`EXPLAIN ANALYZE` executes the query, so it is for disposable databases only.

**Looks for:**

- **Missing and unused indexes**, with the query that wants them. An index
  recommendation with no query behind it is a guess.
- **Query shape at the call sites:** N+1 patterns, `SELECT *` on wide tables,
  missing pagination, filtering in application code that belongs in the query.
- **Schema design:** normalisation that went too far or not far enough, nullable
  columns encoding state, missing constraints and foreign keys, types that cannot
  hold what the code puts in them.
- **Migration safety:** no down path, a lock that blocks writes on a large table,
  and whether the migration and the code that needs it can deploy in either order.
- **Connection handling:** pool sizing against the server's own limit, leaked
  connections, transactions held open across network calls.

**Row counts are part of every finding.** A missing index on a 50-row table is
not a finding, and a plan alone does not say which case applies.

**Boundary:** Engineer 3 owns injection, credentials and access control. This
role owns performance and design. The hot-path analyst hands over query-shape
problems it finds from the code side rather than reporting them twice.

**Evidence ceiling:** **SUPPORTED** without a query plan. Reasoning that a query
"must be slow" is the mechanistic story Phase 1 warns is usually a misreading.

## 5. Hot-path analyst — the code that runs most

**Trigger:** the user names speed or cost as a concern, or recon finds
benchmarks, profiling config, or a service handling repeated requests. **Off**
with no performance question in play, where every nested loop becomes a Medium.

**The name is the rule.** Not "profiler", because that claims a profile was taken
and usually none was. A claim may not be stronger than the check behind it
(`general-guidelines.md`), and that starts with what the role is called.

**Pre-check:** none. The analysis is mostly static, and the one dynamic
measurement it can nearly always take is below.

**Looks for:**

- **The hot paths, structurally:** call-site counts, loop nesting, the functions
  every request passes through, recursion, repeated work inside iteration.
  "Called a lot" is largely a static property.
- **The expensive shapes:** work inside a loop that could be hoisted, repeated
  serialisation, synchronous I/O on a hot path, unbounded in-memory accumulation,
  a pure expensive function with no memoisation, a regex compiled per call.
- **Algorithmic cost where the input grows.** A quadratic pass over something
  user-sized is a finding; over a fixed list of six it is not.

**Take the one measurement that is always available: the test suite.**
`cProfile` on a pytest run, `go test -cpuprofile`, `--cpu-prof` on Vitest. **Say
plainly what it is not** — a suite exercises setup and fixtures far more than
real traffic, so it names the hot functions *in the suite*, which overlaps
production unevenly. It is still the difference between a guess and evidence.

**Boundary:** Engineer 1 owns complexity, duplication and abstraction quality.
This role owns cost at runtime. Anything needing a query plan goes to the
database engineer; where both apply, the report belongs to whoever can measure it.

**Evidence ceiling:** **SUPPORTED** for anything not covered by a profile taken
during the run. Limitations states that no production profile was taken.

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
