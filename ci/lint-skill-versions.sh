#!/usr/bin/env bash
# Every script a skill hands to projects carries a SCRIPT_VERSION, and a change
# to one bumps it.
#
# The design-system skill's scripts are COPIED into each project that uses them
# (the gate, the preview builder), so a fix made here never reaches a project
# that copied the old file. Each copy compares its own SCRIPT_VERSION with the
# installed skill's and says when it is behind, but that comparison is only as
# good as the number: change a script, forget the bump, and every stale copy
# reports itself current. That forgotten bump is the mistake nothing else would
# catch, so this lint makes it red.
#
# Two rules, over every file in VERSIONED_DIRS:
#   1. The file declares exactly one `SCRIPT_VERSION = <n>` at the start of a
#      line (`const SCRIPT_VERSION = <n>` in JavaScript).
#   2. With --base <ref>: a file that exists at <ref> with a version, and whose
#      contents differ from <ref>, has a strictly higher version than at <ref>.
#      A file new since <ref>, or one that had no version there, passes rule 2.
#
# Run:      bash ci/lint-skill-versions.sh [--base <git-ref>]
# Selftest: bash ci/lint-skill-versions.sh --selftest

set -euo pipefail

log() { echo "[lint-skill-versions] $*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF="${REPO_DIR}/ci/lint-skill-versions.sh"
# Space-separated, relative to the repo root. SKILL_VERSIONED_DIRS overrides it
# (read per call, not here, so the selftest can point lint at its fixture tree).
VERSIONED_DIRS="configs/claude/skills/design-system/scripts"
VERSION_RE='^(const )?SCRIPT_VERSION = [0-9]+'

# The version declared in text on stdin, or nothing.
version_of() {
  grep -E "${VERSION_RE}" | head -n 1 | sed -E 's/^(const )?SCRIPT_VERSION = ([0-9]+).*/\2/' || true
}

# lint <root> <base-ref or empty>; prints one line per problem, returns 1 if any.
lint() {
  local root="$1" base="$2" dir path rel count now was problems=0
  for dir in ${SKILL_VERSIONED_DIRS:-${VERSIONED_DIRS}}; do
    [[ -d "${root}/${dir}" ]] || {
      log "FAIL ${dir}: not a directory"
      problems=1
      continue
    }
    for path in "${root}/${dir}"/*; do
      [[ -f "${path}" ]] || continue
      case "${path}" in *.py | *.mjs | *.js | *.sh) ;; *) continue ;; esac
      rel="${path#"${root}"/}"
      count="$(grep -cE "${VERSION_RE}" "${path}" || true)"
      if [[ "${count}" != 1 ]]; then
        log "FAIL ${rel}: needs exactly one SCRIPT_VERSION line, found ${count}"
        problems=1
        continue
      fi
      [[ -n "${base}" ]] || continue
      git -C "${root}" cat-file -e "${base}:${rel}" 2>/dev/null || continue # new since base
      git -C "${root}" diff --quiet "${base}" -- "${rel}" && continue       # unchanged
      was="$(git -C "${root}" show "${base}:${rel}" | version_of)"
      [[ -n "${was}" ]] || continue # first version introduced by this change
      now="$(version_of <"${path}")"
      if ((now <= was)); then
        log "FAIL ${rel}: changed since ${base} but SCRIPT_VERSION is still ${now} (was ${was}); bump it"
        problems=1
      fi
    done
  done
  return "${problems}"
}

selftest() {
  local work fail=0
  work="$(mktemp -d)"
  trap 'rm -rf "${work}"' RETURN
  expect() { # expect <pass|fail> <description> <base or empty>
    local want="$1" desc="$2" base="$3" got=pass
    SKILL_VERSIONED_DIRS=s lint "${work}" "${base}" >/dev/null || got=fail
    if [[ "${got}" == "${want}" ]]; then echo "  ok   ${desc}"; else
      echo "  FAIL ${desc} (wanted ${want}, got ${got})"
      fail=1
    fi
  }
  git -C "${work}" init -q
  git -C "${work}" config user.email selftest@example.invalid
  git -C "${work}" config user.name selftest
  mkdir "${work}/s"
  printf 'SCRIPT_VERSION = 1\nx = 1\n' >"${work}/s/a.py"
  printf "const SCRIPT_VERSION = 3\nconst x = 1\n" >"${work}/s/b.mjs"
  printf 'not a script\n' >"${work}/s/notes.md"
  git -C "${work}" add -A
  git -C "${work}" commit -qm base
  expect pass "versioned files pass; other files are ignored" HEAD
  printf 'SCRIPT_VERSION = 1\nx = 2\n' >"${work}/s/a.py"
  expect fail "a change without a bump fails" HEAD
  printf 'SCRIPT_VERSION = 2\nx = 2\n' >"${work}/s/a.py"
  expect pass "a change with a bump passes" HEAD
  printf 'SCRIPT_VERSION = 0\nx = 2\n' >"${work}/s/a.py"
  expect fail "a version that goes down fails" HEAD
  printf 'x = 2\n' >"${work}/s/a.py"
  expect fail "a missing SCRIPT_VERSION fails" ""
  printf 'SCRIPT_VERSION = 1\nSCRIPT_VERSION = 2\n' >"${work}/s/a.py"
  expect fail "two SCRIPT_VERSION lines fail" ""
  git -C "${work}" checkout -q -- s/a.py
  printf 'SCRIPT_VERSION = 1\n' >"${work}/s/new.py"
  expect pass "a file new since base passes at any version" HEAD
  rm "${work}/s/new.py"
  printf 'x = 1\n' >"${work}/s/a.py"
  git -C "${work}" commit -qam unversioned
  printf 'SCRIPT_VERSION = 1\nx = 1\n' >"${work}/s/a.py"
  expect pass "introducing the first version passes" HEAD
  return "${fail}"
}

case "${1:-}" in
  --selftest)
    selftest
    ;;
  --base)
    log "comparing with ${2:?--base needs a ref}"
    lint "${REPO_DIR}" "$2"
    log "ok"
    ;;
  "")
    lint "${REPO_DIR}" ""
    log "ok"
    ;;
  *)
    echo "usage: bash ${SELF#"${REPO_DIR}"/} [--base <git-ref>] | --selftest" >&2
    exit 2
    ;;
esac
