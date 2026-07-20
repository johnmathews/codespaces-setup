# Documentation model

> Loaded when writing or auditing project documentation — Phase 1's doc
> assessment, Phase 2's plan hygiene, Phase 3's "docs touched?" check, Phase 4's
> living-docs reconciliation, and `/done`'s documentation audit. Answers two
> questions: **what kind of document is this, and what is it allowed to claim?**
> (§1–§6), and **how is it written?** — heading numbering, stable IDs, and the
> status stamp (§7–§8). The formatting half lived in the router until it was the
> largest thing there, paid for on every invocation and needed only when writing.

Six document types. Each has **one job and one authority**. The value is not the
taxonomy for its own sake — it is that a reader (or a fresh session) never has to
ask "which of these do I trust?", because the answer is structural.

Apply the model to every project. Define the types always; create each directory
the **first time a document of that type is written**. A project with no
hard-to-reverse decisions simply has no `docs/adr/` yet — that is different from
not having the concept, and it means the model costs nothing until it earns its
place.

## 1. The six types

| Type | Answers | Lives in | Lifecycle | Authoritative for |
| --- | --- | --- | --- | --- |
| **RFC** | "what should we build, and why this over the alternatives?" | `docs/rfc/` | Draft → Discussion → Accepted/Rejected. **Frozen on acceptance** | the exploration and reasoning |
| **ADR** | "what did we decide, and what does it cost?" | `docs/adr/` | Proposed → Accepted → Superseded by ADR-NNNN | the current ruling on **one** hard-to-reverse decision |
| **Spec** | "what must the system do?" | `docs/spec/` | Living | required behaviour and contracts |
| **Plan** | "how, and in what order, do we build it?" | `docs/spec/` or `docs/` | Living until executed, then archived | work breakdown and sequencing |
| **Journal** | "what happened, and what bit us?" | `journal/` | **Append-only. Never edited** | **nothing** — narrative history |
| **Explainer** | "how should I *understand* this?" | `docs/explainers/` | Living (status-stamped) | **nothing** — teaches around the sources of truth |

### 1.1 RFC vs ADR — the distinction that carries the model

**An RFC is the conversation. An ADR is the conclusion, indexed.**

The ADR never re-argues the decision; it states it, names the consequences, and
links back to the RFC for the reasoning. RFCs are never edited after acceptance —
they are a record of what was thought at a moment. When a decision changes, write
a **new ADR that supersedes the old one**; never edit the original. The old ADR
stays, marked superseded, because "why did we change our mind?" is a question
someone will ask.

The economics: the most common question a cold engineer asks is *"why is it built
this way?"* A greppable ADR log answers that in seconds. Nothing else in the
documentation set does.

**One decision per ADR.** An ADR covering three decisions cannot be superseded
when one of them changes.

### 1.2 The decision matrix

| Situation | RFC? | ADR? |
| --- | --- | --- |
| Significant design, real alternatives to weigh | **Yes** | **Yes** — one per resulting hard-to-reverse decision |
| Hard-to-reverse decision, but the choice is obvious | No | **Yes** |
| Reversible or local implementation detail | No | No — code and comments suffice |
| New service or subsystem design | **Yes** | **Yes** — its key decisions |
| A decision changes later | Maybe, if large | **Yes** — a new ADR superseding the old |
| A **concept** is hard to onboard | No | No — write an **explainer** |

Rule of thumb: **RFC when a decision needs discussion before committing; ADR when
a decision is made and is expensive to reverse.**

## 2. Authority precedence

When documents disagree, this is the order. Do not negotiate it per-argument.

1. **Code** is what actually runs — but if it contradicts the spec, that is a
   defect to fix, not a precedence rule to invoke.
2. **Spec** wins on *what the system does now*.
3. **ADR** wins on *why a decision was made*.
4. **RFC** is historical reasoning. It never overrides a later ADR or the spec.
5. **Journal** overrides nothing.
6. **Explainer** overrides nothing.

## 3. Living vs point-in-time — and why the split is drawn by path

**Living** documents describe current truth and actively mislead when stale:
README, spec, runbooks, plans, explainers, controls registers. They carry the
status stamp (§8 below).

**Point-in-time** documents are historical by design and are *supposed* to age:
ADRs, accepted RFCs, journal entries. They are exempt from freshness.

**Draw the line by location, never by judgement.** Everything under `docs/adr/`,
`docs/rfc/`, and `journal/` is point-in-time; everything else living. Two reasons,
and the second is the important one:

1. A path rule is mechanically checkable, so the freshness gate can be twenty
   lines and no one has to adjudicate.
2. **It is what survives a documentation failure.** When a real project's living
   docs rotted into a false claim about what was deployed, its journal and its
   ADRs stayed accurate — because nobody updates a point-in-time document, so
   nobody could corrupt one. The true, weak claim in the journal is what made the
   false, strong claim in the living doc detectable at all. Point-in-time
   documents aged correctly; the living ones did not.

The corollary for the journal: **record what was observed, and no more.** Its
value is precisely that it is not a summary. Never retro-edit it to match what you
later learned — append a new entry.

## 4. Explainers

An explainer takes one **concept** — not a decision, not a procedure — and builds
a mental model: connecting the idea, the technology, the several decisions behind
it, and the tradeoff actually hit, for a reader who wasn't in the room. It is the
"Explanation" quadrant:

| | Practical (steps) | Theoretical (knowledge) |
| --- | --- | --- |
| **Working** (I have a task) | How-to guide — `docs/runbooks/` | Reference — `docs/spec/` |
| **Studying** (I want to understand) | Tutorial | **Explanation — `docs/explainers/`** |

### 4.1 The defining shape: living, stamped, and authoritative for nothing

Both halves matter, and the combination is deliberate:

- **Living and status-stamped**, so a reader can tell whether it still describes
  the system.
- **Authoritative for nothing.** If an explainer disagrees with the spec or an
  ADR, *they win*. It teaches *around* the sources of truth; it never becomes one.

That is what makes an explainer safe to write. It can simplify, use an analogy,
and skip the edge cases, because it is not the contract.

### 4.2 The form

```markdown
# Explainer: how <the concept works, in plain language>

**Status:** active. **Last updated:** YYYY-MM-DD. **Last verified:** YYYY-MM-DD ([`file.py`](...), [ADR-00NN](...)). **Supersedes:** none.

> This is an **explainer** — its job is to build your mental model, not to be
> authoritative. The binding decisions live in [ADR-00NN](...); current behaviour
> lives in the [spec](...) §7. Where this doc and any of those disagree, they win.

## 1. The problem            <- why you'd care; the pain, before the solution
## 2. The one idea to hold onto   <- the single central insight, named outright
## 3..N. <build-up>          <- concept ↔ technology ↔ the decisions behind it
## N. The honest tradeoff    <- what it costs. Not a sales pitch
## N+1. The whole chain, in one pass   <- end to end, once, concretely
## N+2. Where the truth lives <- links out to spec / ADR / RFC
```

Two structural signatures do most of the work: an **early "the one idea" section**
that names the insight instead of building to it, and a **closing "whole chain in
one pass"** that walks it end to end once the parts are known.

### 4.3 The test that stops them multiplying

> An explainer earns its place when it **connects things the RFC couldn't**, for
> an audience the RFC wasn't written for. An explainer that merely restates one
> RFC in a warmer tone has failed — delete it and link the RFC.

Explainers are **a small curated set for the hardest-to-onboard ideas — not one
per module.** If you cannot name the conceptual load it carries, don't write it.

## 5. Conventions common to all docs

- **Headings:** one unnumbered H1 (the title); H2+ numbered decimally from `## 1.`;
  an unnumbered `> Purpose` blockquote as the lead. Full rule in §7 below.
- **Status stamp** on every living doc, with a **method that matches the kind of
  claim** it certifies, within the stamp's character budget (§8 below).
  Point-in-time docs are exempt. A stamp records state and does not narrate: the
  evidence is linked, never inlined, and narrative goes to the document type that
  owns it — which is what the six types above are for.
- **The README is the front door.** It links to the ADR index, the spec, and the
  current plan. A document nothing links to is shadow inventory — discoverable
  only by someone who already knows it exists, which is nobody.
- **Cross-references are clickable links**, so a reader can jump from a claim to
  where it's defined. Link the target on first mention; `§` citations after a doc
  link may stay bare (`[ADR-0003](...) §3.1`).
- **Anchors follow GitHub's slug rule:** lowercase, punctuation dropped, **each**
  whitespace character becomes **one** hyphen (runs are not collapsed) — so
  `### W3 — Database schema` → `#w3--database-schema`. Double hyphens are correct
  where an em-dash sat between spaces. A link checker with `--include-fragments`
  verifies these.
- **Acceptance criteria live in the plan or the issue, not the spec.** They are
  traceable *back* to a spec statement. If you find yourself writing a criterion
  the spec doesn't ground, the spec is incomplete — fix the spec first.
  `spec → plan → issue → PR` is one chain.

## 6. Where the machine half lives

The gates that enforce this model — link/anchor checking, the staleness check
(**driven by change to what a doc covers**, with a long clock only for runtime
claims), the stamp **size budget**, and the rule that each must ship with a test
proving it goes red — are specified in `worktree.md` under
"Documentation gates". The
human half is Phase 3's "docs touched?" check, Phase 4's living-docs
reconciliation, and `/done`'s documentation audit.

Gates catch a broken link or a missing stamp. They cannot catch a doc that is
well-formed and no longer **true**. That is what the human steps are for, and why
neither half is optional.

## 7. Heading numbering and stable IDs

Whenever this skill produces or updates any documentation — evaluation reports,
improvement plans, discussion reports, journal entries, runbooks, project docs in
`/docs/`, anything markdown — **number every heading hierarchically using decimal
notation, except the H1.** The number is part of the heading text, inside the `#`
line.

Example:

```markdown
# Evaluation report

> Purpose
>
> One short paragraph: what this document is for.

## 1. Scope and context

## 2. Findings
### 2.1 Security
### 2.2 Code quality

## 3. Recommendations
### 3.1 Critical
### 3.2 Important
```

Rules:

- **One H1 per document, and it is not numbered.** It is the title — there is
  only ever one, so a number adds nothing. Never open a second H1 to mean
  "part 2"; that's an H2.
- **H2 and below are numbered, starting at `## 1.`**, nesting decimally
  (`### 1.1`, `### 1.2`). The first section of a document is `## 1.`, not `## 2.`.
- The lead paragraph under the title is an unnumbered `> Purpose` blockquote.
- When you add, remove, or reorder sections during an edit, renumber the affected
  sibling and descendant headings so the sequence stays contiguous, and update any
  in-doc cross-references (`§2.1`, "see 2.3") in the same edit.
- This applies to docs you write directly AND to docs subagents return — if a
  subagent's report comes back without numbered headings, add the numbering
  before persisting it to disk.
- Code blocks and inline markdown inside body text are not headings and are
  not numbered.

Why: these documents are read and re-read in long form (run dirs, archived
plans, journal history). Hierarchical numbers make it trivial to reference a
specific section in conversation ("see 2.1") and make structural drift obvious
when sections are added or removed.

**Numbering things that outlive their position.** Section numbers move when a
document is restructured, so anything referenced from outside the document —
decisions, work units, findings — gets a **stable ID of its own** (`D1`, `W3`,
`F7`) that never changes and is never reused, rather than being cited by
section number. A decision recorded as "see 7.2" becomes a lie the moment a
section is inserted above it.

## 8. The living-document status stamp

Any **living** document — one that describes current truth and misleads when
stale (README, spec, runbooks, architecture docs, security/controls registers,
persistent plans) — carries a status stamp as the first line under its title.

**A stamp records state; it does not narrate.** It is a fixed-size header taken
in at a glance: status, dates, one link to evidence, and the scope of what was
*not* verified. Everything else belongs in a document that owns it — cited from
the stamp by link, never copied into it.

```
**Status:** active. **Last updated:** YYYY-MM-DD. **Last verified:** YYYY-MM-DD ([evidence](link)). **Supersedes:** <doc-or-none>.
```

- **Last updated** — when the prose last changed.
- **Last verified** — when its claims were last checked against reality (the
  code, a real run, the live config). **It cites evidence; it never contains
  it** — one link out to the run, the command, or the section that holds the
  detail. Use "not yet — <reason>" until first verified; never leave it blank.
- **Covers** *(optional)* — the paths this doc describes (`infra/`,
  `src/api/**`). It lets the freshness gate ask the only question that means
  anything — *has the thing this doc describes changed since it was last
  verified?* — instead of counting calendar days. Omit it for a doc that
  describes no particular code.
- When you edit a living doc, bump **Last updated**; when you confirm its claims
  still hold, **re-stamp** — replace the date and the evidence link rather than
  appending a second one.

**Budget the stamp: ~600 characters, and gate it** beside the link and freshness
checks (`worktree.md`, "Documentation gates"). Land the threshold where
it **reds real documents on arrival**, so the migration lands in the same change
and the gate is real from its first run; ratchet down from there. **Never raise
the budget to turn a red doc green** — the red is the gate working, and the
overflow is content that belongs elsewhere. 600 is a starting point, not a law.

**Where the displaced prose goes:**

| Content | Destination |
| --- | --- |
| narrative, "what changed", what bit us | the journal |
| why a decision was made | an ADR |
| what the system does now | the spec body, under a heading |
| what is deployed right now | a dedicated live-state doc |
| verification state, evidence, per-pass method records | the verification doc |

Then link the destination from the stamp. Without a named destination "keep it
short" loses to the deadline, because there is nowhere obvious to put things.

**Corrections replace; they never accumulate.** A retraction is not retired by
appending it to the stamp. Fix the claim where it lives, and date the correction
in the journal. A stamp carrying its own errata grows with every fix — so the
document gets harder to read each time it gets more accurate.

**The method must match the kind of claim it certifies.** This is the rule that
makes the stamp worth anything, and it is the one most easily filled in honestly
and still got wrong. A **runtime** claim ("deployed", "live", "the worker calls
the model") requires a **runtime observation** — a run id, a job name, a log
line. Reading other documents is a valid method for a doc-derived claim and an
invalid one for a runtime claim: doc-to-doc consistency proves only that the
documents agree with each other.

The failure this prevents is real and looks like diligence. A stamp reading
`Last verified: 2026-07-15 (re-derived from RFC-0001…0006 and the spec)` was
complete, honest, and per the convention — and it certified a claim about live
model calls that had never happened. The stamp refuted itself in its own words,
and nobody noticed, because the convention never required the method to match
the claim.

So when one document mixes claim kinds, say **which claims were not
re-verified** — "verified" with no scope reads as "all of it", and a reader
without that clause is misled. **Split what that produces.** The scope is state:
one short clause in the stamp naming what is not covered. The **per-pass method
record** — which pass ran, when, how, against what evidence — is history: it goes
to a change-history section in the document body or to the journal, linked from
the stamp. That split is what stops this rule ratcheting: the protection is
per-document and bounded, the log it generates is per-pass and unbounded.

The mirror failure, and why the budget exists: across 34 living docs in one repo,
stamps had grown to **112,790 characters** — median 1,495, worst 21,096 on a
single line, the agent-facing `CLAUDE.md` at 14,826 (a six-layer dated changelog,
an evidence ledger, post-mortems about the file's own past errors, corrections to
its own prose). ~90% restated documents that already owned those facts, so the
copies drifted from their sources — one still asserted an inference its owner had
retracted. All of it passed a green doc gate that only checked the field *names*
were present. Same idiom as the failure above, opposite direction: a check that
could not fail on the defect actually present.

Point-in-time records (ADRs, accepted RFCs, journal entries) are exempt — they
are historical by design and are allowed to age. ADRs instead carry a
`Proposed | Accepted | Superseded by <id>` status. This stamp is what lets a
reader, and the CI doc-freshness gate, tell live docs from stale ones at a
glance. Which documents are living, which are point-in-time, and why the split is
drawn by path: §3 above.
