# Development

This repo is a set of provisioning shell scripts — there is no application code,
build step, or unit-test suite. "Testing" here means **linting the scripts** and
checking that they stay wired together correctly. All of it runs in CI
(`.github/workflows/ci.yml`) on every push to `main` and every pull request, and
every check can be run locally with the same commands.

## Checks

| Check | Tool | What it catches |
|-------|------|-----------------|
| Shell correctness | `shellcheck` | Quoting bugs, `set -euo pipefail` interactions, unsafe expansions |
| Formatting | `shfmt` | Drift from the repo's formatting convention |
| Step wiring | `ci/lint-steps.sh` | A `scripts/NN-*.sh` that isn't wired into `setup.sh`'s `STEPS` array (so it would silently never run), or a `STEPS` entry pointing at a missing script |
| Skill gates | `check_report.py --selftest`, `check_run.py --selftest` | A malformed evaluation report, or a `run.yaml` whose schema is invalid or whose `phase:` disagrees with the artifacts on disk (the `engineering-team` skill's two shipped gates; their fixtures are the test) |
| Router probes | [`tests/engineering-team-probes/`](../tests/engineering-team-probes/) | An edit to the skill router (`SKILL.md`) that dropped a load-bearing invariant. **Manual, LLM-in-the-loop — not in CI** (see that dir's README for why and how to run it on router edits) |

## Run locally

```bash
# Correctness
shellcheck setup.sh deploy-engineering-team-skill.sh scripts/*.sh ci/*.sh

# Formatting (‑d = show diff and fail if anything is unformatted; ‑w = rewrite in place)
shfmt -i 2 -ci -kp -d setup.sh deploy-engineering-team-skill.sh scripts ci
shfmt -i 2 -ci -kp -w setup.sh deploy-engineering-team-skill.sh scripts ci    # auto-fix

# Step-array wiring
bash ci/lint-steps.sh

# engineering-team skill gates (also run in CI)
python3 configs/claude/skills/engineering-team/scripts/check_report.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_run.py --selftest
```

Install the tools on macOS with `brew install shfmt shellcheck` (the Codespace
itself already installs `shfmt` via `scripts/15-dev-tools.sh`).

The **router probe test** (`tests/engineering-team-probes/`) is the one check
that is not a command here: it is an on-demand, model-in-the-loop regression
test for the skill router, run when `SKILL.md` changes. Its README documents the
before/after procedure and why it cannot live in headless CI.

## Formatting convention

`shfmt -i 2 -ci -kp`:

- `-i 2` — two-space indentation (the existing style across all scripts).
- `-ci` — indent switch-case bodies.
- `-kp` — **keep padding**: preserve the hand-aligned columns in blocks like the
  `check_tool` verification summary in `setup.sh` and the `deploy` calls in
  `scripts/11-dotfiles.sh`. Without this, shfmt collapses that intentional
  alignment.

The shfmt version is pinned in `.github/workflows/ci.yml`
(`docker://mvdan/shfmt:v3.13.1`). If you bump it, re-run `shfmt -w` locally and
update that pin and this doc together, since formatting output can vary slightly
between versions.

## Adding a new provisioning step

`setup.sh` runs an explicit, ordered `STEPS` array — **not** every file in
`scripts/`. The numeric filename prefixes are labels, not execution order. So to
add a step:

1. Create `scripts/NN-name.sh` following the [per-script conventions](../CLAUDE.md)
   (shebang, `set -euo pipefail`, `log()` prefix, idempotency, pinned versions).
2. Add an entry to the `STEPS` array in `setup.sh` at the position you want it to
   run (e.g. `"NN-name.sh|Human-readable description"`).
3. Optionally add a verification line to the summary block at the bottom of
   `setup.sh`.

`ci/lint-steps.sh` fails the build if step 2 is skipped. A script that is
intentionally *not* in `STEPS` (like `13-nvim-plugins.sh`, which is launched in
the background) must be listed in that linter's `EXEMPT` array with a reason.

## Deploying the engineering-team skill on its own

This repo is the source of truth for the vendored `engineering-team` skill
(`configs/claude/skills/engineering-team/`). Two things deploy it into
`~/.claude/skills/`:

- **`scripts/17-claude-skills.sh`** — runs as part of `bash setup.sh`. Also
  deploys the `/done`, `/merge-push`, `/prompt` slash commands, and **skips**
  when the trees already match (`diff -rq`).
- **`bash deploy-engineering-team-skill.sh`** (repo root) — the standalone
  inner-loop tool. Deploys *only* the skill and overwrites the local copy
  **unconditionally**, so after editing the skill you get the repo's exact bytes
  on disk without diff-guessing. This is the one to reach for after a quick edit.

Both deliberately write **no `.bak`**: `~/.claude/skills/` is scanned, so a
backup directory registers as a *duplicate skill* rather than sitting inertly
beside the original. The lint scope (`shellcheck`/`shfmt`) above includes the
root deploy script so it stays correct.
