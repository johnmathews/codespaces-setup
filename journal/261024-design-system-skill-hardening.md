# Hardening the design-system skill

Follow-up to `261024-design-system-skill.md`, from a review of the skill the same
day. Five changes, all in `configs/claude/skills/design-system/` plus CI.

## Dark mode could pass without being tested

`design_preview.py --tokens-css` put the dark theme on `[data-theme="dark"]`;
`templates/a11y.spec.ts` flipped a `.dark` class. A project copying both with their
defaults ran every dark axe audit against the light theme. That was observed, not
inferred: in a scratch Playwright harness the old spec's two dark audits went green
against a mismatched `tokens.css`.

Decision: `.dark` is the default (Tailwind is the likely case, and shadcn-vue
follows it). The spec has a single `DARK` setting and a first test that fails when
switching themes leaves `--canvas` unchanged. It reads the custom property rather
than a painted background, because an app may paint its canvas on `<html>` or on
`<body>`.

## Vue was assumed, not detected

Step 5 now reads `package.json` before giving component advice. Vue goes to
`code.md`, anything else to the new `references/other-frameworks.md`. That file
separates what carries over unchanged (tokens, `app-theme.css`'s shadcn variables,
the a11y spec, the gate) from a mapping of the component layer, labelled as
untested. The `description:` was left alone on purpose: changing it would invalidate
the triggering baseline (`c6da1846c4b8`), and React projects should still get
steps 1–4.

## Copies of the scripts now know their version

Every script declares `SCRIPT_VERSION`. The two that projects copy compare it with
the installed skill's copy on each run and print a `note:` on stderr: skill newer,
copy newer, or same number with different bytes. It never fails a build, because CI
has no skill to compare against. `ci/lint-skill-versions.sh` keeps the number
honest: one version line per script, and a script changed since the PR base must
have a higher one. A plain integer was chosen over a date, because two changes on
the same day must still order.

## One token compiler

`render_previews.mjs` had its own copy of `tokens_css()`. It now runs
`design_preview.py --tokens-css` (dark on `[data-theme]`, because that is how it
switches previews). Both it and `wordmark.py` gained `--selftest`. The wordmark test
builds a two-glyph font with fontTools, so the repo holds no font file. Each new
test was seen to fail against a planted bug: a flipped version comparison, and
tracking removed.

## Worth knowing next time

- In a worktree-isolated session, the harness refuses writes to the main checkout,
  and that includes the engineering-team `$RUN_DIR`. Run state had to be
  reconciled after leaving the worktree.
- `~/.claude/scripts/sync-skills.sh` is not vendored in this repo. It was updated
  in place to mirror `skills/design-system` too.
