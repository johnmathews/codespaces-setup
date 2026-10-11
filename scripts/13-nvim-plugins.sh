#!/usr/bin/env bash
# Background synchronization owned by the Neovim config: plugins from the
# lockfile, Mason tools and parsers. setup.sh redirects to ~/.cache/nvim-setup.log.

set -euo pipefail

log() { echo "[nvim-plugins] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NVIM_STATUS_FILE="${NVIM_STATUS_FILE:-${HOME}/.cache/nvim-setup.status}"
mkdir -p "$(dirname "${NVIM_STATUS_FILE}")"
printf 'running\n' >"${NVIM_STATUS_FILE}"

finish() {
  local rc=$?
  if ((rc == 0)); then
    printf 'ok\n' >"${NVIM_STATUS_FILE}"
  else
    printf 'incomplete\nupstream sync failed (exit %s); see nvim-setup.log\n' "${rc}" >"${NVIM_STATUS_FILE}"
  fi
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

NVIM_CONFIG_DIR="${HOME}/.config/nvim"
SYNC="${NVIM_CONFIG_DIR}/scripts/sync-plugins"
if [[ ! -f "${SYNC}" ]]; then
  log "ERROR: ${SYNC} missing; run scripts/04-neovim-config.sh first."
  exit 1
fi
if ! command -v nvim >/dev/null 2>&1; then
  log "ERROR: nvim not found; run scripts/03-neovim.sh first."
  exit 1
fi

cd "${NVIM_CONFIG_DIR}"
log "Synchronizing pinned plugins, Mason tools and parsers (may take several minutes)..."
# The clone is managed: discard lockfile drift from an interrupted attempt.
# Keep this inside the timed process group, and never retry upstream refusals.
# shellcheck disable=SC2016 # Positional arguments expand in the timed child.
RETRY_TIMEOUT="${NVIM_SYNC_TIMEOUT:-900}" RETRY_ATTEMPTS=3 RETRY_PROCESS_GROUP=1 RETRY_STOP_RC=2 \
  retry bash -c 'git -C "$1" checkout -- lazy-lock.json || exit 2; exec bash "$2"' \
  bash "${NVIM_CONFIG_DIR}" "${SYNC}"
log "Upstream synchronization complete; lockfile unchanged."
