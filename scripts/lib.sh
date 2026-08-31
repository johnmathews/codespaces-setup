#!/usr/bin/env bash
# Shared helpers for the setup scripts.
#
# This file is SOURCED, never executed as a step: it holds nothing to run on its
# own, only functions the numbered scripts pull in. It is therefore deliberately
# absent from setup.sh's STEPS array and listed as EXEMPT in ci/lint-steps.sh.
# (It still lives in scripts/ so `chmod +x scripts/*.sh` keeps its mode stable,
# which is why it is committed 100755 like every other file here.)
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
# Tunables (env, so a caller or a test can override without changing call sites):
#   RETRY_ATTEMPTS    total attempts before giving up   (default 4)
#   RETRY_BASE_DELAY  seconds to wait after the 1st fail (default 3), doubled
#                     after each subsequent failure (3s, 6s, 12s, ...)
#
# Returns the command's own exit code from the final attempt, so callers can
# still branch on failure (`retry curl ... || handle`). It intentionally does
# NOT swallow failure — a step that must abort still can.
retry() {
  # Locals are prefixed to avoid bash's dynamic scoping clobbering a variable of
  # the same name inside the command being retried (a function passed to retry
  # would otherwise see and mutate these).
  local _retry_attempts="${RETRY_ATTEMPTS:-4}"
  local _retry_delay="${RETRY_BASE_DELAY:-3}"
  local _retry_n=1 _retry_rc=0

  while true; do
    # `cmd && return 0` (not `if cmd`) so that $? below is the command's own exit
    # code: an `if` with no else resets $? to 0 when the condition is false.
    "$@" && return 0
    _retry_rc=$?
    if ((_retry_n >= _retry_attempts)); then
      _retry_log "command failed after ${_retry_n} attempt(s) (exit ${_retry_rc}): $*"
      return "${_retry_rc}"
    fi
    _retry_log "attempt ${_retry_n}/${_retry_attempts} failed (exit ${_retry_rc}); retrying in ${_retry_delay}s: $*"
    sleep "${_retry_delay}"
    _retry_delay=$((_retry_delay * 2))
    _retry_n=$((_retry_n + 1))
  done
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
