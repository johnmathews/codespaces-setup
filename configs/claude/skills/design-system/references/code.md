# Bringing the design system into a Vue 3 app

The component advice here is Vue only. For React, Svelte or anything else, read
`other-frameworks.md` first: it says which sections of this file still apply (the token and
Tailwind steps, the testing notes) and what replaces the rest.

## Start from what the app already uses

Before choosing anything, find out how the app is styled today and follow it:

- **Tailwind v4** (`@tailwindcss/vite`, `@theme` blocks): tokens into Tailwind, below.
- **Scoped or plain CSS** (`<style scoped>`, a global stylesheet, existing CSS variables): keep it.
  Generate `tokens.css`, rename existing variables to the standard roles (references/tokens.md),
  and use `var(--ink)` and friends in the existing styles.
- **Tailwind v3 or a config file**: ask whether to upgrade before mapping tokens.

Don't add Tailwind to get a component library. In an app with dozens of scoped-CSS components it
means two styling systems, or a rewrite of every component, and that is a restyle the person has
to choose deliberately. Check the person's other projects too: if one already pairs a headless
library with a table library, reuse that pairing.

## Choosing the component layer

| Option | When |
| --- | --- |
| **Plain HTML + the tokens** | Marketing and landing pages, emails, anything that needs only forms, `<details>` and links. Lightest; no JS cost. Any styling. |
| **shadcn-vue** (default for Tailwind apps) | Apps with dialogs, selects, menus, tabs, popovers. Copies component source into the repo (you own and restyle it), built on Reka UI's accessible behaviour and Tailwind v4. |
| **Reka UI, headless** (default for non-Tailwind apps) | The same accessible behaviour as shadcn-vue without its styling layer: unstyled parts you style with the tokens in scoped CSS. Also for a Tailwind app that needs only one or two complex widgets. |
| **TanStack Table** (`@tanstack/vue-table`) | Data tables (sorting, filtering, pagination) in any app: headless, so it renders your markup and styles. |
| **Nuxt UI** (v4, free, works in plain Vue via its Vite plugin) | Only for internal tools already on Tailwind, where 125+ ready components beat a distinct look. Themed by config, not by owning the source. |
| Not: PrimeVue, Vuetify, Quasar, Element Plus | Strong built-in looks that fight a bespoke brand. |

Measured once (2026-10-24): button, input, dialog, select and accordion from shadcn-vue added about
67 KB of gzipped JS over a bare Vue app (24 KB → 91 KB). Fine for an app; too much for a landing
page that plain HTML can serve.

## Tokens without Tailwind (scoped or plain CSS)

1. Copy the scripts and `checks.json` as in step 1 below.
2. Generate `tokens.css` with the dark selector the app already uses. The default is a `.dark`
   class; an app that toggles `data-theme` passes `--dark-selector '[data-theme="dark"]'`:
   `python3 scripts/design_preview.py brand/design-system --tokens-css src/styles/tokens.css --dark-selector '[data-theme="dark"]'`
3. Import it once, before the app's own styles (`main.ts` or the global stylesheet).
4. Rename the app's existing variables to the roles in one sweep (references/tokens.md,
   "Projects that already have tokens"), then replace raw colours in components with the roles.
5. Style Reka UI parts in the component's scoped CSS through their state attributes
   (`[data-state="open"]`, `[data-highlighted]`, `[data-disabled]`), using only `var(--…)` tokens.
   Keep the solid 2px focus ring: `:focus-visible { outline: 2px solid var(--focus);
   outline-offset: 2px; }` in the global stylesheet.

## Tokens into Tailwind

1. Copy `scripts/check_design_system.py` and `scripts/design_preview.py` from this skill into the
   project's `scripts/`, and `templates/checks.json` to `brand/design-system/checks.json`.
2. Generate the app's tokens (re-run whenever `tokens.json` changes; consider a check in CI that
   the generated file is current):
   `python3 scripts/design_preview.py brand/design-system --tokens-css src/styles/tokens.css`
   (the dark theme lands on `.dark`, the default: what shadcn-vue toggles, and what Tailwind's
   `dark:` variant follows once `app-theme.css` declares it with `@custom-variant`)
3. Use `templates/app-theme.css` as the main stylesheet: it imports Tailwind and `tokens.css` and
   maps the roles to utilities (`bg-canvas`, `text-ink-secondary`, `border-control-border`, …).
4. Dark mode is a `.dark` class on `<html>`, set before first paint (from `prefers-color-scheme`
   or a stored choice). Tailwind's `dark:` variant and shadcn-vue both follow it.
5. The type styles arrive as plain classes (`.display`, `.body`, `.caption`, `.label`, `.code`).
   If an app already uses those class names, rename the styles in `tokens.json` with a prefix.

## shadcn-vue setup (Vite, Tailwind apps only)

```
pnpm dlx shadcn-vue@latest init --base-color stone --icon-library lucide -y
pnpm dlx shadcn-vue@latest add button input dialog select accordion
```

Init needs Tailwind v4 (`tailwindcss`, `@tailwindcss/vite` in `vite.config.ts`) and the `@` alias
in both `vite.config.ts` and `tsconfig*.json` (`paths` only; `baseUrl` is deprecated in TS 6).
Then:

1. **Replace the generated `src/style.css`** with `templates/app-theme.css`. The generated one
   defines its own palette in oklch and a font; ours maps shadcn's names (`--primary`,
   `--muted-foreground`, …) onto the design system's roles instead.
2. **The font.** Init adds a Google Fonts `@import` for Geist. Replace it with the brand's font,
   self-hosted (`@fontsource/<font>`) or from Google Fonts, whichever the project allows.
3. **Restyle in the source.** shadcn's defaults are dense: `h-8`, `text-sm`, `rounded-lg`. Edit
   each component's `cva` variants in `src/components/ui/<name>/index.ts` (and the `.vue` files)
   to the design system's sizes. Some sizes are set through data-attribute variants
   (`data-[size=default]:h-8`) that a `class` prop can't override; change those in the source.
4. **The focus ring.** The default is a translucent 3px ring (`focus-visible:ring-ring/50`), which
   can miss 3:1. Use the solid 2px outline at 2px offset (app-theme.css sets it globally; remove the
   ring utilities from the components you touch).
5. **Wrapper attributes.** Attributes on some parts land on a wrapper, not the control: on
   `AccordionTrigger` they go to the `<h3>`, so target `[data-…] button` in tests.

## Testing the app

Copy `templates/a11y.spec.ts` into the Playwright suite: axe WCAG A/AA in light and dark, no
sideways scroll at 375px, and the focus-ring shape. Set its `DARK` to match how `tokens.css`
was generated: `{ class: 'dark' }` for the default, `{ attribute: 'data-theme' }` for
`--dark-selector '[data-theme="dark"]'`. Its first test fails if switching
themes leaves `--canvas` unchanged, which is what a mismatch looks like: without it, every dark
audit silently re-runs the light theme and passes. shadcn-vue components use `transition-all`, so
colours and outlines animate: wait for transitions to settle before measuring, or you will read
half-way values and chase false failures. For keyboard behaviour (dialog focus trap, Escape,
focus return, select arrows) Reka UI was correct in every case tested; test it once per app rather
than per component.
