# Phase 2: Planning

> Loaded when an evaluation report exists at `$RUN_DIR/evaluation-report.md`
> and no improvement plan has been written yet.

## Announce the phase

Before any other action in this phase, tell the user in one plain-prose
line that you are entering Phase 2 (planning). This is the per-phase
instance of the announce-every-transition rule, whose home is `../SKILL.md`
§"Announce phase transitions".

## Frontmatter on the improvement plan (required)

The plan file (`$RUN_DIR/improvement-plan.md`) MUST begin with a
YAML frontmatter block delimited by `---` lines, listing every work unit
with its `id` and `title`. This is the machine-readable index used to
track progress. The IDs declared here are authoritative: every Phase 3
progress report must reference them verbatim. Format:

    ---
    plan: <short kebab-case name>
    units:
      - id: W1
        title: <title that matches the work-unit heading below>
      - id: W2
        title: <...>
    ---

Use IDs of the form `W<n>` numbered from 1 in the order units are listed.
Do not reuse or renumber IDs after the plan is approved — Phase 3 progress
reporting is keyed on them. If a unit is added later, give it the next
free `W<n>`.

Also add an **ID:** line to each per-work-unit field list so each unit
references its frontmatter ID explicitly.

**Mirror the unit list into `$RUN_DIR/run.yaml`** in the same write, each with
`status: pending`, and set `phase: 2`. The plan's frontmatter is the *index* —
which units exist; `run.yaml` is the *state* — what each one has done. Keeping
them in one file would mean editing the approved plan to record progress, which
the multi-lane rules forbid (the plan is coordinator-owned and read-only to
workers). Two files, two owners, one write.

## File persistence mandate

The improvement plan MUST be written to `$RUN_DIR/improvement-plan.md`
on disk using the Write tool — not produced inline in the chat. If
`$RUN_DIR` does not exist, `mkdir -p` it first. After writing,
open it in the user's default viewer if a GUI opener exists (`open` on
macOS, `xdg-open` on Linux) — skip on headless hosts. Do not proceed past Phase 2
to Phase 3 until the file exists on disk.

Whether the plan is *also* tracked in git is the project's call, not this
phase's — the rule and the check are in "The run directory" in `../SKILL.md`.
Where it is tracked, it is tracked for the life of the run only, and Phase 4
retires it.

---

The goal is to produce a concrete, actionable improvement plan based on the evaluation findings.

### Step 1: Prioritize

Every finding in the evaluation report already carries a severity —
**Critical / High / Medium / Low** — assigned against the rubric in
`../references/general-guidelines.md` ("Severity: what it would cost if it is
true"). **Read the rubric; do not re-derive the words here.** They were
defined once, at the point of first assignment, precisely so a finding does
not get re-weighed by a phase that never saw the code.

Order the fixes by that severity: Critical first, then High, then Medium,
then Low. A unit's **Priority** field inherits the severity of the finding
that motivated it, and if you change it, say why in the unit — a plan that
silently demotes a Critical is a plan that overrode the evaluation without
saying so.

**Priority captures urgency, not blast radius.** A trivial typo fix and a multi-day auth
refactor can both be "High" priority but carry very different risk if the change goes
wrong. Risk is a separate axis on each work unit (see Step 3) — don't conflate the two.

**Grade is a third axis, and it decides what kind of unit the finding becomes.** Each
finding in the evaluation report carries **[VERIFIED]** / **[SUPPORTED]** / **[SUSPECTED]**
(`../references/general-guidelines.md`). Read it — it is the difference between a defect
and a hypothesis, and it changes the work:

- **[VERIFIED]** — plan the fix.
- **[SUPPORTED]** — plan the fix, and make reproducing the problem the unit's first
  step, so the fix has something to prove it worked against.
- **[SUSPECTED]** — **do not plan a fix.** Plan the check that would settle it. A unit
  that changes code to correct a problem nobody has observed is a unit that cannot be
  verified: with no failing behaviour to reproduce, "done" means "the code now looks
  right to me", and if the hypothesis was wrong the change is unmotivated churn in code
  that worked. If the check is cheap, do it now, while planning, and regrade the
  finding rather than carrying a spike into Phase 3.

A high-priority [SUSPECTED] finding is not a reason to skip this. Urgency is a reason to
settle the question *first*, not a licence to act on an unconfirmed one.

### Step 2: Plan Development

Do not assume what changes are needed — base every recommendation on specific findings from
the evaluation report. If the evaluation didn't identify a problem, don't invent one. If you're
unsure whether something is an issue, go back and verify before planning a fix for it.

**Read the code before specifying any change.** Plans drafted from the evaluation summary alone
routinely turn out structurally wrong — the function has been renamed, the abstraction lives in
a different module, the issue was already fixed in passing. The cost is real: a code-ungrounded
plan typically gets rewritten as a "v2" once implementation starts, with the rewrite consuming
more time than the original code-reading would have. One pass of code reading at planning time
prevents that cycle. If a subagent is proposing changes to a file, that subagent must have read
the file.

Launch subagents to develop specific improvement plans for different areas
(dispatch mechanics: `../references/team-structure.md`):

**Engineer — Code improvements:**
- For each code issue, specify: what file, what change, why, and which specific existing
  tests will need updates, deletion, or new siblings (read the test file — don't guess).
  This populates the Test impact field on the work unit.
- When proposing changes that involve third-party APIs, SDKs, or libraries, reference the
  web research from Phase 1 (Engineer 1's findings) — see `phase-1-evaluation.md`. If the
  specific API or pattern wasn't covered in Phase 1, use `WebSearch` and `WebFetch` to look
  it up now — don't guess from training data.
- Group related changes into logical units of work
- Identify dependencies between changes (what must happen first)

**Engineer — Test improvements:**
- For each test gap, specify: what to test, what kind of test, where it goes
- For existing tests that need changes, specify what changes and why
- Include edge cases identified during evaluation

**Product Owner — Documentation improvements:**
- For each doc gap, specify: what to document, where it goes, what to reference
- For inaccurate docs, specify what's wrong and what the correct information is
- Plan any new documentation files needed

### Step 3: Plan Review

As Lead Engineer, review the subagent plans and synthesize into a single improvement plan.

**File persistence is mandatory, not optional.** You MUST write the plan to
`$RUN_DIR/improvement-plan.md` on disk using the Write tool — not
produce it inline in the chat, not embed it in a commit message, not describe
it in prose. The file on disk is the contract Phase 3 reads from and that
later phases and future sessions parse for YAML frontmatter and
work-unit IDs. If `$RUN_DIR` does not exist, `mkdir -p` it first.
After writing, open it in the user's default viewer if a GUI opener
exists (`open` on macOS, `xdg-open` on Linux; skip on headless hosts).
**Do not proceed to Phase 3 until
the file exists on disk** — a Phase 3 run without a written plan file is a
contract violation, even if the plan exists in chat.

**Checked mechanically.** Once written, `scripts/check_plan.py "$RUN_DIR"`
validates the plan's frontmatter index (a `plan:` name, `W<n>` unit IDs, every
declared unit present as a body section and vice versa, no unfilled `<...>`
placeholders) and cross-checks those IDs against `run.yaml` (a `run.yaml` unit
the plan never declared is a hard failure). Run it before announcing the plan —
the frontmatter that Phase 3 and `run.yaml` are keyed on must parse. It does not
judge whether the plan is *good*; that is the Plan Review below.

The plan must contain (in order):

**Frontmatter (required)** — exactly as specified in "Frontmatter on the improvement
plan" at the top of this doc: the file begins with a YAML block listing every work
unit's `id` and `title`; IDs are `W<n>`, numbered from 1, never reused or renumbered
after approval.

**Non-goals** — A short list of things this plan is *not* doing. Examples: "not optimizing
cold-start latency in this round," "not refactoring the auth module — separate plan,"
"not changing the public API surface." Non-goals prevent scope creep more reliably than
per-finding out-of-scope notes, because they are stated up front rather than buried per-issue.
A plan with no non-goals is suspicious — almost every real plan is shaped as much by what
it deliberately excludes as by what it includes.

**Work units** — A sequence of work units. Each unit contains:

- **ID:** The `W<n>` identifier from the frontmatter. Must match exactly — this is the
  key that Phase 3 progress reports use to track the unit.
- **Title:** What this unit accomplishes. Must match the title in the frontmatter.
- **Priority:** Critical / High / Medium / Low — urgency, when this should be done.
- **Risk:** Low / Medium / High — blast radius if the change goes wrong. High = touches
  auth, migrations, persistent state, hot paths, public API, or anything where a bad
  deploy is hard to reverse. Risk is independent of priority — a Low-priority unit can
  be High-risk (e.g. a "nice-to-have" refactor that touches the auth module).
- **Size:** S / M / L — rough effort. S = under an hour. M = a single session. L =
  multi-session. Flag any L unit for splitting unless splitting would create artificial
  seams (e.g. a coherent migration that can't be half-shipped). If a unit is "too big to
  estimate confidently," that itself is a finding — say so and propose a spike instead
  of a plan.
- **Changes:** Specific files and modifications (code, tests, docs).
- **Files (footprint):** The actual paths this unit touches, as paths —
  `src/auth/**`, `tests/test_auth.py`, `pyproject.toml`. Not a description: "the auth
  stuff" is not a footprint. This field does three jobs. It predicts conflicts with
  other in-flight branches; it scopes review; and it is the input to lane derivation
  (below) if the plan is ever split across sessions. It also does a fourth quietly:
  **a unit whose footprint you cannot name has not been planned** — you are guessing
  at the shape of the change, which is exactly what "read the code before specifying
  any change" is meant to prevent.
- **External action:** Anything this unit needs that you cannot do — a credential, an
  approval, a decision from someone else, a provider registration. Name the blocker,
  the owner, and what "unblocked" looks like. "None" is the common answer. This field
  exists so that **blocked never masquerades as not-done**.
- **Test impact:** Which existing tests will need updates, deletion, or new siblings.
  "None" is a valid answer but must be deliberate — read the test file before claiming it.
  Discovering broken tests in Phase 3 that the plan didn't predict is a planning failure.
- **Reversibility:** How to back this out if it ships and goes wrong. "Pure code change,
  revert commit" is fine for most units. For migrations, data backfills, schema changes,
  or config changes affecting prod: name the explicit rollback path (down-migration,
  reverse backfill, kill switch). If a change is genuinely irreversible (data deletion,
  one-way migration), say so explicitly — that signals "review extra carefully" to
  implementation and to the user.
- **Dependencies:** Hard dependencies — units that must complete first. Note soft
  dependencies separately ("easier after W3 but not blocked by it").
- **Acceptance criteria:** Specific, observable conditions. "Tests pass" is not enough —
  name *which behavior* is verified by *which test*, or what the user-visible outcome is.
  For doc changes, name the section that exists and is correct. The criterion should let
  someone other than the implementer judge whether the unit is done.

**Verification units** — Not every unit's deliverable is a diff. Some units
exist to produce an **observation**, and the field list above cannot carry
one: its "Changes" would be empty, its "Test impact" meaningless, and its
"Reversibility" nothing at all. Written as a build unit, such work either
gets distorted into a code change nobody needed or does not get written down.

The skill already generates this kind of work in three places and has never
named it as one thing:

1. Step 1 above: a **[SUSPECTED]** finding gets *the check that would settle
   it*, not a fix.
2. `../references/general-guidelines.md`: **a new gate ships with a test
   proving it goes red.**
3. The same file: **revert the fix and watch the test fail** — the one
   control in this skill with a recorded catch of a confident false finding.

All three are the same shape. Give it fields, so it can be planned:

| Field | What it must contain |
| --- | --- |
| **ID / Title / Priority / Dependencies** | As any other unit |
| **Claim under test** | The proposition, quoted from the finding, the spec, the plan, or a doc. Not "check auth works" — a verification unit tests **a sentence someone wrote** |
| **Why it needs proving** | What would be believed-but-false if nobody looked. This is what separates a necessary check from ceremony |
| **Method, and why it can answer** | The observation you will make, **and the argument that it bears on the claim**. A runtime claim needs a runtime observation; a claim about what a gate detects needs the gate's own source or a known-bad input, never the workflow that calls it. **The method must differ from whatever produced the belief** — re-running the original check reproduces its mistakes faithfully |
| **How it goes red** | What failure looks like concretely. **If you cannot say, the unit does not ship** — that is rule 1 turned on the skill's own work |
| **Result** | *(filled in Phase 3)* The observation itself: the command and its output, or the run id and the log line. This is the deliverable, the way a diff is a build unit's deliverable |
| **Grade earned** | *(filled in Phase 3)* [VERIFIED] / [SUPPORTED] / [SUSPECTED] — fed back into the evaluation report, so settling the check regrades the finding that motivated it |

**Emit one verification unit per [SUSPECTED] finding you are carrying into
Phase 3.** If the check is cheap, do it now while planning and regrade the
finding instead — that is better than either a unit or a guess. What is not
acceptable is a [SUSPECTED] finding that reaches Phase 4 with neither a
result nor an explicit statement that it remains unsettled.

**These are ordinary units in an ordinary plan** — same frontmatter, same
`run.yaml` status, executed by Phase 3 in dependency order like anything
else. There is no separate verification phase, and adding one would buy a
router change and a new `phase:` value for something the existing sequencing
already handles. Where a verification unit pairs with a build unit, make it
depend on that unit so it runs on completion.

**Ordering** — When multiple units have no hard dependency between them, default to:
foundation-first (units that other units build on), then risk-first (high-risk units go
early so problems surface while context is fresh and the plan can still be revised),
then quick wins. Do not default to "the order subagents wrote them in" — that is not
ordering. State the chosen ordering rationale in one sentence at the top of the
work-unit list.

### Step 3.5: Derive lanes from the footprints

Once every unit has a footprint, work out which units *could* run in parallel. The
rule is mechanical, so do it mechanically:

> **Any footprint overlap → same lane.**

Units sharing a file are never parallelised. They are merged into one lane, or
sequenced so the second rebases onto the first. Two units that both touch
`pyproject.toml` are one lane, however unrelated their purposes.

Do this **even when the run stays solo** — it takes a minute, it catches units the
plan thought were independent and aren't, and it tells you the real merge order. If
two units land in the same lane that you expected to be separate, that is a finding
about the plan, not a scheduling detail.

**Then decide whether to actually split.** Suggest parallel sessions only when all
of these hold:

1. Three or more units, **and**
2. at least two lanes with genuinely disjoint footprints, **and**
3. units sized M or larger.

Otherwise stay solo and use subagents within one worktree. Splitting a two-unit plan
across sessions costs more in coordination than it saves in wall-clock.

**Do not confuse the two kinds of parallelism:** subagents parallelise units *inside*
one lane and share your worktree; sessions parallelise *lanes* and each own a
worktree, a branch, and a PR. If you're proposing a split, load
`../references/multi-session.md` before writing the dashboard or any hand-off
prompts.

**Then build the contract register**, once every unit has a footprint, and
allocate reservation ranges per lane. Full rules and the table shapes:
`../references/coordination-protocol.md` §4.

**If the register is non-empty, the plan gets a U0** that lands every seam as
stubs and types and merges before any lane launches. If it is empty, there is
no U0.

### Step 3.6: If the user agrees to split — you are now the coordinator

Only after the user confirms the split at the gate below. Writing `progress.md` is
what makes the run multi-lane, so writing it **promotes this session from solo to
coordinator** — the role you were assigned at activation is now stale, and the
single-writer rule binds you from here (`../SKILL.md`, "Decide your role").

1. **Write `$RUN_DIR/progress.md`** — the board *and* the tracking contract restated
   in full, so a fresh session needs no other document. Shape in
   `../references/multi-session.md` §6.1. The `Owns` column holds each lane's file
   footprint, verbatim from the units — it is the disjointness contract made visible.
2. **Name each lane's branch and worktree** and record them on the board:
   `eng-<plan-short-name>-<lane>` (e.g. `eng-auth-refactor-a`). **Every lane must get
   a distinct name** — they all read the same plan, so a name derived from the plan
   alone collides across every lane, and the second session to start would fail on the
   branch that already exists.
3. **Validate the board before handing out prompts:**
   `python3 scripts/check_board.py "$RUN_DIR"`. It catches footprint overlaps,
   prose footprints, and a non-empty register with no U0 — all of which are
   cheap now and expensive after three sessions have started.
4. **Emit one hand-off prompt per lane** — `/prompt`, Step 4b. Each names the role,
   the lane, its footprint, its branch and worktree, and absolute paths to the plan,
   the dashboard, and its own `status-<lane>.md`. **If `/prompt` is not installed on
   this machine**, write the prompts inline to that same shape and say which skill
   was missing — a sibling skill's absence changes who writes the prompt, not
   whether one is written.
5. **Inline the coordination protocol in every prompt.** Pointing at
   `../references/coordination-protocol.md` is not enough: the receiving session is
   fresh, loads only `../SKILL.md`, and reaches phase 3's worker section — where the
   gate is described — only if it happens to route there. A worker that never loads
   it opens an ungated PR while believing it followed the plan. So the prompt must
   carry the rules themselves, in full, so the worker complies without loading
   anything. Paste this block into each prompt, with `<lane>` and the paths filled in:

   ```text
   Coordination protocol — these rules bind you; you need not load anything to follow them.

   - Message the coordinator only. Never message another lane. Use exactly these
     types: CLAIM (starting: here is my branch and worktree), SURPRISE (reality
     diverged from the plan), GATE-REQUEST (unit believed done), BLOCKED (named
     blocker). You will receive VERDICT (PASS or CHANGES) and ADVISE (ground truth
     you depend on moved). Do not invent a seventh type.
   - Every message carries a `ref`: an absolute path or URL where the detail is
     written down. Envelope, every time:
         <TYPE> lane=<lane> unit=<U-id>
         ref: <absolute path or URL>
         <one to three fields specific to the type>
     A message whose fact is written nowhere else is malformed. Ticks go in your
     status file, not into messages — there is no TICK, STATUS or ACK type.
   - THE GATE BLOCKS, AND IT RUNS BEFORE THE PR EXISTS. When a unit is done:
     self-check it against its acceptance criteria, commit and push the branch
     (NO PR), write your evidence to status-<lane>.md, then send GATE-REQUEST.
     Wait. Open a PR only once the coordinator has written Verdict PASS on the
     status line of <RUN_DIR>/gate-<lane>-<unit>.md. `/done` checks this and will
     stop you; do not work around it. Your lane may carry several units — every
     one of them that is not already merged needs its own PASS before the PR opens.
   - CHANGES means fix and resubmit as the next round. After two CHANGES on one
     unit, stop: the spec is the suspect, and that is the coordinator's to fix.
   - No VERDICT? Resend GATE-REQUEST once after a reasonable wait. Still nothing:
     write "gate pending since <t>" to your status file, stop, and say in your own
     terminal that you are waiting on an unresponsive coordinator. NEVER
     self-clear. A stalled lane is recoverable; an ungated merge is the thing the
     gate is paid to prevent.
   - Cross-lane seams are frozen. Never change one unilaterally, even when the
     file is inside your footprint — owning a file grants the right to edit it,
     not the right to change a promise another lane is coding against. Raise
     SURPRISE naming the replacement you want and wait for ADVISE.
   - Never ask a peer session to do something your own permissions blocked. Route
     it back to the human.
   ```

   The rules above are restatements; the canonical home for all of them is
   `../references/coordination-protocol.md` (§2 for the message protocol, §3 for the
   gate, §4.3 for frozen seams). Edit them there, then re-emit prompts.
6. **Hand them to the user.** They open the sessions and paste.
   **Do not run a lane yourself.** As coordinator you own the gate, and a gate
   applied to your own work is not a gate (`../references/multi-session.md` §5.1).

From here you own the plan, the dashboard, and memory. You do **not** write any
lane's `status-<lane>.md`, and you do not reach into a lane's worktree.

Ensure the plan is complete — every issue from the evaluation should be addressed or
explicitly marked as out-of-scope with a reason. (Non-goals capture *categories* of
out-of-scope work; per-finding notes capture specific exclusions within scope.)

### Step 4: User confirmation before Phase 3

Phase 2 ends with an explicit user gate. Do not proceed to Phase 3 (development) until
the user has confirmed the plan or applied edits. The user opening the file in a viewer
is not enough — Phase 3 is the expensive phase, and a 60-second confirmation prevents
hours of rework on plan content the user would have changed.

Enforce the gate by stopping and asking the user directly (use the
AskUserQuestion tool or a plain question), then waiting for the answer.
For example:

```text
Plan saved at `$RUN_DIR/improvement-plan.md`. Three work units:
W1 ..., W2 ..., W3 .... Reply "go" to start Phase 3, or paste edits / call
out units to drop, reshape, or reorder.
```

**If Step 3.5 found the plan is splittable, ask that here too** — it is a
decision only the user can make, since they are the one who would open the
sessions. State the lanes and their footprints, and give an honest
recommendation either way:

```text
The six units fall into three lanes with disjoint footprints (A: infra/**,
B: src/api/**, C: docs/**), so they could run as three parallel sessions —
you'd open them and paste a prompt into each. Or I run them solo in
sequence. Solo is simpler; parallel is worth it here because lane A is the
long pole. Which?
```

Do not start Phase 3 work, dispatch subagents, or create a worktree while
the question is outstanding.

If the user edits the plan, re-read it in full before starting Phase 3 — don't assume
the edits were cosmetic. If the user changes priorities, ordering, or scope, the
implementation plan changes accordingly.

This gate applies whenever Phase 3 is going to run. If the user invoked only "evaluate"
or "plan" (Phase 1 or Phases 1-2), there is no gate to enforce — the plan is itself the
deliverable.

### Step 5: Close the run, or hand off to Phase 3

Read `scope:` from `$RUN_DIR/run.yaml`, not the mood of the conversation.

- **`scope: plan`** — the plan is the deliverable and this run is finished.
  **Close it: follow "Closing a run" in `../SKILL.md`** — remove the (empty)
  worktree, set `phase: complete`, clear `current.txt` — then say in one line
  that the scope was planning, where the plan is, and that Phase 3
  (development) is the next phase if they want it. Offer; do not start.
- **`scope: full`** — do not close anything. Take the Step 4 gate, then
  announce Phase 3.

### Plan hygiene and persistence

The improvement plan in `$RUN_DIR/improvement-plan.md` is a working document — Phase 3
consumes it and it isn't meant to outlive the session. But the user sometimes asks for a plan
that *will* outlive this session: a refactor roadmap, a multi-week initiative plan, a feature
plan referenced from `docs/`. When the plan is **persistent** (will live in `docs/` and be
referenced in future sessions), apply these conventions — they prevent the failure modes that
make older planning docs hard to maintain (shadow inventory, no clear status, plan content
buried under execution sequencing).

1. **Status header at the top.** Every persistent plan begins with:
   ```
   **Status:** active. **Last updated:** YYYY-MM-DD. **Last verified:** YYYY-MM-DD ([evidence](link)). **Supersedes:** <doc-or-none>.
   ```
   This lets a future reader tell at a glance whether the doc is live, stale, or superseded —
   without cross-referencing a roadmap. Same form and same character budget as every other
   living doc (`../references/documentation-model.md` §8): state only, evidence linked
   rather than inlined, and re-stamped rather than appended to on each pass.

2. **Index it from the canonical roadmap immediately.** If the project has a `docs/roadmap.md`
   (or equivalent — check during Phase 1), add a link to the new plan from the roadmap in the
   same edit that creates the plan. A plan that isn't indexed becomes shadow inventory —
   discoverable only by a reader who already knows it exists.

3. **Decisions first, execution second.** Lead with a short "Decisions & tradeoffs" section
   *before* the work-unit list. For each cross-cutting decision: what was chosen, what was
   rejected, why. The decisions are the part of the plan with long-term value; work units age
   out as soon as they're executed. Putting decisions at the top means they survive even when
   the execution sequence shifts.

4. **Prefer shorter docs, no hard cap.** Length is fine if the scope warrants it.
   The real failure mode is *content density* — padding, restated background,
   execution sequencing buried under decisions. If a plan is hard to re-read,
   the right responses are: split into decisions + execution docs, cut
   restate-from-elsewhere content, or use headings / TOC so readers can navigate
   without reading top-to-bottom. Judge by re-readability, not character count.

5. **Kill criteria** (multi-week initiatives only). For a plan that spans multiple sessions or
   weeks, include a "Kill criteria" section: what would invalidate this plan? ("We'd abandon
   this if library X gets deprecated"; "We'd redesign if assumption Y turns out wrong.") This
   forces clarity about what would change our minds. Skip for tactical work — a bug-fix plan
   doesn't need kill criteria.

6. **Superseding or closing a plan — archive it.** When a new plan replaces an existing one, or
   a plan is closed (all work units shipped), add a `**Status:** superseded by
   [new-plan.md] (YYYY-MM-DD).` or `**Status:** closed YYYY-MM-DD.` header to the top of the old
   plan, then `git mv` it into `docs/archive/` and update inbound links from any active docs.
   This keeps the rationale and decisions accessible while keeping the active `docs/` listing
   easy to scan. Do not just leave closed/superseded plans alongside active ones — the listing
   becomes shadow inventory and readers waste time triaging which docs to trust.

For a one-shot improvement plan that lives only in `$RUN_DIR/` and is consumed by
Phase 3, conventions 1, 2, 5, and 6 don't apply — just write the work units. The hygiene rules
are about *persistence*, not ceremony for its own sake.
