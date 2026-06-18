# codespaces-setup

Scripts to set up a new GitHub Codespace with a full, opinionated development environment.

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

### CLI tools installed via apt

`htop`, `ffmpeg`, `7zip`, `jq`, `poppler-utils`, `fd-find`, `ripgrep`,
`fzf`, `zoxide`, `imagemagick`, `tree`, `bat`, `tmux`, `rsync`, `sqlite3`

## Usage

### Automatic (GitHub Codespaces)

Open this repository (or any repository that has a `.devcontainer/` symlink
to this one) in a GitHub Codespace. The `postCreateCommand` in
`.devcontainer/devcontainer.json` runs `setup.sh` automatically.

### Manual

```bash
git clone https://github.com/johnmathews/codespaces-setup.git ~/codespaces-setup
cd ~/codespaces-setup
bash setup.sh
exec zsh
```

The script is idempotent – safe to run multiple times.

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
setup.sh                # Main entry point – calls all scripts in order, then
                        # launches 13-nvim-plugins.sh in background
```

## Customisation

- **Shell config**: edit `configs/.zshrc` then re-run `bash scripts/11-dotfiles.sh`
- **Aliases**: edit `configs/.zsh_aliases` then re-run `bash scripts/11-dotfiles.sh`
- **Git aliases**: edit `configs/.gitconfig_managed` then re-run `bash scripts/11-dotfiles.sh`
- **Local overrides** (not managed here): `~/.zshrc.local` and `~/.zsh_aliases.local`
- **Prompt**: run `p10k configure` after setup to customise the Powerlevel10k theme

## Neovim configuration

The Neovim config is pulled directly from
[johnmathews/neovim](https://github.com/johnmathews/neovim) into `~/.config/nvim`.
Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim) and are
**pre-loaded in the background** during Codespace creation so that `nvim` is
ready to use immediately. Progress is logged to `~/.cache/nvim-setup.log`.

```bash
# Monitor plugin installation progress
tail -f ~/.cache/nvim-setup.log
```

If the background pre-load is still running when you first open `nvim`, plugins
will already be partially or fully installed – lazy.nvim will not re-download
what it has already cached.

## Related repositories

- [johnmathews/neovim](https://github.com/johnmathews/neovim) – Neovim configuration
- [johnmathews/home-server](https://github.com/johnmathews/home-server) – Ansible roles
  (particularly the `shell_environment` role that this repo mirrors for Codespaces)
