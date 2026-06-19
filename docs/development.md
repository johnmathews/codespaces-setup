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

## Run locally

```bash
# Correctness
shellcheck setup.sh scripts/*.sh ci/*.sh

# Formatting (‑d = show diff and fail if anything is unformatted; ‑w = rewrite in place)
shfmt -i 2 -ci -kp -d setup.sh scripts ci
shfmt -i 2 -ci -kp -w setup.sh scripts ci    # auto-fix

# Step-array wiring
bash ci/lint-steps.sh
```

Install the tools on macOS with `brew install shfmt shellcheck` (the Codespace
itself already installs `shfmt` via `scripts/15-dev-tools.sh`).

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
