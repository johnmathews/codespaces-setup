# Two test suites pass on macOS again; struck evidence passes the issue check

> Purpose
>
> Why `tests/setup-resilience` and `tests/claude-config-dir` were red on macOS, how #117 was settled under the new issue-update rules, and the checker bug that settling it exposed.

## 1. Causes (both confirmed)

- **#116, `tests/claude-config-dir/run.sh:53`:** read a folder's mode with GNU `stat -c %a`. On macOS, `stat -c %a /tmp` printed `stat: illegal option -- c`. The fix tries GNU `stat` and falls back to BSD `stat -f %Lp`.
- **#117, scenario 13 of `tests/setup-resilience/run.sh`:**
  - The fake `bootstrap-linux` required `NODE_EXTRA_CA_CERTS` to name `/etc/ssl/certs/ca-certificates.crt`.
  - `scripts/lib.sh:18` exports it only when that file exists, and macOS has none. So the script was right and the test was Linux-only.
  - A rerun with a diagnostic printed `CHECK FAILED: NODE_EXTRA_CA_CERTS=<unset>` on all three attempts.
  - The bootstrap never succeeded, so `03-neovim.sh` stopped before its `sudo` calls. That is why one cause showed as three failures.
  - The test now expects the bundle only where it exists, and elsewhere only that the variable does not claim it. A user's own `NODE_EXTRA_CA_CERTS` on macOS therefore still passes.

## 2. Settling #117 with the new rules

#117 was filed as an `investigation` earlier the same day. Settling it followed `references/issues.md` §7:

- a `**TL;DR:**` comment with the evidence;
- a body edit with a new TL;DR, the guess struck through and the verified claim added;
- `investigation` swapped for `maintenance`;
- `verify` afterwards.

The first `check` of the edited body failed. A struck claim (`- ~~Inferred: ...~~`) was read as an unlabelled one, so the rule "strike wrong evidence, never delete it" was impossible to follow. `issue_labels.py` now strips the strike before reading the label, and leaves a struck claim out of the live claims, so a struck `Inferred:` cannot satisfy an `investigation`. The new test failed before the fix (observed).

## 3. What is deliberately not done

- **No change to `scripts/lib.sh` or `03-neovim.sh`.** They target Linux Codespaces, and skipping a missing CA bundle is the intended behaviour.
- **No macOS job in CI.** The suites are meant to run locally on macOS and in CI on Linux. A macOS runner would add cost for a portability gap that two one-line fixes closed.
