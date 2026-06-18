# vim: ft=zsh
# Zsh configuration for GitHub Codespaces
# Managed by codespaces-setup - edit configs/.zshrc in the repo to change.

# Enable Powerlevel10k instant prompt (must be near the top of .zshrc)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Completion settings
HYPHEN_INSENSITIVE="true"
COMPLETION_WAITING_DOTS="true"

# Plugins
plugins=(
  git
  docker
  sudo
  history
  fzf
  colored-man-pages
  extract
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Autosuggestions style
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# Load Powerlevel10k config
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Load shell aliases
[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases

# Editor
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less

# Trust the system CA bundle for tools that bundle their own (Node/npm, Python).
# Behind a TLS-intercepting proxy this is what lets Neovim's Mason install
# npm/pip-based tools (prettierd, biome, eslint_d, markdownlint, ruff, mypy)
# instead of failing with SELF_SIGNED_CERT_IN_CHAIN.
if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
  export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
  export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
  export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
fi

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# Vi mode configuration
bindkey -v
export KEYTIMEOUT=10

# Use 'kj' to exit insert mode (alternative to ESC)
bindkey -M viins 'kj' vi-cmd-mode

# Change cursor shape for vi modes
function zle-keymap-select {
  case $KEYMAP in
    vicmd)      echo -ne '\e[1 q';;  # blinking block (normal mode)
    viins|main) echo -ne '\e[5 q';;  # blinking beam (insert mode)
  esac
}
function zle-line-init { echo -ne '\e[5 q'; }
zle -N zle-keymap-select
zle -N zle-line-init

# Atuin integration (must be last - overwrites Ctrl+R)
if command -v atuin &>/dev/null; then
  eval "$(atuin init zsh)"
fi

# Zoxide integration (smart directory jumping)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# uv completions
if command -v uv &>/dev/null; then
  eval "$(uv generate-shell-completion zsh 2>/dev/null)"
fi

# Local customisations (not managed by codespaces-setup)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
