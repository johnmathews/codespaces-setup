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

This governs prose written for a human reader. Project documentation, reports,
runbooks and explainers all count.

**It governs the Reference register specifically**: prose for an engineer who
arrives with a question. Two other registers exist and this file does not govern
them. `voice-registers.md` owns the audience axis and defines the **Briefing**
register (a reader who does not write code) and the **Product** register (copy
inside the thing being used). Register follows the file path, so check there
before writing anything a non-engineer reads. §2 rule 1 in particular differs by
register.

Two things are outside all of it. A machine-read format such as a status stamp
keeps its required shape even where that shape breaks a rule below. And a project
with its own written style guide outranks this file, per the project-conventions
rule in `worktree.md`.

This skill's own reference files, commit messages and PR bodies are in scope for
§2 only. Both of its rules are greppable, and neither depends on a reader
arriving with a question.

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
   speaker, which is the whole of the reason. Where a speaker genuinely exists —
   a company addressing a customer, a team briefing a stakeholder — `we` is
   carved out by register in `voice-registers.md` §2. "I" stays banned in every
   register except a UI label the reader is choosing.
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

The register is plain and unhurried. Precise does not require severe, and a
document that reads as if it resents being written is one a reader puts down.

- **Lead with the thing.** First sentence, first paragraph. No preamble and no
  "this document describes".
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

## 5. Rhythm

- **Vary sentence length**, and let a long sentence run where the thought needs
  it. **Nothing past forty words.**
- **No em dashes.** Use a full stop, a comma, or brackets. A sentence that needs
  an em dash is two sentences.
- **No semicolons.** Use a full stop.
- **Bold sparingly.** A few per section, not a few per paragraph. If a point only
  lands because it is bold, rewrite the sentence instead.
- **Paragraphs run two to five sentences** and carry one idea each.

## 6. Length, and the detail budget

**A document nobody finishes has failed.** Not every document is read end to
end, and that is fine for the ones built to be searched. But an ADR, an RFC, an
explainer and a README are arguments, and an argument only works if it lands. If
the habit is to skim and never finish, the document is too long, and the fix is
to cut it rather than to expect more of the reader.

So split documents by how they are used:

| Kind | Examples | Read how | Budget |
| --- | --- | --- | --- |
| **Read-through** | ADR, RFC, explainer, README, briefing | start to finish, once | **yes, below** |
| **Lookup** | spec, configuration reference, API surface, runbook, troubleshooting | searched, never read whole | **no budget** — completeness is the job |

§8 says developers scan rather than read. That is true of lookup surfaces and it
is not a licence for a read-through document to sprawl.

### 6.1 Budgets

Starting points, not laws. Measure with `wc -w`.

| Document | Budget |
| --- | --- |
| ADR | **400 words.** One decision, its consequences, a link to the RFC |
| Explainer | **900 words** |
| RFC | **2,000 words.** The one type whose job is exploring alternatives |
| README | **600 words.** Longer means the detail belongs in `docs/` |
| Briefing | **one screen** (`voice-registers.md` §3) |

Follow the status-stamp precedent in `documentation-model.md` §8: land the
threshold where it reds real documents on arrival, then ratchet down. **Never
raise a budget to turn a red document green.** The red is the measurement
working, and the overflow is content that belongs somewhere else.

### 6.2 Where the cut content goes

Without a named destination, "keep it short" loses to the instinct that the
detail might matter. It usually does matter. It just belongs elsewhere.

| Content | Destination |
| --- | --- |
| the incident that motivated a rule | the journal, cited in one clause |
| the alternatives weighed | the RFC this ADR links to |
| every field, flag and default | the spec or reference surface |
| the step-by-step | a runbook |
| background a reader may already have | one sentence and a link |
| the same point made again in different words | nowhere. Delete it |

### 6.3 The four things that make a document long

Each is cheap to write and expensive to read, and all four look like diligence.

1. **The war story.** A rule earns its place by being correct, not by being
   argued at length. State the rule, then name the incident in a clause with a
   link. Three paragraphs of narrative belong in the journal, which exists for
   exactly this.
2. **Pre-emptive defence.** Answering objections nobody raised. Say the thing
   once and let it stand. If an objection is genuinely common, one sentence
   handles it.
3. **Over-explaining.** Context the reader already has. Judge by the reader the
   document names, not by the least informed person who might open it.
4. **Restatement.** The paragraph summarising the paragraph above it, the
   section recapping the section before. §7 already bans the local form. The
   same rule applies at document scale.

### 6.4 The length test

Read the headings alone. A reader who sees only those and the first sentence
under each should come away with the answer, and everything else should be
support for someone who wants it. If the headings alone do not carry the
document, the structure is wrong and length is the symptom.

Then ask the blunt one: **would you read this to the end?** A document whose
author would skim it has already found its defect.

## 7. Do not write

These read as machine generated:

- "It's not just X, it's Y", and every variant.
- Rule-of-three flourishes.
- A rhetorical question you then answer.
- "Let's dive in", "Here's the thing", "The reality is", "In conclusion".
- "Importantly", "Notably", "Crucially", "It should be noted that", used to
  announce that something matters. "Most importantly" is fine when genuinely
  ranking things.
- The previous paragraph restated in different words.

## 8. Skimmability, and how it squares with §5

Developers scan documentation rather than reading it through, so a reader has to
find an answer by eye. **Structure carries that load, and bold does not.** That
is the reconciliation with the bold rule in §5, which still holds.

- Put the answer in a heading someone can find without reading the paragraph
  under it.
- Prefer a table or a list wherever the content is a set of parallel things.
  Prose is for arguments, not for inventories.
- A bullet is a sentence. Do not glue a fragment to a colon and call it a point.
- A heading exists because a reader needs to find something, not because three
  paragraphs have gone by. A short piece needs none.

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

Then check the two hard rules mechanically, because both are greppable. Each
pattern also matches quotations and fenced code, which §2 and §5 allow, so
discount those hits by eye rather than editing them out:

```bash
# §2 rule 1: first person outside a quotation. The capitals matter, because
# "We" and "Our" open sentences and a case-sensitive alternation misses them.
grep -nE '\b(I|[Ww]e|[Oo]ur|[Uu]s)\b' <file>
# §5: the two banned marks
grep -nE '—|;' <file>
```
