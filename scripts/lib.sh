#!/usr/bin/env bash
# Shared helpers for the setup scripts.
#
# This file is SOURCED, never executed as a step: it holds nothing to run on its
# own, only functions the numbered scripts pull in. It is therefore deliberately
# absent from setup.sh's STEPS array and listed as EXEMPT in ci/lint-steps.sh.
# (It is committed 100755 like every other file in scripts/, which ci/lint-steps.sh
# checks — the mode is uniform for the directory, not because anything execs it.)
#
# Source it from a step with:
#   # shellcheck source=scripts/lib.sh
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# retry <cmd...> — run a command, retrying on any non-zero exit with exponential
# backoff. This is the shared answer to the failure mode that dominates this
# repo: nearly every step fetches something over the network, so a *transient*
# hiccup (DNS blip, a flaky release CDN, a proxy that drops one connection) is
# the expected way a step fails, not the exception. Wrapping the download/install
# in a few backed-off attempts turns most of those into a non-event.
#
# A RETRY WRAPS FAILURE, NOT SLOWNESS — hence RETRY_TIMEOUT below. `retry` can
# only act once the command *exits*: a stalled TCP connection, a DNS lookup with
# no answer, or a download trickling at 2 KB/s never returns, so without a wall
# clock the whole run stops dead on one step and the platform eventually reaps it
# with nothing written down. Every attempt therefore runs under `timeout`.
#
# Tunables (env, so a caller or a test can override without changing call sites):
#   RETRY_ATTEMPTS    total attempts before giving up    (default 5)
#   RETRY_BASE_DELAY  seconds to wait after the 1st fail (default 5), doubled
#                     after each subsequent failure and capped at RETRY_MAX_DELAY
#   RETRY_MAX_DELAY   ceiling on the backoff             (default 60)
#   RETRY_TIMEOUT     wall clock for ONE attempt, seconds (default 180); set to
#                     0 to disable the bound (used by the tests that pass shell
#                     functions, which `timeout` cannot exec)
#
# Budget note: these numbers multiply. RETRY_TIMEOUT bounds one attempt, so the
# worst case for a step whose network is entirely dead is
# RETRY_ATTEMPTS x RETRY_TIMEOUT plus backoff — about 15 minutes at the defaults.
# That is deliberately long enough to ride out a slow link and short enough to
# stay inside a Codespace creation window. It was previously unbounded.
#
# Defaults are deliberately more patient than they look: the two dominant causes
# here are a Codespace VM whose network is not up yet when postCreateCommand
# fires, and apt's dpkg lock held by unattended-upgrades. Both routinely outlast
# the old 3+6+12 = 21s budget. 5 attempts at base 5 gives ~75s of backoff.
#
# Jitter is applied to each sleep so that many Codespaces created at once do not
# retry in lockstep against the same CDN.
#
# Returns the command's own exit code from the final attempt, so callers can
# still branch on failure (`retry curl ... || handle`). It intentionally does
# NOT swallow failure — a step that must abort still can.
#
# RETRY_LAST_ATTEMPTS is set on return to the number of attempts made, so a
# caller (setup.sh's run record) can report how much retrying a step needed.
retry() {
  # Locals are prefixed to avoid bash's dynamic scoping clobbering a variable of
  # the same name inside the command being retried (a function passed to retry
  # would otherwise see and mutate these).
  local _retry_attempts="${RETRY_ATTEMPTS:-5}"
  local _retry_delay="${RETRY_BASE_DELAY:-5}"
  local _retry_max_delay="${RETRY_MAX_DELAY:-60}"
  local _retry_timeout="${RETRY_TIMEOUT:-180}"
  local _retry_n=1 _retry_rc=0 _retry_sleep

  while true; do
    # `cmd && return 0` (not `if cmd`) so that $? below is the command's own exit
    # code: an `if` with no else resets $? to 0 when the condition is false.
    _retry_run "${_retry_timeout}" "$@" && {
      # shellcheck disable=SC2034  # for a same-process caller; steps use _retry_report
      RETRY_LAST_ATTEMPTS="${_retry_n}"
      _retry_report "${_retry_n}"
      return 0
    }
    _retry_rc=$?
    if ((_retry_n >= _retry_attempts)); then
      # shellcheck disable=SC2034  # for a same-process caller; steps use _retry_report
      RETRY_LAST_ATTEMPTS="${_retry_n}"
      _retry_report "${_retry_n}"
      _retry_log "command failed after ${_retry_n} attempt(s) (exit ${_retry_rc}): $*"
      return "${_retry_rc}"
    fi
    # Jitter: up to +50% of the current delay, so concurrent runs desynchronise.
    _retry_sleep=$((_retry_delay + RANDOM % (_retry_delay / 2 + 1)))
    _retry_log "attempt ${_retry_n}/${_retry_attempts} failed (exit ${_retry_rc}); retrying in ${_retry_sleep}s: $*"
    sleep "${_retry_sleep}"
    _retry_delay=$((_retry_delay * 2))
    ((_retry_delay > _retry_max_delay)) && _retry_delay="${_retry_max_delay}"
    _retry_n=$((_retry_n + 1))
  done
}

# Report the attempt count to the parent. Each step runs as its own `bash`
# process, so a shell variable cannot travel back to setup.sh — it writes the
# high-water mark to the file named by RETRY_COUNT_FILE, which setup.sh creates
# per step and reads after the step exits. Silent no-op when unset, so a step run
# by hand (`bash scripts/05-eza.sh`) behaves exactly as before.
_retry_report() {
  local n="$1" prev=0
  [[ -n "${RETRY_COUNT_FILE:-}" ]] || return 0
  prev="$(cat "${RETRY_COUNT_FILE}" 2>/dev/null || echo 0)"
  [[ "${prev}" =~ ^[0-9]+$ ]] || prev=0
  ((n > prev)) && printf '%s' "${n}" >"${RETRY_COUNT_FILE}" 2>/dev/null
  return 0
}

# Run one attempt under a wall clock. `timeout` can only bound an external
# command, so when the target is a shell function (or when the bound is disabled
# with RETRY_TIMEOUT=0, or `timeout` is simply absent) fall through to running it
# directly — a missing bound is worse than no retry, but silently failing to run
# the command at all would be worse still.
_retry_run() {
  local _rr_timeout="$1"
  shift
  if ((_rr_timeout > 0)) && command -v timeout >/dev/null 2>&1 &&
    ! declare -F "$1" >/dev/null 2>&1; then
    timeout --foreground "${_rr_timeout}" "$@"
  else
    "$@"
  fi
}

# net_curl — curl with the flags that make a flaky or slow network fail *fast and
# loudly* rather than stalling. Use this instead of bare `curl` for every remote
# fetch, and wrap it in `retry`.
#
#   --connect-timeout   cap the TCP/TLS handshake
#   --max-time          cap the whole transfer
#   --speed-limit/-time THE important pair: a transfer trickling below 1 KB/s for
#                       30s is treated as an error, which converts a stall into an
#                       exit code that `retry` can actually act on
#   --retry*            curl's own transport-level retry, complementary to `retry`
#   --remove-on-error   do not leave a partial file at the destination. Added only
#                       when the local curl supports it (7.83+); Ubuntu 22.04
#                       ships 7.81, so this is belt-and-braces on top of the
#                       download-to-staging discipline, never the mechanism.
net_curl() {
  local _nc_opts=(
    --fail --silent --show-error --location
    --connect-timeout "${CURL_CONNECT_TIMEOUT:-15}"
    --max-time "${CURL_MAX_TIME:-300}"
    --speed-limit "${CURL_SPEED_LIMIT:-1024}"
    --speed-time "${CURL_SPEED_TIME:-30}"
    --retry 2 --retry-delay 2 --retry-connrefused
  )
  if curl --help all 2>/dev/null | grep -q -- '--remove-on-error'; then
    _nc_opts+=(--remove-on-error)
  fi
  curl "${_nc_opts[@]}" "$@"
}

# installed_version_is <cmd> <want> — true only when <cmd> exists, actually RUNS,
# and reports version <want> (with or without a leading "v").
#
# This is the guard that makes a broken install self-healing, and it is why an
# existence-only check is a bug rather than a shortcut: `[[ -x path ]]` and
# `command -v` cannot tell a working binary from a truncated download left at the
# same path by a dropped transfer. They report "already installed" forever, so
# the documented remedy — "re-run setup.sh, it's idempotent" — never repairs
# anything. Running the artifact answers both questions at once: does it execute,
# and is it the pinned version. That second half also makes a version bump take
# effect on a machine that already has the tool.
#
# <cmd> may be a bare name on PATH or an absolute path (an /opt install checked
# before its symlink exists). The version is the first dotted triple on the first
# line of `--version` output, stderr included: one rule covers every banner in
# this repo (eza/yazi/nvim/glow/stylua/shfmt/node/lazygit/gh/az) without a
# per-tool regex. The found version is left in INSTALLED_VERSION so a caller can
# log "found X, upgrading". Uses grep -oE (POSIX ERE), not -oP, so it does not
# depend on a PCRE-enabled grep.
#
# Call it as a condition (`if installed_version_is ...`), never bare: under
# `set -e` a bare call returning 1 would abort the script.
installed_version_is() {
  local cmd="$1" want="${2#v}"
  INSTALLED_VERSION=""
  command -v "${cmd}" >/dev/null 2>&1 || return 1
  INSTALLED_VERSION="$("${cmd}" --version 2>&1 | head -1 |
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  [[ -n "${INSTALLED_VERSION}" && "${INSTALLED_VERSION}" == "${want}" ]]
}

# installed_runs <cmd> — the same guard for a tool with NO pinned version (atuin,
# uv, claude). It cannot assert which version is present, but it still asserts the
# one thing an existence check cannot: that the artifact executes.
installed_runs() {
  local cmd="$1"
  INSTALLED_VERSION=""
  command -v "${cmd}" >/dev/null 2>&1 || return 1
  INSTALLED_VERSION="$("${cmd}" --version 2>&1 | head -1 || true)"
  [[ -n "${INSTALLED_VERSION}" ]]
}

# fetch_verified <url> <dest> — download to <dest> and prove the result is a
# COMPLETE file before any caller acts on it.
#
# The other half of the same defect. `curl -o` writes bytes as they arrive and
# does not unlink its output on error, so a connection that drops mid-transfer
# leaves a real, plausible-looking file at <dest>. Callers must therefore point
# <dest> at a STAGING path, never an install path, and must not trust the file
# until this returns 0.
#
# Verification is by extension, because "did all of it arrive" is exactly what an
# archive index can answer:
#   *.tar.gz/*.tgz  tar -tzf   (gzip CRC + complete member table)
#   *.zip           unzip -t   (central directory + per-entry CRC)
#   anything else   non-empty only — the caller must verify it itself (run the
#                   binary, check magic bytes, `sh -n` an installer script).
#
# The verification runs INSIDE retry, not after it: the failure this exists for is
# a server that truncates and closes cleanly, which curl can report as success.
# Verifying outside the retry would diagnose that once and give up.
#
# Every failure path removes <dest>. That is the portable equivalent of curl's
# --remove-on-error and is strictly stronger: it also removes a file curl
# considered a success but that failed the archive check, which is the actual
# reproduced failure. It is also why this does not depend on that flag, which
# Ubuntu 22.04's curl 7.81 — the default Codespaces image, and the one the
# account-wide dotfiles path lands on — does not have.
fetch_verified() {
  retry _fetch_verified_once "$1" "$2"
}

_fetch_verified_once() {
  local url="$1" dest="$2"
  rm -f "${dest}"
  if ! net_curl "${url}" -o "${dest}"; then
    rm -f "${dest}"
    return 1
  fi
  if [[ ! -s "${dest}" ]]; then
    _retry_log "download produced an empty file: ${url}"
    rm -f "${dest}"
    return 1
  fi
  case "${dest}" in
    *.tar.gz | *.tgz)
      if ! tar -tzf "${dest}" >/dev/null 2>&1; then
        _retry_log "downloaded archive is truncated or corrupt: ${url}"
        rm -f "${dest}"
        return 1
      fi
      ;;
    *.zip)
      if ! unzip -tqq "${dest}" >/dev/null 2>&1; then
        _retry_log "downloaded archive is truncated or corrupt: ${url}"
        rm -f "${dest}"
        return 1
      fi
      ;;
  esac
}

# Exit code a step uses to say "deliberately not installed here" — as opposed to
# 0 (installed) or anything else (failed). setup.sh records these as SKIPPED with
# a reason, so an unsupported platform is not reported as a broken step.
SETUP_SKIP_RC=3

# glibc_at_least <major.minor> — true when the system glibc is at least <version>.
#
# Prebuilt binaries are compiled against a glibc and simply will not run on an
# older one. Ubuntu 20.04 (focal) ships glibc 2.31, and Neovim, yazi and stylua
# all fail there — observed in CI: the binaries download and extract fine and
# then do not execute, with stylua's installer saying outright
# "System glibc version (`2.31') is too old".
#
# The install guards already catch this (they run the artifact before installing
# it, so a non-working binary is never installed) but only AFTER paying for the
# download and extraction, and the result reads as a failure rather than as
# "this platform is too old". Checking first makes it fast and honest.
#
# Returns 0 (do not block) when the version cannot be determined: a missing or
# unparseable `ldd` is not evidence that the platform is unsupported, and
# refusing to install on no evidence would be worse than trying.
glibc_at_least() {
  local want="$1" have want_maj want_min have_maj have_min
  GLIBC_VERSION=""
  have="$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | tail -1)"
  [[ -n "${have}" ]] || return 0
  GLIBC_VERSION="${have}"
  want_maj="${want%%.*}"
  want_min="${want##*.}"
  have_maj="${have%%.*}"
  have_min="${have##*.}"
  ((have_maj > want_maj)) && return 0
  ((have_maj < want_maj)) && return 1
  ((have_min >= want_min))
}

# require_glibc <version> <what> — skip this step, with a clear reason, when the
# system glibc is too old for the binary it installs.
#
# The floor is set to "newer than focal" rather than a per-tool number, because
# what is established is that 2.31 fails and 2.39 works; the exact per-tool floor
# is not. Conservative in the right direction — and overridable with
# SETUP_SKIP_GLIBC_CHECK=1 for anyone who knows their platform is fine.
require_glibc() {
  local want="$1" what="$2"
  [[ "${SETUP_SKIP_GLIBC_CHECK:-0}" == "1" ]] && return 0
  glibc_at_least "${want}" && return 0
  log "SKIPPING ${what}: it needs glibc >= ${want}, and this system has ${GLIBC_VERSION}."
  log "  That is Ubuntu 20.04 (focal) or older. The binary would download and then"
  log "  refuse to run, so there is nothing to gain by trying."
  log "  Fix: use a base image on Ubuntu 22.04 or newer — e.g."
  log "    mcr.microsoft.com/devcontainers/universal:6        (was universal:2)"
  log "    mcr.microsoft.com/devcontainers/python:1-3.12-bookworm"
  log "  See the README's 'Choosing a base image' section."
  log "  Override with SETUP_SKIP_GLIBC_CHECK=1 if you know better."
  exit "${SETUP_SKIP_RC}"
}

# Log through the sourcing script's own log() (so retry lines carry that script's
# [prefix]) when one exists, and fall back to a self-contained prefix otherwise —
# keeping lib.sh usable even from a script that has not defined log() yet.
_retry_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$*"
  else
    echo "[retry] $*"
  fi
}
