---
name: design-system
description: Give a web project a deliberate brand and a design system, and keep its UI on it. Covers the whole path — finding the brand direction with the person (references like "Apple meets Stripe", mockups of directions), publishing a claude.ai Design System artifact whose source and checks live in the repo, wiring its tokens into Tailwind v4, and building Vue components (shadcn-vue on Reka UI, restyled to the tokens) with contrast, axe and phone-width checks. Use it whenever someone wants a brand, a visual identity, a "proper" look instead of a template, a design system, design tokens, a redesign or reskin of a site or app, consistent UI components across projects, or asks which component library to use (shadcn, shadcn-vue, Nuxt UI, Reka UI, Tailwind) — and before designing or building any page, screen or email in a project that already has a brand/design-system folder, so the work follows it.
---

# Design system

A project's look should be a decision, not a template's leftovers. This skill takes a project from
"generic" to a brand with a published design system, and then keeps the code on it. It is the
recipe first worked out on Parkahead (`johnmathews/parker`, 2026-10-24); that repo is the worked
example to read when in doubt (`brand/design-system/`, `docs/brand.md`,
`docs/superpowers/specs/2026-10-24-brand-design.md`).

## Where is the project now?

Look before asking. Check for `brand/design-system/` (or a `docs/brand.md`), a Design System
artifact (`Artifact list` with `type: "Design System"`), and the app's styles (`@theme` blocks,
`tailwind.config.*`, component folders).

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
  every project, different values: that is what makes the gate, the Tailwind mapping and the
  shadcn-vue adapter reusable.
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

## 5. Bring it into the code (Vue 3 + Tailwind v4)

Read `references/code.md`. The short version:

- Generate `tokens.css` from `tokens.json` (`design_preview.py --tokens-css … --dark-selector .dark`)
  and use `templates/app-theme.css` as the main stylesheet, so utilities are named after the roles
  (`bg-canvas`, `text-ink-secondary`) and shadcn's variables map onto them.
- Pick the component layer by surface: plain HTML for landing pages and email; **shadcn-vue** for
  apps (owned source on Reka UI); Nuxt UI for internal dashboards where speed beats a distinct
  look. Don't reach for a styled kit (PrimeVue, Vuetify, …) for a branded product.
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
| `scripts/design_preview.py` | Offline gallery, and `--tokens-css` for the app. Stdlib only; `--selftest`. |
| `scripts/wordmark.py` | A name in the brand font as SVG outlines, one file per theme ink (`uv run --with fonttools --with brotli`). |
| `scripts/render_previews.mjs` | Every preview at phone width in every theme, with overflow report (needs Playwright). |
| `templates/checks.json`, `app-theme.css`, `a11y.spec.ts`, `brand-doc.md` | Starting points to copy into a project. |
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
