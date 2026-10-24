# Hardening the design-system skill

Follow-up to `261024-design-system-skill.md`, from a review of the skill the same
day. Four changes in `configs/claude/skills/design-system/` plus CI, and the docs to match.

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

## What the wrap-up review caught

An independent code review found a real bug in this branch's own work. Confirmed by
running the script through a symlink: `render_previews.mjs` guarded its entry point
with `resolve(process.argv[1]) === fileURLToPath(import.meta.url)`, and Node resolves
the module URL but not argv. So through a symlinked path every mode did nothing and
exited 0, including `--selftest`. In a Codespace, `~/.claude` is such a symlink. The
guard is gone, since nothing imports the module.

The same review led to four more changes:

- In CI, a PR base that can't be fetched now fails the version step instead of
  quietly skipping the bump rule.
- `copy_note` can no longer raise.
- `copy_note` looks the skill's copy up by a fixed `SCRIPT_NAME`, so a renamed copy
  still compares.
- The duplicated compare code sits between `# >>> copy-version` markers, and the lint
  keeps the two copies byte-identical.

A docs audit fixed wording that overstated or misdescribed the change. Examples: "every
script prints a note" (only the two copied ones do); `DARK` described as a selector
string when it is an object; Tailwind "following" `.dark` (it does so only through
`app-theme.css`'s `@custom-variant`).

## What is deliberately not done

- **The description is unchanged.** React prompts still route to the skill, which is
  right for steps 1–4.
- **No generic `deploy-skill.sh`.** It was offered and not chosen.
  `scripts/17-claude-skills.sh` already deploys both skills.
- **A rename passes the version lint** as a new file, at any version. This is noted
  in the script, not prevented.
- **Pre-existing doc gaps the audit found are left alone:** `check_board.py` is
  missing from the "three gates" wording, and several CI checks are missing from
  `docs/development.md`.
- **Pre-existing macOS-only test failures are left alone:** 3 in
  `tests/setup-resilience`, 1 in `tests/claude-config-dir`. The same failures show
  on `main`; CI runs on Ubuntu.
- **`sync-skills.sh` was not run.** The local `~/.claude` copy of the skill is the
  pre-branch version until this merges and is deployed.

## Worth knowing next time

- In a worktree-isolated session, the harness refuses writes to the main checkout,
  and that includes the engineering-team `$RUN_DIR`. Run state had to be
  reconciled after leaving the worktree.
- `~/.claude/scripts/sync-skills.sh` is not vendored in this repo. It was updated
  in place to mirror `skills/design-system` too.
