# The design-system skill

Added `configs/claude/skills/design-system/`, deployed by `scripts/17-claude-skills.sh` like
`engineering-team`. It captures the recipe worked out on Parkahead (`johnmathews/parker`) on
2026-10-24: a brand conversation with mockups of three directions, a written brand design, a
claude.ai Design System artifact with its source and a gate in the repo, the tokens wired into
Tailwind v4, and Vue components on shadcn-vue, checked for contrast, axe and phone width.

## Decisions

1. **One skill for the whole path**, entered at whichever stage the project is at (no brand / a
   brand but no system / a system the code doesn't use / building a page on an existing system).
   The founder asked for the work to be standardised across projects, and the stages depend on
   each other's outputs.
2. **Standard colour role names** (`canvas`, `panel`, `tile`, `line`, `control-border`, `ink`,
   `on-ink`, `ink-secondary`, `error-ink`, `focus`) in every project, with per-project values and
   accents. That is what makes the gate's contrast pairs, the Tailwind mapping and the shadcn-vue
   adapter reusable unchanged.
3. **The scripts are copied into each project**, not run from `~/.claude`, so a project's CI does
   not depend on a developer's machine. Both Python scripts are stdlib-only and have `--selftest`,
   which this repo's CI now runs (they are the part a regression would spread from).
4. **Project settings in `checks.json`** (required components, extra contrast pairs, banned words,
   email preview, gallery group order) instead of constants, which is what the Parkahead originals
   had.
5. **shadcn-vue is the default component layer for apps**, after a test on 2026-10-24: Reka UI's
   keyboard and focus behaviour was right in every case, axe was clean in both themes once the
   tokens were mapped, but five components cost ~67 KB gzipped JS, so landing pages stay plain
   HTML. Nuxt UI is the alternative for internal dashboards.
6. **Fonts are the project's call.** The first draft treated Google Fonts as forbidden because
   Parkahead's CSP was strict at the time; the founder relaxed that the same day, so the skill
   asks rather than assumes.

## Verification

- `check_design_system.py --selftest` and `design_preview.py --selftest` pass; deliberately broken
  copies of each fail their selftest.
- Run against Parkahead's design system, the gate passes, `--tokens-css` produces the expected
  file, `wordmark.py` reproduces the committed wordmark byte for byte, and `render_previews.mjs`
  reports only the cover (overflowing by design).
- `templates/app-theme.css` was applied to a scratch shadcn-vue app with tokens generated from
  Parkahead's `tokens.json`: build clean, 14/14 keyboard, focus-ring, axe (light and dark) and
  375px checks pass.
- shellcheck, shfmt, `ci/lint-conventions.sh`, `ci/lint-steps.sh` pass; the workflow YAML parses.

## Not done

The skill's triggering (does its description fire on the right prompts?) is not measured yet; the
engineering-team skill has `tests/engineering-team-triggering/` for that, and the same approach
would work here.
