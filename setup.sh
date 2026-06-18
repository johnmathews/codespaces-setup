#!/usr/bin/env bash
# Main setup script for GitHub Codespace environment.
# Clone this repo and run: bash setup.sh
# Safe to run multiple times (idempotent).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${REPO_DIR}/scripts"
REPO_URL="https://github.com/johnmathews/codespaces-setup"
README_URL="${REPO_URL}#readme"

# Mirror every line of output to a log file as well as the terminal, so the run
# can be followed from any other shell (or after it finishes) with:
#   tail -f ~/.cache/codespaces-setup.log
# This works even when setup.sh runs in the background, e.g. as the Codespaces
# postCreateCommand.
SETUP_LOG="${HOME}/.cache/codespaces-setup.log"
mkdir -p "$(dirname "${SETUP_LOG}")"
exec > >(tee -a "${SETUP_LOG}") 2>&1

STEPS=(
  "01-apt-packages.sh|Installing apt packages and CLI tools"
  "11-dotfiles.sh|Deploying dotfiles (.zshrc, aliases, gitconfig)"
  "14-fonts.sh|Installing MesloLGS NF (Nerd Font)"
  "02-nodejs.sh|Installing Node.js 22"
  "03-neovim.sh|Installing Neovim"
  "04-neovim-config.sh|Setting up Neovim configuration"
  "05-eza.sh|Installing eza (modern ls)"
  "06-yazi.sh|Installing yazi (file manager)"
  "07-lazygit.sh|Installing lazygit"
  "08-atuin.sh|Installing atuin (shell history)"
  "09-uv.sh|Installing uv (Python package manager)"
  "10-zsh-setup.sh|Setting up Zsh + Oh My Zsh + Powerlevel10k"
  "12-claude-code.sh|Installing Claude Code"
  "15-dev-tools.sh|Installing editor CLI tools (formatters, linters, glow)"
  "16-gh.sh|Installing GitHub CLI (gh)"
)

TOTAL_STEPS="${#STEPS[@]}"
SETUP_START_TS="$(date +%s)"
CURRENT_STEP=""

log() { echo "[setup] $*"; }
die() {
  if [[ -n "${CURRENT_STEP}" ]]; then
    echo "[setup] ERROR: ${*} (current step: ${CURRENT_STEP})" >&2
  else
    echo "[setup] ERROR: $*" >&2
  fi
  exit 1
}

repeat_char() {
  local char="$1"
  local count="$2"
  if (( count <= 0 )); then
    return 0
  fi
  printf "%${count}s" "" | tr " " "${char}"
}

progress_bar() {
  local current="$1"
  local total="$2"
  local width=24
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  printf "[%s%s]" "$(repeat_char "=" "${filled}")" "$(repeat_char "." "${empty}")"
}

print_header() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                     CODESPACES SETUP START                      ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  printf "  Repository : %s\n" "${REPO_URL}"
  printf "  README     : %s\n" "${README_URL}"
  printf "  User       : %s\n" "$(whoami)"
  printf "  Home       : %s\n" "${HOME}"
  printf "  Steps      : %d foreground steps + Neovim preload in background\n" "${TOTAL_STEPS}"
  printf "  Log        : %s  (follow from any shell: tail -f %s)\n" "${SETUP_LOG}" "${SETUP_LOG}"
  echo ""
}

run_step() {
  local step_number="$1"
  local script="$2"
  local name="$3"
  local started_at elapsed
  started_at="$(date +%s)"
  CURRENT_STEP="${name}"

  echo ""
  printf "▶ %s [%02d/%02d] %s\n" "$(progress_bar "${step_number}" "${TOTAL_STEPS}")" "${step_number}" "${TOTAL_STEPS}" "${name}"
  printf "  Script     : %s\n" "${script}"

  if bash "${SCRIPTS_DIR}/${script}"; then
    elapsed=$(( $(date +%s) - started_at ))
    printf "✓ Completed  : %s (%ss)\n" "${name}" "${elapsed}"
  else
    die "Step failed: ${name} (${script})"
  fi
}

print_header

log "Ensuring setup scripts are executable..."
chmod +x "${SCRIPTS_DIR}"/*.sh

for i in "${!STEPS[@]}"; do
  IFS="|" read -r script name <<< "${STEPS[$i]}"
  run_step "$(( i + 1 ))" "${script}" "${name}"
done

CORE_ELAPSED=$(( $(date +%s) - SETUP_START_TS ))

echo ""
printf "▶ %s [BG] Starting Neovim plugin pre-load\n" "$(progress_bar "${TOTAL_STEPS}" "${TOTAL_STEPS}")"
mkdir -p "${HOME}/.cache"
NVIM_LOG="${HOME}/.cache/nvim-setup.log"
bash "${SCRIPTS_DIR}/13-nvim-plugins.sh" >"${NVIM_LOG}" 2>&1 &
NVIM_SETUP_PID=$!
printf "✓ Started    : Neovim plugin pre-load (PID: %s)\n" "${NVIM_SETUP_PID}"
printf "  Monitor    : tail -f %s\n" "${NVIM_LOG}"
printf "  Wait       : wait %s\n" "${NVIM_SETUP_PID}"

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    CODESPACES SETUP COMPLETE                    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
printf "  Core setup : completed in %ss\n" "${CORE_ELAPSED}"
printf "  Next step  : run 'exec zsh' in this terminal if you want to switch now\n"
printf "  New shells : should open in zsh automatically\n"
printf "  README     : %s\n" "${README_URL}"
printf "  Setup log  : %s\n" "${SETUP_LOG}"
printf "  Nvim log   : %s\n" "${NVIM_LOG}"

# Print a verification summary so the user can confirm every tool landed.
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              SETUP VERIFICATION SUMMARY              ║"
echo "╚══════════════════════════════════════════════════════╝"

check_tool() {
  local label="$1"
  local bin="$2"
  shift 2
  local version_output
  if version_output="$("$bin" "$@" 2>/dev/null | head -1)"; then
    printf "  ✅  %-18s %s\n" "${label}" "${version_output}"
  else
    printf "  ❌  %-18s not found\n" "${label}"
  fi
}

check_tool "zsh"        zsh        --version
check_tool "node"       node       --version
check_tool "nvim"       nvim       --version
check_tool "eza"        eza        --version
check_tool "yazi"       yazi       --version
check_tool "lazygit"    lazygit    --version
check_tool "atuin"      atuin      --version
check_tool "uv"         uv         --version
check_tool "claude"     claude     --version
check_tool "gh"         gh         --version
check_tool "glow"       glow       --version
check_tool "ruff"       ruff       --version
check_tool "stylua"     stylua     --version
check_tool "shfmt"      shfmt      --version
check_tool "prettierd"  prettierd  --version
check_tool "biome"      biome      --version

FONT_DIR="${HOME}/.local/share/fonts/MesloLGS-NF"
if [[ -f "${FONT_DIR}/MesloLGS NF Regular.ttf" ]]; then
  printf "  ✅  %-18s installed in %s\n" "MesloLGS NF" "${FONT_DIR}"
else
  printf "  ❌  %-18s not found\n" "MesloLGS NF"
fi

NVIM_LOG="${NVIM_LOG:-${HOME}/.cache/nvim-setup.log}"

echo ""
echo "  Shell config : ${HOME}/.zshrc"
echo "  Aliases      : ${HOME}/.zsh_aliases"
echo "  Git config   : ${HOME}/.gitconfig"
echo "  Nvim plugins : tail -f ${NVIM_LOG}"
echo ""
