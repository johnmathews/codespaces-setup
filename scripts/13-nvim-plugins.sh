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
RETRY_TIMEOUT="${NVIM_SYNC_TIMEOUT:-900}" RETRY_ATTEMPTS=3 \
  retry bash "${SYNC}"
log "Upstream synchronization complete; lockfile unchanged."
