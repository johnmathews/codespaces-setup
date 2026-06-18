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

FONT_DIR="${HOME}/.local/share/fonts/MesloLGS-NF"
BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"

declare -a FONTS=(
  "MesloLGS NF Regular.ttf"
  "MesloLGS NF Bold.ttf"
  "MesloLGS NF Italic.ttf"
  "MesloLGS NF Bold Italic.ttf"
)

# Check if all four variants are already present
all_present=true
for font in "${FONTS[@]}"; do
  [[ -f "${FONT_DIR}/${font}" ]] || all_present=false
done

if [[ "${all_present}" == "true" ]]; then
  log "MesloLGS NF already installed in ${FONT_DIR}, skipping."
  exit 0
fi

log "Creating font directory ${FONT_DIR}..."
mkdir -p "${FONT_DIR}"

for font in "${FONTS[@]}"; do
  dest="${FONT_DIR}/${font}"
  if [[ -f "${dest}" ]]; then
    log "  ${font}: already present, skipping."
  else
    log "  Downloading: ${font}..."
    # URL-encode the spaces
    encoded="${font// /%20}"
    curl -fsSL "${BASE_URL}/${encoded}" -o "${dest}"
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
