# codespaces-setup

Scripts to set up a new GitHub Codespace with a full, opinionated development environment.

## Table of contents

- [Logs](#logs)
- [Getting started](#getting-started)
  - [Automatic (GitHub Codespaces)](#automatic-github-codespaces)
  - [Manual](#manual)
- [What it installs](#what-it-installs)
- [Structure](#structure)
- [Customisation](#customisation)
- [Neovim configuration](#neovim-configuration)
- [Related repositories](#related-repositories)

## Logs

`setup.sh` mirrors all of its output to `~/.cache/codespaces-setup.log` as well
as the screen, so you can follow progress from any other shell — or after the
fact — even when it runs in the background (e.g. as the Codespaces
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

### Automatic (GitHub Codespaces)

Open this repository (or any repository that has a `.devcontainer/` symlink
to this one) in a GitHub Codespace. The `postCreateCommand` in
`.devcontainer/devcontainer.json` runs `.devcontainer/post-create.sh`, which
resolves the shared repository path and then runs `setup.sh` automatically.

### Manual

```bash
git clone https://github.com/johnmathews/codespaces-setup.git ~/codespaces-setup
cd ~/codespaces-setup
bash setup.sh
exec zsh
```

The script is idempotent – safe to run multiple times.

## What it installs

| Tool | Version | Purpose |
|------|---------|---------|
| **Neovim** | v0.11.5 | Editor (config from [johnmathews/neovim](https://github.com/johnmathews/neovim)) |
| **Node.js** | 20 LTS | Required for Neovim Mason LSP servers |
| **eza** | v0.20.14 | Modern `ls` replacement |
| **yazi** | v0.4.2 | Terminal file manager |
| **lazygit** | v0.60.0 | Git TUI |
| **atuin** | latest | Shell history (local, no sync in Codespaces) |
| **uv** | latest | Python package manager |
| **Claude Code** | latest | AI coding assistant CLI |
| **Zsh** + **Oh My Zsh** | — | Shell |
| **Powerlevel10k** (lean) | — | Zsh theme |
| **zsh-autosuggestions** | — | Fish-style suggestions |
| **zsh-syntax-highlighting** | — | Command highlighting |
| **Git identity** | — | Sets global `user.name` and `user.email` for commits |
| **Editor tooling** | — | Formatters/linters on `PATH` (`prettierd`, `biome`, `eslint_d`, `markdownlint`, `ruff`, `mypy`, `stylua`, `shfmt`) + `glow` |

### CLI tools installed via apt

`htop`, `ffmpeg`, `7zip`, `jq`, `poppler-utils`, `fd-find`, `ripgrep`,
`fzf`, `zoxide`, `imagemagick`, `tree`, `bat`, `tmux`, `rsync`, `sqlite3`

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
  02-nodejs.sh          # Install Node.js 20 via NodeSource
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
  15-dev-tools.sh       # Install formatters/linters + glow that Neovim needs on PATH
setup.sh                # Main entry point – calls all scripts in order, then
                        # launches 13-nvim-plugins.sh in background
```

## Customisation

- **Shell config**: edit `configs/.zshrc` then re-run `bash scripts/11-dotfiles.sh`
- **Aliases**: edit `configs/.zsh_aliases` then re-run `bash scripts/11-dotfiles.sh`
- **Git aliases**: edit `configs/.gitconfig_managed` then re-run `bash scripts/11-dotfiles.sh`
- **Git identity**: `scripts/11-dotfiles.sh` sets global Git user details for the Codespace
- **Editor tooling**: `scripts/15-dev-tools.sh` installs the formatters/linters
  (and `glow`) that Neovim expects on `PATH`. `.zshrc` also points Node/Python
  at the system CA bundle so Mason can install npm/pip tools behind a
  TLS-intercepting proxy (otherwise installs fail with `SELF_SIGNED_CERT_IN_CHAIN`)
- **Local overrides** (not managed here): `~/.zshrc.local` and `~/.zsh_aliases.local`
- **Prompt**: run `p10k configure` after setup to customise the Powerlevel10k theme

## Neovim configuration

The Neovim config is pulled directly from
[johnmathews/neovim](https://github.com/johnmathews/neovim) into `~/.config/nvim`.
Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim) and are
**pre-loaded in the background** during Codespace creation so that `nvim` is
ready to use immediately. Progress is logged to `~/.cache/nvim-setup.log` (see
[Logs](#logs)).

If the background pre-load is still running when you first open `nvim`, plugins
will already be partially or fully installed – lazy.nvim will not re-download
what it has already cached.

## Related repositories

- [johnmathews/neovim](https://github.com/johnmathews/neovim) – Neovim configuration
- [johnmathews/home-server](https://github.com/johnmathews/home-server) – Ansible roles
  (particularly the `shell_environment` role that this repo mirrors for Codespaces)
