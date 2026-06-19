# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal Codespace provisioning kit. `setup.sh` turns a fresh GitHub Codespace into a fully-configured dev environment (Neovim, Zsh + Oh My Zsh + Powerlevel10k, CLI tools, Node/uv/Claude Code, editor formatters/linters). It mirrors the `shell_environment` Ansible role from [johnmathews/home-server](https://github.com/johnmathews/home-server), but as plain shell scripts instead of Ansible. There is no application code, build step, or test suite — the "product" is the shell scripts themselves.

## Two independent run paths

Both are self-contained and assume a Debian/Ubuntu (`apt`) base. They do not depend on each other; running both (one machine with dotfiles enabled *and* this repo's devcontainer) is harmless because everything is idempotent.

1. **Account-wide dotfiles** — `johnmathews/codespaces-setup` set as the GitHub Codespaces dotfiles repo. GitHub clones it into *every* Codespace and auto-runs `setup.sh` (it's on GitHub's recognized install-script list). Works across any repo.
2. **This repo's devcontainer** — `.devcontainer/devcontainer.json`'s `postCreateCommand` → `.devcontainer/post-create.sh` → `setup.sh`. Applies only to this repo (or repos that symlink `.devcontainer` here).

## Architecture

`setup.sh` is the orchestrator. It does **not** simply run every file in `scripts/` — it executes an explicit ordered `STEPS` array (`"NN-name.sh|Human description"`), so **adding a new script requires editing the `STEPS` array in `setup.sh`** or it won't run. The numeric filename prefixes are labels, not the source of execution order; the array order is what matters (e.g. `01` then `11` then `14` then `02`…).

- All foreground steps run sequentially via `run_step` with a progress bar; any non-zero exit aborts the whole run (`die`, naming the failing step).
- `13-nvim-plugins.sh` is launched **in the background** at the end (headless lazy.nvim plugin pre-load), logging separately to `~/.cache/nvim-setup.log`. It is not in `STEPS`.
- `setup.sh` ends with a verification summary that runs `--version` on every installed tool.
- All output is `tee`'d to `~/.cache/codespaces-setup.log` via `exec > >(tee -a ...) 2>&1`, so background runs can be followed with `tail -f`.

### Per-script conventions (follow these when editing/adding scripts)

- `#!/usr/bin/env bash` + `set -euo pipefail`, and a top comment explaining *why* (especially any proxy/version workarounds).
- A `log() { echo "[name] $*"; }` prefix function per script.
- **Idempotent**: check if already installed/up-to-date and early-`exit 0` (binaries) or skip-if-unchanged (configs deploy via `diff -q`, backing up to `.bak`). Re-running must be safe.
- **Pinned versions** for binary installs (e.g. `EZA_VERSION`, `NODE_VERSION`), kept in sync with the home-server `shell_environment` role — the comment usually cites the matching role variable.
- Install binaries from upstream tarballs/release assets into `/opt/<tool>-<version>` and symlink into `/usr/local/bin` (or extract into `/usr/local`); detect arch via `uname -m` (`aarch64`/`arm64` vs `x86_64`/`x64`).
- `configs/` holds the deployed dotfiles (`.zshrc`, `.zsh_aliases`, `.gitconfig_managed`); `11-dotfiles.sh` copies them to `$HOME`, wires `~/.gitconfig_managed` into `~/.gitconfig` via a marked `[include]` block, sets git identity, switches the default shell to zsh, and adds a bash→zsh handoff block to `~/.bashrc`. Edit the file in `configs/` then re-run `bash scripts/11-dotfiles.sh`.
- `configs/claude/` holds vendored personal Claude Code assets — the `engineering-team` skill (`skills/engineering-team/`) and the `/done` + `/merge-push` slash commands (`commands/*.md`). `17-claude-skills.sh` deploys them idempotently into `~/.claude/skills/` and `~/.claude/commands/` (same diff/`.bak` convention as `11-dotfiles.sh`, with `diff -rq` for the skill dir). These are copies of the user's local `~/.claude` assets — when the originals change, re-vendor them into `configs/claude/` and re-run the script. To add another skill/command, drop it into `configs/claude/` and add a `deploy_skill`/`deploy_file` call in the script.

### TLS-intercepting-proxy handling (important, easy to break)

Corporate Codespaces sit behind a TLS-intercepting proxy. Tools that bundle their own CA store fail with `SELF_SIGNED_CERT_IN_CHAIN` unless pointed at the system bundle. Two places cooperate:

- `configs/.zshrc` exports `NODE_EXTRA_CA_CERTS`, `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE` → `/etc/ssl/certs/ca-certificates.crt` (so Mason's npm/pip installs work).
- `02-nodejs.sh` deliberately installs Node from the official nodejs.org tarball into `/usr/local` (not NodeSource/apt), because NodeSource silently no-ops behind the proxy and Ubuntu's node is too old / ships without npm.

Don't "simplify" these back to apt/NodeSource or remove the CA exports.

### GitHub CLI auth (spans three files)

Codespaces injects a `GITHUB_TOKEN` scoped to the originating repo; `gh` prefers
it over stored credentials, so `gh auth login` can't save your own token and you
can't push to other repos. Three files cooperate to fix this:

- `16-gh.sh` installs `gh` (release tarball → `/opt` → `/usr/local/bin`, same as
  the other binaries, deliberately *not* the cli.github.com apt repo).
- `configs/.zshrc` runs `unset GITHUB_TOKEN GH_TOKEN` for interactive shells so
  `gh auth login` works and stored creds take over.
- `configs/.gitconfig_managed` registers `!gh auth git-credential` as the
  `github.com` credential helper (with a leading empty `helper =` to reset any
  inherited helper) so `git push` reuses the `gh` login.

The user still runs `gh auth login` once per Codespace — that step can't be
automated in `setup.sh`.

## Commands

```bash
bash setup.sh                      # full run (idempotent)
bash scripts/NN-<name>.sh          # run a single step in isolation
bash scripts/11-dotfiles.sh        # re-deploy shell/git config after editing configs/
tail -f ~/.cache/codespaces-setup.log   # follow a run
tail -f ~/.cache/nvim-setup.log          # follow the background Neovim plugin pre-load

# Lint (also runs in CI; see docs/development.md)
shellcheck setup.sh scripts/*.sh ci/*.sh   # shell correctness
shfmt -i 2 -ci -kp -d setup.sh scripts ci  # formatting (‑w to auto-fix)
bash ci/lint-steps.sh                       # every scripts/NN-*.sh is wired into STEPS
```

There are no unit tests (the "product" is the scripts), but CI
(`.github/workflows/ci.yml`) runs `shellcheck`, `shfmt`, and `ci/lint-steps.sh`
on every push to `main` and PR. The formatting convention is `shfmt -i 2 -ci -kp`
(the `-kp` keeps the hand-aligned columns in `setup.sh`/`11-dotfiles.sh`); the
shfmt version is pinned in the workflow. See [docs/development.md](docs/development.md).

## Related repositories

- [johnmathews/neovim](https://github.com/johnmathews/neovim) — Neovim config, cloned to `~/.config/nvim` by `04-neovim-config.sh`.
- [johnmathews/home-server](https://github.com/johnmathews/home-server) — the `shell_environment` Ansible role this repo mirrors; keep pinned versions in sync with it.
