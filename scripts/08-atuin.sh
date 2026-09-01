#!/usr/bin/env bash
# Install atuin (shell history sync).
# Uses the official installer and places the binary in /usr/local/bin.
# In Codespaces, atuin sync is not configured (no private server available).

set -euo pipefail

log() { echo "[atuin] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BIN_DIR="/usr/local/bin"

# No pinned version for atuin, so the guard can only prove the binary EXECUTES —
# but that is still the half an existence check cannot do. See scripts/lib.sh.
if installed_runs atuin; then
  log "atuin already installed (${INSTALLED_VERSION}), skipping."
  exit 0
fi

log "Installing atuin via official installer..."
export ATUIN_DONT_PRINT_WELCOME=1
# Download the installer to a file first (with retries) rather than piping
# curl straight into sh: a transient network failure mid-pipe would otherwise
# feed a truncated script to sh with no chance to retry.
ATUIN_INSTALLER="$(mktemp)"
trap 'rm -f "${ATUIN_INSTALLER}"' EXIT
retry net_curl --proto '=https' --tlsv1.2 https://setup.atuin.sh -o "${ATUIN_INSTALLER}"
# `sh -n` is the script-shaped equivalent of `tar -tzf`: it proves the download
# is complete before it is executed.
if ! sh -n "${ATUIN_INSTALLER}"; then
  log "ERROR: the downloaded atuin installer is not valid shell (truncated download?)."
  exit 1
fi
# Retry the INSTALLER too, not just its download. The retried curl above fetches
# a few KB of shell; the multi-megabyte binary is fetched inside this script, and
# that is the transfer likely to fail on a flaky network.
retry sh "${ATUIN_INSTALLER}" --no-modify-path

# The installer puts the binary in ~/.atuin/bin/atuin
ATUIN_LOCAL="${HOME}/.atuin/bin/atuin"
if [[ -x "${ATUIN_LOCAL}" ]]; then
  log "Installing atuin to ${BIN_DIR}/atuin..."
  sudo install -m 755 "${ATUIN_LOCAL}" "${BIN_DIR}/atuin"
else
  # Previously this fell through silently and the step exited 0 having installed
  # nothing — a step that reports success while doing nothing is exactly the
  # failure the run record cannot see.
  log "ERROR: the atuin installer did not produce ${ATUIN_LOCAL}."
  exit 1
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
