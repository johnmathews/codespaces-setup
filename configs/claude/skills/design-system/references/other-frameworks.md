# Bringing the design system into a non-Vue app

`code.md` is the worked path, and it is Vue 3: every package, command and file path there was
used on a real project. This file covers everything else. Its mappings are **equivalents, not
experience**. Nothing below has been taken through a real project yet, so say that to the person
before recommending a library, and check each package's current docs before running its setup.

## What carries over unchanged

These don't depend on the framework, so use them exactly as `code.md` describes:

- `tokens.css` from `design_preview.py --tokens-css` (dark theme on `.dark` by default), and the
  standard role names: `var(--ink)`, `var(--canvas)`.
- `templates/app-theme.css` in a Tailwind v4 app, for the role-named utilities (`bg-canvas`,
  `text-ink-secondary`). Its shadcn adapter block maps `--background`, `--primary` and the rest,
  and shadcn/ui (React) and shadcn-svelte read the same variable names as shadcn-vue. Keep the
  imports their `init` writes; drop the two marked `shadcn-vue only`.
- The solid 2px focus ring, the "wait for transitions to settle" rule, and
  `templates/a11y.spec.ts`, which is plain Playwright and knows nothing about the framework.
- The gate, the previews and the artifact: steps 1 to 4 and 6 of `SKILL.md`.

## What changes: the component layer

Pick by the same rule as `code.md`: plain HTML for landing pages and email, an owned-source kit
for Tailwind apps, headless parts styled with the tokens for apps that aren't on Tailwind, and
never a strongly styled kit for a branded product.

| Role (Vue, from code.md) | React | Svelte |
| --- | --- | --- |
| Owned source on Tailwind: shadcn-vue | shadcn/ui | shadcn-svelte |
| Headless parts: Reka UI | Radix UI primitives, or React Aria | Bits UI |
| Data tables: `@tanstack/vue-table` | `@tanstack/react-table` | `@tanstack/svelte-table` |
| Avoid for a branded product: PrimeVue, Vuetify | MUI, Chakra, Ant Design | Skeleton, Flowbite-Svelte |

The `code.md` notes that come from the shadcn family hold for its React and Svelte versions too:
replace the generated stylesheet and font, restyle the dense defaults (`h-8`, `text-sm`) in the
copied source, and swap the translucent focus ring for the solid one. Reka UI is a Vue port of
Radix UI, so Radix parts expose the same state attributes (`data-state="open"`,
`data-highlighted`, `data-disabled`) to style against.

## Anything else (Solid, Angular, Lit, server templates)

Use plain HTML and the tokens, styled with `tokens.css` in whatever the app already writes, and
ask the person before adding a component library: there is no worked default to lean on.

## When a project takes one of these paths

That project is the first worked example for its framework. Record what was learned (package
versions, setup commands, the traps) back into this file, in `configs/claude/skills/design-system/`
in the codespaces-setup repo, so the next project inherits experience rather than a mapping.
