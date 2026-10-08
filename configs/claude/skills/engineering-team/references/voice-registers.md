# Voice registers — who is reading, and how the prose sounds

> Purpose
>
> Pick the register before writing a word. Three audiences read what this team
> produces and they do not want the same prose. This file owns the **axis** and
> defines the two non-engineering registers. The Reference register's detailed
> rules live in `writing-style.md`, which this file points at rather than
> restates.
>
> Load it when writing anything a non-engineer reads: product copy, a status
> report, an explainer written for a product owner.

## 1. The axis

One question picks the register: **who is reading, and what do they want back?**

| Register | Reader | Wants | Rules live in |
| --- | --- | --- | --- |
| **Reference** | an engineer with a question | the answer, fast | `writing-style.md` |
| **Briefing** | a colleague who does not write code | to understand a decision | §3 |
| **Product** | someone using the thing | to get on with it | §4 |

**Scope by path, not by judgement.** `documentation-model.md` §3 draws
living-versus-point-in-time by path for exactly this reason: a rule that needs a
decision gets a different decision each time. Set the mapping once in the
project, and default to this:

| Path | Register |
| --- | --- |
| `README.md`, `docs/adr/`, `docs/rfc/`, `docs/spec/`, `docs/explainers/`, `journal/` | Reference |
| `docs/briefings/`, status reports, anything addressed to a named non-engineer | Briefing |
| UI strings, locale files, email and notification templates, error copy, onboarding flows | Product |

The failure this prevents is a warm-voice pass rewriting the ADR log. Register
follows the file, so that pass has nowhere to land.

**A document is written in one register.** When a Reference document needs a
paragraph a non-engineer can read, that paragraph is a summary at the top, not a
register change halfway down. Prose that switches voice mid-document reads as two
people arguing.

## 2. Person, and the first-person carve-out

This is the rule that differs most between registers, so it is stated once, here.

| Register | First person | Second person |
| --- | --- | --- |
| **Reference** | **Banned.** `writing-style.md` §2 rule 1 owns this and is unchanged | Encouraged |
| **Briefing** | **"We" permitted** for the team. "I" still banned | Encouraged |
| **Product** | **"We" preferred** over the company name. "I" only in UI labels the reader is choosing ("Remember my password") | Required |

**Why the registers split rather than sharing one rule.** Published voice guides
genuinely disagree, so this is a choice and not a consensus. Mailchimp mandates
the first person everywhere, including API documentation: *"Refer to Mailchimp as
'we,' not 'it.'"* Microsoft discourages it everywhere, including marketing, on
the grounds that "we" reads as "a daunting corporate presence". Monzo and
Mailchimp are the target here, so "we" is carved out — but only where a speaker
actually exists. A reference document has no narrator, which is why the ban
survives in the one register whose reader is looking something up.

**"We" needs a referent the reader can name.** In Product copy it is the
company. In a Briefing it is the team. A "we" that could mean either is the
corporate fog both guides warn about, so name the actor instead.

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

- **"We" for the company, "you" for the reader.** Never "the user" in copy the
  user is reading.
- **Contractions are the default.** They are the single largest warmth lever and
  both verified guides treat them that way.
- **Keep sentences to 25 words or fewer** — Mailchimp's published number, and
  tighter than the 40-word ceiling `writing-style.md` §5 sets for Reference.
- **Plain words.** Short, everyday, and jargon defined on first use or removed.
- **Respect the reader.** Explain without patronising. Address them, do not
  market at them.
- **Exclamations are allowed, sparingly.** Use one where a person would. Never to
  manufacture enthusiasm the reader does not share.
- **Active voice, actor named.** Shared with every register.

### 4.1 Error copy

The highest-value product copy and the easiest to get wrong, so it gets its own
rules.

- **Say what happened, in the reader's terms.** Not the exception name.
- **Say what to do next.** An error with no next step strands the reader it was
  written for.
- **Never blame the reader.** "That card number does not look right" beats
  "You entered an invalid card number".
- **Do not apologise repeatedly.** One apology where the fault is genuinely the
  product's. None where it is not.
- **Never promise a fix the code does not make.** "Try again in a few minutes"
  is a claim about the system, so it needs to be true.

## 5. What no register changes

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
   not mean enthusiastic on the reader's behalf.
