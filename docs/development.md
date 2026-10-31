# Development

**Status:** active. **Last updated:** 2026-10-31. **Last verified:** 2026-10-31 (the sync-skills test, shellcheck and shfmt below executed; the design-system and skill-version commands 2026-10-24; the rest last executed 2026-09-01). **Covers:** `setup.sh`, `scripts/**`, `ci/**`, `.github/workflows/ci.yml`, `.github/workflows/smoke.yml`, `tests/setup-resilience/**`, `configs/claude/skills/design-system/scripts/**`, `configs/claude/scripts/**`, `tests/sync-skills/**`.


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
| Step wiring | `ci/lint-steps.sh` | A `scripts/NN-*.sh` that isn't wired into `setup.sh`'s `STEPS` array (so it would silently never run), a `STEPS` entry pointing at a missing script, or a `--group` whose members aren't real `STEPS` entries (what keeps the update path a *selector over* `STEPS` rather than a second list of it) |
| Skill gates | `check_report.py`, `check_run.py`, `check_plan.py`, `check_board.py`, `check_footprint.py` (each `--selftest`) | A malformed evaluation report; a `run.yaml` whose schema is invalid or whose `phase:` disagrees with the artifacts on disk; or an improvement plan with an invalid frontmatter index or unit IDs that don't match `run.yaml`, plus a warning for a plan unit with no acceptance criteria or dependencies field; a lane dashboard with overlapping footprints or a malformed contract register; or a footprint check that misreads a plan's **Files (footprint):** field or a branch's diff (the `engineering-team` skill's five shipped gates; their fixtures and selftests are the test) |
| design-system scripts | `check_design_system.py`, `design_preview.py`, `render_previews.mjs`, `wordmark.py` (each `--selftest`) | A regression in the scripts the `design-system` skill ships. Projects copy the gate and the preview builder, so a bug there spreads to every repo that uses them. `wordmark.py` runs through `uv` for fontTools and builds its own test font |
| Skill script versions | `ci/lint-skill-versions.sh` (`--selftest`, then `--base <ref>`) | A design-system script without exactly one `SCRIPT_VERSION`, one changed since the PR base without a bump, or the two copied scripts' `# >>> copy-version` blocks (the duplicated compare code) no longer byte-identical. Copies in projects compare that number with the installed skill's, so a missed bump leaves stale copies reporting themselves current |
| Triggering parsers | `tests/engineering-team-triggering/run.py --selftest`, `tests/design-system-triggering/run.py --selftest` | A silent bug in the triggering test's own deterministic parsers (verdict parsing, folded-description extraction) — the part that turns an LLM reply into a scored number, where a bug yields a confident wrong result. Headless; the LLM measurement itself is not in CI (the Router probes / Triggering eval rows below) |
| Rule-ownership drift-scan | [`tests/engineering-team-drift/`](../tests/engineering-team-drift/) | The skill's rule-ownership index lying about where a rule lives (a cited home heading that no longer exists), a home that lost its canonical statement, or a worktree-idiom copy that dropped `--path-format=absolute` — the idiom check spans the skill docs **and** the vendored slash commands. Fully headless — runs the real scan in CI |
| Command→skill link-check | [`tests/engineering-team-command-links/`](../tests/engineering-team-command-links/) | A `/done` or `/merge-push` cross-reference into the skill tree (e.g. `references/worktree.md`), or a prefixed `~/.claude/skills/engineering-team/…` path in another vendored skill (`/sitrep`), left dangling by a rename or move — the commands and other skills ship separately from the skill, so the drift-scan's skill-internal scope doesn't cover them. Fully headless — runs the real check in CI |
| Setup resilience | [`tests/setup-resilience/`](../tests/setup-resilience/) | A regression that lets one failing step abort the whole unattended run again: drives the real `setup.sh` over fake steps and asserts a non-required failure no longer stops the run, the summary names it, the exit code is non-zero, and a durable signal file is left behind — plus a unit test of the shared retry helper (`scripts/lib.sh`), and the update path: `--only`/`--group` selection, the refusal of a clean partial run to clear the failure signal, and the self-update (stale, current, dirty, shallow, non-git, offline). Fully headless — runs the real test in CI |
| Router probes | [`tests/engineering-team-probes/`](../tests/engineering-team-probes/) | An edit to the skill router (`SKILL.md`) that dropped a load-bearing invariant. **Manual, LLM-in-the-loop — not in CI** (see that dir's README for why and how to run it on router edits) |
| Triggering eval | [`tests/engineering-team-triggering/`](../tests/engineering-team-triggering/), [`tests/design-system-triggering/`](../tests/design-system-triggering/) | An edit to the skill's `description:` frontmatter that makes it mis-fire — trigger on prompts it shouldn't, or miss the ones it should. **Manual, LLM-in-the-loop — not in CI** (a frozen labelled prompt set scored by `claude -p`; see that dir's README). Its parsers *are* CI-checked — the row above. |

## Run locally

```bash
# Correctness
shellcheck setup.sh deploy-engineering-team-skill.sh scripts/*.sh ci/*.sh \
  bin/setup-status bin/codespaces-update .devcontainer/post-create.sh \
  tests/setup-resilience/run.sh tests/claude-config-dir/run.sh \
  configs/claude/scripts/sync-skills.sh tests/sync-skills/run.sh

# Formatting (‑d = show diff and fail if anything is unformatted; ‑w = rewrite in place)
shfmt -i 2 -ci -kp -d setup.sh deploy-engineering-team-skill.sh scripts ci bin .devcontainer configs/claude/scripts tests/sync-skills
shfmt -i 2 -ci -kp -w setup.sh deploy-engineering-team-skill.sh scripts ci bin .devcontainer configs/claude/scripts tests/sync-skills  # auto-fix

# Step-array wiring
bash ci/lint-steps.sh

# engineering-team skill gates (also run in CI)
python3 configs/claude/skills/engineering-team/scripts/check_report.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_run.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_plan.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_board.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_footprint.py --selftest
python3 configs/claude/skills/engineering-team/scripts/context_usage.py --selftest
python3 configs/claude/skills/engineering-team/scripts/model_usage.py --selftest

# design-system skill scripts (also run in CI)
python3 configs/claude/skills/design-system/scripts/check_design_system.py --selftest
python3 configs/claude/skills/design-system/scripts/design_preview.py --selftest
node configs/claude/skills/design-system/scripts/render_previews.mjs --selftest
uv run --with fonttools python3 configs/claude/skills/design-system/scripts/wordmark.py --selftest

# every changed design-system script bumped its SCRIPT_VERSION (also run in CI)
bash ci/lint-skill-versions.sh --selftest
bash ci/lint-skill-versions.sh --base origin/main

# triggering-eval parser selftests (also run in CI; the LLM measurement is not)
python3 tests/engineering-team-triggering/run.py --selftest
python3 tests/design-system-triggering/run.py --selftest

# rule-ownership drift-scan (also run in CI; fully headless)
python3 tests/engineering-team-drift/drift_scan.py --selftest
python3 tests/engineering-team-drift/drift_scan.py

# setup resilience + retry helper (also run in CI; fully headless)
bash tests/setup-resilience/run.sh

# /sync-skills against a bare clone standing in for GitHub (also run in CI; needs gh
# signed in, node and uv). Commit first: it tests the tree of this checkout's HEAD.
bash tests/sync-skills/run.sh
```

The resilience suite also exercises the Neovim bootstrap/sync wrappers over fake
upstream scripts: checkout working directory, user-local prefix/PATH, proxy trust,
retry recovery, timeout, and truthful failure status. The real container smoke
test (`bash ci/smoke-container.sh`, run by `.github/workflows/smoke.yml`) uses the devcontainer post-create entrypoint
on Ubuntu 24.04, waits for background sync to finish, checks the selected Neovim
pin and unchanged lockfile, then reruns config deployment, bootstrap and sync.
CI also exercises the account-wide dotfiles environment with `universal:6`.

### What gates and what only reports

`ci.yml` is the gate, and its result must not depend on a service outside
GitHub being up: `/sync-skills` merges on its run alone, so a red there has to
mean a defect in this repo. shellcheck and shfmt come from GitHub release
assets (shfmt was a Docker Hub image), the zsh install retries, and the one
PyPI package (fontTools, with brotli) is kept in GitHub's uv cache and retried
`--offline` from it when PyPI is down. On a cold cache with PyPI down, that
step can still fail.

`smoke.yml` runs on every PR, on `main`, weekly and by hand, and **never
gates**. Its job is to install real tools from apt mirrors, GitHub releases,
nodejs.org, npm and PyPI, so it can fail because one of them is down. Read a
red smoke run as "look at the log", not "the change is wrong". It used to be a
`continue-on-error` job inside `ci.yml` waiting to be promoted to required;
it won't be, because it can never stop depending on the internet.

Install the tools on macOS with `brew install shfmt shellcheck` (the Codespace
itself already installs `shfmt` via `scripts/15-dev-tools.sh`).

Some checks are not commands here — they are on-demand, model-in-the-loop
regression tests for the skills, run when the relevant part of a `SKILL.md`
changes, and none can live in headless CI:

- The **router probe test** (`tests/engineering-team-probes/`) — run when the
  router body changes, to confirm no load-bearing invariant was dropped.
- The **triggering eval** (`tests/engineering-team-triggering/`) — run when the
  `description:` frontmatter changes, to confirm the skill still fires on the
  right prompts and not the wrong ones. `python3 tests/engineering-team-triggering/run.py`,
  and for the `design-system` skill `python3 tests/design-system-triggering/run.py`.
  Its *deterministic parsers* have a headless `--selftest` that **does** run in CI
  (the table above); only the `claude -p` routing measurement is on-demand.

Each dir's README documents its before/after procedure and why the LLM-in-the-loop
part cannot live in headless CI.

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
intentionally *not* in `STEPS` (like `13-nvim-plugins.sh`, which a full run
launches in the background, and which `--group nvim` appends as a foreground
step) must be listed in that linter's `EXEMPT` array with a reason.

## Adding or changing a `--group`

`setup.sh --group <name>` is a **selector over the existing `STEPS` array**, never
a second list. `STEP_GROUPS` in `setup.sh` maps a name to members of `STEPS`, and
`ci/lint-steps.sh` fails the build if a group names anything that is not a real
`STEPS` entry. That check is the whole reason this design is safe: a standalone
`update.sh` with its own list of commands would silently stop including new steps
the moment one was added, which is precisely the defect `ci/lint-steps.sh` was
written to prevent one level down. `bin/codespaces-update` forwards a group name
and nothing else; if it ever grows a list of steps, the design has failed.

## Deploying the Claude skills

This repo is the source of truth for the vendored skills in
`configs/claude/skills/`: `engineering-team`, `design-system` and `sitrep`. Edit them here,
never in `~/.claude`, because the next deploy overwrites `~/.claude`.

| To update | Run | Deploys |
| --- | --- | --- |
| A Codespace | `codespaces-update claude` (or `bash setup.sh --group claude`) | Pulls this checkout first, then both skills and the slash commands |
| This machine, from a checkout | `bash scripts/17-claude-skills.sh` | Both skills and the slash commands; **skips** each one whose tree already matches (`diff -rq`) |
| Just `engineering-team`, after an edit | `bash deploy-engineering-team-skill.sh` | Only that skill, overwritten **unconditionally**, so the bytes on disk are exactly the repo's |
| Remote hosts (`agent`) | `/sync-skills`, i.e. `~/.claude/scripts/sync-skills.sh` | Mirrors this machine's `~/.claude` copies of both skills, so deploy locally first. That script lives in `~/.claude`, not in this repo |

None of them writes a `.bak`: `~/.claude/skills/` is scanned, so a backup
directory registers as a *duplicate skill* rather than sitting inertly beside the
original. The lint scope (`shellcheck`/`shfmt`) above includes the root deploy
script so it stays correct.

## Changing a design-system script

Projects copy `check_design_system.py` and `design_preview.py`, and each copy
compares its `SCRIPT_VERSION` with the installed skill's on every run, printing a
`note:` on stderr when they differ. So **every change to a file in
`configs/claude/skills/design-system/scripts/` bumps that file's
`SCRIPT_VERSION`**; `ci/lint-skill-versions.sh` fails the PR otherwise. A copy
that has fallen behind then says so the next time someone runs it locally.

The compare code itself lives in both copied scripts, between `# >>> copy-version`
and `# <<< copy-version`, because each copy has to stand alone in a project. Edit
one and make the other match: the same lint fails when the two blocks differ.
