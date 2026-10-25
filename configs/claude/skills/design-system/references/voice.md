# Voice and rhythm: how a brand writes

A design system decides how a product writes as firmly as how it looks. Every system ships
`project/voice.md`, and every string in the product, its site, its emails and its docs follows it.
This file holds the defaults and how they bend for each surface. A project's own `voice.md`
outranks it, and says so where it differs.

The defaults come from real projects. Parkahead (`johnmathews/parker`,
`brand/design-system/project/voice.md`) and Fitness Planner (`johnmathews/fitness-planner`, the
same path) agree on almost all of them. Read one of those files before writing a new one.

## 1. The voice is decided, not inherited

Voice is part of discovery (`brand-discovery.md`, "What to find out"), not something written after
the components. Get it in the person's words, then write it down as rules with examples.

### 1.1 What `voice.md` holds

1. **One paragraph that names the voice.** Three or four plain adjectives, and what they mean in
   practice. "Plain, calm and brief, in the second person. Facts first, then the next step."
2. **Rules**, each a bold claim and one or two sentences of why or how. Seven to twelve of them.
3. **An "Instead of / Write" table** built from the product's real strings: the template's or the
   old copy on the left, the rewrite on the right. One column per language the product ships.
   This table teaches more than the rules do.
4. **Surface notes** only where the project departs from §3: a sign-in flow, a pricing page, a
   legal line.
5. **Banned words**, with the reason, mirrored into `checks.json` `forbidden_words` so the gate
   enforces them (Parkahead bans every camera and surveillance word, and says why).

### 1.2 The choices each project makes

These differ between good projects. Decide each one, record it in `voice.md`, and apply it the
same way everywhere.

| Choice | Options | Parkahead | Fitness Planner |
| --- | --- | --- | --- |
| Who speaks | No speaker, or "we" for the people behind it | "we" for its people | No "we". The app is a tool, not a company |
| The reader | "you", or no address | "you" | "you" |
| Formality per language | Dutch je or u, German du or Sie | always "je" | English only |
| Numbers in sentences | words or figures | figures | small numbers as words, figures in grids |
| Exclamation marks | none, or a genuine thank-you only | thank-you only | none |
| Dates | the locale's long form, or short | not set | "Thursday 22 October" |
| The product as a subject | "it", "he", its name | "it" ("hij" in Dutch) | its name |

## 2. The rules that hold everywhere

Every surface follows these unless its own section says otherwise.

- **Lead with the thing.** The first sentence says what this is or what happened. No warm-up and
  no "this page describes". A scope line is different, and welcome. Once the thing is named, say
  what this covers and what it does not.
- **One idea per sentence.** A sentence that joins two claims of different kinds with "and", or
  bolts a second clause on with a colon, is two sentences.
- **No semicolons and no em dashes.** Use a full stop, a comma or brackets. A colon introduces a
  list, an example or a quotation, never a second clause.
- **Name the subject.** Write "this document", "your account" or "the sensor" wherever "it" could
  point at more than one thing, and always when a new sentence changes the subject. "That set",
  "the former" and "the above" are pronouns in disguise.
- **Concrete nouns over abstract ones.** "The data model", not "its data". A catch-all noun
  ("parts", "things", "aspects", "elements", "solutions") holds the place of a word not yet found.
  Find it.
- **Exact, never hyped.** "Every few minutes", not "in real time". "Four minutes", not "fast".
  No superlatives, and none of "seamless", "effortless", "revolutionary", "powerful", "amazing".
- **Say what it doesn't do.** A limit stated plainly builds more trust than a claim. "In the first
  few weeks it has too little history to predict, so it shows only which bays are free right now."
- **End on the point.** A closing pointer elsewhere ("those live in the docs") stays only if the
  reader needs to go there next.
- **Sentence case everywhere**, including buttons, headings, tabs and email subjects. No
  uppercase letter-spaced labels.
- **Contractions are welcome.** "It's", "you'll", "doesn't". They are most of the difference
  between a colleague and a policy.
- **Never blame the reader, and never guilt them.** "That password didn't match", not "You
  entered a wrong password". An empty box already says a day was missed.

A worked example, from the owner's rewrite of a design system's opening paragraph:

| Before | After |
| --- | --- |
| This document defines that set for Fitness Planner and shows each part in light and dark; new screens are built from it and the app is checked against it. | This document shows each part of the Fitness Planner web app in light and dark. New screens are built off of this design system, and the app is checked against it. |
| It does not describe how the app works, its data or its code, and it is not a picture of every screen: those live in the repository's docs and in the app itself. | This document does not describe how the app works, the data model or the code itself. It is also not a picture of every screen. |

The rewrite splits the joined clauses, names its subject, swaps "its data" for "the data model",
and drops the closing pointer.

## 3. Surfaces

Each surface has a job, and the job sets the rhythm. §4 gives the numbers.

### 3.1 Controls: buttons, links, labels, menus

- **A button is a verb and its object, naming the result.** "Create account", "Delete exercise",
  "Send link". Never "Submit", "OK", "Yes", "Confirm" or "Click here".
- **The same verb all the way through.** The heading says "Edit exercise", so the button says
  "Save exercise" or "Save", never "Update". A confirm dialog's button repeats the question's verb.
- **A link says where it goes.** "Go to sign in", "Read the privacy notice". Never a bare "Learn
  more" or "here". A line that is only a link has no full stop after it.
- **A label is a noun phrase**, with no colon after it and no "Please" before it. It stays visible
  above the field. A placeholder shows an example or a format ("name@example.com"), never the
  label.
- **A hint is one sentence** that says what the value changes or what format it takes.
- **An icon button's accessible name is the words a text button would show**, plus the context
  the icon gets from its position: "Edit Push-ups", not "Pencil".

### 3.2 Settings pages

- **Section headings name what they control**: "Appearance", "Planner", "Your data", "Account".
- **A switch's label states the on state, positively.** "Show weekly totals", never "Hide weekly
  totals" or "Don't show". The switch itself says on or off.
- **The hint says the effect**, in a sentence or two, including what it never does. "Export saves
  everything to a file. Import adds a file's plans and marks to yours and never deletes anything."
  (Fitness Planner's Your data section)
- **A control that applies at once has no Save button**, and the page doesn't mention saving.
  Mixing instant and saved controls on one page is a design bug, not a copy problem.
- **An account action names its consequence**, before the button and in it. "Signing out removes
  your data from this device. Your account keeps it." Then "Sign out".

### 3.3 Messages: errors, empty states, confirmations, success, loading

- **An error says what happened, then what to do.** Two sentences at most, no error code first,
  no "invalid", no blame. "This link has expired or was already used. Ask for a new one."
- **An empty state says what will go here, then gives the one action.** "No exercises this week.
  Add one, or copy last week's plan." Never "Nothing here yet!".
- **A confirm dialog asks the question with its verb**, says exactly what changes and what stays,
  and repeats the verb on the button. Fitness Planner: title "Remove Push-ups?", body "It comes
  off this week's plan. Weeks with their own plan keep it, and its marks stay.", buttons "Remove"
  and "Cancel".
- **Success states the fact and the next step, quietly.** "Check your inbox. We've sent you an
  email. Click the link in it to confirm your spot." (Parkahead) Never "Success!" or "You're in!".
- **Progress says what is happening**, with the ellipsis character: "Loading your data…",
  "Sending…". The words keep full colour. Only a disabled control fades.
- **Sync and offline states say where the data is safe.** "Not synced. Your changes are saved on
  this device and will sync when you're back online."
- **A toast is one sentence**, and it is never the only place important information appears,
  because it disappears.

### 3.4 Landing pages and marketing sites

- **The headline says what it does for the reader**, in their words, without an adjective about
  the product. "Know if you can park outside your home", not "Real-time parking intelligence".
- **The subhead is one sentence that says how**, concretely. "It takes a quick look every few
  minutes, works out which bays are free, and deletes the image."
- **Each section makes one claim, and its heading carries it.** A reader who reads only the
  headings should know what the product does, for whom, and what it costs.
- **Proof over adjectives.** A number, the mechanism, a real screenshot. "As easy as setting up a
  smart plug" beats "effortless".
- **The depth layer states the limits.** FAQs, specs and "how it works" sections say plainly where
  the product stops working, and why (Parkahead's voice.md, "Stating a limit").
- **One call to action, one verb, the same all the way down**, with the price or commitment next to
  it. "Reserve one for €10 (expected price €119)".
- **Not here:** rhetorical questions, "It's not just X, it's Y", rule-of-three flourishes, fake
  urgency ("Only 3 left!"), testimonials nobody gave.

### 3.5 Email

Transactional email first, because every product sends it. The email preview component carries
the layout. This section is the words.

- **The subject is the thing that happened or the action needed.** "Confirm your place on the
  Parkahead waitlist". Under 50 characters, no "[Brand]" prefix, no exclamation mark.
- **The preheader is the next useful sentence**, never "View in browser".
- **The first line repeats the subject's point**, for a reader who opened it from a notification.
- **One action, one button, labelled with the verb.** "Confirm my email address". The same link
  also appears as plain text underneath, at full length, for clients that strip buttons: "Or open
  this link in your browser: …"
- **Say exactly when it stops working.** "The link works for 7 days."
- **Say what to do if they didn't ask for it.** "Didn't sign up? Then you can ignore this email."
  Add why they got it when that isn't obvious from the subject.
- **Sign off with the product's name**, and its address if that helps: "Parkahead,
  parkahead.eu". No "Cheers!", no "The X Team 🚀". Say whether a reply reaches a person ("Reply to
  this email to reach us").
- **The plain-text version reads on its own**, with the same words in the same order.

A newsletter or announcement takes the landing page's rules (§3.4), one story per email.

### 3.6 Documentation, including the design system's own

Documentation is reference reading. A reader arrives with a question and leaves once it is
answered.

- **No first person**, not even "we", unless `voice.md` gives a company a voice in its docs.
- **Steps take the imperative.** "Run `make up`." A precondition comes before the step it governs.
- **Paragraphs carry one idea**, two to five sentences, none past forty words.
- **Headings say what is under them**, so the headings alone carry the document.
- **The design system's README opens by saying what it is.** "This is the X design system." Then
  what a design system is: the product's design language (colour, type, spacing, marks and voice),
  the components built from it, and the rules for using them. Then what this document does and
  doesn't do, in its own paragraph. Fitness Planner's README is the model.
- **A component README's first sentence is its summary**, then use, states, and what the consumer
  provides. Usage rules name tokens (`ink-secondary`, `radius-md`), never raw values.
- **A "Never" list is concrete**: "uppercase letter-spaced labels", not "inconsistent styling".

When the engineering-team skill is installed, its `references/writing-style.md` governs project
docs in full detail (budgets, mood, the greppable checks). This section is the part a design
system needs.

### 3.7 Legal, consent and pricing lines

- **Plain words, the same size as the text around them**, never hidden in a lighter grey that
  fails contrast.
- **Consent says what will happen, specifically.** "We'll email you once, when it ships", not "I
  agree to receive communications".
- **A price says what it includes and when it's charged.** No asterisks pointing at a footnote.

## 4. Rhythm by surface

Starting points. A project may tighten them in `voice.md`, and the previews check the longest
language against them.

| Surface | Length | Shape | Ends with |
| --- | --- | --- | --- |
| Button | 1 to 3 words | verb + object | nothing |
| Link on its own line | 2 to 5 words | where it goes | nothing |
| Field label | 1 to 4 words | noun phrase | nothing, no colon |
| Hint | one sentence, under 15 words | what it changes | full stop |
| Error | one or two sentences | what happened, what to do | full stop |
| Toast | one sentence, under 80 characters | the fact | full stop |
| Dialog title | under 8 words | the question, with its verb | question mark |
| Headline | under 10 words | the benefit, in the reader's words | nothing |
| Subhead | one sentence, under 25 words | how, concretely | full stop |
| Landing section | two or three sentences under a heading that is the claim | one claim | full stop |
| Email subject | under 50 characters | the event or the action | nothing |
| Transactional email body | under 120 words | point, action, expiry, why you got it | the sign-off |
| Docs paragraph | two to five sentences, none past 40 words | one idea | full stop |

Vary sentence length inside those limits. Three sentences of the same length read as a list
somebody forgot to format.

## 5. Every language the product ships

- **Write each language, don't translate it word for word.** "Net zo makkelijk als een slimme
  stekker" is Dutch. A literal translation of the English is not.
- **Keep strings whole.** Never assemble a sentence from fragments, because word order differs.
  Plurals go through the i18n library's plural rules, never `count + " items"`.
- **Leave room.** German and Dutch run up to a third longer than English. A preview shows the
  longest language, and a button that wraps is a defect.
- **Format numbers, prices and dates per locale.** "€ 119" in Dutch, "€119" in English.

## 6. Words and accessibility

- **Link and button text makes sense out of context**, because screen readers list them alone.
- **Never point by colour or position.** "The green button" and "on the right" fail a reader who
  can't see either. Name the control.
- **An accessible name carries the context the eye gets from layout.** "Push-ups, Thursday 22
  October, partly done".
- **A state that changes says so in words**, in a live region where it matters, not only by colour
  or an icon.

## 7. Checking it

1. **Read it aloud.** A sentence that runs out of breath gets cut. A run of same-length sentences
   gets one broken.
2. **Grep the marks**: `grep -nE '—|;' <file>` over copy and docs. Quotations and code are
   allowed hits.
3. **The gate checks banned words.** Put them in `checks.json` `forbidden_words`, or point
   `forbidden_words_js` at the product's own copy-rules list.
4. **Check against the "Instead of / Write" table.** Every new string should look like the right
   column.
5. **Preview with real copy** in every language, never lorem ipsum, so a long string shows up
   before it ships.
