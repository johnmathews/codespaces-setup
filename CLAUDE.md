# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal Codespace provisioning kit. `setup.sh` turns a fresh GitHub Codespace into a fully-configured dev environment (Neovim, Zsh + Oh My Zsh + Powerlevel10k, CLI tools, Node/uv/Claude Code, editor formatters/linters). It mirrors the `shell_environment` Ansible role from [johnmathews/home-server](https://github.com/johnmathews/home-server), but as plain shell scripts instead of Ansible. There is no application code or build step, and the "product" is the shell scripts themselves — but that is not the same as "nothing to test". The **runner** (`setup.sh`) and the **shared helpers** (`scripts/lib.sh`) have a real behavioural suite in `tests/setup-resilience/`; the **installers are executed by nothing in CI**, so a defect in one stays latent until a Codespace is created. Naming that second clause is what makes the gap actionable — it is the reason a container smoke test is worth adding.

## Two independent run paths

Both are self-contained and assume a Debian/Ubuntu (`apt`) base. They do not depend on each other; running both (one machine with dotfiles enabled *and* this repo's devcontainer) is harmless because everything is idempotent.

1. **Account-wide dotfiles** — `johnmathews/codespaces-setup` set as the GitHub Codespaces dotfiles repo. GitHub clones it into *every* Codespace (at `/workspaces/.codespaces/.persistedshare/dotfiles`) and auto-runs `setup.sh` (it's on GitHub's recognized install-script list). Works across any repo.
2. **This repo's devcontainer** — `.devcontainer/devcontainer.json`'s `postCreateCommand` → `.devcontainer/post-create.sh` → `setup.sh`. Applies only to this repo (or repos that symlink `.devcontainer` here).

## Architecture

`setup.sh` is the orchestrator. It does **not** simply run every file in `scripts/` — it executes an explicit ordered `STEPS` array (`"NN-name.sh|Human description"`), so **adding a new script requires editing the `STEPS` array in `setup.sh`** or it won't run. The numeric filename prefixes are labels, not the source of execution order; the array order is what matters (e.g. `01` then `11` then `14` then `02`…).

- All foreground steps run sequentially via `run_step` with a progress bar. A failing step is **recorded and the run continues** (so an unattended dotfiles auto-run can't be stranded half-built by one flaky download); at the end `setup.sh` prints a FAILED summary naming each failed step, writes a durable signal file (`~/.cache/codespaces-setup.failed`, which `configs/.zshrc` surfaces on next shell start), and exits non-zero. The one exception is steps listed in the `REQUIRED` array (currently just `01-apt-packages.sh`, which installs the foundational tools every later step needs) — a required failure still aborts via `die`. The runner honours `SETUP_STEPS`/`SETUP_REQUIRED`/`SETUP_SCRIPTS_DIR` env hooks purely so `tests/setup-resilience/` can drive it over fake steps.
- Network downloads/installs go through the shared helpers in `scripts/lib.sh` (sourced by each step, EXEMPT from the STEPS lint since it is never run as a step), and `ci/lint-conventions.sh` enforces it:
  - `retry` — exponential backoff with jitter, **and a per-attempt wall clock**. The timeout is the load-bearing part: `retry` cannot act until a command *exits*, so a stalled transfer is not a failure it can see. Slow networks and flaky networks are different failure modes.
  - `net_curl` — curl with connect/transfer caps and `--speed-limit`/`--speed-time`, which is what converts a trickling download into an exit code `retry` can act on.
  - `fetch_verified` — download to a **staging** path and prove the artifact is complete before any caller touches it; removes the destination on every failure path.
  - `installed_version_is` / `installed_runs` — the “already installed?” guard. It must **run** the artifact, never stat it: `[[ -x ]]` cannot tell a working binary from a truncated download at the same path, so an existence check reports “installed” forever and the documented remedy (“re-run, it’s idempotent”) repairs nothing.
- `13-nvim-plugins.sh` is launched **in the background** at the end of a *full* run (headless lazy.nvim plugin pre-load), logging separately to `~/.cache/nvim-setup.log`. It is not in `STEPS` — but `--group nvim` appends it as a real foreground step, because an interactive update should show you the sync fail rather than bury it in a log.
- `setup.sh` ends with a verification summary that runs `--version` on every installed tool.
- All output is `tee`'d to `~/.cache/codespaces-setup.log` via `exec > >(tee -a ...) 2>&1`, so background runs can be followed with `tail -f`.

### `setup.sh` is also the update path — there is deliberately no `update.sh`

Re-running `bash setup.sh` is how you bring an already-provisioned Codespace up to date: every step is idempotent. Two pieces make that actually work, and both matter when editing this file.

- **Self-update.** Before anything else, `setup.sh` fetches and fast-forwards its own checkout (`REPO_DIR`) and re-execs **once**, guarded by `SETUP_SELF_UPDATE_DONE`. Without this, the dotfiles route re-applies the commit the Codespace was created with, forever. The re-exec is load-bearing, not cosmetic: bash reads scripts lazily, so continuing in-process after a fast-forward would execute a splice of the old and new file. Every branch of `self_update` ends in *continue with the code on disk* — not a git repo, no `origin`, shallow (`--unshallow`), dirty (**never** reset; unlike `04-neovim-config.sh`, this tree may hold the user's unpushed work), or unreachable network. An update is an improvement to the run, never a precondition for it. `SETUP_NO_SELF_UPDATE=1` opts out, and `.devcontainer/post-create.sh` sets it (that checkout is already current, and may be a PR branch). The resolved commit lands in the run record and in `setup-status`.
- **Selection, not a second list.** `--only <step>` and `--group <name>` *filter the existing `STEPS` array in place*, so ordering, `STEP_DEPS`, timeouts, the retry pass, logging and the summary all keep working untouched. `STEP_GROUPS` maps a name to **members of `STEPS`** (`claude`, `nvim`, `shell`); `ci/lint-steps.sh` asserts every member is a real `STEPS` entry. **Never replace this with a parallel list of commands** — that is the exact drift `ci/lint-steps.sh` exists to prevent, one level up: you would add `19-foo.sh`, wire it into `STEPS`, see lint pass green, and the update path would silently never run it. `bin/codespaces-update` is a thin wrapper that forwards a group name and must never learn a step name. Filtering preserves **`STEPS` order, not argv order**. Unknown args are an error (`exit 2`), not a silent full run — `setup.sh` used to ignore argv entirely.
- **A clean partial run does not clear `~/.cache/codespaces-setup.failed`.** This is the subtle correctness point. The signal answers "is this environment fully set up?", which only a full run can answer; letting `--group claude` clear it would mask a broken machine. Filtered runs also skip the whole-environment verification block entirely — otherwise `--group claude` would report "node missing" and that verdict would decide the exit code.
- **Watch out for `GROUPS`.** It is a bash special variable (the current user's group IDs) and assignments to it are *silently discarded*. The array is `STEP_GROUPS` for that reason. Naming it `GROUPS` produced a plausible-looking, completely non-functional `--group`.


### Per-script conventions (follow these when editing/adding scripts)

- `#!/usr/bin/env bash` + `set -euo pipefail`, and a top comment explaining *why* (especially any proxy/version workarounds).
- A `log() { echo "[name] $*"; }` prefix function per script.
- **Idempotent**: check if already installed/up-to-date and early-`exit 0` (binaries) or skip-if-unchanged (configs deploy via `diff -q`). Re-running must be safe.
- **Back up to `.bak` only when the target may hold edits that exist nowhere else** — `~/.zshrc` does, so `11-dotfiles.sh` backs it up. Do **not** back up a target that is vendored in this repo: git already holds every previous version, so the `.bak` protects nothing. And **never** write a `.bak` into a directory that another tool scans — `~/.claude/skills/` registers every subdirectory containing a `SKILL.md`, so a backup there loads as a *duplicate skill* rather than sitting inertly beside the original (this happened; see `17-claude-skills.sh`). A backup of a scanned directory is not a backup, it is a fork.
- **Pinned versions** for binary installs (e.g. `EZA_VERSION`, `NODE_VERSION`), kept in sync with the home-server `shell_environment` role — the comment usually cites the matching role variable.
- Install binaries from upstream tarballs/release assets into `/opt/<tool>-<version>` and symlink into `/usr/local/bin` (or extract into `/usr/local`); detect arch via `uname -m` (`aarch64`/`arm64` vs `x86_64`/`x64`).
- `configs/` holds the deployed dotfiles (`.zshrc`, `.zsh_aliases`, `.gitconfig_managed`); `11-dotfiles.sh` copies them to `$HOME`, wires `~/.gitconfig_managed` into `~/.gitconfig` via a marked `[include]` block, sets git identity, switches the default shell to zsh, and adds a bash→zsh handoff block to `~/.bashrc`. Edit the file in `configs/` then re-run `bash scripts/11-dotfiles.sh` (or, on a Codespace that needs the repo pulled first, `bash setup.sh --group shell`).
- `configs/claude/` holds vendored personal Claude Code assets — the `engineering-team` skill (`skills/engineering-team/`), the `design-system` skill (`skills/design-system/`: a project's brand and design system, from the brand conversation to a claude.ai Design System artifact and app code in whatever styling the app already uses (Vue is the worked path; step 5 reads `package.json` and maps other frameworks in `references/other-frameworks.md`) (Tailwind v4 or plain CSS); its `scripts/check_design_system.py` and `scripts/design_preview.py` are stdlib-only and meant to be copied into each project that uses them, and all four of its scripts have a `--selftest` that CI runs; every script there declares a `SCRIPT_VERSION`, the two copied ones compare theirs with the installed skill's, so **a change to any of them must bump it** — `ci/lint-skill-versions.sh` fails it otherwise), the `/done`, `/merge-push`, `/prompt` and `/sync-skills` slash commands (`commands/*.md`), and the script `/sync-skills` runs (`scripts/sync-skills.sh`, deployed to `~/.claude/scripts/` and kept executable). `17-claude-skills.sh` deploys them idempotently into `~/.claude/skills/` and `~/.claude/commands/` (same skip-if-unchanged `diff` convention as `11-dotfiles.sh`, with `diff -rq` for the skill dir — but **deliberately no `.bak`**: `~/.claude/skills/` is scanned, so a backup registers as a duplicate skill, and these assets are in git anyway. The script reaps any `.bak` left by older versions of itself). **Where they are edited:** usually in `~/.claude` on the main machine, and `/sync-skills` (`configs/claude/scripts/sync-skills.sh`, deployed to `~/.claude/scripts/`) keeps the two copies equal, on that machine or in a Codespace. It finds the checkout at `~/projects/codespaces`, `/workspaces/codespaces-setup` or the dotfiles clone, or wherever `CODESPACES_SETUP_DIR` says. It syncs its own two files like any other asset, and restarts once if it pulls a newer copy of itself, because bash reads a running script lazily (pulled files are renamed into place, never written over, for the same reason). From a Codespace, pushing needs a `gh` login that can write to this repo: a Codespace of this repo has one, but one created for another repo may not. It **pulls before it pushes**: each file is compared three ways against the base, the commit of this repo that machine last synced with (kept as `refs/sync-skills/base` in its checkout). A file only that machine changed is pushed; a file only this repo changed is pulled into `~/.claude` first, with a backup; a file both changed is merged, and an overlapping change stops the sync with nothing written. So a change merged here directly (from a Codespace, say) is never overwritten, and a deletion is pushed only when the base shows the file existed. When there is something to push it works in a fresh worktree from `origin/main`, runs the skill checks below, opens a PR, waits for CI, squash-merges it and records the new base. Every Codespace installs from this copy. One consequence: on the main machine, don't run `17-claude-skills.sh` or `deploy-engineering-team-skill.sh` while `~/.claude` holds unsynced edits, because they overwrite them; run `/sync-skills` instead, which pulls the repo's changes without losing local ones. The sync refuses to vendor an asset that `17-claude-skills.sh` doesn't deploy, so adding one means a `deploy_skill`/`deploy_file` line here and an `ASSETS` entry there. For the common inner-loop case of just re-pushing the `engineering-team` skill after an edit, the repo-root `deploy-engineering-team-skill.sh` deploys *only* that skill and overwrites the local copy unconditionally (no commands, no diff-skip); `17-claude-skills.sh` remains the setup-path deployer for the skill **and** the commands. To add another skill/command, drop it into `configs/claude/` and add a `deploy_skill`/`deploy_file` call in the script. The skill is not markdown-only: it also ships `templates/evaluation-report.md` (the single definition of an evaluation report's structure) and **three** structural gates — `scripts/check_report.py` + `scripts/fixtures/` (the evaluation report, run before announcing it), `scripts/check_run.py` + `scripts/fixtures_run/` (the run's `run.yaml` state file — schema + reconciliation against artifacts), and `scripts/check_plan.py` + `scripts/fixtures_plan/` (the improvement plan — frontmatter index + cross-check against `run.yaml`). `deploy_skill` uses `cp -a`, so subdirectories and modes come along; nothing extra is needed to ship them. (Two LLM-in-the-loop tests are deliberately **not** here — the router *probe* test and the *triggering eval* (`tests/engineering-team-triggering/`, which measures whether the skill's `description:` fires on the right prompts). Both live in the repo's `tests/`, outside the skill, because their value is skill-editing, not skill-use, so they must not deploy to `~/.claude`. The triggering test's deterministic parsers do have a headless `run.py --selftest` that CI runs; its `claude -p` measurement is on-demand. The `design-system` skill has the same kind of triggering eval in `tests/design-system-triggering/`, a copy of that runner with a different route roster.)

### Claude Code state persists on `/workspaces` (spans two files)

A Codespace rebuild wipes `$HOME` and keeps only `/workspaces`, which used to take every Claude Code session transcript with it. `19-claude-config-dir.sh` makes `/workspaces/.claude-config` (mode 700) the real config dir and symlinks `~/.claude` and `~/.claude.json` to it; `configs/.zshrc` exports `CLAUDE_CONFIG_DIR` by following that link, so the path is stated once. **Both halves are needed**: the env var only reaches interactive zsh, and without the links anything launched otherwise (the VS Code extension, `17-claude-skills.sh`, setup's verification) writes a second config that the next rebuild discards. The step runs **before** `12-claude-code.sh` and `17-claude-skills.sh`, and on a merge the persisted copy wins. Everything else keeps writing to `~/.claude` — do not "update" scripts to `$CLAUDE_CONFIG_DIR`; the link is what makes the plain path correct everywhere. Tested headlessly by `tests/claude-config-dir/run.sh`.

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
bash setup.sh                      # pull this checkout, then run everything (idempotent)
bash setup.sh --list               # the steps and the groups that can be selected
bash setup.sh --group claude       # update path: just configs/claude/ -> ~/.claude
bash setup.sh --group nvim         # Neovim config + tools + a FOREGROUND plugin sync
bash setup.sh --group shell        # .zshrc, aliases, gitconfig, Oh My Zsh/p10k
bash setup.sh --only 11-dotfiles.sh  # one named step, through the runner
SETUP_NO_SELF_UPDATE=1 bash setup.sh  # ...without fetching this checkout first
codespaces-update claude           # thin wrapper for the above, from anywhere
bash scripts/NN-<name>.sh          # run a single step in isolation (no runner)
bash scripts/11-dotfiles.sh        # re-deploy shell/git config after editing configs/
bash deploy-engineering-team-skill.sh   # overwrite ~/.claude engineering-team skill with this repo's copy (standalone; only the skill)
tail -f ~/.cache/codespaces-setup.log   # follow a run
tail -f ~/.cache/nvim-setup.log          # follow the background Neovim plugin pre-load

# Lint (also runs in CI; see docs/development.md)
shellcheck setup.sh deploy-engineering-team-skill.sh scripts/*.sh ci/*.sh bin/* \
  .devcontainer/post-create.sh tests/setup-resilience/run.sh tests/claude-config-dir/run.sh \
  configs/claude/scripts/sync-skills.sh tests/sync-skills/run.sh  # shell correctness
shfmt -i 2 -ci -kp -d setup.sh deploy-engineering-team-skill.sh scripts ci bin .devcontainer configs/claude/scripts tests/sync-skills  # formatting (‑w to auto-fix)
bash ci/lint-steps.sh                       # every scripts/NN-*.sh is wired into STEPS,
                                            # and every --group member is a real STEPS entry
python3 configs/claude/skills/engineering-team/scripts/check_report.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_run.py --selftest
python3 configs/claude/skills/engineering-team/scripts/check_plan.py --selftest
python3 tests/engineering-team-triggering/run.py --selftest
python3 tests/design-system-triggering/run.py --selftest
python3 configs/claude/skills/design-system/scripts/check_design_system.py --selftest
python3 configs/claude/skills/design-system/scripts/design_preview.py --selftest
node configs/claude/skills/design-system/scripts/render_previews.mjs --selftest
uv run --with fonttools python3 configs/claude/skills/design-system/scripts/wordmark.py --selftest
bash ci/lint-skill-versions.sh --selftest && bash ci/lint-skill-versions.sh --base origin/main  # changed scripts bumped SCRIPT_VERSION
python3 tests/engineering-team-drift/drift_scan.py --selftest && python3 tests/engineering-team-drift/drift_scan.py
python3 tests/engineering-team-command-links/check_command_links.py --selftest && python3 tests/engineering-team-command-links/check_command_links.py
bash tests/claude-config-dir/run.sh         # ~/.claude -> /workspaces/.claude-config merge + links
bash tests/sync-skills/run.sh               # /sync-skills against a bare clone: three-way plan, conflict,
                                            # pull, push up to the PR, restart on a newer copy of itself
bash tests/setup-resilience/run.sh          # setup.sh runs every step (records failures, keeps going),
                                            # the retry helper, --only/--group selection, the self-update
```

The `engineering-team` skill ships **three** structural gates over its own
artifacts — `check_report.py` (the evaluation report), `check_run.py` (the run's
`run.yaml` state file — schema + reconciliation against artifacts), and
`check_plan.py` (the improvement plan — a valid frontmatter index whose `W<n>`
unit IDs are cross-checked against `run.yaml`). The triggering-eval and drift-scan commands above belong to
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
