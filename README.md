# codespaces-setup

Scripts to set up a new GitHub Codespace with a full, opinionated development environment.

## Manual steps (do these yourself)

`setup.sh` automates everything it can, but two things **cannot** be scripted and must be done by hand in **every**
Codespace (any repo, not just this one). Do these and the environment is complete.

If you need to run the script manually:

```bash
git clone https://github.com/johnmathews/codespaces-setup.git ~/codespaces-setup
cd ~/codespaces-setup
bash setup.sh
exec zsh
```

The script is idempotent – safe to run multiple times.

### 1. Set the terminal font (UI step, browser Codespaces)

The container installs **MesloLGS NF** (the Nerd Font that gives Powerlevel10k its icons/glyphs), but a **browser-based**
Codespace renders the VS Code terminal on _your local machine_, so the in-container font does nothing there. You must
install the font locally and point VS Code at it:

1. **Install the font on your local machine** — download all four MesloLGS NF variants and install them:
   <https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k>
2. **Tell VS Code to use it** — open the Settings UI (`Cmd/Ctrl+,`), search for **`terminal.integrated.fontFamily`**, and
   set it to:

   ```
   "MesloLGS NF"
   ```

   (Or add `"terminal.integrated.fontFamily": "MesloLGS NF"` to `settings.json`.)

This is a per-machine VS Code setting, so you only do it **once per local machine**, not once per Codespace. Without it,
the prompt shows tofu boxes (□) instead of icons. The in-container install (`scripts/14-fonts.sh`) is only used when you
access the Codespace over **SSH**. See also [Neovim configuration](#neovim-configuration).

### 2. Authenticate the GitHub CLI (once per Codespace)

Codespaces auto-injects a `GITHUB_TOKEN` that is **scoped to the repo the Codespace was created from**, and `gh`/git
prefer it — so you can't push to _other_ repos until you log in as yourself. `configs/.zshrc` already runs
`unset GITHUB_TOKEN GH_TOKEN` for interactive shells; you just need to authenticate **once per Codespace**:

```bash
gh auth login          # GitHub.com → HTTPS → paste a PAT or use the web flow
```

After that, `git push`/`pull` work against any repo (via the `gh` credential helper wired up in
`configs/.gitconfig_managed`). Full details and the "give me the restricted token back" escape hatch are in
[GitHub CLI authentication](#github-cli-authentication).

## Table of contents

- [Manual steps (do these yourself)](#manual-steps-do-these-yourself)
- [Logs](#logs)
- [Getting started](#getting-started)
  - [As account-wide dotfiles (any repo)](#as-account-wide-dotfiles-any-repo)
  - [As this repo's devcontainer (this repo only)](#as-this-repos-devcontainer-this-repo-only)
  - [Manual](#manual)
- [What it installs](#what-it-installs)
- [Structure](#structure)
- [Customisation](#customisation)
- [Development](#development)
- [GitHub CLI authentication](#github-cli-authentication)
- [Neovim configuration](#neovim-configuration)
- [Related repositories](#related-repositories)

## Logs

`setup.sh` mirrors all of its output to `~/.cache/codespaces-setup.log` as well as the screen, so you can follow progress
from any other shell — or after the fact — even when it runs in the background (e.g. as the Codespaces
`postCreateCommand`):

```bash
tail -f ~/.cache/codespaces-setup.log
```

The Neovim plugin pre-load runs in the background and logs separately:

```bash
tail -f ~/.cache/nvim-setup.log
```

If a step fails, the error line names the failing step and script, e.g.
`[setup] ERROR: Step failed: ... (current step: ...)`.

## Getting started

There are two independent ways this runs in Codespaces. They do **not** depend on each other, and the dotfiles route is
the one that works across _every_ repo.

| Mechanism                              | Scope                         | Runs when                                                                                            |
| -------------------------------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Dotfiles** (account setting)         | Every Codespace, **any** repo | On each Codespace you create, regardless of repository                                               |
| **`devcontainer.json`** (in this repo) | **This repo only**            | Only when you open a Codespace on `codespaces-setup` (or a repo whose `.devcontainer` symlinks here) |

### As account-wide dotfiles (any repo)

Set `johnmathews/codespaces-setup` as your dotfiles repository under **GitHub → Settings → Codespaces → "Automatically
install dotfiles"**. GitHub then clones it into every new Codespace and runs the first install script it recognises, in
this order:

```
install.sh → install → bootstrap.sh → bootstrap → script/bootstrap → setup.sh → setup → script/setup
```

`setup.sh` is on that list, so it runs automatically. It derives its own location (so it works from wherever GitHub
clones the dotfiles repo) and is fully self-contained (installs everything via apt/curl — it does **not** rely on this
repo's `devcontainer.json` features or image).

Notes:

- Only **one** dotfiles repo can be designated per account.
- The target repo's own `devcontainer.json` is **not** replaced — dotfiles run _on top of_ whatever base image/features
  that repo defines. `setup.sh` assumes a Debian/Ubuntu (`apt`) base, which covers the default image and most
  devcontainers, but not non-Debian images.
- If the dotfiles install fails, the Codespace still starts; check the creation log (Command Palette → "Codespaces: View
  Creation Log") or `~/.cache/codespaces-setup.log`.

### As this repo's devcontainer (this repo only)

Opening a Codespace on this repository (or a repo whose `.devcontainer` symlinks here) runs the `postCreateCommand` in
`.devcontainer/devcontainer.json`, which calls `.devcontainer/post-create.sh` → `setup.sh`. This applies **only** to this
repo, not to others. (If you also have dotfiles enabled, `setup.sh` runs twice here — harmless, since it is idempotent.)

### Manual

```bash
git clone https://github.com/johnmathews/codespaces-setup.git ~/codespaces-setup
cd ~/codespaces-setup
bash setup.sh
exec zsh
```

The script is idempotent – safe to run multiple times.

## What it installs

| Tool                        | Version  | Purpose                                                                                                                     |
| --------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------- |
| **Neovim**                  | v0.11.5  | Editor (config from [johnmathews/neovim](https://github.com/johnmathews/neovim))                                            |
| **Node.js**                 | 22 LTS   | Required for Neovim Mason LSP servers / formatters                                                                          |
| **eza**                     | v0.20.14 | Modern `ls` replacement                                                                                                     |
| **yazi**                    | v0.4.2   | Terminal file manager                                                                                                       |
| **lazygit**                 | v0.60.0  | Git TUI                                                                                                                     |
| **atuin**                   | latest   | Shell history (local, no sync in Codespaces)                                                                                |
| **uv**                      | latest   | Python package manager                                                                                                      |
| **Claude Code**             | latest   | AI coding assistant CLI                                                                                                     |
| **GitHub CLI** (`gh`)       | v2.95.0  | GitHub from the terminal; also used as git's credential helper                                                              |
| **Zsh** + **Oh My Zsh**     | —        | Shell                                                                                                                       |
| **Powerlevel10k** (lean)    | —        | Zsh theme                                                                                                                   |
| **zsh-autosuggestions**     | —        | Fish-style suggestions                                                                                                      |
| **zsh-syntax-highlighting** | —        | Command highlighting                                                                                                        |
| **Git identity**            | —        | Sets global `user.name` and `user.email` for commits                                                                        |
| **Editor tooling**          | —        | Formatters/linters on `PATH` (`prettierd`, `biome`, `eslint_d`, `markdownlint`, `ruff`, `mypy`, `stylua`, `shfmt`) + `glow` |

### CLI tools installed via apt

`htop`, `ffmpeg`, `7zip`, `jq`, `poppler-utils`, `fd-find`, `ripgrep`, `fzf`, `zoxide`, `imagemagick`, `tree`, `bat`,
`tmux`, `rsync`, `sqlite3`

## Structure

```
.devcontainer/
  devcontainer.json     # Codespace auto-setup (postCreateCommand: bash setup.sh)
configs/
  .zshrc                # Zsh configuration
  .zsh_aliases          # Shell aliases
  .gitconfig_managed    # Git aliases + portable settings (included from ~/.gitconfig)
scripts/
  01-apt-packages.sh    # Install CLI tools via apt
  02-nodejs.sh          # Install Node.js 22 (official tarball into /usr/local)
  03-neovim.sh          # Install Neovim AppImage (v0.11.5)
  04-neovim-config.sh   # Clone johnmathews/neovim → ~/.config/nvim
  05-eza.sh             # Install eza binary
  06-yazi.sh            # Install yazi binary
  07-lazygit.sh         # Install lazygit binary
  08-atuin.sh           # Install atuin (local history only)
  09-uv.sh              # Install uv Python package manager
  10-zsh-setup.sh       # Install Oh My Zsh, plugins, Powerlevel10k
  11-dotfiles.sh        # Deploy .zshrc, aliases, gitconfig; set default shell to zsh
  12-claude-code.sh     # Install Claude Code CLI
  13-nvim-plugins.sh    # Pre-load Neovim plugins headlessly (run in background)
  14-fonts.sh           # Install MesloLGS NF Nerd Font (in-container; SSH use)
  15-dev-tools.sh       # Install formatters/linters + glow that Neovim needs on PATH
  16-gh.sh              # Install GitHub CLI (gh) from release tarball
ci/
  lint-steps.sh         # Assert every scripts/NN-*.sh is wired into setup.sh's STEPS
.github/workflows/
  ci.yml                # shellcheck + shfmt + lint-steps on push/PR
docs/
  development.md        # CI checks, local lint commands, how to add a step
journal/                # Dated development-journal entries
setup.sh                # Main entry point – runs the ordered STEPS array, then
                        # launches 13-nvim-plugins.sh in background
```

> **Note:** `setup.sh` runs an explicit, ordered `STEPS` array — **not** every file in `scripts/`. Filename number
> prefixes are labels, not run order, and `13-nvim-plugins.sh` is deliberately excluded (launched in the background).
> Adding a script means also adding it to `STEPS`; `ci/lint-steps.sh` enforces this. See
> [docs/development.md](docs/development.md).

## Customisation

- **Shell config**: edit `configs/.zshrc` then re-run `bash scripts/11-dotfiles.sh`
- **Aliases**: edit `configs/.zsh_aliases` then re-run `bash scripts/11-dotfiles.sh`
- **Git aliases**: edit `configs/.gitconfig_managed` then re-run `bash scripts/11-dotfiles.sh`
- **Git identity**: `scripts/11-dotfiles.sh` sets global Git user details for the Codespace
- **Editor tooling**: `scripts/15-dev-tools.sh` installs the formatters/linters (and `glow`) that Neovim expects on
  `PATH`. `.zshrc` also points Node/Python at the system CA bundle so Mason can install npm/pip tools behind a
  TLS-intercepting proxy (otherwise installs fail with `SELF_SIGNED_CERT_IN_CHAIN`)
- **Local overrides** (not managed here): `~/.zshrc.local` and `~/.zsh_aliases.local`
- **Prompt**: run `p10k configure` after setup to customise the Powerlevel10k theme

## Development

There are no unit tests (the "product" is the provisioning scripts), but CI (`.github/workflows/ci.yml`) lints them on
every push to `main` and PR, and you can run the same checks locally:

```bash
shellcheck setup.sh scripts/*.sh ci/*.sh    # shell correctness
shfmt -i 2 -ci -kp -d setup.sh scripts ci    # formatting (-w to auto-fix)
bash ci/lint-steps.sh                         # every scripts/NN-*.sh is wired into STEPS
```

Full details — the formatting convention, why `-kp`, and how to add a new provisioning step — are in
[docs/development.md](docs/development.md).

## GitHub CLI authentication

Codespaces auto-injects a `GITHUB_TOKEN` environment variable that is **scoped to the repository the Codespace was
created from**. `gh` (and git) prefer that token over any stored credentials, so `gh auth login` refuses to save your own
token while it is set, and you can't push to _other_ repos.

To work around this, `configs/.zshrc` runs `unset GITHUB_TOKEN GH_TOKEN` for interactive shells. Once it's cleared,
authenticate as yourself **once per Codespace**:

```bash
gh auth login          # choose GitHub.com → HTTPS → paste a PAT or use the web flow
```

After that, `git push`/`pull` work against any repo because `configs/.gitconfig_managed` registers
`gh auth git-credential` as git's credential helper for `github.com`.

If you specifically need the original restricted token back in a shell (e.g. for headless automation), re-export it:
`export GITHUB_TOKEN=...`.

## Neovim configuration

The Neovim config is pulled directly from [johnmathews/neovim](https://github.com/johnmathews/neovim) into
`~/.config/nvim`. Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim) and are **pre-loaded in the
background** during Codespace creation so that `nvim` is ready to use immediately. Progress is logged to
`~/.cache/nvim-setup.log` (see [Logs](#logs)).

If the background pre-load is still running when you first open `nvim`, plugins will already be partially or fully
installed – lazy.nvim will not re-download what it has already cached.

## Related repositories

- [johnmathews/neovim](https://github.com/johnmathews/neovim) – Neovim configuration
- [johnmathews/home-server](https://github.com/johnmathews/home-server) – Ansible roles (particularly the
  `shell_environment` role that this repo mirrors for Codespaces)
