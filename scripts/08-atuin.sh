#!/usr/bin/env bash
# Install atuin (shell history sync).
# Uses the official installer and places the binary in /usr/local/bin.
# In Codespaces, atuin sync is not configured (no private server available).

set -euo pipefail

log() { echo "[atuin] $*"; }

BIN_DIR="/usr/local/bin"

if command -v atuin &>/dev/null; then
  log "atuin already installed ($(atuin --version)), skipping."
  exit 0
fi

log "Installing atuin via official installer..."
export ATUIN_DONT_PRINT_WELCOME=1
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --no-modify-path

# The installer puts the binary in ~/.atuin/bin/atuin
ATUIN_LOCAL="${HOME}/.atuin/bin/atuin"
if [[ -x "${ATUIN_LOCAL}" ]]; then
  log "Installing atuin to ${BIN_DIR}/atuin..."
  sudo install -m 755 "${ATUIN_LOCAL}" "${BIN_DIR}/atuin"
fi

log "Creating atuin config directory..."
mkdir -p "${HOME}/.config/atuin"

# Write a minimal atuin config suitable for a codespace (no sync server)
if [[ ! -f "${HOME}/.config/atuin/config.toml" ]]; then
  cat >"${HOME}/.config/atuin/config.toml"  <<'EOF'
## Atuin config for GitHub Codespaces
## Sync is disabled; history is local only.

dialect = "uk"
auto_sync = false
update_check = false
search_mode = "fuzzy"
filter_mode = "global"
style = "compact"

[daemon]
enabled = false
EOF
fi

log "Installed: $(atuin --version)"
