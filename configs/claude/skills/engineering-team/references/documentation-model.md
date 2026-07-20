# Documentation model

> Loaded when writing or auditing project documentation — Phase 1's doc
> assessment, Phase 2's plan hygiene, Phase 3's "docs touched?" check, Phase 4's
> living-docs reconciliation, and `/done`'s documentation audit. Answers one
> question: **what kind of document is this, and what is it allowed to claim?**

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
status stamp (see `../SKILL.md`).

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
  an unnumbered `> Purpose` blockquote as the lead. Full rule in `../SKILL.md`.
- **Status stamp** on every living doc, with a **method that matches the kind of
  claim** it certifies, within the stamp's character budget (`../SKILL.md`).
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

The gates that enforce this model — link/anchor checking, the status-stamp check
**with a parsed date window**, the stamp **size budget**, and the rule that each
must ship with a test proving it goes red — are specified in `worktree.md` under
"Documentation gates". The
human half is Phase 3's "docs touched?" check, Phase 4's living-docs
reconciliation, and `/done`'s documentation audit.

Gates catch a broken link or a missing stamp. They cannot catch a doc that is
well-formed and no longer **true**. That is what the human steps are for, and why
neither half is optional.
