# Brand discovery: finding the direction before building anything

The brand is the person's taste plus the product's job. Neither is in the code, so this part is a
conversation. Run it with superpowers:brainstorming if it is installed (it supplies the cadence:
one question per message, play back what you heard, offer the visual companion); this file adds
what is specific to brands.

## Read first

Read the project's own design rules before the first question: `CLAUDE.md`/`AGENTS.md`, `docs/`
(architecture, ADRs, accessibility or style notes), and the main stylesheet. Rules found there
(a contrast floor, a font already chosen, "no animation", a dark-first app) are constraints on
every direction you mock up, and saying "your architecture doc sets secondary text at 7:1, so all
three directions keep that" shows the person you looked.

## What to find out

1. **The feeling, in their words.** Ask about a moment, not adjectives in the abstract: "Picture
   someone opening the site for the first time: what should they feel in the first few seconds?"
   Write their words down verbatim; they become the README's first lines.
2. **References, and what exactly is borrowed from each.** People name brands ("Apple, Tesla,
   SpaceX"). Each name carries several traits, and usually only one or two are wanted. Guess and
   let them correct you: "I'm guessing you'd borrow Tesla's sense of engineering rather than its
   dark, dramatic look?" The correction is the most useful answer you will get.
3. **Where the depth shows.** Most products need two layers: a sparse first impression and a
   denser layer (docs, FAQ, emails, settings) where expertise and care are visible. Ask where
   they picture someone noticing the quality.
4. **Current state.** Is today's look deliberate or a template? Read the code's styles first so
   you can say what exists (e.g. "the colours are the Tailwind template's indigo and pink").
5. **The voice.** Ask how the product should sound in a moment that matters: "Someone's
   payment failed. What should the message say?" Then the choices in `voice.md` §1.2: who
   speaks ("we", or nobody), how formal each language is, whether it ever uses an exclamation
   mark. Rewrite two or three of the product's real strings in the direction you heard, and let
   them correct the rewrite.
6. **Anti-goals.** What would make them wince? If they skip it, propose the usual ones (looks like
   a template or like generated "AI design", busy, the rejected direction) and let them edit.

## Show, don't describe

Once the feeling and references are clear, mock up **three directions** that differ in how much
of the references they lean on, each as a small real hero (headline, sentence, button, a product
visual), with palette swatches and a named typeface. Use real copy from the project, not lorem
ipsum, and write that copy in each direction's voice, so the person chooses how it sounds as
well as how it looks. Typical spread: one quiet/minimal, one bold/technical, one in between. Ask them to pick and
say what they'd change; mixing is allowed.

Mockups go in the browser (the brainstorming visual companion, or an Artifact), never as text
descriptions: people choose a brand by looking.

**Don't make them wait for pictures.** If the first message already gives the feeling and the
references ("calm, like Linear"), that is enough to mock up: send the three directions in the
first reply, with each guess about which trait you borrowed marked as a guess, and put your
questions underneath. Questions without pictures cost the person a round trip and get vaguer
answers. Hold the mockups back only when you genuinely don't know the feeling yet.

## Then write it down

Write a short brand design (docs/superpowers/specs/YYYY-MM-DD-brand-design.md or the project's
equivalent) covering: intent and the references (what is borrowed from each, in their words), the
layers, the chosen direction as concrete rules (palette with starting values, type, shape,
restraint), voice, what the design system will contain (the component list is the full scope),
non-goals, anti-goals, constraints (contrast, themes, fonts, languages, email), and the calls you
made. Get it approved before building.

## Things that went well (keep doing them)

- Quoting the person's own words back ("calm, effortless, it just works first time").
- Naming the tension between references explicitly instead of averaging them.
- Recording every call you make on their behalf in the spec, so they can veto it.
