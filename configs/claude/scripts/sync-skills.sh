#!/usr/bin/env bash
# sync-skills.sh — keep this machine's Claude Code skills and commands and the
# codespaces-setup repo's copy (configs/claude/) equal, pulling before pushing.
#
# ~/.claude is where skills are usually edited, and configs/claude/ in
# codespaces-setup is what every new Codespace installs. Either side can change:
# an edit here, or a change merged into the repo from a Codespace or another
# machine. So a sync is three-way, against the BASE: the repo commit this
# machine last synced with (kept as refs/sync-skills/base in the checkout).
# For every file:
#
#   this machine == repo           nothing to do
#   only this machine changed it   push it (an edit, a new file, a deletion)
#   only the repo changed it       pull it into ~/.claude first
#   both changed it                merge the two; a conflict stops the sync
#
# Nothing on either side is overwritten unless the base proves the other side
# is the only one that changed. Pulled files are backed up first (outside
# ~/.claude/skills, which Claude Code scans).
#
# The script and its /sync-skills command are assets too, so the sync keeps
# itself current. If it pulls a newer copy of the script that is running, it
# restarts once on that copy, because bash reads a running script lazily.
#
# Then, if the repo needs the result: the repo's skill checks in a fresh
# worktree from origin/main, a PR, a wait for CI, a squash merge, and the new
# base recorded. The main checkout is never written, except a fast-forward when
# it is on a clean main.
#
# Usage: sync-skills.sh [--dry-run] [--base <commit>]
#   --dry-run        print what each file would do, change nothing
#   --base <commit>  use this repo commit as the base (the commit ~/.claude was
#                    last installed from or synced to). Needed once on a machine
#                    with no recorded base, if the sync can't tell on its own.
#
# Exit codes: 0 synced or already in sync; 1 a check, CI or the merge failed
# (the worktree or PR is left for inspection); 2 stopped before changing
# anything (a conflict, or no base to decide with).

set -euo pipefail

# === CONFIGURATION ===

REPO_SLUG="johnmathews/codespaces-setup"
# Where the checkout lives: the main machine's, then a Codespace's (the
# devcontainer's repo, then the dotfiles clone). CODESPACES_SETUP_DIR wins.
REPO_CANDIDATES=(
  "$HOME/projects/codespaces"
  /workspaces/codespaces-setup
  /workspaces/.codespaces/.persistedshare/dotfiles
)
DEST_PREFIX="configs/claude"
BASE_REF="refs/sync-skills/base"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sync-skills"

# Paths relative to ~/.claude/. Each one must also be deployed by the repo's
# scripts/17-claude-skills.sh, or a new Codespace would never install it; the
# script checks this. Adding an asset means adding it here AND there.
ASSETS=(
  skills/engineering-team
  skills/design-system
  skills/sitrep
  commands/done.md
  commands/merge-push.md
  commands/prompt.md
  commands/sync-skills.md
  scripts/sync-skills.sh
)

# Never synced: bytecode, OS litter, editor swap files.
EXCLUDES=(__pycache__ .DS_Store '*.pyc' '*.swp')

# === OPTIONS AND HELPERS ===

LOCAL_BASE="$HOME/.claude"
SELF="$LOCAL_BASE/scripts/sync-skills.sh"
ORIG_ARGS=("$@")
DRY_RUN=0
BASE_ARG=""
while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --base)
      BASE_ARG="${2:?--base needs a commit}"
      shift
      ;;
    -h | --help)
      sed -n '2,36p' "$0"
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

log() { echo "[sync-skills] $*"; }
die() {
  echo "[sync-skills] ERROR: $*" >&2
  exit "${2:-1}"
}

excluded() {
  local x part parts
  IFS=/ read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    for x in "${EXCLUDES[@]}"; do
      # shellcheck disable=SC2053 # $x is a glob on purpose
      [[ "$part" == $x ]] && return 0
    done
  done
  return 1
}

# Every file under ~/.claude/<asset>, as repo paths (configs/claude/<asset>/...).
local_paths() {
  local asset="$1" src="$LOCAL_BASE/$1" rel
  if [[ -f "$src" ]]; then
    echo "$DEST_PREFIX/$asset"
  elif [[ -d "$src" ]]; then
    (cd "$src" && find . -type f | sed 's|^\./||') | while IFS= read -r rel; do
      excluded "$rel" || echo "$DEST_PREFIX/$asset/$rel"
    done
  fi
}

# Every file under the asset in a repo commit.
tree_paths() {
  git -C "$REPO_DIR" ls-tree -r --name-only "$1" -- "$DEST_PREFIX/$2" 2>/dev/null || true
}

# Blob id of a path in a commit, or empty when it isn't there.
blob_at() { git -C "$REPO_DIR" rev-parse -q --verify "$1:$2" 2>/dev/null || true; }

# Blob id of this machine's copy of a repo path, or empty.
local_file() { echo "$LOCAL_BASE/${1#"$DEST_PREFIX"/}"; }
local_blob() {
  local f
  f="$(local_file "$1")"
  if [[ -f "$f" ]]; then git -C "$REPO_DIR" hash-object "$f"; fi
}

# === PREFLIGHT ===

is_checkout() {
  [[ -e "$1/.git" ]] && [[ "$(git -C "$1" remote get-url origin 2>/dev/null)" == *"$REPO_SLUG"* ]]
}
if [[ -n "${CODESPACES_SETUP_DIR:-}" ]]; then
  REPO_DIR="$CODESPACES_SETUP_DIR"
  is_checkout "$REPO_DIR" || die "$REPO_DIR is not a checkout of $REPO_SLUG"
else
  REPO_DIR=""
  for c in "${REPO_CANDIDATES[@]}"; do
    if is_checkout "$c"; then
      REPO_DIR="$c"
      break
    fi
  done
  [[ -n "$REPO_DIR" ]] || die "no checkout of $REPO_SLUG in ${REPO_CANDIDATES[*]} (set CODESPACES_SETUP_DIR)"
fi
log "repo: $REPO_DIR"
command -v gh >/dev/null || die "gh is not installed"
gh auth status >/dev/null 2>&1 || die "gh is not signed in (run: gh auth login)"

log "fetching origin/main"
git -C "$REPO_DIR" fetch -q origin main
REMOTE="$(git -C "$REPO_DIR" rev-parse origin/main)"

for asset in "${ASSETS[@]}"; do
  [[ -e "$LOCAL_BASE/$asset" || -n "$(tree_paths "$REMOTE" "$asset")" ]] ||
       die "$asset is listed but exists neither in $LOCAL_BASE nor in the repo"
  git -C "$REPO_DIR" show "$REMOTE:scripts/17-claude-skills.sh" | grep -q "\${SRC_DIR}/$asset\"" ||
       die "$asset is not deployed by scripts/17-claude-skills.sh; add a deploy_skill/deploy_file line there first"
done

# The base: --base, else the recorded ref, else none.
BASE=""
if [[ -n "$BASE_ARG" ]]; then
  BASE="$(git -C "$REPO_DIR" rev-parse --verify "$BASE_ARG^{commit}")" || die "--base $BASE_ARG is not a commit"
  git -C "$REPO_DIR" merge-base --is-ancestor "$BASE" "$REMOTE" || die "--base $BASE_ARG is not on origin/main"
elif BASE="$(git -C "$REPO_DIR" rev-parse -q --verify "$BASE_REF" 2>/dev/null)"; then
  :
else
  BASE=""
  log "no recorded base: files that differ can only be decided where history settles it"
fi
if [[ -n "$BASE" ]]; then log "base: ${BASE:0:7}, origin/main: ${REMOTE:0:7}"; fi

# Bring the main checkout to origin/main, but only when that can't disturb
# anything: it is on main, clean, and main can fast-forward. Every real run
# ends here, whether it pushed, only pulled, or found nothing to do.
ff_main_checkout() {
  git -C "$REPO_DIR" fetch -q --prune origin
  if [[ "$(git -C "$REPO_DIR" branch --show-current)" != main || -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
    log "main checkout not on a clean main: left as it is"
  elif [[ "$(git -C "$REPO_DIR" rev-parse HEAD)" == "$(git -C "$REPO_DIR" rev-parse origin/main)" ]]; then
    :
  elif git -C "$REPO_DIR" merge -q --ff-only origin/main 2>/dev/null; then
    log "main checkout fast-forwarded to $(git -C "$REPO_DIR" rev-parse --short HEAD)"
  else
    log "main checkout has commits origin/main doesn't: left as it is"
  fi
}

# === PLAN ===
#
# One line per file that differs: "<action> <path>", action one of
# push | pull | merge | conflict. Nothing is written until the whole plan has
# no conflict.

PLAN="$(mktemp)"
MERGED_DIR="$(mktemp -d)"
trap 'rm -rf "$PLAN" "$MERGED_DIR"' EXIT

for asset in "${ASSETS[@]}"; do
  {
    local_paths "$asset"
    tree_paths "$REMOTE" "$asset"
    if [[ -n "$BASE" ]]; then tree_paths "$BASE" "$asset"; fi
  } | sort -u | while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    l="$(local_blob "$p")"
    r="$(blob_at "$REMOTE" "$p")"
    [[ "$l" == "$r" ]] && continue
    if [[ -n "$BASE" ]]; then
      b="$(blob_at "$BASE" "$p")"
      if [[ "$r" == "$b" ]]; then
        echo "push $p"
      elif [[ "$l" == "$b" ]]; then
        echo "pull $p"
      elif [[ -n "$l" && -n "$r" && -n "$b" ]]; then
        out="$MERGED_DIR/$(echo "$p" | tr / _)"
        # merge-file reads real files: a <(...) pipe reads as empty and the
        # merge would come out "clean" against nothing.
        git -C "$REPO_DIR" cat-file blob "$b" >"$out.base"
        git -C "$REPO_DIR" cat-file blob "$r" >"$out.repo"
        if git -C "$REPO_DIR" merge-file -p -L "this machine" -L base -L repo \
          "$(local_file "$p")" "$out.base" "$out.repo" >"$out"; then
          echo "merge $p"
        else
          echo "conflict $p"
        fi
      else
        echo "conflict $p" # added on both sides, or deleted on one and changed on the other
      fi
    else
      # No base. History can still prove the repo is ahead: this machine's copy
      # is an older repo version, or the file is one only the repo has. Anything
      # else is undecidable without a base, so it stops rather than guess.
      history=""
      for c in $(git -C "$REPO_DIR" log --format=%H "$REMOTE" -- "$p"); do
        history+="$(blob_at "$c" "$p")"$'\n'
      done
      # Searched after collecting: grep -q closing a pipe early would trip pipefail.
      if [[ -z "$l" ]] || grep -qx "$l" <<<"$history"; then
        echo "pull $p"
      else
        echo "conflict $p"
      fi
    fi
  done
done >"$PLAN"

count() { grep -c "^$1 " "$PLAN" || true; }
if [[ ! -s "$PLAN" ]]; then
  log "already in sync: ~/.claude and the repo's configs/claude match."
  if [[ "$DRY_RUN" == 0 ]]; then
    git -C "$REPO_DIR" update-ref "$BASE_REF" "$REMOTE"
    ff_main_checkout
  fi
  exit 0
fi

log "plan: $(count push) to push, $(count pull) to pull, $(count merge) to merge, $(count conflict) in conflict"
sed 's/^/  /' "$PLAN"

if grep -q '^conflict ' "$PLAN"; then
  if [[ -z "$BASE" ]]; then
    log "with no recorded base, a file that differs on both sides can't be decided safely."
    log "If ~/.claude was last installed from or synced to a known repo commit, rerun with"
    log "--base <that commit>. Otherwise compare the files above by hand first."
  else
    CONFLICTS="$STATE_DIR/conflicts/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$CONFLICTS"
    grep '^conflict ' "$PLAN" | cut -d' ' -f2- | while IFS= read -r p; do
      f="$MERGED_DIR/$(echo "$p" | tr / _)"
      [[ -f "$f" ]] && cp "$f" "$CONFLICTS/"
    done
    log "both sides changed these files and the changes overlap. Nothing was changed."
    log "Merge attempts with conflict markers, where there was one to make: $CONFLICTS"
    log "Resolve each in ~/.claude (take the repo's change into it), then sync again."
  fi
  exit 2
fi

if ((DRY_RUN)); then
  log "dry run: nothing changed."
  exit 0
fi

# === PULL (and merge) INTO ~/.claude, with backups ===

BACKUP="$STATE_DIR/backups/$(date -u +%Y%m%dT%H%M%SZ)"
{ grep -E '^(pull|merge) ' "$PLAN" || true; } | while read -r action p; do
  f="$(local_file "$p")"
  if [[ -e "$f" ]]; then
    mkdir -p "$BACKUP/$(dirname "${p#"$DEST_PREFIX"/}")"
    cp -p "$f" "$BACKUP/${p#"$DEST_PREFIX"/}"
  fi
  # Written beside the file and renamed into place, never truncated in place:
  # one of these files may be this very script, still being read by bash.
  tmp="$f.sync-skills.$$"
  mkdir -p "$(dirname "$f")"
  if [[ "$action" == merge ]]; then
    cp "$MERGED_DIR/$(echo "$p" | tr / _)" "$tmp"
    if [[ -x "$f" ]]; then chmod +x "$tmp"; fi
    mv -f "$tmp" "$f"
  elif [[ -n "$(blob_at "$REMOTE" "$p")" ]]; then
    git -C "$REPO_DIR" cat-file blob "$REMOTE:$p" >"$tmp"
    if [[ "$(git -C "$REPO_DIR" ls-tree "$REMOTE" -- "$p" | cut -c1-6)" == 100755 ]]; then chmod +x "$tmp"; fi
    mv -f "$tmp" "$f"
  else
    rm -f "$f" # the repo deleted it
  fi
  echo "  pulled $p"
done
if grep -qE '^(pull|merge) ' "$PLAN"; then log "pulled into ~/.claude (previous copies in $BACKUP)"; fi

# A newer copy of this script came in: finish on it, once. Everything pulled so
# far now matches the repo, so the restarted run plans only what is left.
if grep -qE "^(pull|merge) $DEST_PREFIX/scripts/sync-skills.sh\$" "$PLAN" &&
     [[ "$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")" == "$(cd "$(dirname "$SELF")" && pwd -P)/$(basename "$SELF")" ]] &&
     [[ -z "${SYNC_SKILLS_RESTARTED:-}" ]]; then
  log "pulled a newer sync-skills.sh: restarting on it"
  SYNC_SKILLS_RESTARTED=1 exec "$SELF" ${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}
fi

# Only pulls: the repo already holds the result.
if ! grep -qE '^(push|merge) ' "$PLAN"; then
  git -C "$REPO_DIR" update-ref "$BASE_REF" "$REMOTE"
  log "nothing to push. Base is now ${REMOTE:0:7}."
  ff_main_checkout
  exit 0
fi

# === PUSH: a worktree from origin/main, the checks, a PR, CI, the merge ===

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BRANCH="sync-skills-$STAMP"
WT="${TMPDIR:-/tmp}/codespaces-setup-$BRANCH"
git -C "$REPO_DIR" worktree add -q -b "$BRANCH" "$WT" "$REMOTE"
cleanup() {
  git -C "$REPO_DIR" worktree remove --force "$WT" 2>/dev/null || true
  git -C "$REPO_DIR" branch -D "$BRANCH" >/dev/null 2>&1 || true
}
log "worktree: $WT (branch $BRANCH)"

{ grep -E '^(push|merge) ' "$PLAN" || true; } | cut -d' ' -f2- | while IFS= read -r p; do
  f="$(local_file "$p")"
  if [[ -f "$f" ]]; then
    mkdir -p "$WT/$(dirname "$p")"
    cp -p "$f" "$WT/$p"
  else
    rm -f "$WT/$p"
  fi
done
git -C "$WT" add -A "$DEST_PREFIX"

# After the pulls and the pushes, both sides must hold the same files.
for asset in "${ASSETS[@]}"; do
  diff -rq "${EXCLUDES[@]/#/--exclude=}" "$LOCAL_BASE/$asset" "$WT/$DEST_PREFIX/$asset" >/dev/null 2>&1 ||
       die "after the sync, ~/.claude/$asset and the worktree still differ (worktree left at $WT)"
done

run_check() {
  log "check: $*"
  if ! (cd "$WT" && "$@") >/dev/null 2>&1; then
    (cd "$WT" && "$@") 2>&1 | tail -20 | sed 's/^/  /'
    die "check failed: $* (worktree left at $WT)"
  fi
}
ET="$DEST_PREFIX/skills/engineering-team/scripts"
DS="$DEST_PREFIX/skills/design-system/scripts"
for s in check_report check_run check_plan check_board check_footprint context_usage; do run_check python3 "$ET/$s.py" --selftest; done
run_check python3 "$DS/check_design_system.py" --selftest
run_check python3 "$DS/design_preview.py" --selftest
run_check node "$DS/render_previews.mjs" --selftest
run_check python3 "$DS/mockup.py" --selftest
run_check node "$DS/render_mockup.mjs" --selftest
# The second try resolves from uv's cache alone, so a PyPI outage doesn't fail
# the check when the packages were fetched before. A real failure fails both.
uv_run_cached() { uv run -q "$@" || uv run -q --offline "$@"; }
if command -v uv >/dev/null; then
  run_check uv_run_cached --with fonttools --with brotli python3 "$DS/wordmark.py" --selftest
else
  log "uv not installed: skipping wordmark.py's selftest (CI still runs it)"
fi
run_check bash ci/lint-skill-versions.sh --base "$REMOTE"
run_check python3 tests/engineering-team-triggering/run.py --selftest
run_check python3 tests/design-system-triggering/run.py --selftest
run_check python3 tests/engineering-team-drift/drift_scan.py
run_check python3 tests/engineering-team-command-links/check_command_links.py

changed="$(git -C "$WT" diff --cached --name-only | sed -E "s#^$DEST_PREFIX/(skills/[^/]+|commands/[^/]+).*#\1#" | sort -u)"
subject="Sync Claude skills and commands from ~/.claude"
# Backticks below are Markdown for the PR body, not command substitution.
# shellcheck disable=SC2016
body="$(
  printf 'Brings %s/ up to date with ~/.claude for:\n\n' "$DEST_PREFIX"
  while IFS= read -r a; do printf -- '- `%s`\n' "$a"; done <<<"$changed"
  printf '\n```\n%s\n```\n\n' "$(git -C "$WT" diff --cached --stat)"
  printf 'Made by `~/.claude/scripts/sync-skills.sh`, three-way against base %s: ' "${BASE:0:7}"
  printf '%s pushed, %s merged, %s pulled into ~/.claude first. ' "$(count push)" "$(count merge)" "$(count pull)"
  printf 'The skill checks passed before the push.\n\nSync-Skills: %s\n' "$STAMP"
)"
git -C "$WT" commit -q -m "$subject" -m "$body"
SYNCED="$(git -C "$WT" rev-parse HEAD)"
git -C "$WT" push -q -u origin "$BRANCH"
pr_url="$(cd "$WT" && gh pr create --base main --head "$BRANCH" --title "$subject" --body "$body")"
log "PR: $pr_url"

# The gate is the ci workflow's run on the synced commit, and nothing else.
# Other checks on the PR depend on services outside GitHub (the container smoke
# test installs real tools from the internet; third-party apps have their own
# outages), so they are reported, never waited on: a change to skill docs must
# not be held up by a CDN. Waiting on every check is how a failed Neovim plugin
# download once stopped a sync.
CI_WORKFLOW="ci.yml"
POLL="${SYNC_SKILLS_POLL:-20}" # seconds; the test sets 0
log "waiting for CI ($CI_WORKFLOW)"
run_id=""
# A run registers a few seconds after the PR opens.
for _ in $(seq 1 30); do
  run_id="$(cd "$WT" && gh run list --workflow "$CI_WORKFLOW" --commit "$SYNCED" --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  [[ -n "$run_id" ]] && break
  sleep "$POLL"
done
[[ -n "$run_id" ]] ||
  die "no $CI_WORKFLOW run started for $pr_url; nothing merged (worktree left at $WT). ~/.claude keeps what was pulled."
(cd "$WT" && gh run watch "$run_id" --interval "$POLL" >/dev/null 2>&1) || true
conclusion="$(cd "$WT" && gh run view "$run_id" --json conclusion -q .conclusion 2>/dev/null || true)"
if [[ "$conclusion" != success ]]; then
  (cd "$WT" && gh pr checks "$pr_url") | sed 's/^/  /' || true
  die "CI ($CI_WORKFLOW) ended '${conclusion:-unknown}' on $pr_url; nothing merged (worktree left at $WT). ~/.claude keeps what was pulled."
fi
others="$(cd "$WT" && gh pr checks "$pr_url" 2>/dev/null | awk -F'\t' '$2 == "fail" { print $1 }' || true)"
if [[ -n "$others" ]]; then
  log "note: merging on $CI_WORKFLOW; these other checks failed and do not gate: $(paste -sd ',' - <<<"$others" | sed 's/,/, /g')"
fi

# A squash merge that would conflict (main changed the same file meanwhile)
# fails here rather than overwriting it.
(cd "$WT" && gh pr merge "$pr_url" --squash --delete-branch --subject "$subject (#$(basename "$pr_url"))" --body "$body") >/dev/null 2>&1 ||
     die "the merge of $pr_url failed (worktree left at $WT)"
log "merged: $(cd "$WT" && gh pr view "$pr_url" --json mergeCommit -q .mergeCommit.oid | cut -c1-7)"

# The base is the commit this machine's files equal: the synced branch, not
# main, because main may have gained another change while CI ran. The ref also
# keeps that commit alive after its branch is deleted.
git -C "$REPO_DIR" update-ref "$BASE_REF" "$SYNCED"
cleanup
git -C "$REPO_DIR" fetch -q --prune origin
if [[ "$(git -C "$REPO_DIR" rev-parse "origin/main:$DEST_PREFIX")" != "$(git -C "$REPO_DIR" rev-parse "$SYNCED:$DEST_PREFIX")" ]]; then
  log "note: main gained another change to $DEST_PREFIX while this sync ran; the next sync pulls it."
fi
ff_main_checkout
log "done. Base is now ${SYNCED:0:7}."
