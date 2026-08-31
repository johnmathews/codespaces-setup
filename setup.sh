#!/usr/bin/env bash
# Main setup script for GitHub Codespace environment.
# Clone this repo and run: bash setup.sh
# Safe to run multiple times (idempotent).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SCRIPTS_DIR is overridable via env (SETUP_SCRIPTS_DIR) so the resilience test in
# tests/setup-resilience/ can drive this exact runner over a throwaway set of
# fake steps without touching the real scripts/.
SCRIPTS_DIR="${SETUP_SCRIPTS_DIR:-${REPO_DIR}/scripts}"
REPO_URL="https://github.com/johnmathews/codespaces-setup"
README_URL="${REPO_URL}#readme"

# Mirror every line of output to a log file as well as the terminal, so the run
# can be followed from any other shell (or after it finishes) with:
#   tail -f ~/.cache/codespaces-setup.log
# This works even when setup.sh runs in the background, e.g. as the Codespaces
# postCreateCommand.
SETUP_LOG="${SETUP_LOG:-${HOME}/.cache/codespaces-setup.log}"
mkdir -p "$(dirname "${SETUP_LOG}")"

# Durable failure signal. When any step fails, a human-readable summary is
# written here and configs/.zshrc surfaces it on the next interactive shell.
# The path that matters most is unattended — Codespaces auto-runs this script via
# the dotfiles mechanism at creation, with nobody watching the output — so a
# half-built environment must leave a mark a human actually trips over rather
# than passing for a complete one. A fully successful run removes the file.
SETUP_FAILURE_FILE="${SETUP_FAILURE_FILE:-${HOME}/.cache/codespaces-setup.failed}"

# Detect whether we're attached to a real terminal *before* redirecting stdout
# through tee — afterwards stdout is a pipe and `[[ -t 1 ]]` is always false.
# When interactive we animate a progress bar / spinner straight to /dev/tty, so
# the live UI never pollutes the log file. Non-interactive runs (Codespaces
# postCreateCommand, dotfiles auto-run, `tail -f` from another shell) get no
# animation and behave exactly as before.
HAS_TTY=0
[[ -t 1 ]] && HAS_TTY=1

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
  "17-claude-skills.sh|Deploying Claude skills and slash commands"
  "15-dev-tools.sh|Installing editor CLI tools (formatters, linters, glow)"
  "16-gh.sh|Installing GitHub CLI (gh)"
  "18-azure-cli.sh|Installing Azure CLI (az)"
)

# Test hook: SETUP_STEPS, if set, replaces the list above with ';'-separated
# "script|description" entries. Lets tests/setup-resilience/ exercise the runner
# over fake steps. Unset in every real run, so production behaviour is unchanged.
if [[ -n "${SETUP_STEPS:-}" ]]; then
  IFS=';' read -r -a STEPS <<<"${SETUP_STEPS}"
fi

# Steps that MUST succeed for the rest of the run to be meaningful. A required
# step that fails aborts the run immediately (the historical behaviour) instead
# of being recorded-and-skipped, because continuing past it would only produce a
# cascade of derived failures.
#
# Only 01-apt-packages qualifies: it installs the foundational tools every later
# step assumes are already on PATH (curl, git, unzip, tar, zsh). If it fails,
# essentially every remaining step fails too, so aborting yields one clear,
# actionable error instead of 16 misleading ones. Every other step installs an
# independent tool whose failure the rest of the run can survive, so those are
# recorded and skipped past rather than fatal.
#
# Overridable via env for the resilience test: SETUP_REQUIRED="" means "none".
if [[ -n "${SETUP_REQUIRED+defined}" ]]; then
  IFS=';' read -r -a REQUIRED <<<"${SETUP_REQUIRED}"
else
  REQUIRED=("01-apt-packages.sh")
fi

TOTAL_STEPS="${#STEPS[@]}"
SETUP_START_TS="$(date +%s)"
CURRENT_STEP=""
# Each step that exits non-zero is recorded here as "NN|script|name"; the run
# keeps going and reports them all at the end.
declare -a FAILED_STEPS=()

log() { echo "[setup] $*"; }
die() {
  if [[ -n "${CURRENT_STEP}" ]]; then
    echo "[setup] ERROR: ${*} (current step: ${CURRENT_STEP})" >&2
  else
    echo "[setup] ERROR: $*" >&2
  fi
  exit 1
}

# Is this step one whose failure must abort the whole run? (See REQUIRED above.)
is_required() {
  local candidate="$1" r
  for r in ${REQUIRED[@]+"${REQUIRED[@]}"}; do
    [[ "${candidate}" == "${r}" ]] && return 0
  done
  return 1
}

# Write the durable, human-readable failure signal that configs/.zshrc surfaces
# on the next interactive shell. Overwrites any previous signal so it always
# reflects the latest run.
write_failure_file() {
  local entry n s nm
  mkdir -p "$(dirname "${SETUP_FAILURE_FILE}")"
  {
    echo "⚠️  codespaces-setup did NOT finish cleanly (last run: $(date))."
    echo ""
    echo "Failed step(s):"
    for entry in "${FAILED_STEPS[@]}"; do
      IFS="|" read -r n s nm <<<"${entry}"
      printf "  ✗ [%s] %s (%s)\n" "${n}" "${nm}" "${s}"
    done
    echo ""
    echo "Your environment is only partially set up. To fix it:"
    echo "  bash ${REPO_DIR}/setup.sh      # re-run (idempotent; safe to repeat)"
    echo "  tail -n 200 ${SETUP_LOG}       # see what went wrong"
    echo ""
    echo "This notice clears itself once setup completes with no failures."
  } >"${SETUP_FAILURE_FILE}"
}

# Print the end-of-run FAILED summary banner listing every failed step.
print_failure_summary() {
  local entry n s nm
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                  ❌  CODESPACES SETUP FAILED  ❌                  ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  printf "  %d of %d step(s) failed — the rest still ran:\n" "${#FAILED_STEPS[@]}" "${TOTAL_STEPS}"
  for entry in "${FAILED_STEPS[@]}"; do
    IFS="|" read -r n s nm <<<"${entry}"
    printf "    ✗ [%s] %s (%s)\n" "${n}" "${nm}" "${s}"
  done
  printf "  📝 Full log     : %s\n" "${SETUP_LOG}"
  printf "  🚩 Signal file  : %s (shown on next shell start)\n" "${SETUP_FAILURE_FILE}"
  printf "  🔁 Re-run        : bash %s/setup.sh\n" "${REPO_DIR}"
}

repeat_char() {
  local char="$1"
  local count="$2"
  if ((count <= 0)); then
    return 0
  fi
  printf "%${count}s" "" | tr " " "${char}"
}

progress_bar() {
  local current="$1"
  local total="$2"
  local width=24
  local filled=$((current * width / total))
  local empty=$((width - filled))
  printf "[%s%s]" "$(repeat_char "=" "${filled}")" "$(repeat_char "." "${empty}")"
}

# Spinner frames (Braille dots; single-width, terminal-only — never logged).
SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# Restore the terminal (clear the spinner line, show the cursor) on any exit, so
# an interrupted or failed run never leaves a hidden cursor or half-drawn bar.
restore_tty() {
  ((HAS_TTY)) || return 0
  printf '\r\033[K\033[?25h' >/dev/tty 2>/dev/null || true
}
trap restore_tty EXIT

# Animate a spinner + overall progress bar on the real terminal while a step
# runs in the background. Writes only to /dev/tty, so nothing reaches the log.
spin() {
  local pid="$1" step="$2" name="$3"
  local i=0 idx
  printf '\033[?25l' >/dev/tty 2>/dev/null || true # hide cursor
  while kill -0 "${pid}" 2>/dev/null; do
    idx=$((i % ${#SPINNER[@]}))
    printf '\r\033[K  %s %s %s' \
      "$(progress_bar "${step}" "${TOTAL_STEPS}")" "${SPINNER[idx]}" "${name}" \
      >/dev/tty 2>/dev/null || true
    i=$((i + 1))
    sleep 0.1
  done
  printf '\r\033[K\033[?25h' >/dev/tty 2>/dev/null || true # clear line + show cursor
}

print_header() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                  🚀  CODESPACES SETUP START  🚀                  ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  printf "  📦 Repository : %s\n" "${REPO_URL}"
  printf "  📖 README     : %s\n" "${README_URL}"
  printf "  👤 User       : %s\n" "$(whoami)"
  printf "  🏠 Home       : %s\n" "${HOME}"
  printf "  🔢 Steps      : %d foreground steps + Neovim preload in background\n" "${TOTAL_STEPS}"
  printf "  📝 Log        : %s  (follow from any shell: tail -f %s)\n" "${SETUP_LOG}" "${SETUP_LOG}"
  echo ""
}

run_step() {
  local step_number="$1"
  local script="$2"
  local name="$3"
  local started_at elapsed rc
  started_at="$(date +%s)"
  CURRENT_STEP="${name}"

  echo ""
  printf "▶ %s [%02d/%02d] %s\n" "$(progress_bar "${step_number}" "${TOTAL_STEPS}")" "${step_number}" "${TOTAL_STEPS}" "${name}"
  printf "  Script     : %s\n" "${script}"

  rc=0
  if ((HAS_TTY)); then
    # Interactive: keep the step's verbose output out of the terminal (it still
    # streams to the log) and show a live spinner + progress bar instead.
    bash "${SCRIPTS_DIR}/${script}" >>"${SETUP_LOG}" 2>&1 &
    local pid=$!
    spin "${pid}" "${step_number}" "${name}"
    wait "${pid}" || rc=$?
  else
    # Non-interactive: stream everything through tee, exactly as before.
    bash "${SCRIPTS_DIR}/${script}" || rc=$?
  fi

  if ((rc == 0)); then
    elapsed=$(($(date +%s) - started_at))
    printf "✓ Completed  : %s (%ss)\n" "${name}" "${elapsed}"
  else
    if ((HAS_TTY)); then
      # The output was hidden behind the spinner; surface recent log context.
      printf '\r\033[K' >/dev/tty 2>/dev/null || true
      echo "----- last 20 lines of ${SETUP_LOG} (full detail there) -----"
      tail -n 20 "${SETUP_LOG}" 2>/dev/null || true
    fi
    elapsed=$(($(date +%s) - started_at))
    FAILED_STEPS+=("${step_number}|${script}|${name}")

    if is_required "${script}"; then
      # A required step is foundational: continuing past it only produces derived
      # failures, so abort now — but still leave the durable signal first, so even
      # this early exit can't pass for success on an unattended run.
      printf "✗ FAILED     : %s (%ss) — REQUIRED, aborting run\n" "${name}" "${elapsed}"
      write_failure_file
      print_failure_summary
      die "Required step failed: ${name} (${script})"
    fi

    # Non-required: record it and keep going so one broken installer can't strand
    # the remaining steps (the whole point — an unattended run must not stop dead
    # on the first flaky download).
    printf "✗ FAILED     : %s (%ss) — continuing with remaining steps\n" "${name}" "${elapsed}"
  fi
}

print_header

log "Ensuring setup scripts are executable..."
chmod +x "${SCRIPTS_DIR}"/*.sh

for i in "${!STEPS[@]}"; do
  IFS="|" read -r script name <<<"${STEPS[$i]}"
  run_step "$((i + 1))"   "${script}" "${name}"
done

CORE_ELAPSED=$(($(date +%s) - SETUP_START_TS))

echo ""
printf "▶ %s [BG] Starting Neovim plugin pre-load\n" "$(progress_bar "${TOTAL_STEPS}" "${TOTAL_STEPS}")"
mkdir -p "${HOME}/.cache"
NVIM_LOG="${HOME}/.cache/nvim-setup.log"
# Guard existence: SETUP_SCRIPTS_DIR may be a test fixture without this script.
if [[ -f "${SCRIPTS_DIR}/13-nvim-plugins.sh" ]]; then
  bash "${SCRIPTS_DIR}/13-nvim-plugins.sh" >"${NVIM_LOG}" 2>&1 &
  NVIM_SETUP_PID=$!
  printf "✓ Started    : Neovim plugin pre-load (PID: %s)\n" "${NVIM_SETUP_PID}"
  printf "  Monitor    : tail -f %s\n" "${NVIM_LOG}"
  printf "  Wait       : wait %s\n" "${NVIM_SETUP_PID}"
else
  printf "• Skipped    : Neovim plugin pre-load (%s not present)\n" "${SCRIPTS_DIR}/13-nvim-plugins.sh"
fi

# Choose the closing banner from the actual outcome: a partial run must never
# print the green "COMPLETE" banner, or the whole point of tracking failures is
# lost.
echo ""
if ((${#FAILED_STEPS[@]} == 0)); then
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                🎉  CODESPACES SETUP COMPLETE  🎉                 ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
else
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║             ⚠️   CODESPACES SETUP INCOMPLETE  ⚠️                 ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  printf "  ❗ %d of %d step(s) failed — details in the summary below.\n" "${#FAILED_STEPS[@]}" "${TOTAL_STEPS}"
fi
printf "  🕒 Core setup : completed in %ss\n" "${CORE_ELAPSED}"
printf "  👉 Next step  : run 'exec zsh' in this terminal if you want to switch now\n"
printf "  🐚 New shells : should open in zsh automatically\n"
printf "  📖 README     : %s\n" "${README_URL}"
printf "  📝 Setup log  : %s\n" "${SETUP_LOG}"
printf "  📋 Nvim log   : %s\n" "${NVIM_LOG}"

# Print a verification summary so the user can confirm every tool landed.
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          🔍  SETUP VERIFICATION SUMMARY  🔍          ║"
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
check_tool "tig"        tig        --version
check_tool "atuin"      atuin      --version
check_tool "uv"         uv         --version
check_tool "claude"     claude     --version
check_tool "gh"         gh         --version
check_tool "az"         az         --version
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

if [[ -f "${HOME}/.claude/skills/engineering-team/SKILL.md" &&
     -f "${HOME}/.claude/commands/done.md" &&
     -f "${HOME}/.claude/commands/merge-push.md" &&
     -f "${HOME}/.claude/commands/prompt.md" ]]; then
  printf "  ✅  %-18s engineering-team, /done, /merge-push, /prompt\n" "Claude skills"
else
  printf "  ❌  %-18s missing (see %s)\n" "Claude skills" "${SETUP_LOG}"
fi

NVIM_LOG="${NVIM_LOG:-${HOME}/.cache/nvim-setup.log}"

echo ""
echo "  🐚 Shell config : ${HOME}/.zshrc"
echo "  📜 Aliases      : ${HOME}/.zsh_aliases"
echo "  🔧 Git config   : ${HOME}/.gitconfig"
echo "  🔌 Nvim plugins : tail -f ${NVIM_LOG}"
echo ""

# Final outcome. Any failed step means the run did not complete: write the
# durable signal, print the summary that names each failure, and exit non-zero.
# A clean run removes any stale signal from a previous failed run so a later
# success silences the shell-start warning.
if ((${#FAILED_STEPS[@]} > 0)); then
  write_failure_file
  print_failure_summary
  echo ""
  exit 1
fi

rm -f "${SETUP_FAILURE_FILE}"
