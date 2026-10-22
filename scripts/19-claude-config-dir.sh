#!/usr/bin/env bash
# Keep Claude Code's config dir on the persisted /workspaces volume, so session
# transcripts, history, memory and settings survive a Codespace rebuild.
#
# A rebuild recreates the container: $HOME is wiped and only /workspaces is kept.
# Claude Code keeps everything in ~/.claude plus ~/.claude.json, so a rebuild
# silently lost every session transcript — `claude --resume` came back empty and
# the only trace of the previous session was a Claude-Session trailer in a commit.
#
# Two mechanisms, deliberately both:
#
#   1. CLAUDE_CONFIG_DIR — exported by configs/.zshrc, derived from the symlink
#      below. With it set, Claude Code also keeps .claude.json INSIDE the dir, so
#      one directory holds the whole state.
#   2. Symlinks ~/.claude and ~/.claude.json -> the persisted dir. The env var only
#      reaches interactive zsh; anything launched another way (the VS Code
#      extension, a non-interactive shell, 17-claude-skills.sh, setup.sh's own
#      verification) still uses ~/.claude. Without the links those would write a
#      second, divergent config that the next rebuild throws away.
#
# Must run BEFORE 12-claude-code.sh and 17-claude-skills.sh, so their writes go
# through the link rather than into a fresh ~/.claude this step then has to merge.
#
# Merge rule when both sides exist (the normal case right after a rebuild, where
# something already created a fresh ~/.claude): the union of the two, and where
# a file exists in both, the PERSISTED copy wins — it holds the history; the fresh
# one holds minutes of setup. Built in a staging dir with plain `cp -a` and
# swapped in by rename, because `cp -n`'s exit status differs across coreutils
# versions and a half-merged config dir is worse than none.
#
# Not a Codespace (no /workspaces) -> nothing to persist to; exits 0 untouched.
# Test hooks: CLAUDE_PERSIST_DIR overrides the target, HOME the source.

set -euo pipefail

log() { echo "[claude-config-dir] $*"; }

PERSIST_DIR="${CLAUDE_PERSIST_DIR:-/workspaces/.claude-config}"
HOME_DIR="${HOME}/.claude"
HOME_JSON="${HOME}/.claude.json"
PERSIST_JSON="${PERSIST_DIR}/.claude.json"

if [[ ! -d "$(dirname "${PERSIST_DIR}")" ]]; then
  log "$(dirname "${PERSIST_DIR}") does not exist (not a Codespace?); leaving ~/.claude alone."
  exit 0
fi

# True when $1 is a symlink resolving to $2.
links_to() {
  [[ -L "$1" ]] && [[ "$(readlink -f "$1")" == "$(readlink -f "$2")" ]]
}

# --- ~/.claude --------------------------------------------------------------
if links_to "${HOME_DIR}" "${PERSIST_DIR}"; then
  log "${HOME_DIR} -> ${PERSIST_DIR}: already linked."
elif [[ -L "${HOME_DIR}" ]]; then
  # Someone pointed it elsewhere on purpose. Not ours to override.
  log "ERROR: ${HOME_DIR} is a symlink to $(readlink "${HOME_DIR}"), not ${PERSIST_DIR}; leaving it."
  exit 1
elif [[ -e "${HOME_DIR}" && ! -d "${HOME_DIR}" ]]; then
  log "ERROR: ${HOME_DIR} exists and is not a directory; leaving it."
  exit 1
else
  staging="${PERSIST_DIR}.staging.$$"
  rm -rf "${staging}"
  mkdir -p "${staging}"
  if [[ -d "${HOME_DIR}" ]]; then
    log "merging ${HOME_DIR} into ${PERSIST_DIR} (persisted copy wins on conflict)..."
    cp -a "${HOME_DIR}/." "${staging}/"
  fi
  if [[ -d "${PERSIST_DIR}" ]]; then
    cp -a "${PERSIST_DIR}/." "${staging}/"
  fi
  chmod 700 "${staging}"
  # Same filesystem, so both renames are atomic; .old is removed only after the
  # merged dir is in place.
  if [[ -d "${PERSIST_DIR}" ]]; then
    mv "${PERSIST_DIR}" "${PERSIST_DIR}.old.$$"
  fi
  mv "${staging}" "${PERSIST_DIR}"
  rm -rf "${PERSIST_DIR}.old.$$"
  rm -rf "${HOME_DIR}"
  ln -s "${PERSIST_DIR}" "${HOME_DIR}"
  log "${HOME_DIR} -> ${PERSIST_DIR}: linked."
fi

# --- ~/.claude.json ---------------------------------------------------------
# Lives inside the persisted dir (where Claude Code puts it when
# CLAUDE_CONFIG_DIR is set); ~/.claude.json links to it for everything else.
if links_to "${HOME_JSON}" "${PERSIST_JSON}"; then
  log "${HOME_JSON} -> ${PERSIST_JSON}: already linked."
else
  if [[ -L "${HOME_JSON}" ]]; then
    rm -f "${HOME_JSON}" # a stale link of ours, or a dangling one; nothing to keep
  elif [[ -f "${HOME_JSON}" ]]; then
    if [[ -f "${PERSIST_JSON}" ]]; then
      # The persisted one wins, as above. The fresh one may hold edits that exist
      # nowhere else, so it is kept as a .bak — $HOME is not a scanned dir.
      log "${PERSIST_JSON} already exists; keeping it, old ${HOME_JSON} saved as ${HOME_JSON}.bak"
      mv "${HOME_JSON}" "${HOME_JSON}.bak"
    else
      mv "${HOME_JSON}" "${PERSIST_JSON}"
    fi
  fi
  ln -s "${PERSIST_JSON}" "${HOME_JSON}"
  log "${HOME_JSON} -> ${PERSIST_JSON}: linked."
fi
