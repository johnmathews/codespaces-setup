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
# `bash -n` is the script-shaped equivalent of `tar -tzf`: it proves the download
# is complete before it is executed.
if ! bash -n "${ATUIN_INSTALLER}"; then
  log "ERROR: the downloaded atuin installer is not valid shell (truncated download?)."
  exit 1
fi

# RUN IT WITH BASH, NOT SH. This is not a style preference — under `sh` this
# installer cannot work at all in an unattended Codespace.
#
# Its first real statement probes for a controlling terminal:
#
#     if { exec 3</dev/tty; } 2>/dev/null; then
#
# `exec` is a POSIX *special builtin*, and a redirection failure on a special
# builtin terminates a non-interactive POSIX shell immediately — even inside an
# `if` condition, where `set -e` does not apply. /bin/sh is dash on
# Debian/Ubuntu, which does exactly that. With no tty (the Codespaces
# postCreateCommand and dotfiles paths both have none) the installer therefore
# died with exit 2 before printing even its own banner, and the `2>/dev/null`
# swallowed the message — so the failure was completely silent. Ten retries
# across two passes produced 190 seconds of nothing.
#
# Verified in a container: the installer's exact `if { exec 3</dev/tty; }` shape
# exits 2 under dash with no tty, and reaches the next line under bash.
# It works when a human runs it in a terminal, which is presumably how it is
# tested upstream.
#
# `--non-interactive` is the flag this installer actually parses; the
# `--no-modify-path` we used to pass is silently ignored by its `*) ;;` case.
retry bash "${ATUIN_INSTALLER}" --non-interactive

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
