# 2026-06-19 — Add CI linting + README manual-steps runbook

## What changed

- **README runbook.** Added a "Manual steps (do these yourself)" section at the
  very top of `README.md`, before everything else. It covers the two things
  `setup.sh` cannot automate, for **any** repo's Codespace:
  1. Setting the VS Code terminal font (`MesloLGS NF`) — a client-side / UI step
     that the in-container font install (`scripts/14-fonts.sh`) does not cover
     for browser Codespaces. Previously this was only documented inside a code
     comment in `14-fonts.sh`, so a reader following the README would never learn
     their terminal needs a client-side font.
  2. `gh auth login` — the once-per-Codespace GitHub auth step (the injected
     `GITHUB_TOKEN` is scoped to the originating repo).
- **CI linting.** First CI in the repo (`.github/workflows/ci.yml`), runs on push
  to `main` and PRs:
  - `shellcheck` over `setup.sh scripts/*.sh ci/*.sh`.
  - `shfmt -i 2 -ci -kp -d` (pinned `mvdan/shfmt:v3.13.1`).
  - `ci/lint-steps.sh` — new linter that cross-checks `scripts/NN-*.sh` against
    the `STEPS` array in `setup.sh`, so an unwired script (which would silently
    never run) fails the build.
- **shfmt pass.** Normalized `setup.sh`, `scripts/08-atuin.sh`,
  `scripts/11-dotfiles.sh` to the convention. Only 3 files were dirty.
- **Docs.** Added `docs/development.md` (CI checks, local commands, formatting
  convention, how to add a step) and updated `CLAUDE.md` (the old "no
  linter/test/CI configured" note is no longer true).

## Decisions / rationale

- **Why no unit tests?** The "product" is provisioning scripts — mostly
  "download tarball, symlink, done". Per-script unit tests would mostly assert
  the script does what it says with mocked `curl`/`apt`, giving little real
  signal. The high-value checks are lint + formatting + step-wiring, plus (future
  option) a twice-through idempotency run in a container.
- **`-kp` (keep padding).** Plain `shfmt -i 2 -ci` collapses the hand-aligned
  columns in the `check_tool` summary and the `deploy` calls. `-kp` preserves
  that intentional alignment, so the formatting pass stayed minimal and didn't
  fight the author's layout.
- **shfmt pinned to v3.13.1** to match the local version, since formatting output
  can drift between shfmt releases. Bump the pin and re-run `shfmt -w` together.
- **`ci/` not `scripts/`.** CI tooling lives in `ci/` so it isn't mistaken for a
  provisioning step (and so `lint-steps.sh` doesn't flag itself as an orphan).

## Follow-ups (not done)

- Idempotency smoke test: run `setup.sh` twice in an Ubuntu container in CI and
  assert the second run is clean. Strongest "does it actually work" signal, but
  slower and heavier than the lint job — deferred.
