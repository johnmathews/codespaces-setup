# engineering-team commands — cross-reference link-check

A mechanical check over the vendored slash commands
(`configs/claude/commands/*.md`) and the one thing they depend on that lives
*outside* them: files inside the `engineering-team` skill tree. It answers one
question: **do the commands' hardcoded pointers into the skill still resolve?**

`/done` and `/merge-push` reach into the skill by path — `/done` cites
`references/documentation-model.md` (the six-type doc model) and both cite
`references/worktree.md`. Those files ship on a different track from the commands
(the skill deploys to `~/.claude/skills/`, the commands to `~/.claude/commands/`),
so a rename or move inside the skill silently strands the pointer: the command
keeps telling every Codespace to read a file that no longer exists, and nothing
notices. This is the guard that notices.

## Why it isn't the drift-scan's job

The [rule-ownership drift-scan](../engineering-team-drift/) guards references
*within* the skill — its scope is the skill's own rule-ownership index. The
commands sit outside the skill boundary, so their inbound links fall outside that
scan. This check owns exactly that edge: `commands/*.md` → skill files.

## Why it's in CI (like the drift-scan, unlike the LLM suites)

The [router probes](../engineering-team-probes/) and the
[triggering eval](../engineering-team-triggering/) are LLM-in-the-loop, so they run
on-demand. This check is **pure text analysis — no model** — so it runs in headless
CI on every push and PR. It lives at repo level rather than inside the skill for the
same reason those do: its value is asset-*editing*, not asset-*use*, so it must not
deploy to `~/.claude`.

## What it checks

`check_command_links.py`, stdlib only. One **HARD** check (exits non-zero on any
failure): every skill-relative path a command names — any `<subdir>/….md` whose
first segment is a real top-level skill subdir, or a bare `SKILL.md`, with or
without the deployed `~/.claude/skills/engineering-team/` prefix — must resolve to a
real file under the skill tree. Anchoring on real subdir names keeps project docs
(`docs/roadmap.md`) out: those aren't skill cross-references.

## Running it

```bash
python3 tests/engineering-team-command-links/check_command_links.py            # check; exit 1 on any dangling ref
python3 tests/engineering-team-command-links/check_command_links.py --selftest # prove the check catches a seeded dangling ref
```

CI runs both (`--selftest` first, then the real check) — see `.github/workflows/ci.yml`.

## Maintaining it

- **Adding a new command** under `configs/claude/commands/` needs nothing here — the
  check globs the directory, so a new command's skill references are covered
  automatically.
- **Adding a new skill subdir** (beyond `references/`, `templates/`, `phases/`,
  `scripts/`) is picked up automatically too: the matchable prefixes are discovered
  from the skill directory, not hardcoded.
- **When you move or rename a file inside the skill** that a command points at,
  update the command's reference in the same change — this check reds until you do.
