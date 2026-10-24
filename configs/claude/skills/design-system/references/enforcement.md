# Keeping a project on its design system

A skill says how; nothing makes a later change follow it. Enforcement lives in each repository, so
it works in CI and for any contributor, with or without this skill.

## In every project that has a design system

1. **The gate in CI.** Copy `scripts/check_design_system.py` into the repo and run it with
   `--complete` in CI and in the local check target (e.g. `make docs-check` or `npm run check`).
   Settings in `brand/design-system/checks.json`.
2. **Accessibility in the e2e suite.** `templates/a11y.spec.ts` for every public page.
3. **Generated tokens stay generated.** If the app compiles `tokens.css` from `tokens.json`, add a
   CI step that regenerates it and fails on a diff.
4. **No raw colours in components (optional but valuable).** A lint rule that rejects hex, `rgb()`
   and Tailwind palette classes (`bg-indigo-500`) in `src/` outside the generated tokens file
   keeps everything going through the roles. In a non-Tailwind app, also reject any `var(--…)`
   colour that isn't a role or a named accent, so old token names can't creep back. A simple CI grep works:
   `! grep -rEn '#[0-9a-fA-F]{3,8}\b|\b(bg|text|border)-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-[0-9]{2,3}\b' src --include=*.vue --include=*.ts`
5. **docs/brand.md** (from `templates/brand-doc.md`): where the system lives and how to change it.
6. **Project instructions.** One line in the project's CLAUDE.md: "UI work follows the design
   system in brand/design-system (see docs/brand.md); use the design-system skill."

## Across all projects

The skill itself is versioned in the codespaces-setup repo (`configs/claude/skills/design-system/`)
and deployed to `~/.claude/skills/` by `scripts/17-claude-skills.sh`. Edit it there, never in
`~/.claude`. A line in the global `~/.claude/CLAUDE.md` makes every session reach for it on UI work.
