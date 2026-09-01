#!/usr/bin/env bash
# Enforce the per-script conventions that CLAUDE.md states and that nothing
# checked.
#
# WHY THIS EXISTS: an evaluation added a script to scripts/ that violated every
# one of the documented conventions at once — no `set -euo pipefail`, no `log()`
# prefix function, an unretried and unpinned `curl … | bash`, non-idempotent, and
# the exact `.bak`-into-a-scanned-directory bug CLAUDE.md records as having
# already happened once — wired it into STEPS, and watched shellcheck, shfmt,
# ci/lint-steps.sh and the resilience suite all pass green. The repo's most
# detailed quality contract had no enforcement at all: shellcheck does not
# require `set -euo pipefail`, knows nothing about `retry`, and cannot see
# idempotency; lint-steps.sh checks wiring and file mode, not content.
#
# Scope is deliberately narrow — the checks below are the ones that are both
# mechanical and load-bearing. Idempotency is NOT checked here: it is a
# behavioural property, and asserting it by grep would be a check that cannot
# fail, which is worse than no check. It is covered by the guards themselves
# (scripts/lib.sh installed_version_is) and by the container smoke test.
#
# Run: bash ci/lint-conventions.sh [scripts_dir]
# Selftest (fixtures prove each rule can go red): bash ci/lint-conventions.sh --selftest

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ERRORS=0
err() {
  printf '[lint-conventions] ERROR: %s\n' "$*" >&2
  ERRORS=$((ERRORS + 1))
}
note() { printf '[lint-conventions] %s\n' "$*"; }

# Network verbs that must be retried. A step that fetches something without
# `retry` is the failure mode this whole repo is shaped around: nearly every
# step downloads, so a transient hiccup is the expected way one fails.
#
# Matched at COMMAND POSITION only — start of line, after optional `if`, `!`,
# `sudo`, or `env VAR=x`. Matching the bare word anywhere would flag the package
# names in 01-apt-packages.sh's PACKAGES array, the word "curl" in a for-loop
# list, and any log message that happens to mention apt — none of which are
# network calls, and all of which would train the reader to ignore this gate.
NETWORK_RE='^[[:space:]]*(if[[:space:]]+)?(![[:space:]]*)?(sudo[[:space:]]+)?(env[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(curl|wget|git[[:space:]]+(clone|fetch|pull)|npm[[:space:]]+install|uv[[:space:]]+tool[[:space:]]+install|apt-get[[:space:]]+(install|update)|pip[[:space:]]+install)([[:space:]]|$)'

check_dir() {
  local dir="$1" f base
  local checked=0

  for f in "${dir}"/*.sh; do
    [[ -e "${f}" ]] || continue
    base="$(basename "${f}")"
    checked=$((checked + 1))

    # lib.sh is SOURCED, never executed as a step. It must not set shell options
    # on its callers, and it defines _retry_log rather than log() precisely so it
    # can defer to the sourcing script's prefix. Rules 1, 2 and 4 do not apply.
    if [[ "${base}" == "lib.sh" ]]; then
      head -1 "${f}" | grep -qE '^#!/usr/bin/env bash$' ||
        err "${base}: first line must be '#!/usr/bin/env bash'"
      continue
    fi

    # 1. Strict mode. Without it a failing command mid-script is silently
    #    skipped past and the step still exits 0 — reporting success while
    #    having installed nothing.
    grep -qE '^set -euo pipefail$' "${f}" ||
      err "${base}: missing 'set -euo pipefail'"

    # 2. A log() prefix function, so every line in a 3000-line combined log says
    #    which step produced it.
    grep -qE '^log\(\) \{' "${f}" ||
      err "${base}: missing a 'log() { ... }' prefix function"

    # 3. Shebang.
    head -1 "${f}" | grep -qE '^#!/usr/bin/env bash$' ||
      err "${base}: first line must be '#!/usr/bin/env bash'"

    # 4. Every network operation is retried, or carries an explicit waiver.
    local line n
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      [[ "${line}" =~ ^[[:space:]]*# ]] && continue
      # A line holding one bare word is an array element (the PACKAGES list in
      # 01-apt-packages.sh contains "curl" and "wget"), never a call: every real
      # invocation carries a subcommand, a flag, or a URL.
      [[ "${line}" =~ ^[[:space:]]*[A-Za-z0-9._-]+[[:space:]]*$ ]] && continue
      [[ "${line}" =~ ${NETWORK_RE} ]] || continue
      # Retried, staged, or explicitly waived on the same line?
      [[ "${line}" =~ (^|[[:space:]])(retry|fetch_verified)[[:space:]] ]] && continue
      [[ "${line}" =~ \#[[:space:]]*no-retry: ]] && continue
      err "${base}:${n}: network call is not wrapped in 'retry' and carries no '# no-retry: <reason>' waiver
        ${line}"
    done <"${f}"

    # 5. Never write a .bak into ~/.claude/skills/. That directory is SCANNED —
    #    every subdirectory holding a SKILL.md registers as a skill — so a backup
    #    there loads as a DUPLICATE skill rather than sitting inertly beside the
    #    original. This happened; see scripts/17-claude-skills.sh.
    if grep -qE '\.claude/skills.*\.bak|\.bak.*\.claude/skills' "${f}"; then
      grep -qE '#.*(reap|remove|clean).*\.bak' "${f}" ||
        err "${base}: writes a .bak inside ~/.claude/skills/, which is a scanned directory — the backup registers as a duplicate skill"
    fi
  done

  note "checked ${checked} script(s) in ${dir}"
}

selftest() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN
  local failures=0

  # Run check_dir against one fixture and report how many errors it raised.
  # Deliberately NOT in a subshell: ERRORS must come back to the caller.
  _errors_for() {
    local d="$1"
    ERRORS=0
    check_dir "${d}" >/dev/null 2>&1 || true
    printf '%s' "${ERRORS}"
  }

  _expect_red() {
    local name="$1" body="$2" d n
    d="${tmp}/${name}"
    mkdir -p "${d}"
    printf '%s' "${body}" >"${d}/01-fixture.sh"
    n="$(_errors_for "${d}")"
    if ((n > 0)); then
      printf '  ok: %s is rejected\n' "${name}"
    else
      printf '  FAIL: %s was ACCEPTED — the rule does not fire\n' "${name}" >&2
      failures=$((failures + 1))
    fi
  }

  echo "== lint-conventions selftest =="

  _expect_red "no-strict-mode" '#!/usr/bin/env bash
log() { echo "[x] $*"; }
echo hi
'
  _expect_red "no-log-function" '#!/usr/bin/env bash
set -euo pipefail
echo hi
'
  _expect_red "bad-shebang" '#!/bin/bash
set -euo pipefail
log() { echo "[x] $*"; }
'
  _expect_red "unretried-curl" '#!/usr/bin/env bash
set -euo pipefail
log() { echo "[x] $*"; }
curl -fsSL https://example.com/install.sh | bash
'
  _expect_red "bak-in-scanned-skills-dir" '#!/usr/bin/env bash
set -euo pipefail
log() { echo "[x] $*"; }
cp -r ~/.claude/skills/engineering-team ~/.claude/skills/engineering-team.bak
'

  # And a good script must stay GREEN, or the gate is just noise.
  local d="${tmp}/good"
  mkdir -p "${d}"
  printf '%s' '#!/usr/bin/env bash
set -euo pipefail
log() { echo "[good] $*"; }
retry net_curl https://example.com/x.tar.gz -o /tmp/x.tar.gz
apt-get install -y foo # no-retry: illustrative
' >"${d}/01-fixture.sh"
  local n
  n="$(_errors_for "${d}")"
  if ((n == 0)); then
    printf '  ok: a compliant script passes\n'
  else
    printf '  FAIL: a compliant script was rejected with %s error(s)\n' "${n}" >&2
    ERRORS=0
    check_dir "${d}" >/dev/null || true
    failures=$((failures + 1))
  fi

  if ((failures > 0)); then
    printf '[lint-conventions] SELFTEST FAILED with %d problem(s).\n' "${failures}" >&2
    return 1
  fi
  printf '[lint-conventions] selftest OK\n'
  return 0
}

if [[ "${1:-}" == "--selftest" ]]; then
  selftest
  exit $?
fi

check_dir "${1:-${REPO_DIR}/scripts}"

if ((ERRORS > 0)); then
  printf '[lint-conventions] FAILED with %d error(s).\n' "${ERRORS}" >&2
  exit 1
fi
printf '[lint-conventions] OK: all scripts follow the documented conventions.\n'
