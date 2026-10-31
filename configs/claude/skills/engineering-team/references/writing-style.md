# Writing style for documentation

> Purpose
>
> How documentation should **read**, and what a document must **contain** where
> `documentation-model.md` does not say. That file decides which type to write and
> where authority sits. This one governs the prose inside it.
>
> Load it before writing or rewriting any document a human reads: a README, an
> explainer, a runbook, a reference page, an ADR, a report.

## 1. Scope

**The goal everywhere: no reader can tell a model wrote it.** That covers
documentation, emails, PR and commit bodies, chat replies, code comments, and the
copy on a web page, a dashboard or any other UI.

So three sections of this file apply to everything the skill produces, in every
register:

- §4, the voice
- §5, the rhythm
- §7, the machine-generated tells

§8 (scannable by default) applies to everything except web pages and UIs, which
have a layout of their own to do that job.

The rest of this file governs the **Reference register**: prose for an engineer
who arrives with a question. `voice-registers.md` owns the audience axis and
defines the other two, the **Briefing** register (a reader who does not write
code) and the **Product** register (copy inside the thing being used). Register
follows the file path, so check there before writing anything a non-engineer
reads. §2 rule 1 in particular differs by register.

Two things are outside all of it. A machine-read format such as a status stamp
keeps its required shape even where that shape breaks a rule below. And a project
with its own written style guide outranks this file, per the project-conventions
rule in `worktree.md`.

This skill's own reference files are in scope for §2 only. Both of its rules are
greppable, and neither depends on a reader arriving with a question.

## 2. The two hard rules

Documentation is **reference reading**. It is not a blog post, and it is not a
narrative. A reader arrives with a question and leaves once it is answered.

Two rules follow. Rule 2 has no exception in any register. Rule 1 holds without
exception **inside this register**, and `voice-registers.md` §2 is the only place
that can relax it.

1. **Never write in the first person. Not "I", not "we", not "our", not "us".**
   There is no narrator. A quoted phrase may contain one, such as a developer's
   complaint reproduced in quotation marks. Nothing else may.

   **This rule is the Reference register's.** A reference document has no
   speaker, which is the whole of the reason. Where a real speaker exists,
   `voice-registers.md` §2 carves out the first person: `we` for a team briefing
   a stakeholder, and `I` in an email the user will send as their own. Product
   copy and system emails stay out of the first person entirely and name the
   product instead.
2. **Use the active voice, and name the actor.** The actor is almost always the
   thing itself. The gate rejects the change. The suite runs in four minutes. The
   deployment stops. If a sentence only works in the passive, the actor is
   missing, so find it and put it in front.

These change how a claim is phrased, never what is claimed:

| Do not write | Write |
|---|---|
| What we deliberately do not claim | What this document does not claim |
| a third of the tests check our gates | a third of the tests check the gates themselves |
| I found the configuration overwhelming | The number of options is large enough to be a problem in itself |
| the change is rejected by the gate | the gate rejects the change |
| It was determined to be excessive | It does more than the project needs |

**Second person is encouraged, and it is not the first person.** "You can
configure the timeout" beats "the timeout is configurable". The two get confused,
and only one of them is banned.

## 3. Mood: imperative for steps

**Anything the reader is meant to do takes the imperative mood.** Installation
steps, tutorials, runbook procedures, migration instructions.

| Do not write | Write |
|---|---|
| You should now run `make up`. | Run `make up`. |
| The next step is for the user to clone the repo. | Clone the repository. |
| It is recommended that you set `AUTH_MODE`. | Set `AUTH_MODE` to `entra`. |
| One would then verify the output. | Verify that both APIs answer on `/ready`. |

Keep the imperative for the step and the second person for the explanation around
it. "Run the seed script. You need it because the compose stack runs no
migrations." State a precondition **before** the step it governs, never after.

Descriptive prose is not a procedure, so it does not take the imperative. An
explainer describing how something works stays descriptive.

## 4. Voice

Assume the reader is speed-reading. **Write the shortest text that still states
each fact.** If a word or clause carries no new information then cut it.

The register is plain. Precise does not require severe, and a document that reads
as if it resents being written is one a reader puts down.

- **Lead with the thing.** First sentence, first paragraph. No preamble, and no
  "this document describes" standing in for the thing itself. A scope statement
  is different, and welcome. Once the thing is named, say in two or three short
  sentences what this document does and what it does not. Keep what the thing
  *is* and what the document *does* in separate paragraphs.
- **Name the subject instead of leaving a pronoun to resolve.** Write "this
  document", "this design system" or "the app" wherever "it" could point at more
  than one thing, and always when a new sentence changes the subject. "That
  set", "the former" and "the above" are pronouns in disguise.
- **Concrete nouns over abstract ones.** "The data model" and "the code
  itself", not "its data". "Shows each part in light and dark", not "defines
  that set". A catch-all noun ("parts", "things", "aspects", "elements") holds
  the place of a word not yet found. Find it.
- **Use the plain, literal word.** A turn of phrase makes the reader translate
  it. A literal word just means what it says.

  | Do not write | Write |
  |---|---|
  | straight away | immediately |
  | get to the bottom of | find the cause of |
  | at the end of the day | finally |

- **Cut emphasis words that add nothing.** "Every", "all", "fully", "really",
  "actually", "completely". Keep one only if removing it changes the meaning.
  "Lists every result" becomes "lists the results".
- **End on the point.** A closing pointer elsewhere ("those live in the
  repository's docs") stays only if the reader needs to go there next.
  Otherwise cut it, and let the sentence end on the claim.
- **Don't point at what the reader can already see.** If the results heading
  sits right below, "the next email lists the results" is enough. Naming the
  section the reader is about to reach adds length and no information.
- **Mark a judgement as a judgement, without a narrator.** "This is the weakest
  part of the design" beats "in our opinion this is the weakest part". If a claim
  is contestable, say what it rests on.
- **Say what is not known, and move on.** "Which part of the build does this is
  still unknown." No defensiveness, and no promise to fix it.
- **Be specific, and hedge an approximation openly.** "Four minutes", "about 12%
  of rows", "roughly 40 files". Never "significantly larger".
- **Contractions are welcome.** "It's", "you'll", "doesn't". They cost nothing
  and they are most of the difference between prose that sounds like a colleague
  and prose that sounds like a policy.
- **Address the reader as a competent colleague.** Explain the thing, not the
  obvious thing next to it. Over-explaining reads as distrust, and it is a common
  source of the bulk §6.1 budgets.
- **No jokes and no asides about feelings.** The goal is prose a person is
  comfortable reading, not a performance of being human. An exclamation mark is
  not forbidden outright, but one per document is already plenty.

A worked example, from an owner's rewrite of a design system's opening. The
rewrite splits the joined clauses, names its subject, swaps the abstract nouns
for concrete ones and drops the closing pointer:

| Before | After |
|---|---|
| This document defines that set for Fitness Planner and shows each part in light and dark; new screens are built from it and the app is checked against it. | This document shows each part of the Fitness Planner web app in light and dark. New screens are built off of this design system, and the app is checked against it. |
| It does not describe how the app works, its data or its code, and it is not a picture of every screen: those live in the repository's docs and in the app itself. | This document does not describe how the app works, the data model or the code itself. It is also not a picture of every screen. |

## 5. Rhythm

- **Write the way a person talks.** Read aloud, the text should sound like a
  colleague explaining something across a desk. Join related clauses with "and",
  "but", "so" or "because", as speech does. Avoid a run of short fragments, and
  avoid the punchy one-line closer ("That's the point.").
- **Say the order or the condition with a word.** Join steps with "then":
  "deploys each approved upgrade then checks it". Write a condition as "if …
  then": "If a check fails then the advisor emails you". A comma leaves the
  reader to work out the link, and the word states it outright.
- **Vary sentence length**, and let a long sentence run where the thought needs
  it. **Nothing past forty words.**
- **No em dashes.** Use a full stop, a comma, or brackets. A sentence that needs
  an em dash is two sentences.
- **No semicolons.** Use a full stop.
- **One claim per sentence.** Two claims of different kinds are two sentences.
  Two parts of the same thought can share a sentence, joined by a plain word. A
  colon introduces a list, an example or a quotation, never a second clause.
- **Bold sparingly.** A few per section, not a few per paragraph. If a point only
  lands because it is bold, rewrite the sentence instead.
- **Paragraphs run two to five sentences** and carry one idea each.

## 6. Length, and the detail budget

**A document nobody finishes has failed.** Some documents are built to be
searched and that is fine. But an ADR, an RFC, an explainer and a README are
arguments, and an argument only works if it lands. If the habit is to skim and
never finish, the document is too long, and the fix is to cut it rather than to
expect more of the reader.

| Kind | Examples | Read how | Budget |
| --- | --- | --- | --- |
| **Read-through** | ADR, RFC, explainer, README, briefing | skimmed start to finish, once | **yes, below** |
| **Lookup** | spec, configuration reference, API surface, runbook, troubleshooting | searched, never read whole | **none** — completeness is the job |

Every document is speed-read (§8). For a read-through document that raises the
bar: a reader skimming it should still reach the end with the answer.

### 6.1 Budgets

Starting points, not laws. Measure with `wc -w`.

| Document | Budget |
| --- | --- |
| ADR | **400 words** — one decision, its consequences, a link to the RFC |
| Explainer | **900 words** |
| RFC | **2,000 words** — the one type whose job is exploring alternatives |
| README | **600 words** — longer means the detail belongs in `docs/` |
| Briefing | **one screen** (`voice-registers.md` §3) |

Follow the status-stamp precedent in `documentation-model.md` §8: land the
threshold where it reds real documents on arrival, then ratchet down. **Never
raise a budget to turn a red document green.** The red is the measurement
working, and the overflow belongs somewhere else:

| Content | Destination |
| --- | --- |
| the incident that motivated a rule | the journal, cited in one clause |
| the alternatives weighed | the RFC this ADR links to |
| every field, flag and default | the spec or reference surface |
| the step-by-step | a runbook |
| background a reader may already have | one sentence and a link |
| the same point made again in different words | nowhere. Delete it |

### 6.2 What makes a document long

Four habits, each cheap to write, expensive to read, and disguised as diligence.

1. **The war story.** State the rule, then name the incident in a clause with a
   link. The narrative belongs in the journal.
2. **Pre-emptive defence.** Answering objections nobody raised. Say it once.
3. **Over-explaining.** Judge by the reader the document names, not by the least
   informed person who might open it.
4. **Restatement.** §7 bans the local form; the same applies at document scale.

### 6.3 The length test

Read the headings alone. A reader who sees only those and the first sentence
under each should come away with the answer. If the headings do not carry the
document, the structure is wrong and length is the symptom.

Then the blunt one: **would you read this to the end?**

## 7. Do not write

These read as machine generated, so they are banned in everything the skill
produces (§1):

- **Contrast framing, in every form.** The text describes a thing by what it
  is not, then corrects itself:
  - "It's not just X, it's Y."
  - "This is X, not Y."
  - ", not Y" tacked onto the end of a claim.
  - "Not X. Y."
  - "It isn't about X, it's about Y."
  - "X rather than Y" when nobody suggested Y.

  Say what the thing is. If a reader would genuinely assume the wrong thing then
  add a separate plain sentence about the thing itself: "It doesn't retry."
  A do/don't table, or a real choice between named options, is fine.
- Rule-of-three flourishes.
- A rhetorical question you then answer.
- "Let's dive in", "Here's the thing", "The reality is", "In conclusion".
- "Importantly", "Notably", "Crucially", "It should be noted that", used to
  announce that something matters. "Most importantly" is fine when genuinely
  ranking things.
- The previous paragraph restated in different words.
- Emphasis words that add nothing, and pointers to what the reader can already
  see (§4).

## 8. Scannable by default

**Assume everything is speed-read.** Readers skim emails, docs, PR bodies, chat
replies and briefings, and many never read past the skim. Write so the skim is
enough.

- **Lists before prose.** Wherever the content is a set of facts, steps, options
  or findings, use a list or a table. Keep prose for a chain of reasoning that a
  list would break apart.
- **Numbered when order matters or someone will refer to an item.** Steps, ranked
  findings and questions get numbers. Everything else gets bullets.
- **One short lead sentence, then the list.** The lead says what the list is.
- **A bullet may be a phrase**, as long as it makes sense without the line above
  it. Don't glue a fragment to a colon and leave the reader to join them.
- **Put the answer in a heading** someone can find without reading the paragraph
  under it.
- **Structure carries the emphasis.** Bold doesn't, and the bold rule in §5 still
  holds.
- **A heading earns its place by helping a reader find something.** A short piece
  needs none.

Web pages and UIs are exempt from this section, because their layout does the
job. §4, §5 and §7 still apply to their copy.

## 9. What a document must contain

`documentation-model.md` §1 decides which document to write. These are content
rules for the kinds it does not enumerate, and they never override it.

**Any snippet, in any document:**

- **Every snippet must run exactly as written.** Copy-pasteable, current, and
  correct.
- **Mark a placeholder unmistakably**, as `<YOUR_API_KEY>` or `<subscription-id>`.
  Never leave a plausible-looking fake value a reader might use by mistake.
- **Show the expected output after any step whose success is not obvious**, so a
  reader can tell they are on track before the next step compounds the error.

**A README or getting-started page:**

- **State the purpose in the first two sentences.** A reader who stops there
  should still know what the project does and who it is for.
- **List the prerequisites explicitly, with versions.** A prerequisite discovered
  halfway through a quickstart is a defect in the quickstart.

**A reference surface** (a spec, a configuration schema, an API or CLI):

- **State the data type, whether a field is required or optional, and the
  default.** All three, for every field.
- **Show an error response as well as a successful one.** The half a reference
  omits is the half a reader reaches for under pressure.

**A troubleshooting page:**

- **Group entries by the error message the reader will paste into a search box.**
  Grouping by subsystem assumes the reader already knows which subsystem failed,
  and a reader who knew that would not need the page.
- **Say what to do when the fix does not work.** An entry with one remedy and no
  fallback strands the reader it was written for.

## 10. The test

Read it aloud. If you run out of breath, cut the sentence. If every sentence is
the same length, break one. If the emphasis lives in the bold rather than in the
words, delete the bold and rewrite.

Then check the two hard rules and the contrast framing mechanically, because all
three are greppable. Each pattern also matches quotations, fenced code and
legitimate uses, so judge each hit by eye rather than editing blindly:

```bash
# §2 rule 1: first person outside a quotation. The capitals matter, because
# "We" and "Our" open sentences and a case-sensitive alternation misses them.
grep -nE '\b(I|[Ww]e|[Oo]ur|[Uu]s)\b' <file>
# §5: the two banned marks
grep -nE '—|;' <file>
# §7: contrast framing ("This is X, not Y", "not just", "isn't about")
grep -nE ", not |[Nn]ot just|(isn't|is not) about" <file>
```
