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
#   tail -f <repo>/.setup-logs/latest.log
# This works even when setup.sh runs in the background, e.g. as the Codespaces
# postCreateCommand, which is the path where nobody is watching the terminal.
# Every run gets an id. Without one the log was a single append-only file with
# no timestamps and no run boundary, so `tail -n 200` silently spliced two runs
# together and there was no way to tell today's rebuild from last week's.
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
RUN_STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Logs go NEXT TO THE SCRIPT by default, because that is where someone standing
# in a broken Codespace already is. ~/.cache is a fine place for a file you know
# the name of and a poor place to discover one. Fall back to ~/.cache when the
# repo directory is not writable (the dotfiles path can land read-only).
if [[ -z "${SETUP_LOG_DIR:-}" ]]; then
  if mkdir -p "${REPO_DIR}/.setup-logs" 2>/dev/null && [[ -w "${REPO_DIR}/.setup-logs" ]]; then
    SETUP_LOG_DIR="${REPO_DIR}/.setup-logs"
  else
    SETUP_LOG_DIR="${HOME}/.cache"
  fi
fi
mkdir -p "${SETUP_LOG_DIR}"

SETUP_LOG="${SETUP_LOG:-${SETUP_LOG_DIR}/setup-${RUN_ID}.log}"
mkdir -p "$(dirname "${SETUP_LOG}")"

# A stable name that always points at the most recent run, so the documented
# `tail -f` command keeps working and does not need the run id.
SETUP_LATEST_LOG="${SETUP_LOG_DIR}/latest.log"

# The machine-readable record. Everything a diagnosis needs was already being
# computed - per-step status, duration, retry attempts, tool presence - and then
# thrown away, leaving only prose banners nothing could parse.
SETUP_SUMMARY="${SETUP_SUMMARY:-${SETUP_LOG_DIR}/summary-${RUN_ID}.json}"
SETUP_LATEST_SUMMARY="${SETUP_LOG_DIR}/latest.json"

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
ln -sf "${SETUP_LOG}" "${SETUP_LATEST_LOG}" 2>/dev/null || true

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

# Hard dependencies between steps: "script:dependency[,dependency...]".
#
# These were unreachable before a non-required failure stopped aborting the run —
# the run died at the dependency, so the dependent never ran. Now it does, and it
# fails for a reason that has nothing to do with itself: 09-uv.sh failing produced
# TWO entries in the FAILED banner, with nothing saying which was the cause and
# which the consequence. Marking dependents SKIPPED keeps one root cause to one
# line, and stops a derived failure being re-attempted by the retry pass (which
# would just fail again, slowly).
#
# Overridable for tests via SETUP_DEPS; empty means "no dependencies".
if [[ -n "${SETUP_DEPS+defined}" ]]; then
  IFS=';' read -r -a STEP_DEPS <<<"${SETUP_DEPS}"
else
  STEP_DEPS=(
    "18-azure-cli.sh:09-uv.sh"
    "15-dev-tools.sh:02-nodejs.sh,09-uv.sh"
    "04-neovim-config.sh:03-neovim.sh"
  )
fi

# A wall clock for an entire step, as a backstop behind the per-operation bound
# inside `retry` (scripts/lib.sh).
#
# The retry-level timeout covers a stalled download, which is the common case.
# It does NOT cover a step that hangs for any other reason — a debconf prompt
# with no tty to answer it, a sudo password prompt, apt blocking on the dpkg
# lock, a compile that never finishes. Without a bound here, one such step stops
# the whole run dead and the platform eventually reaps the process tree, which
# is the outcome that leaves the least evidence.
#
# Generous by design: 20 minutes is far longer than any real step (the slowest,
# Node, is a ~45 MB download) and short enough that a wedged run still reports
# rather than being killed from outside. 0 disables it.
SETUP_STEP_TIMEOUT="${SETUP_STEP_TIMEOUT:-1200}"

TOTAL_STEPS="${#STEPS[@]}"
SETUP_START_TS="$(date +%s)"
CURRENT_STEP=""
CURRENT_SCRIPT=""
# Each step that exits non-zero is recorded here as "NN|script|name"; the run
# keeps going and reports them all at the end.
declare -a FAILED_STEPS=()
# Tools the verification summary found missing. Before this existed the summary
# printed a cross and then the run printed the green COMPLETE banner and exited
# 0 - so a Codespace missing tools reported success, which is the single most
# confusing thing this script did.
declare -a MISSING_TOOLS=()
# Every step's outcome as "NN|script|name|status|seconds|attempts", including the
# ones that succeeded. FAILED_STEPS only ever recorded failures, so nothing could
# answer "which steps ran, in what order, and how long did they take".
declare -a STEP_RECORDS=()
# Scratch for the end-of-run retry pass.
# Steps not run because a dependency failed, as "NN|script|name|blocker".
declare -a SKIPPED_STEPS=()
declare -a RETRY_TARGETS=()
RECOVERED=0
entry=""
rnum=""
rscript=""
rname=""
before=0

log() { echo "[setup] $*"; }
die() {
  if [[ -n "${CURRENT_STEP}" ]]; then
    echo "[setup] ERROR: ${*} (current step: ${CURRENT_STEP})" >&2
  else
    echo "[setup] ERROR: $*" >&2
  fi
  exit 1
}

# Names of steps that have already failed, for the dependency check below.
failed_scripts() {
  local entry n s nm
  for entry in ${FAILED_STEPS[@]+"${FAILED_STEPS[@]}"}; do
    IFS="|" read -r n s nm <<<"${entry}"
    printf '%s\n' "${s}"
  done
}

# If this step declares a dependency that already failed, name it. Prints the
# failed dependency and returns 0; returns 1 when the step is good to run.
blocked_by() {
  local candidate="$1" spec dep_script deps dep failed
  failed="$(failed_scripts)"
  for spec in ${STEP_DEPS[@]+"${STEP_DEPS[@]}"}; do
    dep_script="${spec%%:*}"
    [[ "${dep_script}" == "${candidate}" ]] || continue
    deps="${spec#*:}"
    IFS=',' read -r -a _deps <<<"${deps}"
    for dep in "${_deps[@]}"; do
      if printf '%s\n' "${failed}" | grep -qx -- "${dep}"; then
        printf '%s' "${dep}"
        return 0
      fi
    done
  done
  return 1
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
  local entry n s nm t
  mkdir -p "$(dirname "${SETUP_FAILURE_FILE}")"
  {
    echo "⚠️  codespaces-setup did NOT finish cleanly (last run: $(date))."
    echo ""
    if ((${#FAILED_STEPS[@]} > 0)); then
      echo "Failed step(s):"
      for entry in "${FAILED_STEPS[@]}"; do
        IFS="|" read -r n s nm <<<"${entry}"
        printf "  ✗ [%s] %s (%s)\n" "${n}" "${nm}" "${s}"
      done
      echo ""
    fi
    if ((${#MISSING_TOOLS[@]} > 0)); then
      if ((${#FAILED_STEPS[@]} == 0)); then
        # The genuinely surprising case, and the defect this check was added
        # for: every step exited 0 and the tool still is not there.
        echo "Missing after setup (every step reported success, but these are absent):"
      else
        # Some steps failed, so a missing tool is very likely just that step's
        # tool. Saying "reported success" here would be false — and a diagnostic
        # that lies is worse than one that says less.
        echo "Missing after setup:"
      fi
      for t in "${MISSING_TOOLS[@]}"; do
        printf "  ✗ %s\n" "${t}"
      done
      echo ""
    fi
    echo "Your environment is only partially set up. To fix it:"
    echo "  bash ${REPO_DIR}/setup.sh      # re-run (idempotent; safe to repeat)"
    echo "  tail -n 200 ${SETUP_LOG}       # see what went wrong"
    echo ""
    echo "This notice clears itself once setup completes with no failures."
  } >"${SETUP_FAILURE_FILE}"
}

# Write the machine-readable run record. This is what `setup-status` reads and
# what makes "which steps ran, and what did they cost" answerable after the fact.
# Hand-rolled JSON: this runs on a bare Codespace before any step has installed
# jq or python, so it cannot depend on either. Only the fields below are
# interpolated and they are all controlled by this script, so escaping is limited
# to backslashes and quotes in the free-text fields.
json_escape() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  printf '%s' "${str}"
}

write_summary() {
  local outcome="$1"
  local entry n s nm st sec att first t
  mkdir -p "$(dirname "${SETUP_SUMMARY}")"
  {
    printf '{\n'
    printf '  "schema": 1,\n'
    printf '  "run_id": "%s",\n' "$(json_escape "${RUN_ID}")"
    printf '  "started_at": "%s",\n' "${RUN_STARTED_AT}"
    printf '  "ended_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "outcome": "%s",\n' "${outcome}"
    printf '  "elapsed_seconds": %s,\n' "$(($(date +%s) - SETUP_START_TS))"
    printf '  "interactive": %s,\n' "$( ((HAS_TTY)) && echo true || echo false)"
    printf '  "log": "%s",\n' "$(json_escape "${SETUP_LOG}")"
    printf '  "repo_dir": "%s",\n' "$(json_escape "${REPO_DIR}")"
    printf '  "total_steps": %s,\n' "${TOTAL_STEPS}"
    printf '  "steps": [\n'
    first=1
    for entry in ${STEP_RECORDS[@]+"${STEP_RECORDS[@]}"}; do
      IFS="|" read -r n s nm st sec att <<<"${entry}"
      ((first)) || printf ',\n'
      first=0
      printf '    {"n": %s, "script": "%s", "name": "%s", "status": "%s", "seconds": %s, "attempts": %s}' \
        "${n}" "$(json_escape "${s}")" "$(json_escape "${nm}")" "${st}" "${sec}" "${att}"
    done
    printf '\n  ],\n'
    printf '  "missing_tools": ['
    first=1
    for t in ${MISSING_TOOLS[@]+"${MISSING_TOOLS[@]}"}; do
      ((first)) || printf ', '
      first=0
      printf '"%s"' "$(json_escape "${t}")"
    done
    printf ']\n'
    printf '}\n'
  } >"${SETUP_SUMMARY}"
  ln -sf "${SETUP_SUMMARY}" "${SETUP_LATEST_SUMMARY}" 2>/dev/null || true
}

# Print the end-of-run FAILED summary banner listing every failed step.
# $1: "aborted" when a REQUIRED step stopped the run, so the summary does not
# claim the remaining steps ran when they did not.
print_failure_summary() {
  local mode="${1:-completed}" entry n s nm t b
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                  ❌  CODESPACES SETUP FAILED  ❌                  ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  if ((${#FAILED_STEPS[@]} > 0)); then
    if [[ "${mode}" == "aborted" ]]; then
      printf "  A required step failed, so the run aborted and %d later step(s) never ran:\n" \
        "$((TOTAL_STEPS - ${#FAILED_STEPS[@]}))"
    else
      printf "  %d of %d step(s) failed — the rest still ran:\n" "${#FAILED_STEPS[@]}" "${TOTAL_STEPS}"
    fi
    for entry in "${FAILED_STEPS[@]}"; do
      IFS="|" read -r n s nm <<<"${entry}"
      printf "    ✗ [%s] %s (%s)\n" "${n}" "${nm}" "${s}"
    done
  fi
  if ((${#SKIPPED_STEPS[@]} > 0)); then
    printf "  %d step(s) were skipped because something they depend on failed:\n" "${#SKIPPED_STEPS[@]}"
    for entry in "${SKIPPED_STEPS[@]}"; do
      IFS="|" read -r n s nm b <<<"${entry}"
      printf "    - [%s] %s (%s) — needs %s\n" "${n}" "${nm}" "${s}" "${b}"
    done
  fi
  if ((${#MISSING_TOOLS[@]} > 0)); then
    if ((${#FAILED_STEPS[@]} == 0)); then
      printf "  %d tool(s) are missing even though every step reported success:\n" "${#MISSING_TOOLS[@]}"
    else
      printf "  %d tool(s) are missing after this run:\n" "${#MISSING_TOOLS[@]}"
    fi
    for t in "${MISSING_TOOLS[@]}"; do
      printf "    ✗ %s\n" "${t}"
    done
  fi
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

# Set once the run has printed its own verdict, so the EXIT trap knows the
# outcome was already reported and does not overwrite it.
RUN_FINALISED=0

# An interrupted run must leave a mark. This is the failure mode that used to
# leave NOTHING: Codespaces enforces a creation-time budget and reaps
# postCreateCommand, and with no timeout anywhere (before W1) a stalled download
# made reaping the expected outcome, not an edge case. write_failure_file was
# only ever called from two in-flow paths, so a SIGTERM, an OOM kill, or `set -e`
# firing anywhere outside run_step exited with no signal, no banner, and no
# record — indistinguishable from a clean run to every later shell.
on_interrupt() {
  local sig="$1"
  restore_tty
  ((RUN_FINALISED)) && exit 0
  RUN_FINALISED=1
  echo ""
  echo "[setup] INTERRUPTED by ${sig}${CURRENT_STEP:+ during: ${CURRENT_STEP}}"
  if [[ -n "${CURRENT_STEP}" ]]; then
    FAILED_STEPS+=("--|${CURRENT_SCRIPT:-unknown}|${CURRENT_STEP} (interrupted by ${sig})")
    # Record it as a step too, so the run record shows WHICH step was in flight
    # rather than an empty list. This is the whole question someone asks after a
    # Codespace creation is reaped.
    STEP_RECORDS+=("${#STEP_RECORDS[@]}|${CURRENT_SCRIPT:-unknown}|${CURRENT_STEP}|interrupted|$(($(date +%s) - SETUP_START_TS))|1")
  fi
  write_failure_file
  write_summary "interrupted"
  exit 130
}

on_exit() {
  local rc=$?
  restore_tty
  ((RUN_FINALISED)) && return
  # A non-zero exit that never reached the verdict block: `set -e` fired
  # somewhere outside a step. Record it rather than vanishing.
  if ((rc != 0)); then
    RUN_FINALISED=1
    write_failure_file
    write_summary "aborted"
  fi
}

trap 'on_interrupt INT' INT
trap 'on_interrupt TERM' TERM
trap on_exit EXIT

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
  printf "  🆔 Run id     : %s\n" "${RUN_ID}"
  printf "  🕐 Started    : %s\n" "${RUN_STARTED_AT}"
  printf "  📝 Log        : %s\n" "${SETUP_LOG}"
  printf "                  (follow from any shell: tail -f %s)\n" "${SETUP_LATEST_LOG}"
  printf "  📊 Summary    : %s\n" "${SETUP_SUMMARY}"
  echo ""
}

# Invoke one step, under a wall clock when `timeout` is available. Exit code 124
# is timeout(1)'s "the command ran out of time", which run_step reports as a
# failure like any other — the point is that it REPORTS, rather than hanging.
run_one() {
  local script="$1"
  if ((SETUP_STEP_TIMEOUT > 0)) && command -v timeout >/dev/null 2>&1; then
    timeout --foreground "${SETUP_STEP_TIMEOUT}" bash "${SCRIPTS_DIR}/${script}"
  else
    bash "${SCRIPTS_DIR}/${script}"
  fi
}

run_step() {
  local step_number="$1"
  local script="$2"
  local name="$3"
  local started_at elapsed rc attempts blocker
  # A step whose dependency already failed is SKIPPED, not failed: reporting it
  # as a failure duplicates one root cause across two lines and sends the reader
  # to the wrong script.
  if blocker="$(blocked_by "${script}")"; then
    echo ""
    printf "▶ %s [%02d/%02d] %s\n" "$(progress_bar "${step_number}" "${TOTAL_STEPS}")" \
      "${step_number}" "${TOTAL_STEPS}" "${name}"
    printf "• Skipped    : depends on %s, which failed\n" "${blocker}"
    STEP_RECORDS+=("${step_number}|${script}|${name}|skipped|0|0")
    SKIPPED_STEPS+=("${step_number}|${script}|${name}|${blocker}")
    return 0
  fi
  started_at="$(date +%s)"
  CURRENT_STEP="${name}"
  CURRENT_SCRIPT="${script}"
  # Steps run as separate `bash` processes, so RETRY_LAST_ATTEMPTS (set inside
  # lib.sh in the CHILD) cannot propagate back. A step reports its own retry
  # count by writing it here; absent means "did not retry".
  RETRY_COUNT_FILE="$(mktemp)"
  export RETRY_COUNT_FILE

  echo ""
  printf "▶ %s [%02d/%02d] %s  (%s)\n" "$(progress_bar "${step_number}" "${TOTAL_STEPS}")" \
    "${step_number}" "${TOTAL_STEPS}" "${name}" "$(date -u +%H:%M:%SZ)"
  printf "  Script     : %s\n" "${script}"

  rc=0
  if ((HAS_TTY)); then
    # Interactive: keep the step's verbose output out of the terminal (it still
    # streams to the log) and show a live spinner + progress bar instead.
    run_one "${script}" >>"${SETUP_LOG}" 2>&1 &
    local pid=$!
    spin "${pid}" "${step_number}" "${name}"
    wait "${pid}" || rc=$?
  else
    # Non-interactive: stream everything through tee, exactly as before.
    run_one "${script}" || rc=$?
  fi

  attempts="$(cat "${RETRY_COUNT_FILE}" 2>/dev/null || echo 1)"
  [[ "${attempts}" =~ ^[0-9]+$ ]] || attempts=1
  rm -f "${RETRY_COUNT_FILE}"

  if ((rc == 0)); then
    elapsed=$(($(date +%s) - started_at))
    STEP_RECORDS+=("${step_number}|${script}|${name}|ok|${elapsed}|${attempts}")
    printf "✓ Completed  : %s (%ss)\n" "${name}" "${elapsed}"
  else
    if ((HAS_TTY)); then
      # The output was hidden behind the spinner; surface recent log context.
      #
      # Written to /dev/tty, NOT to stdout — stdout is redirected into
      # `tee -a "${SETUP_LOG}"`, so echoing a tail of the log to stdout appended
      # 20 lines of the log back INTO the log, and the next failure's tail then
      # re-read the injected copy. Five failing steps turned 25 real lines into
      # 220, complete with duplicated run headers and steps appearing to complete
      # twice out of order. The log became a false record on exactly the run
      # where someone is reading it, and only interactively — which is the mode a
      # user enters when following the "re-run to fix it" advice.
      {
        printf '\r\033[K'
        printf -- '----- last 20 lines of %s (full detail there) -----\n' "${SETUP_LOG}"
        tail -n 20 "${SETUP_LOG}" 2>/dev/null || true
      } >/dev/tty 2>/dev/null || true
    fi
    elapsed=$(($(date +%s) - started_at))
    STEP_RECORDS+=("${step_number}|${script}|${name}|failed|${elapsed}|${attempts}")
    FAILED_STEPS+=("${step_number}|${script}|${name}")

    if is_required "${script}"; then
      # A required step is foundational: continuing past it only produces derived
      # failures, so abort now — but still leave the durable signal first, so even
      # this early exit can't pass for success on an unattended run.
      printf "✗ FAILED     : %s (%ss) — REQUIRED, aborting run\n" "${name}" "${elapsed}"
      RUN_FINALISED=1
      write_failure_file
      write_summary "aborted"
      print_failure_summary aborted
      die "Required step failed: ${name} (${script})"
    fi

    # Non-required: record it and keep going so one broken installer can't strand
    # the remaining steps (the whole point — an unattended run must not stop dead
    # on the first flaky download).
    if ((rc == 124)); then
      printf "✗ TIMED OUT  : %s (%ss) — exceeded SETUP_STEP_TIMEOUT=%ss\n" \
        "${name}" "${elapsed}" "${SETUP_STEP_TIMEOUT}"
    fi
    printf "✗ FAILED     : %s (%ss) — continuing with remaining steps\n" "${name}" "${elapsed}"
  fi
}

print_header

# NOTE: there is deliberately no `chmod +x` here. Every step is invoked as
# `bash "${SCRIPTS_DIR}/${script}"` (see run_step), so the execute bit is never
# consulted. The chmod that used to live here could only ever *cause* a failure —
# unguarded under `set -e`, on a read-only checkout it aborted the whole run
# before a single step ran, and left no signal because it was outside run_step.

for i in "${!STEPS[@]}"; do
  IFS="|" read -r script name <<<"${STEPS[$i]}"
  run_step "$((i + 1))"   "${script}" "${name}"
done

# Second pass: re-attempt the steps that failed.
#
# The per-download `retry` in scripts/lib.sh covers a hiccup lasting seconds. It
# does not cover the case this pass exists for: a Codespace VM whose network is
# not fully up when postCreateCommand fires, where the first few steps fail and
# everything after them succeeds. By the end of a run that is minutes later, so
# a single re-attempt converts those into a clean setup instead of a half-built
# environment and a support question.
#
# Safe to do only because every step is now genuinely idempotent — the guards
# run the artifact rather than stat-ing it (see scripts/lib.sh), so a re-run
# repairs a broken install instead of skipping it. Before that work this pass
# would have been useless on exactly the failures it targets.
#
# Set SETUP_RETRY_PASS=0 to disable.
if [[ "${SETUP_RETRY_PASS:-1}" == "1" && ${#FAILED_STEPS[@]} -gt 0 ]]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║              🔁  RETRYING FAILED STEPS (one pass)  🔁             ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  printf "  %d step(s) failed on the first pass. Transient failures often clear\n" "${#FAILED_STEPS[@]}"
  printf "  by now — re-attempting each once before reporting.\n"

  RETRY_TARGETS=("${FAILED_STEPS[@]}")
  FAILED_STEPS=()
  RECOVERED=0

  for entry in "${RETRY_TARGETS[@]}"; do
    IFS="|" read -r rnum rscript rname <<<"${entry}"
    # run_step appends to FAILED_STEPS on failure. Compare the count either side
    # rather than inspecting the last element — the count is unambiguous, and a
    # substring match on the script name would misreport for similarly-named
    # scripts.
    before="${#FAILED_STEPS[@]}"
    # Keep the original name in the record — the "retrying" marker belongs in
    # the live output, not baked into the step's identity, or setup-status
    # reports "Flaky step (retry)" as the step's name forever.
    printf "  ↻ Retrying   : %s\n" "${rname}"
    run_step "${rnum}" "${rscript}" "${rname}"
    if ((${#FAILED_STEPS[@]} == before)); then
      RECOVERED=$((RECOVERED + 1))
      printf "  ✅ Recovered  : %s\n" "${rname}"
    fi
  done

  printf "  🔁 Retry pass : %d recovered, %d still failing\n" \
    "${RECOVERED}" "${#FAILED_STEPS[@]}"
fi

CORE_ELAPSED=$(($(date +%s) - SETUP_START_TS))

echo ""
printf "▶ %s [BG] Starting Neovim plugin pre-load\n" "$(progress_bar "${TOTAL_STEPS}" "${TOTAL_STEPS}")"
mkdir -p "${HOME}/.cache"
NVIM_LOG="${HOME}/.cache/nvim-setup.log"
# Guard existence: SETUP_SCRIPTS_DIR may be a test fixture without this script.
if [[ -f "${SCRIPTS_DIR}/13-nvim-plugins.sh" ]]; then
  # Append, not truncate: `>` destroyed the previous run's evidence, so
  # re-running setup.sh to investigate a broken Neovim erased the log that
  # would have explained it.
  {
    echo ""
    echo "=== run ${RUN_ID} @ $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  } >>"${NVIM_LOG}"
  bash "${SCRIPTS_DIR}/13-nvim-plugins.sh" >>"${NVIM_LOG}" 2>&1 &
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
# The verdict banner is NOT printed here. It used to be, which meant the run
# announced "COMPLETE" before the verification summary below had established
# whether any tool actually landed - and then printed the missing ones
# underneath the green banner. The banner now comes after verification.
printf "  🕒 Core setup : completed in %ss\n" "${CORE_ELAPSED}"
printf "  👉 Next step  : run 'exec zsh' in this terminal if you want to switch now\n"
printf "  🐚 New shells : should open in zsh automatically\n"
printf "  📖 README     : %s\n" "${README_URL}"
printf "  📝 Setup log  : %s\n" "${SETUP_LOG}"
printf "  📋 Nvim log   : %s\n" "${NVIM_LOG}"

echo ""

# Decide presence with `command -v`, and capture the version separately.
#
# The old form was `if version_output="$("$bin" "$@" 2>/dev/null | head -1)"`,
# which took the PIPELINE's status. That worked only because `pipefail` is set
# 300 lines above, and it mis-reported in both directions: a tool whose
# --version output outran head's buffer took SIGPIPE and was reported "not
# found", while a tool printing its version to stderr showed a blank check mark.
# Neither was visible from here, and both become load-bearing now that the
# result decides the exit code.
check_tool() {
  local label="$1"
  local bin="$2"
  shift 2
  local version_output
  if ! command -v "${bin}" >/dev/null 2>&1; then
    printf "  ❌  %-18s not found\n" "${label}"
    MISSING_TOOLS+=("${label}")
    return
  fi
  # Prefer stdout; fall back to stderr only when stdout is empty. Taking 2>&1
  # unconditionally would show a tool's upgrade warning in place of its version
  # (az does this), while dropping stderr entirely would show a blank line for
  # tools that print their version there.
  version_output="$("${bin}" "$@" 2>/dev/null | head -1 || true)"
  if [[ -z "${version_output}" ]]; then
    version_output="$("${bin}" "$@" 2>&1 | head -1 || true)"
  fi
  printf "  ✅  %-18s %s\n" "${label}" "${version_output:-(installed)}"
}

# Same, for the things a run installs that are not binaries on PATH. setup.sh
# used to merely *print* these paths at the end, which reads like verification
# and is not.
check_path() {
  local label="$1" path="$2"
  if [[ -e "${path}" ]]; then
    printf "  ✅  %-18s %s\n" "${label}" "${path}"
  else
    printf "  ❌  %-18s missing: %s\n" "${label}" "${path}"
    MISSING_TOOLS+=("${label}")
  fi
}

# Test hook: SETUP_SKIP_VERIFY=1 skips the checks below. The resilience harness
# drives this runner over FAKE steps that install nothing, so looking for real
# tools there would be a category error - it tests the runner, not the
# installers. Unset in every real run, and scenario 5 deliberately leaves it
# unset so this block itself stays covered.
if [[ "${SETUP_SKIP_VERIFY:-0}" == "1" ]]; then
  log "SETUP_SKIP_VERIFY=1 - skipping tool verification (test hook)."
else
  check_tool "zsh"        zsh        --version
  check_tool "node"       node       --version
  # npm was never checked, yet 15-dev-tools.sh gates four tools on it.
  check_tool "npm"        npm        --version
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
  check_tool "mypy"       mypy       --version

  FONT_DIR="${HOME}/.local/share/fonts/MesloLGS-NF"
  check_path "MesloLGS NF" "${FONT_DIR}/MesloLGS NF Regular.ttf"

  check_path "Claude skill" "${HOME}/.claude/skills/engineering-team/SKILL.md"
  check_path "/done"       "${HOME}/.claude/commands/done.md"
  check_path "/merge-push" "${HOME}/.claude/commands/merge-push.md"
  check_path "/prompt"     "${HOME}/.claude/commands/prompt.md"

  # Config artefacts the run produces that are not binaries. setup.sh used to
  # print these paths at the end, which reads like verification and is not.
  check_path "zshrc"       "${HOME}/.zshrc"
  check_path "oh-my-zsh"   "${HOME}/.oh-my-zsh/oh-my-zsh.sh"
  check_path "nvim config" "${HOME}/.config/nvim"

  # The background plugin pre-load writes its own status, since setup.sh does not
  # wait for it. Reported, but NOT counted as a missing tool: it is still running
  # when this summary prints, and a missing plugin should not fail a Codespace.
  NVIM_STATUS_FILE="${HOME}/.cache/nvim-setup.status"
  if [[ -f "${NVIM_STATUS_FILE}" ]]; then
    case "$(head -1 "${NVIM_STATUS_FILE}")" in
      ok) printf "  ✅  %-18s plugins and parsers ready\n" "nvim plugins" ;;
      running) printf "  ⏳  %-18s still installing (tail -f %s)\n" "nvim plugins" "${NVIM_LOG}" ;;
      *) printf "  ⚠️   %-18s incomplete — see %s\n" "nvim plugins" "${NVIM_LOG}" ;;
    esac
  fi
fi

NVIM_LOG="${NVIM_LOG:-${HOME}/.cache/nvim-setup.log}"

echo ""
echo "  🐚 Shell config : ${HOME}/.zshrc"
echo "  📜 Aliases      : ${HOME}/.zsh_aliases"
echo "  🔧 Git config   : ${HOME}/.gitconfig"
echo "  🔌 Nvim plugins : tail -f ${NVIM_LOG}"
echo ""

# Final outcome, decided by BOTH signals: a step that exited non-zero, and a
# tool that is absent even though its step reported success. The second half is
# new and is the whole point - a run used to print a cross for every missing
# tool and then exit 0 with the green banner, so a half-built Codespace
# reported success and the shell-start notice never fired.
echo ""
if ((${#FAILED_STEPS[@]} == 0 && ${#MISSING_TOOLS[@]} == 0)); then
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                🎉  CODESPACES SETUP COMPLETE  🎉                 ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  # A clean run clears any stale signal from a previous failed run, so a later
  # success silences the shell-start warning.
  rm -f "${SETUP_FAILURE_FILE}"
  RUN_FINALISED=1
  write_summary "complete"
else
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║             ⚠️   CODESPACES SETUP INCOMPLETE  ⚠️                 ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  ((${#FAILED_STEPS[@]} > 0)) &&
    printf "  ❗ %d of %d step(s) failed.\n" "${#FAILED_STEPS[@]}" "${TOTAL_STEPS}"
  ((${#MISSING_TOOLS[@]} > 0)) &&
    printf "  ❗ %d tool(s) missing after a step that reported success.\n" "${#MISSING_TOOLS[@]}"
  RUN_FINALISED=1
  write_failure_file
  write_summary "incomplete"
  print_failure_summary
  printf "  📊 Run record   : %s\n" "${SETUP_SUMMARY}"
  printf "  🔎 Status       : setup-status\n"
  echo ""
  exit 1
fi
