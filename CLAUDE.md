# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal Codespace provisioning kit. `setup.sh` turns a fresh GitHub Codespace into a fully-configured dev environment (Neovim, Zsh + Oh My Zsh + Powerlevel10k, CLI tools, Node/uv/Claude Code, editor formatters/linters). It mirrors the `shell_environment` Ansible role from [johnmathews/home-server](https://github.com/johnmathews/home-server), but as plain shell scripts instead of Ansible. There is no application code, build step, or test suite — the "product" is the shell scripts themselves.

## Two independent run paths

Both are self-contained and assume a Debian/Ubuntu (`apt`) base. They do not depend on each other; running both (one machine with dotfiles enabled *and* this repo's devcontainer) is harmless because everything is idempotent.

1. **Account-wide dotfiles** — `johnmathews/codespaces-setup` set as the GitHub Codespaces dotfiles repo. GitHub clones it into *every* Codespace (at `/workspaces/.codespaces/.persistedshare/dotfiles`) and auto-runs `setup.sh` (it's on GitHub's recognized install-script list). Works across any repo.
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
- **Idempotent**: check if already installed/up-to-date and early-`exit 0` (binaries) or skip-if-unchanged (configs deploy via `diff -q`). Re-running must be safe.
- **Back up to `.bak` only when the target may hold edits that exist nowhere else** — `~/.zshrc` does, so `11-dotfiles.sh` backs it up. Do **not** back up a target that is vendored in this repo: git already holds every previous version, so the `.bak` protects nothing. And **never** write a `.bak` into a directory that another tool scans — `~/.claude/skills/` registers every subdirectory containing a `SKILL.md`, so a backup there loads as a *duplicate skill* rather than sitting inertly beside the original (this happened; see `17-claude-skills.sh`). A backup of a scanned directory is not a backup, it is a fork.
- **Pinned versions** for binary installs (e.g. `EZA_VERSION`, `NODE_VERSION`), kept in sync with the home-server `shell_environment` role — the comment usually cites the matching role variable.
- Install binaries from upstream tarballs/release assets into `/opt/<tool>-<version>` and symlink into `/usr/local/bin` (or extract into `/usr/local`); detect arch via `uname -m` (`aarch64`/`arm64` vs `x86_64`/`x64`).
- `configs/` holds the deployed dotfiles (`.zshrc`, `.zsh_aliases`, `.gitconfig_managed`); `11-dotfiles.sh` copies them to `$HOME`, wires `~/.gitconfig_managed` into `~/.gitconfig` via a marked `[include]` block, sets git identity, switches the default shell to zsh, and adds a bash→zsh handoff block to `~/.bashrc`. Edit the file in `configs/` then re-run `bash scripts/11-dotfiles.sh`.
- `configs/claude/` holds vendored personal Claude Code assets — the `engineering-team` skill (`skills/engineering-team/`) and the `/done`, `/merge-push`, and `/prompt` slash commands (`commands/*.md`). `17-claude-skills.sh` deploys them idempotently into `~/.claude/skills/` and `~/.claude/commands/` (same skip-if-unchanged `diff` convention as `11-dotfiles.sh`, with `diff -rq` for the skill dir — but **deliberately no `.bak`**: `~/.claude/skills/` is scanned, so a backup registers as a duplicate skill, and these assets are in git anyway. The script reaps any `.bak` left by older versions of itself). This repo is the **source of truth** for these assets: edit them in `configs/claude/` and re-run the script to deploy — do not hand-edit `~/.claude` and try to vendor the change back, because the next deploy overwrites it. For the common inner-loop case of just re-pushing the `engineering-team` skill after an edit, the repo-root `deploy-engineering-team-skill.sh` deploys *only* that skill and overwrites the local copy unconditionally (no commands, no diff-skip); `17-claude-skills.sh` remains the setup-path deployer for the skill **and** the commands. To add another skill/command, drop it into `configs/claude/` and add a `deploy_skill`/`deploy_file` call in the script. The skill is not markdown-only: it also ships `templates/evaluation-report.md` (the single definition of an evaluation report's structure) and **three** structural gates — `scripts/check_report.py` + `scripts/fixtures/` (the evaluation report, run before announcing it), `scripts/check_run.py` + `scripts/fixtures_run/` (the run's `run.yaml` state file — schema + reconciliation against artifacts), and `scripts/check_plan.py` + `scripts/fixtures_plan/` (the improvement plan — frontmatter index + cross-check against `run.yaml`). `deploy_skill` uses `cp -a`, so subdirectories and modes come along; nothing extra is needed to ship them. (Two LLM-in-the-loop tests are deliberately **not** here — the router *probe* test and the *triggering eval* (`tests/engineering-team-triggering/`, which measures whether the skill's `description:` fires on the right prompts). Both live in the repo's `tests/`, outside the skill, because their value is skill-editing, not skill-use, so they must not deploy to `~/.claude`. The triggering test's deterministic parsers do have a headless `run.py --selftest` that CI runs; its `claude -p` measurement is on-demand.)

### TLS-intercepting-proxy handling (important, easy to break)

Corporate Codespaces sit behind a TLS-intercepting proxy. Tools that bundle their own CA store fail with `SELF_SIGNED_CERT_IN_CHAIN` unless pointed at the system bundle. Two places cooperate:

- `configs/.zshrc` exports `NODE_EXTRA_CA_CERTS`, `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE` → `/etc/ssl/certs/ca-certificates.crt` (so Mason's npm/pip installs work).
- `02-nodejs.sh` deliberately installs Node from the official nodejs.org tarball into `/usr/local` (not NodeSource/apt), because NodeSource silently no-ops behind the proxy and Ubuntu's node is too old / ships without npm.
- `18-azure-cli.sh` installs the Azure CLI (`az`) via `uv` (not the Microsoft apt repo) for the same reason: `uv` honours `SSL_CERT_FILE`/the system CA bundle, so the install succeeds behind the proxy where the apt repo path is fragile.

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
bash deploy-engineering-team-skill.sh   # overwrite ~/.claude engineering-team skill with this repo's copy (standalone; only the skill)
tail -f ~/.cache/codespaces-setup.log   # follow a run
tail -f ~/.cache/nvim-setup.log          # follow the background Neovim plugin pre-load

# Lint (also runs in CI; see docs/development.md)
shellcheck setup.sh deploy-engineering-team-skill.sh scripts/*.sh ci/*.sh   # shell correctness
shfmt -i 2 -ci -kp -d setup.sh deploy-engineering-team-skill.sh scripts ci  # formatting (‑w to auto-fix)
bash ci/lint-steps.sh                       # every scripts/NN-*.sh is wired into STEPS
python3 configs/claude/skills/engineering-team/scripts/check_report.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_run.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_plan.py --selftest
python3 tests/engineering-team-triggering/run.py --selftest
python3 tests/engineering-team-drift/drift_scan.py --selftest && python3 tests/engineering-team-drift/drift_scan.py
python3 tests/engineering-team-command-links/check_command_links.py --selftest && python3 tests/engineering-team-command-links/check_command_links.py
```

The `engineering-team` skill ships **three** structural gates over its own
artifacts — `check_report.py` (the evaluation report), `check_run.py` (the run's
`run.yaml` state file — schema + reconciliation against artifacts), and
`check_plan.py` (the improvement plan — a valid frontmatter index whose `W<n>`
unit IDs are cross-checked against `run.yaml`). The last two commands belong to
repo-level tests that are **not** shipped in the skill: the triggering eval
(`tests/engineering-team-triggering/run.py`), whose LLM-in-the-loop routing
measurement is on-demand but whose deterministic parsers are headless and
CI-checked; and the **rule-ownership drift-scan**
(`tests/engineering-team-drift/drift_scan.py`), which is fully headless and so
runs its real scan in CI — it fails if the skill's rule-ownership index lies about
where a rule lives, or a duplicated worktree-idiom command drops
`--path-format=absolute` (its worktree-idiom check spans both the skill docs **and**
the vendored slash commands, which carry their own copies of the idiom). A sibling
headless check, the **command→skill
link-check** (`tests/engineering-team-command-links/check_command_links.py`), also
runs its real check in CI: it fails if a `/done` or `/merge-push` cross-reference
into the skill tree (e.g. `references/worktree.md`) no longer resolves — the
commands ship on a separate deploy track, so the drift-scan's skill-internal scope
doesn't cover their inbound links. `shellcheck`/`shfmt` do not see any of this Python (they
are scoped to the repo-root shell scripts — `setup.sh`,
`deploy-engineering-team-skill.sh`, `scripts/`, `ci/` — not the skill tree), so
their fixtures/selftests are their only test.

There are no unit tests (the "product" is the scripts), but CI
(`.github/workflows/ci.yml`) runs `shellcheck`, `shfmt`, and `ci/lint-steps.sh`
on every push to `main` and PR. The formatting convention is `shfmt -i 2 -ci -kp`
(the `-kp` keeps the hand-aligned columns in `setup.sh`/`11-dotfiles.sh`); the
shfmt version is pinned in the workflow. See [docs/development.md](docs/development.md).

## Related repositories

- [johnmathews/neovim](https://github.com/johnmathews/neovim) — Neovim config, cloned to `~/.config/nvim` by `04-neovim-config.sh`.
- [johnmathews/home-server](https://github.com/johnmathews/home-server) — the `shell_environment` Ansible role this repo mirrors; keep pinned versions in sync with it.
