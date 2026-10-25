#!/usr/bin/env bash
# Behavioural test for configs/claude/scripts/sync-skills.sh, the /sync-skills script.
#
# Runs the script as a machine would: installed in a throwaway ~/.claude, against a
# bare clone of this repo standing in for GitHub (its path holds the repo slug, so
# the script's origin check passes). B is this repo's HEAD; a second commit on the
# bare "origin" plays a change merged from elsewhere. No PR can be opened against a
# bare clone, so the push case stops at that step on purpose. Needs git, gh signed
# in (or GH_TOKEN), python3, node, and uv for wordmark.py's selftest. Asserts:
#
#   1. No recorded base: decides only what history settles, stops (exit 2).
#   2. With a base: one plan pushes a local edit and a local deletion, pulls a
#      repo-only file, and merges a file both sides changed in different places.
#   3. Both sides changed the same place: stops (exit 2), changes nothing, saves
#      the merge attempt with conflict markers.
#   4. Only the repo changed: pulls into ~/.claude with backups, moves the base,
#      creates no worktree.
#   5. In sync, using the recorded base: nothing to do.
#   6. Push path: merges into ~/.claude, passes the checks, pushes its branch,
#      then stops at the PR (exit 1).
#   7. The repo holds a newer sync-skills.sh: the running copy pulls it and
#      restarts on it.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
if [[ -z "${GH_TOKEN:-}" ]]; then GH_TOKEN="$(gh auth token)" && export GH_TOKEN; fi

fail=0
check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  ok   ${desc}"
  else
    echo "  FAIL ${desc}"
    sed 's/^/       /' "${WORK}/out"
    fail=1
  fi
}

ORIGIN="${WORK}/johnmathews/codespaces-setup.git"
# The origin holds this checkout's HEAD as main. Pushed rather than cloned: a clone
# takes the repository's HEAD, which in a worktree or CI's detached checkout is not
# the commit under test. Pushing needs full history (CI checks out fetch-depth 0).
git init -q --bare "${ORIGIN}"
git -C "${REPO_DIR}" push -q "${ORIGIN}" HEAD:refs/heads/main
git -C "${ORIGIN}" symbolic-ref HEAD refs/heads/main
git clone -q "${ORIGIN}" "${WORK}/repo"
B="$(git -C "${WORK}/repo" rev-parse origin/main)"
DS=configs/claude/skills/design-system

# A change merged "from elsewhere" after B: the end of SKILL.md, and a new file.
git clone -q "${ORIGIN}" "${WORK}/other"
echo "Repo-side line at the end." >>"${WORK}/other/${DS}/SKILL.md"
echo "# Added in the repo" >"${WORK}/other/${DS}/references/new-in-repo.md"
git -C "${WORK}/other" add -A
git -C "${WORK}/other" commit -q -m "repo-side change"
git -C "${WORK}/other" push -q origin HEAD:main

# ~/.claude as installed from B, with no recorded base.
fresh_home() {
  rm -rf "${WORK:?}/home" "${WORK:?}/state"
  mkdir -p "${WORK}/home"
  git -C "${WORK}/repo" archive "${B}" configs/claude | tar -x -C "${WORK}/home"
  mv "${WORK}/home/configs/claude" "${WORK}/home/.claude"
  rm -rf "${WORK}/home/configs"
  git -C "${WORK}/repo" update-ref -d refs/sync-skills/base 2>/dev/null || true
}
skill() { echo "${WORK}/home/.claude/skills/design-system/SKILL.md"; }
edit_top() {
  python3 - "$(skill)" <<'EOF'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text().replace("# Design system\n", "# Design system\n\nLocal line near the top.\n", 1))
EOF
}
local_edits() {
  edit_top
  echo "local edit" >>"${WORK}/home/.claude/skills/engineering-team/references/writing-style.md"
  rm "${WORK}/home/.claude/skills/design-system/templates/brand-doc.md"
}
run() {
  HOME="${WORK}/home" XDG_STATE_HOME="${WORK}/state" CODESPACES_SETUP_DIR="${WORK}/repo" \
    "${WORK}/home/.claude/scripts/sync-skills.sh" "$@" >"${WORK}/out" 2>&1
  echo $? >"${WORK}/rc"
}
rc_is() { [[ "$(cat "${WORK}/rc")" == "$1" ]]; }
out_has() { grep -qE "$1" "${WORK}/out"; }
base_is_origin() { [[ "$(git -C "${WORK}/repo" rev-parse refs/sync-skills/base)" == "$(git -C "${WORK}/repo" rev-parse origin/main)" ]]; }

echo "1. no recorded base"
fresh_home
local_edits
run --dry-run
check "stops with exit 2" rc_is 2
check "SKILL.md, changed on both sides, is a conflict" out_has "conflict ${DS}/SKILL.md"
check "the deleted template is pulled back, not pushed as a deletion" out_has "pull ${DS}/templates/brand-doc.md"

echo "2. three-way plan against base B"
run --dry-run --base "${B}"
check "exit 0" rc_is 0
check "a local-only edit is pushed" out_has "^  push .*writing-style.md"
check "a local deletion is pushed" out_has "^  push .*brand-doc.md"
check "a repo-only file is pulled" out_has "^  pull .*new-in-repo.md"
check "a file both changed in different places is merged" out_has "^  merge .*SKILL.md"

echo "3. overlapping change"
fresh_home
edit_top
echo "Local line at the end." >>"$(skill)"
cp "$(skill)" "${WORK}/before"
run --base "${B}"
check "stops with exit 2" rc_is 2
check "reports the conflict" out_has "^  conflict .*SKILL.md"
check "leaves ~/.claude unchanged" cmp -s "${WORK}/before" "$(skill)"
check "saves the attempt with conflict markers" grep -rq "^<<<<<<< this machine" "${WORK}/state/sync-skills/conflicts"

echo "4. only the repo changed"
fresh_home
run --base "${B}"
check "exit 0" rc_is 0
check "the repo's edit is pulled" grep -q "Repo-side line at the end." "$(skill)"
check "the repo's new file is pulled" test -f "${WORK}/home/.claude/skills/design-system/references/new-in-repo.md"
check "the old copy is backed up" bash -c "ls '${WORK}'/state/sync-skills/backups/*/skills/design-system/SKILL.md >/dev/null"
check "the base moves to origin/main" base_is_origin
check "no worktree was made" test "$(git -C "${WORK}/repo" worktree list | wc -l)" -eq 1

echo "5. in sync"
run
check "exit 0, nothing to do" bash -c "grep -q 'already in sync' '${WORK}/out'"

echo "6. push path"
fresh_home
local_edits
run --base "${B}"
check "the repo's change is merged into ~/.claude" grep -q "Repo-side line at the end." "$(skill)"
check "the local change survives the merge" grep -q "Local line near the top." "$(skill)"
check "every skill check ran" out_has "check: python3 tests/engineering-team-command-links"
check "the branch reached origin" bash -c "git -C '${ORIGIN}' branch --list 'sync-skills-*' | grep -q sync"
check "stops at the PR with exit 1" rc_is 1

echo "7. a newer sync-skills.sh in the repo"
git -C "${WORK}/other" pull -q
python3 - "${WORK}/other/configs/claude/scripts/sync-skills.sh" <<'EOF'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text().replace("set -euo pipefail\n", "set -euo pipefail\n# newer copy\n", 1))
EOF
git -C "${WORK}/other" commit -q -am "newer sync script"
git -C "${WORK}/other" push -q origin HEAD:main
fresh_home
run --base "${B}"
check "exit 0" rc_is 0
check "the newer script is pulled" grep -q "^# newer copy" "${WORK}/home/.claude/scripts/sync-skills.sh"
check "it stays executable" test -x "${WORK}/home/.claude/scripts/sync-skills.sh"
check "the run restarts on it" out_has "restarting on it"
check "the restarted run finishes in sync" out_has "already in sync"

for wt in $(git -C "${WORK}/repo" worktree list --porcelain | awk '/^worktree /{print $2}' | tail -n +2); do
  git -C "${WORK}/repo" worktree remove --force "${wt}"
done

if [[ "${fail}" -ne 0 ]]; then
  echo "sync-skills: FAILED"
  exit 1
fi
echo "sync-skills: all checks passed"
