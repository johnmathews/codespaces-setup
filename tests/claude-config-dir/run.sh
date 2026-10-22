#!/usr/bin/env bash
# Behavioural test for scripts/19-claude-config-dir.sh.
#
# Headless and filesystem-only (no network, no sudo), so CI runs the real script
# against a throwaway HOME and CLAUDE_PERSIST_DIR. Asserts:
#
#   1. Fresh machine: ~/.claude and ~/.claude.json move to the persisted dir and
#      are replaced by links to it.
#   2. After a rebuild (fresh ~/.claude beside an existing persisted dir): the
#      union survives, the persisted copy wins a conflict, and the fresh
#      ~/.claude.json is kept as .bak.
#   3. A re-run is a no-op.
#   4. A ~/.claude symlink pointing somewhere else is left alone (exit 1).
#   5. No parent dir for the persisted path (not a Codespace): exit 0, untouched.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${REPO_DIR}/scripts/19-claude-config-dir.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail=0
check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  ok   ${desc}"
  else
    echo "  FAIL ${desc}"
    fail=1
  fi
}

# Fresh HOME + persisted root for one scenario; sets H and P.
scenario() {
  H="${WORK}/$1/home"
  P="${WORK}/$1/workspaces/.claude-config"
  mkdir -p "${H}" "$(dirname "${P}")"
}
run() { HOME="${H}" CLAUDE_PERSIST_DIR="${P}" bash "${SCRIPT}" >/dev/null; }

echo "1. fresh machine"
scenario fresh
mkdir -p "${H}/.claude/projects/p"
echo t1 >"${H}/.claude/projects/p/s1.jsonl"
echo '{"a":1}' >"${H}/.claude.json"
run
check "home .claude is a link to the persisted dir" test "$(readlink -f "${H}/.claude")" == "$(readlink -f "${P}")"
check "transcript moved" test -f "${P}/projects/p/s1.jsonl"
check "home .claude.json links into the persisted dir" test "$(readlink -f "${H}/.claude.json")" == "$(readlink -f "${P}/.claude.json")"
check "home .claude.json content kept" grep -q '"a":1' "${P}/.claude.json"
check "persisted dir is private" test "$(stat -c %a "${P}")" == 700

echo "2. after a rebuild"
scenario rebuild
mkdir -p "${P}/projects/p" "${H}/.claude/projects/p"
echo old >"${P}/projects/p/s1.jsonl"
echo persisted >"${P}/settings.json"
echo '{"old":1}' >"${P}/.claude.json"
echo new >"${H}/.claude/projects/p/s2.jsonl"
echo fresh >"${H}/.claude/settings.json"
echo '{"new":1}' >"${H}/.claude.json"
run
check "old transcript survives" grep -q old "${P}/projects/p/s1.jsonl"
check "new transcript merged in" grep -q new "${P}/projects/p/s2.jsonl"
check "persisted copy wins a conflict" grep -q persisted "${P}/settings.json"
check "persisted .claude.json wins" grep -q old "${H}/.claude.json"
check "fresh .claude.json kept as .bak" grep -q new "${H}/.claude.json.bak"
check "no staging or .old dirs left" test -z "$(find "$(dirname "${P}")" -maxdepth 1 -name '.claude-config.*')"

echo "3. re-run is a no-op"
before="$(cd "${P}" && find . -type f | sort | xargs md5sum)"
run
check "persisted contents unchanged" test "${before}" == "$(cd "${P}" && find . -type f | sort | xargs md5sum)"
check "links still in place" test -L "${H}/.claude" -a -L "${H}/.claude.json"

echo "4. foreign symlink"
scenario foreign
mkdir -p "${WORK}/foreign/elsewhere"
ln -s "${WORK}/foreign/elsewhere" "${H}/.claude"
check "exits non-zero" bash -c "! HOME='${H}' CLAUDE_PERSIST_DIR='${P}' bash '${SCRIPT}' >/dev/null"
check "link untouched" test "$(readlink "${H}/.claude")" == "${WORK}/foreign/elsewhere"

echo "5. not a Codespace"
H="${WORK}/nocs/home"
P="${WORK}/nocs/absent/.claude-config"
mkdir -p "${H}/.claude"
run
check "home .claude left a real dir" test -d "${H}/.claude" -a ! -L "${H}/.claude"

if ((fail)); then
  echo "claude-config-dir: FAILED"
  exit 1
fi
echo "claude-config-dir: all passed"
