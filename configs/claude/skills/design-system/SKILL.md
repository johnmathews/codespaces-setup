---
name: design-system
description: Give a web project a deliberate brand and a design system, and keep its UI on it. Covers the whole path — reading the project's own design rules, finding the brand direction with the person (references like "Apple meets Stripe", mockups), publishing a claude.ai Design System artifact whose source and checks live in the repo, wiring its tokens into the styling the app already uses (Tailwind v4 or plain CSS), and building Vue components on Reka UI (shadcn-vue in Tailwind apps, headless Reka plus TanStack Table elsewhere) with contrast, axe and phone-width checks. Use it whenever someone wants a brand, a visual identity (palette, typeface), a "proper" look instead of a template, a design system, design tokens, a redesign or reskin of a site or app, consistent UI across projects, a brand's voice or the copy for a page, screen, settings page, landing page, email or docs (how the product writes), or asks which component library to use (shadcn, shadcn-vue, Nuxt UI, Reka UI, Tailwind) — and before designing or building any page, screen or email in a project that already has a brand/design-system folder, so the work follows it.
---

# Design system

A project's look should be a decision, not a template's leftovers. This skill takes a project from
"generic" to a brand with a published design system, and then keeps the code on it. It is the
recipe first worked out on Parkahead (`johnmathews/parker`, 2026-10-24); that repo is the worked
example to read when in doubt (`brand/design-system/`, `docs/brand.md`,
`docs/superpowers/specs/2026-10-24-brand-design.md`).

## First: read the project's own rules

Before proposing anything, read what the project already decided about its UI: `CLAUDE.md` /
`AGENTS.md`, `docs/` (architecture, ADRs, style or accessibility notes), `CONTRIBUTING`, lint and
stylelint configs, and comments at the top of the main stylesheet. A project that says "secondary
text is 7:1" or "no utility CSS" has made a call this skill must not undo. Where its rule is
stricter than this skill's, the project wins (put the stricter ratio in `checks.json`
`extra_contrast_pairs`); where they conflict, follow the project and say so. Quote the rules you
found back to the person so they can see you read them.

Also look at the person's other projects for precedent (which component library, which table
library, how themes switch). Consistency with what they already run beats a fresh pick.

## Where is the project now?

Look before asking. Check for `brand/design-system/` (or a `docs/brand.md`), a Design System
artifact (`Artifact list` with `type: "Design System"`), which UI framework `package.json` names
(step 5 depends on it), and the app's styles: does it use
Tailwind (`@theme` blocks, `tailwind.config.*`, `@tailwindcss/vite`), scoped CSS, CSS variables
already named as tokens, component folders.

| State | Start at |
| --- | --- |
| No deliberate brand (template colours, stock fonts) | 1. Discover the brand |
| A brand, but no design system | 3. Build the design system |
| A design system, but the app doesn't use it | 5. Bring it into the code |
| All of it exists, and the task is a page or component | Read the system's README, then build from it (step 5 rules) |
| Any of the above, and the person will see something new: a colour, size, spacing, type, a mark, a new component, screen or layout | **Mock it up first** (below), then the row above |

## Mock up before you build

A visual change is decided on a picture, so it starts as a mockup, not as code. Read
`references/mockups.md` and follow its loop: `scripts/mockup.py new` starts a page in
`brand/design-system/mockups/` built from the system's own tokens and fonts, with two to four
options in their real place, both themes side by side and contrast measured on the page;
`mockup.py build` and `scripts/render_mockup.mjs` render it for you to look at first; then it is
published as a private Artifact for the person to pick from and comment on, and their pick is
recorded before any code changes. Skip it only for the cases that reference lists (a bug that
restores the system, a look they already picked, an invisible change).

## See it running locally

The mockup decides the look; the person then checks the build in the real app, on their own
machine, before anything is committed or pushed. A reload is faster than a CI round trip, and
fast iteration loops matter more to them than almost anything else here.

- **When:** every visual change, once the code is written and the checks pass, and before
  commit, push or PR. During a run of small tweaks, keep the stack up so each one shows on a
  reload. Skip it only when the project has no runnable app, or the person says to go straight to
  CI.
- **Bring it up the project's way:** read its README and development docs for the commands (dev
  server, API, database, Compose). Check the ports first: a server already running from another
  checkout serves the wrong code. Start each process in the background, wait until it answers,
  then hand over the URL, how to sign in, and two or three things to try that show the change.
  Point at the style guide or component gallery too when the project has one, since it needs no
  sign-in.
- **Keep the login and the data.** Never delete or reset the local database, run
  `git clean -x`, or drop a Compose volume unless asked. A git worktree has no copy of the
  git-ignored data folder, so point the project's data setting at the main checkout's folder (or
  a stable path such as `~/.local/share/<project>/dev`), and use the same one every time. Reuse an
  existing account; when one has to be made, prefer a local demo account and note how to sign in
  in a git-ignored file. Never commit credentials.
- **Seed demo data wherever possible.** An empty screen hides the change. Use the project's seed
  script or fixtures; if it has none, offer to add one: idempotent, local-only, one demo account,
  and enough data to show every state the screens draw. Seed only what is missing, never over
  what the person made by hand.
- Leave the stack running and say so; stop it when they ask.

## 1. Discover the brand

A conversation, not a form: the person's taste and the product's job are not in the code. Read
`references/brand-discovery.md`. In short: get the feeling in their words, find out exactly which
trait of each reference brand they want (guess and let them correct you), find where the depth
should show, then **mock up three directions in the browser** and let them choose. Use
superpowers:brainstorming for the cadence if it is installed.

**Mock up as soon as the brief is clear.** If the person has already named the feeling and the
references (often in their first message), don't hold the mockups back for a round of questions:
send three directions in that first reply, mark your guesses about which traits you borrowed, and
ask your questions beside them. Reacting to a picture is faster and more accurate than answering
in the abstract.

## 2. Write the brand design and get it approved

A short spec: intent and references, the layers (a sparse first impression and a denser depth
layer), the chosen direction as concrete rules, voice, the component list (the full scope),
non-goals, anti-goals, constraints, and every call you made. Nothing gets built before approval.
The voice gets the same care as the palette: the person's words for it, and the choices in
`references/voice.md` §1.2 (who speaks, formality, numbers) made and recorded.

## 3. Build the design system

Source in the repo, published as a claude.ai Design System artifact. Read `references/artifact.md`
for the layout, the publishing calls and the traps, and `references/tokens.md` for the token
rules.

- Use the **standard colour roles** (`canvas`, `panel`, `tile`, `line`, `control-border`, `ink`,
  `on-ink`, `ink-secondary`, `error-ink`, `focus`) plus the project's own accents. Same names in
  every project, different values: that is what makes the gate, the CSS, the Tailwind mapping and
  the shadcn-vue adapter reusable. **Token names are not negotiable:** if the project already has
  its own (`--color-bg`, `--text-muted`), rename them to the roles (references/tokens.md has the
  migration); don't keep a second vocabulary alongside.
- Copy the gate and its settings into the project: `scripts/check_design_system.py` → the repo's
  `scripts/`, `templates/checks.json` → `brand/design-system/checks.json`. Run it after every
  change; it fails on unreadable token shapes, contrast misses in any theme, banned words, missing
  components and an email that uses `<style>` or `var()`.
- **Copies carry a version.** Every script declares `SCRIPT_VERSION` (`--version` shows it), and
  the two that projects copy (the gate and `design_preview.py`) print a `note:` when theirs
  differs from this skill's. In a project that already has copies,
  act on that note before anything else: update the copy, or update the skill if the copy is newer.
- Every component gets a README (first sentence = summary; use, states, what the consumer
  provides) and a preview in real copy, in every language the product ships. The cover has no README.
- Write `project/voice.md` from `references/voice.md`: the voice in one paragraph, the rules, an
  "Instead of / Write" table from the product's real strings, and banned words mirrored into
  `checks.json`. The README opens by saying it is the design system, what a design system is,
  and what this document does and doesn't do (`references/voice.md` §3.6).
- Upload SVGs first, write the index last, publish with `root`.

## 4. Verify it

Gate with `--complete`; open the artifact and check every card in every theme; render the
previews at 375px with `scripts/render_previews.mjs` (the browser can't be narrowed); then have a
fresh reviewer read the spec, the source and the gate's results. Fix what matters before moving on.
Offer the local gallery: `scripts/design_preview.py <system-dir>` writes an offline, git-ignored
`preview/index.html`.

## 5. Bring it into the code

**First, which framework?** Read it off disk, don't assume it: the `dependencies` in the
`package.json` that builds the UI (in a monorepo, the app's own, not the root's).

| Found | Read |
| --- | --- |
| `vue` or `nuxt` | `references/code.md` (the worked path; the rest of this step) |
| `react`, `next`, `svelte`, `@sveltejs/kit`, `solid-js`, … | `references/other-frameworks.md` |
| No JS framework (static HTML, Astro without islands, server templates) | Plain HTML + `tokens.css`: the first and the "No Tailwind" bullets below |

The component advice below is worked out for **Vue 3 only**. For any other framework, say so to
the person in one line before recommending a library ("this skill's component guidance was built
on Vue; for React I'm mapping it to the equivalents, which it hasn't been tested on"), then follow
`references/other-frameworks.md`. Never hand a React or Svelte app a Vue package, a `.vue` file
or a `shadcn-vue` command. Everything before this step (brand, tokens, the artifact, the gate) is
framework-free and applies unchanged.

Read `references/code.md`. **Don't assume Tailwind**: follow the styling the app already uses.
Adding Tailwind to a project that styles with scoped CSS is a restyle of every component, so it
is the person's decision, never a side effect of picking a component library. The short version:

- Generate `tokens.css` from `tokens.json` (`design_preview.py --tokens-css …`). Dark lands on a
  `.dark` class by default; an app that toggles `data-theme` passes
  `--dark-selector '[data-theme="dark"]'` and sets `templates/a11y.spec.ts`'s `DARK` to match.
  Every app gets the same variables: `var(--ink)`, `var(--canvas)`.
- **Tailwind v4 app:** use `templates/app-theme.css` as the main stylesheet, so utilities are named
  after the roles (`bg-canvas`, `text-ink-secondary`) and shadcn's variables map onto them.
- **No Tailwind (scoped CSS, plain CSS):** import `tokens.css` and use the variables directly in
  the existing styles; no new styling layer.
- Pick the component layer by surface and styling: plain HTML for landing pages and email;
  **shadcn-vue** for apps already on Tailwind (owned source on Reka UI); **headless Reka UI** (plus
  **TanStack Table** for data tables) styled with the tokens for apps that aren't; Nuxt UI only for
  internal dashboards already on Tailwind where speed beats a distinct look. Don't reach for a
  styled kit (PrimeVue, Vuetify, …) for a branded product.
- With shadcn-vue: replace its generated stylesheet and font, restyle the dense defaults in the
  copied source, and make the focus ring the solid 2px one.
- Build only from tokens and the system's components. If something is missing, add it to the
  system first (preview + README), then use it.

## 6. Make it stick

Read `references/enforcement.md`: the gate in CI, `templates/a11y.spec.ts` in the e2e suite, a
check that generated tokens are current, optionally a lint against raw colours, `docs/brand.md`
from `templates/brand-doc.md`, and lines in the project's CLAUDE.md pointing at it all and
making visual changes start as a mockup.

## What this skill ships

| Path | Use |
| --- | --- |
| `scripts/check_design_system.py` | The gate. Stdlib only; `--selftest`, `--version`. Copy into each project. |
| `scripts/design_preview.py` | Offline gallery, and `--tokens-css` for the app (Tailwind or not). Stdlib only; `--selftest`, `--version`. Copy into each project. |
| `scripts/wordmark.py` | A name in the brand font as SVG outlines, one file per theme ink (`uv run --with fonttools --with brotli`); `--selftest`, `--version`. |
| `scripts/render_previews.mjs` | Every preview at phone width in every theme, with overflow report (needs Playwright, and python3 for `design_preview.py` beside it, which compiles its CSS); `--selftest`, `--version`. |
| `scripts/mockup.py` | Starts a mockup (`new`) and builds it for rendering and publishing (`build`). Stdlib only, uses `design_preview.py` beside it; `--selftest`, `--version`. Run from the skill; not copied. |
| `scripts/render_mockup.mjs` | A built mockup at desktop and phone width in light and dark, with overflow, console-error and failed-load lines (needs Playwright); `--selftest`, `--version`. Run from the skill. |
| `templates/checks.json`, `app-theme.css` (Tailwind apps), `a11y.spec.ts`, `brand-doc.md` | Starting points to copy into a project. |
| `templates/mockup.html`, `mockup-readme.md` | What `mockup.py new` copies: the page skeleton and the decision record. |
| `references/*.md` | brand-discovery, tokens, artifact, code (Vue), other-frameworks, enforcement, voice (how the brand writes, surface by surface), mockups (show it before you build it). |

## Principles that earned their place

- **Copy is part of the design.** Every string follows `voice.md`, written for its surface
  (`references/voice.md` §3): a button is a verb and its object, an error says what happened and
  what to do, a headline says what the product does for the reader. One idea per sentence,
  concrete nouns, no hype.

- **Contrast is measured, not eyeballed**, in every theme. The mockup's grey usually fails on a
  tile by a hair; fix it by one step and record the change.
- **A meaningful colour means one thing.** If a colour carries a state (free, error), it never
  decorates, not even on the cover.
- **Never fade what people must read.** "Sending…" keeps full colour; only truly disabled
  controls fade.
- **Consent and legal text stay where the project's rules put them in every state**, including error states.
- **Test after animations settle.** Components animate colour and outline; measuring mid-transition
  produces false failures.
- **The repo is the source of truth**, the artifact is the published view; edits on the page get
  copied back before local edits.
