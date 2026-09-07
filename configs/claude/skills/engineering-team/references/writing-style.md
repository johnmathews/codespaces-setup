# Writing style for documentation

> Purpose
>
> How documentation in a project should **read**, and what each document type
> must **contain**. `documentation-model.md` decides which type to write and
> where authority sits. This file governs the prose inside it.
>
> Load this before writing or rewriting any document a human reads: a README, an
> explainer, a runbook, a reference page, an ADR, a report.

## 1. Scope

This governs prose written for a human reader. Project documentation, reports,
runbooks and explainers all count.

Two things are outside it. A machine-read format such as a status stamp keeps its
required shape even where that shape breaks a rule below. And a project with its
own written style guide outranks this file, per the project-conventions rule in
`worktree.md`.

## 2. The two hard rules

Documentation is **reference reading**. It is not a blog post, and it is not a
narrative. A reader arrives with a question and leaves once it is answered.

Two rules follow, and neither has an exception.

1. **Never write in the first person. Not "I", not "we", not "our", not "us".**
   There is no narrator. A quoted phrase may contain one, such as a developer's
   complaint reproduced in quotation marks. Nothing else may.
2. **Use the active voice, and name the actor.** The actor is almost always the
   thing itself. The gate rejects the change. The suite runs in four minutes. The
   deployment stops. If a sentence only works in the passive, the actor is
   missing, so find it and put it in front.

These change how a claim is phrased, never what is claimed:

| Do not write | Write |
|---|---|
| What we deliberately do not claim | What this document does not claim |
| the cases we thought to write down | the cases the test set covers |
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

- **Lead with the thing.** First sentence, first paragraph. No preamble and no
  "this document describes".
- **Mark a judgement as a judgement, without a narrator.** "This is the weakest
  part of the design" beats "in our opinion this is the weakest part". If a claim
  is contestable, say what it rests on.
- **Say what is not known, and move on.** "Which part of the build does this is
  still unknown." No defensiveness, and no promise to fix it.
- **Offer a possible explanation, label it, then drop it.** "The corpus may
  simply be smaller than the typical case. Either way, the fix was X." Do not
  resolve what cannot be resolved.
- **Report a reversal plainly.** "This was dismissed as unnecessary at first, and
  that turned out to be wrong." A changed position is information, and it needs
  no apology.
- **State the feature, then state the reality flatly.** "It supports every
  logging backend imaginable, and the project uses one."
- **Be specific, and hedge an approximation openly.** "57 degrees", "about
  10mm", "roughly four minutes". Never "significantly larger".
- **End on what it means for the reader.** Do not trail off, and do not restate
  the document.
- **No jokes, no exclamations, no asides about feelings.** The goal is prose a
  person is comfortable reading, not a performance of being human.

## 5. Rhythm

- **Aim for a median around seventeen words a sentence** and a mean around
  nineteen. **Nothing past forty.**
- **Long sentences are allowed.** Roughly one in six may run past thirty words.
  Do not chop everything short.
- **Short sentences are the exception, not the rhythm.** About one in nine under
  eight words, used to land a point.
- **No em dashes.** Use a full stop, a comma, or brackets. A sentence that needs
  an em dash is two sentences.
- **No semicolons.** Use a full stop.
- **Keep the structure simple.** Chain clauses with *and* or *which*. Do not nest
  a clause inside a clause.
- **Bold sparingly.** A few per section, not a few per paragraph. If a point only
  lands because it is bold, rewrite the sentence instead.
- **Occasionally open with a conjunction.** But, Then, So, Either way.
  Occasionally means twice in a long document, not twice a paragraph.
- **Paragraphs run two to five sentences** and carry one idea each.

Treat the rhythm targets as an influence rather than a specification. The two
punctuation bans in §5 and the two hard rules in §2 are not in that category and
always hold.

## 6. Do not write

These read as machine generated:

- "It's not just X, it's Y", and every variant.
- Rule-of-three flourishes.
- A rhetorical question you then answer.
- "Let's dive in", "Here's the thing", "The reality is", "In conclusion".
- "Importantly", "Notably", "Crucially", "It should be noted that", used to
  announce that something matters. "Most importantly" is fine when genuinely
  ranking things.
- The previous paragraph restated in different words.
- A heading every three paragraphs. Short pieces need no headings.

## 7. Skimmability, and how it squares with §5

Developers scan documentation rather than reading it through, so a reader has to
find an answer by eye. **Structure carries that load, and bold does not.** That
is the reconciliation with the bold rule in §5, which still holds.

- Put the answer in a heading someone can find without reading the paragraph
  under it.
- Prefer a table or a list wherever the content is a set of parallel things.
  Prose is for arguments, not for inventories.
- A bullet is a sentence. Do not glue a fragment to a colon and call it a point.
- A heading exists because a reader needs to find something, not because three
  paragraphs have gone by.

## 8. Code examples

- **Every snippet must run exactly as written.** Copy-pasteable, current, and
  correct.
- Mark a placeholder unmistakably, as `<YOUR_API_KEY>` or `<subscription-id>`.
  Never leave a plausible-looking fake value a reader might use by mistake.
- Show the expected output after any step whose success is not obvious, so the
  reader can tell whether it worked.

## 9. What each document type must contain

§1 to §8 govern how the prose reads. This section is about content, by type.
Which type to write at all is `documentation-model.md` §1.

### 9.1 Landing and onboarding

`README.md`, and any getting-started page.

- **State the purpose in the first two sentences.** What it is, and who it is
  for. A reader who stops after two sentences should still know what the project
  does.
- **Give a quickstart of three steps or fewer**, and make it the shortest path to
  something that works rather than the most complete one.
- **List the prerequisites explicitly, with versions.** A prerequisite
  discovered halfway through a quickstart is a defect in the quickstart.
- **Link outward instead of explaining.** A front door that explains everything
  stops being a front door.

### 9.2 Reference

Specs, configuration schemas, API and CLI surfaces.

- **Generate it from the code wherever the code can carry it.** A generated
  reference compared in CI cannot drift. A hand-written one always can.
- **State the data type, whether a field is required or optional, and the
  default.** All three, for every field.
- **Show a successful response and an error response.** A reference that
  documents only the happy path is half a reference, and the half it omits is the
  half a reader reaches for under pressure.

### 9.3 Procedural

Runbooks, tutorials, how-to guides.

- **One goal per guide, named in the title.** "How to authenticate webhooks",
  not "Webhooks".
- **Order the steps chronologically**, in the imperative mood (§3).
- **Show the expected output after any step whose success is not obvious**, so a
  reader can tell they are on track before the next step compounds the error.

### 9.4 Architecture and context

ADRs, RFCs, system design documents.

- **Explain why, not what.** The what belongs in the spec, and an architecture
  document that describes behaviour will contradict the spec eventually.
- **Draw the data flow** rather than describing it in a paragraph. Mermaid,
  inline in the markdown.
- **Stay high-level enough that a minor code change cannot falsify it.** A
  decision record pinned to a function name goes stale at the next rename, and
  nothing will notice.

### 9.5 Maintenance and collaboration

`CONTRIBUTING.md`, troubleshooting pages, changelogs, journals.

- **Give exact commands** for setting up a local environment and running the
  tests. Not a description of the commands.
- **Group troubleshooting entries by the error message the reader will paste
  into a search box.** The heading should be the text they actually saw, because
  that is what they search for. Grouping by subsystem assumes the reader already
  knows which subsystem failed, and a reader who knew that would not need the
  page.
- **Say what to do when the fix does not work.** An entry with one remedy and no
  fallback strands the reader it was written for.

## 10. The test

Read it aloud. If you run out of breath, cut the sentence. If every sentence is
the same length, break one. If the emphasis lives in the bold rather than in the
words, delete the bold and rewrite.

Then check the two hard rules mechanically, because both are greppable:

```bash
# §2 rule 1 — first person outside a quotation
grep -nE '\b(I|we|our|us)\b' <file>
# §5 — the two banned marks
grep -nE '—|;' <file>
```
