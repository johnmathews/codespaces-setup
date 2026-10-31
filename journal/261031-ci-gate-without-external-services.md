# The CI gate no longer depends on services outside GitHub

A `/sync-skills` run for a docs-only skill change stopped with "CI failed". The
failure was the `universal:6` container smoke test: the Neovim plugin sync, which
downloads from the internet, failed. That job was already `continue-on-error`, so
the `ci` workflow as a whole was green, but the sync waited on every check on the
PR (`gh pr checks --watch`), and a failed advisory check counted.

The rule now: **the gate must not depend on services outside GitHub being up.**

- **The sync gates on the `ci.yml` run for its commit**, and nothing else. It lists
  any other failed check in a "note:" line and merges anyway. `tests/sync-skills`
  case 8 drives this with a fake `gh`: ci passed and smoke failed, so it merges and
  names smoke; ci failed, so nothing is merged. Run against the old script, case 8
  fails.
- **The smoke test moved to its own workflow**, `smoke.yml`: PRs, `main`, weekly,
  and by hand. It never gates and won't be promoted to required, as the old comment
  planned, because installing real tools from the internet is its whole purpose.
  Inside `ci.yml` it still showed a red check on every PR, which is how the sync
  tripped over it.
- **`ci.yml` lost its third-party downloads where it could.** shfmt comes from its
  GitHub release instead of a Docker Hub image. The zsh install retries. fontTools
  and brotli come from GitHub's uv cache, with pruning off so the wheels stay, and
  the step retries `--offline` when PyPI can't be reached. The sync script's own
  wordmark check does the same.

What's left: GitHub itself (Actions, release assets, the cache), the Ubuntu
package mirror the runner image uses for zsh, and PyPI on a cold cache. No branch
protection is set on `main`, so the sync's wait is the only thing that holds a merge
back.
