# Voice registers — who is reading, and how the prose sounds

> Loaded on demand, when writing anything a non-engineer reads: product copy, a
> status report, an explainer for a product owner. This file owns the **axis**
> and the two non-engineering registers; the Reference register's rules live in
> `writing-style.md`.

## 1. The axis

One question picks the register: **who is reading, and what do they want back?**

| Register | Reader | Wants | Rules live in |
| --- | --- | --- | --- |
| **Reference** | an engineer with a question | the answer, fast | `writing-style.md` |
| **Briefing** | a colleague who does not write code | to understand a decision | §3 |
| **Product** | someone using the thing | to get on with it | §4 |

**Scope by path, not by judgement** — `documentation-model.md` §3 draws
living-versus-point-in-time the same way, because a rule that needs a decision
gets a different decision each time. Set the mapping once per project, defaulting
to this:

| Path | Register |
| --- | --- |
| `README.md`, `docs/adr/`, `docs/rfc/`, `docs/spec/`, `docs/explainers/`, `journal/` | Reference |
| `docs/briefings/`, status reports, anything addressed to a named non-engineer | Briefing |
| UI strings, locale files, email and notification templates, error copy, onboarding flows | Product |

This is what stops a warm-voice pass rewriting the ADR log: register follows the
file, so that pass has nowhere to land.

**A document is written in one register.** When a Reference document needs a
paragraph a non-engineer can read, that paragraph is a summary at the top, not a
register change halfway down.

## 2. Person, and the first-person carve-out

This is the rule that differs most between registers, so it is stated once, here.

| Register | First person | Second person |
| --- | --- | --- |
| **Reference** | **Banned.** `writing-style.md` §2 rule 1 owns this and is unchanged | Encouraged |
| **Briefing** | **"We" permitted** for the team. "I" still banned | Encouraged |
| **Product** | **"We" preferred** over the company name. "I" only in UI labels the reader is choosing ("Remember my password") | Required |

**Why the registers split.** Published guides disagree, so this is a choice, not
a consensus. Mailchimp mandates the first person everywhere, API docs included —
*"Refer to Mailchimp as 'we,' not 'it.'"* — and Monzo makes it load-bearing in
its apology rule: *"It's never 'We'd like to apologise', it's 'We're sorry'."*
Microsoft discourages it everywhere, including marketing, because "we" reads as
"a daunting corporate presence". Monzo and Mailchimp are the target, so "we" is
carved out where a speaker exists. A reference document has no narrator, which is
why the ban survives there.

**"We" needs a referent the reader can name** — the company in Product copy, the
team in a Briefing. A "we" that could mean either is the corporate fog both
guides warn about.

## 3. The Briefing register

For a reader who makes decisions about the work without writing any of it: a
product owner, a manager, a stakeholder.

- **Lead with the outcome, then the reason.** Not the chronology. A reader who
  stops after the first paragraph should have the decision and its consequence.
- **Say what it means for them.** A fact with no "so what" is a fact the reader
  has to translate, and they will translate it wrong.
- **Gloss every term the first time, or cut it.** Internal shorthand, service
  names and acronyms all count. One clause is enough.
- **Use "we" for the team and "you" for the reader.**
- **Contractions are the default.**
- **One screen.** If it does not fit, the detail belongs in a Reference document
  and the briefing links to it.
- **Numbers carry their own meaning.** "Checkout fails for about one order in
  fifty" beats "elevated error rate".

## 4. The Product register

For copy inside the thing being used: interface strings, errors, notifications,
onboarding, transactional email.

**Warm does not mean funny.** Monzo dials clarity and kindness to the maximum for
operational and support copy and sets humour to **none** — "the risk of getting
it wrong is greater than the benefit of getting it right". Everything this team
writes for a product is in that category, so warmth comes from plain words and
respect for the reader, never from a joke in an error message.

- **"We" for the company, "you" for the reader.** Never "the user" in copy the
  user is reading.
- **Contractions are the default** — the single largest warmth lever.
- **Keep sentences to 25 words or fewer** — Mailchimp's published number, and
  tighter than the 40-word ceiling `writing-style.md` §5 sets for Reference.
- **Plain words, not formal ones:** *about* not *regarding*, *start* not
  *commence*, *use* not *utilise*. Jargon defined on first use, or removed.
- **Read it aloud.** Monzo's test: if it isn't language you'd use face to face,
  it's the wrong language.
- **Open with "but", "and" or "so" when it helps.** There has never been a rule
  against it, and it is how speech joins sentences.
- **Explain without patronising.** Address the reader, do not market at them.
- **Skip idioms, wordplay and cultural references.** They cost the most from
  readers whose first language is not English, and they are the easiest cut.
- **Exclamations sparingly** — where a person would, never to manufacture
  enthusiasm the reader does not share.
- **Active voice, actor named.** Shared with every register.

### 4.1 Error copy

The highest-value product copy and the easiest to get wrong, so it gets its own
rules.

- **Say what happened, in the reader's terms.** Not the exception name.
- **Say what to do next.** An error with no next step strands the reader it was
  written for.
- **Never blame the reader.** "That card number does not look right" beats
  "You entered an invalid card number".
- **Apologise only when the fault is yours, and only once.** Monzo draws this
  line sharply: say sorry sincerely where the product got it wrong — "We're
  sorry", not "We'd like to apologise" — then move straight to what happens next.
  Where the news is simply unwelcome and nothing went wrong, **do not apologise
  at all.** A sorry the reader knows you do not owe them reads as insincere.
- **Never promise a fix the code does not make.** "Try again in a few minutes"
  is a claim about the system, so it needs to be true.

## 5. Serious is not the same as formal

The reflex runs the other way, which is why this needs saying. When the subject
is sensitive — a failure, a refusal, a bill, lost data — prose stiffens. The
sentences lengthen, the actor disappears, and "unfortunately we are unable to
process your request at this time" replaces "we can't take that payment yet".

That reflex is a writer protecting themselves, and it costs the reader exactly
when they can least afford it. A sensitive subject is a reason to be
**warmer and plainer, not more formal.** Treat the stiffening as the tell for two
things already banned: the passive voice creeping in (`writing-style.md` §2 rule
2) and sentences growing past what a reader can hold.

Every register, Reference included. An incident note is not improved by sounding
like a legal filing.

## 6. What no register changes

Warmth changes how a claim is phrased. It never changes what is claimed.

1. **Active voice, with the actor named.** `writing-style.md` §2 rule 2 applies
   everywhere.
2. **A claim may not be stronger than the check behind it.** Friendly prose
   asserting an unverified fact is still an overclaim, and the warm register is
   where that is easiest to miss. `general-guidelines.md` owns this rule.
3. **The machine-generated tells stay banned** in all three registers.
   `writing-style.md` §7 lists them. "It's not just X, it's Y" does not become
   acceptable by being friendly.
4. **No fabricated feeling.** Warm means plain, human and considerate. It does
   not mean enthusiastic on the reader's behalf, and in no register does it mean
   funny. §4 sets the humour dial to none for product and support copy; a
   briefing inherits the same setting for the same reason.
