#!/usr/bin/env bash
# Install MesloLGS NF (Nerd Font patched for Powerlevel10k) into the container.
#
# NOTE: For browser-based Codespaces the VS Code terminal renders fonts on the
# *client* machine, so you also need to install MesloLGS NF locally and then
# set "terminal.integrated.fontFamily" to "MesloLGS NF" in VS Code.
# Download from: https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k
#
# The in-container install here is used when accessing the Codespace via SSH.

set -euo pipefail

log() { echo "[fonts] $*"; }

# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FONT_DIR="${HOME}/.local/share/fonts/MesloLGS-NF"
BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"

declare -a FONTS=(
  "MesloLGS NF Regular.ttf"
  "MesloLGS NF Bold.ttf"
  "MesloLGS NF Italic.ttf"
  "MesloLGS NF Bold Italic.ttf"
)

# A font file counts as installed only if it is a real sfnt — not a truncated
# transfer and not a proxy error page. This URL is a github.com raw redirect, and
# behind a TLS-intercepting proxy a failure arrives as HTML with a 200, which
# `curl -o` used to write straight to the final path where `[[ -f ]]` accepted it
# forever and fc-cache then indexed it. The first four bytes are the sfnt tag.
font_ok() {
  local f="$1" magic
  [[ -s "${f}" ]] || return 1
  magic="$(head -c 4 "${f}" | od -An -tx1 | tr -d ' \n')"
  [[ "${magic}" == "00010000" || "${magic}" == "74727565" || "${magic}" == "4f54544f" ]]
}

# Check if all four variants are already present AND valid
all_present=true
for font in "${FONTS[@]}"; do
  font_ok "${FONT_DIR}/${font}" || all_present=false
done

if [[ "${all_present}" == "true" ]]; then
  log "MesloLGS NF already installed in ${FONT_DIR}, skipping."
  exit 0
fi

log "Creating font directory ${FONT_DIR}..."
mkdir -p "${FONT_DIR}"

# Stage inside FONT_DIR so the final `mv` is a same-filesystem rename and each
# font appears atomically. The dot prefix keeps the staging dir out of the way of
# fc-cache, and the trap removes it before the cache is refreshed.
TMP="$(mktemp -d "${FONT_DIR}/.staging.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

for font in "${FONTS[@]}"; do
  dest="${FONT_DIR}/${font}"
  if font_ok "${dest}"; then
    log "  ${font}: already present, skipping."
  else
    [[ -e "${dest}" ]] && log "  ${font}: present but not a valid font; re-downloading."
    log "  Downloading: ${font}..."
    # URL-encode the spaces
    encoded="${font// /%20}"
    fetch_verified "${BASE_URL}/${encoded}" "${TMP}/${font}"
    if ! font_ok "${TMP}/${font}"; then
      log "  ERROR: downloaded ${font} is not a valid font file (truncated, or a proxy error page)."
      exit 1
    fi
    mv "${TMP}/${font}" "${dest}"
  fi
done

log "Refreshing font cache..."
if command -v fc-cache &>/dev/null; then
  fc-cache -f "${FONT_DIR}"
fi

log "MesloLGS NF installed."
log ""
log "  ⚠️  Browser Codespaces: also install the font on your local machine."
log "     Download: https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k"
