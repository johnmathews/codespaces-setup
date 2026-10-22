# Claude Code sessions lost to a Codespace rebuild

**Date:** 2026-10-22. **PR:** feat/persist-claude-config-dir. Point-in-time record; authoritative for nothing.

A Codespace rebuild wiped `$HOME`, and with it `~/.claude` and `~/.claude.json`: every session transcript, the prompt history, and memory. `/workspaces` survived, so the repos were intact, but `claude --resume` had nothing to resume. The only trace of the previous session was the `Claude-Session:` trailer on the commit it made. The transcript was still on claude.ai, so it was recoverable. Without that trailer, it would not have been.

## 1. What changed

`scripts/19-claude-config-dir.sh` moves the config to `/workspaces/.claude-config` and symlinks `~/.claude` and `~/.claude.json` to it. `configs/.zshrc` exports `CLAUDE_CONFIG_DIR` by following the link. With the variable set, Claude Code keeps `.claude.json` inside the dir (checked: a `claude mcp list` under a scratch `CLAUDE_CONFIG_DIR` wrote `.claude.json` there, not to `$HOME`).

## 2. Why both the variable and the links

The variable alone was the obvious fix, and it would have produced two configs. Only interactive zsh sees it. The VS Code extension, non-interactive shells, `17-claude-skills.sh` and setup's own verification all use `~/.claude`, and would have written a second config into the wiped home. The links make the plain path correct everywhere, which is also why nothing else in the repo needed changing.

## 3. Merge rule

Right after a rebuild both sides exist. The result is their union, and where a file exists on both sides the persisted copy wins: it holds the history, while the fresh one holds a few minutes of setup. The merge is built in a staging dir with plain `cp -a` and swapped in by rename. The step avoids `cp -n` because its exit status on a skipped file changed across coreutils versions.

## 4. Verified

- `tests/claude-config-dir/run.sh` covers 16 assertions across fresh, post-rebuild, re-run, foreign-symlink and non-Codespace cases. CI runs it.
- The step was applied live on the Codespace that lost its history, and the running session's transcript kept growing at the persisted path.
