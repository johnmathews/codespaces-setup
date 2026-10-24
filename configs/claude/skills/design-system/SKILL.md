---
name: design-system
description: Give a web project a deliberate brand and a design system, and keep its UI on it. Covers the whole path — reading the project's own design rules, finding the brand direction with the person (references like "Apple meets Stripe", mockups), publishing a claude.ai Design System artifact whose source and checks live in the repo, wiring its tokens into the styling the app already uses (Tailwind v4 or plain CSS), and building Vue components on Reka UI (shadcn-vue in Tailwind apps, headless Reka plus TanStack Table elsewhere) with contrast, axe and phone-width checks. Use it whenever someone wants a brand, a visual identity, a "proper" look instead of a template, a design system, design tokens, a redesign or reskin of a site or app, consistent UI across projects, or asks which component library to use (shadcn, shadcn-vue, Nuxt UI, Reka UI, Tailwind) — and before designing or building any page, screen or email in a project that already has a brand/design-system folder, so the work follows it.
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
artifact (`Artifact list` with `type: "Design System"`), and the app's styles: does it use
Tailwind (`@theme` blocks, `tailwind.config.*`, `@tailwindcss/vite`), scoped CSS, CSS variables
already named as tokens, component folders.

| State | Start at |
| --- | --- |
| No deliberate brand (template colours, stock fonts) | 1. Discover the brand |
| A brand, but no design system | 3. Build the design system |
| A design system, but the app doesn't use it | 5. Bring it into the code |
| All of it exists, and the task is a page or component | Read the system's README, then build from it (step 5 rules) |

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
- Every component gets a README (first sentence = summary; use, states, what the consumer
  provides) and a preview in real copy, in every language the product ships. The cover has no README.
- Upload SVGs first, write the index last, publish with `root`.

## 4. Verify it

Gate with `--complete`; open the artifact and check every card in every theme; render the
previews at 375px with `scripts/render_previews.mjs` (the browser can't be narrowed); then have a
fresh reviewer read the spec, the source and the gate's results. Fix what matters before moving on.
Offer the local gallery: `scripts/design_preview.py <system-dir>` writes an offline, git-ignored
`preview/index.html`.

## 5. Bring it into the code (Vue 3)

Read `references/code.md`. **Don't assume Tailwind**: follow the styling the app already uses.
Adding Tailwind to a project that styles with scoped CSS is a restyle of every component, so it
is the person's decision, never a side effect of picking a component library. The short version:

- Generate `tokens.css` from `tokens.json` (`design_preview.py --tokens-css …`, with
  `--dark-selector` matching how the app switches themes). Every app gets the same variables:
  `var(--ink)`, `var(--canvas)`.
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
from `templates/brand-doc.md`, and a line in the project's CLAUDE.md pointing at it all.

## What this skill ships

| Path | Use |
| --- | --- |
| `scripts/check_design_system.py` | The gate. Stdlib only; `--selftest`. Copy into each project. |
| `scripts/design_preview.py` | Offline gallery, and `--tokens-css` for the app (Tailwind or not). Stdlib only; `--selftest`. |
| `scripts/wordmark.py` | A name in the brand font as SVG outlines, one file per theme ink (`uv run --with fonttools --with brotli`). |
| `scripts/render_previews.mjs` | Every preview at phone width in every theme, with overflow report (needs Playwright). |
| `templates/checks.json`, `app-theme.css` (Tailwind apps), `a11y.spec.ts`, `brand-doc.md` | Starting points to copy into a project. |
| `references/*.md` | brand-discovery, tokens, artifact, code, enforcement. |

## Principles that earned their place

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
