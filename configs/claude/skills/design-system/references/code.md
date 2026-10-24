# Bringing the design system into a Vue 3 + Tailwind v4 app

## Choosing the component layer

| Option | When |
| --- | --- |
| **Plain HTML + the tokens** | Marketing and landing pages, emails, anything that needs only forms, `<details>` and links. Lightest; no JS cost. |
| **shadcn-vue** (default for apps) | Apps with dialogs, selects, menus, tabs, popovers. Copies component source into the repo (you own and restyle it), built on Reka UI's accessible behaviour and Tailwind v4. |
| **Reka UI directly** | When only one or two complex widgets are needed and the shadcn layer isn't worth adding. |
| **Nuxt UI** (v4, free, works in plain Vue via its Vite plugin) | Internal tools and dashboards where 125+ ready components beat a distinct look. Themed by config, not by owning the source. |
| Not: PrimeVue, Vuetify, Quasar, Element Plus | Strong built-in looks that fight a bespoke brand. |

Measured once (2026-10-24): button, input, dialog, select and accordion from shadcn-vue added about
67 KB of gzipped JS over a bare Vue app (24 KB → 91 KB). Fine for an app; too much for a landing
page that plain HTML can serve.

## Tokens into Tailwind

1. Copy `scripts/check_design_system.py` and `scripts/design_preview.py` from this skill into the
   project's `scripts/`, and `templates/checks.json` to `brand/design-system/checks.json`.
2. Generate the app's tokens (re-run whenever `tokens.json` changes; consider a check in CI that
   the generated file is current):
   `python3 scripts/design_preview.py brand/design-system --tokens-css src/styles/tokens.css --dark-selector .dark`
3. Use `templates/app-theme.css` as the main stylesheet: it imports Tailwind and `tokens.css` and
   maps the roles to utilities (`bg-canvas`, `text-ink-secondary`, `border-control-border`, …).
4. Dark mode is a `.dark` class on `<html>`, set before first paint (from `prefers-color-scheme`
   or a stored choice). Tailwind's `dark:` variant and shadcn-vue both follow it.
5. The type styles arrive as plain classes (`.display`, `.body`, `.caption`, `.label`, `.code`).
   If an app already uses those class names, rename the styles in `tokens.json` with a prefix.

## shadcn-vue setup (Vite)

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
sideways scroll at 375px, and the focus-ring shape. shadcn-vue components use `transition-all`, so
colours and outlines animate: wait for transitions to settle before measuring, or you will read
half-way values and chase false failures. For keyboard behaviour (dialog focus trap, Escape,
focus return, select arrows) Reka UI was correct in every case tested; test it once per app rather
than per component.
