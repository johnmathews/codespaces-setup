# 260901 — Setup resilience and observability

> Why a Codespace could come up missing tools while reporting success, and what
> changed. Follows PR #50 (2026-08-31), which this work reviews and extends.

## 1. The report

> "i need this script to be resilient and handle flaky or slow networks.
> sometimes when a new codespace vm is being setup and the script runs, not all
> the tools are installed. i cant see in the vm much information about what has
> or hasnt happened."

Two complaints, and they turned out to have four distinct causes between them.

## 2. What PR #50 got right, and what it left

PR #50 was a real improvement: one failing step stopped stranding the run, every
direct network call got wrapped in a backoff `retry`, two `curl | sh` pipelines
became download-then-run, and a 24-assertion headless test landed in CI.

But it hardened the failure mode that was already **visible** — a step exiting
non-zero — and left every invisible one open. Each of these was reproduced
before being fixed:

1. **A truncated download became a permanent broken install.** `curl -o` writes
   to its destination as bytes arrive and does not unlink on error; `tar -xzf`
   leaves whatever it wrote. So a dropped transfer left a real, executable,
   *wrong* binary at the final install path — and the next run's `[[ -x ]]` guard
   called it installed. The documented remedy, "re-run setup.sh, it's
   idempotent", was therefore precisely what could not fix it. This is the one
   that made a bad Codespace *permanent* rather than merely bad.

2. **The end-of-run verification could not fail.** It printed a cross for each
   missing tool, then printed the green COMPLETE banner, deleted the durable
   failure signal, and exited 0. Nothing in `check_tool` reached the exit code.
   The banner was also printed *before* the verification ran, so it could not
   have known. The run knew tools were missing and said it had succeeded.

3. **Nothing bounded a hang.** `retry` is a post-mortem mechanism — it cannot act
   until a command *exits*. A stalled TCP connection or a download trickling at
   2 KB/s never exits, so the run stopped dead on one step. There was no
   `timeout`, `--max-time`, `--connect-timeout` or `--speed-limit` anywhere in
   the repo. "Flaky" and "slow" are different failure modes and only the first
   had been addressed.

4. **An interrupted run left no trace at all.** `write_failure_file` was
   reachable from two in-flow paths only, so a SIGTERM — which is what the
   Codespaces creation-time budget does to `postCreateCommand` — exited with no
   signal, no banner and no record. Combined with (3), reaping was the *expected*
   outcome on a slow network, and it was the one outcome that left nothing
   behind.

## 3. Decisions worth keeping

**The guard must run the artifact, not stat it.** This is the single most
important rule to come out of this work. `[[ -x path ]]` and `command -v` cannot
distinguish a working binary from a truncated download at the same path. Three
scripts (`07-lazygit.sh`, `16-gh.sh`, `18-azure-cli.sh`) already did it right by
parsing `--version`; that pattern is now `installed_version_is` in `lib.sh` and
applied everywhere. Everything else in this change depends on it — the end-of-run
retry pass would have been useless without it, because a re-attempt would have
been told the tool was already installed.

**Nothing unverified may reach a final install path.** `fetch_verified` stages
the download, proves the archive is complete (`tar -tzf` / `unzip -t`), and
removes the destination on every failure path. That last part is deliberately not
`curl --remove-on-error`: Ubuntu 22.04 ships curl 7.81 without it, and that is
the default image the account-wide dotfiles path lands on. An unknown flag would
have made curl exit on an option-parse error and burned every retry attempt.

**Bound each attempt *and* each step.** `RETRY_TIMEOUT` covers a stalled
download; `SETUP_STEP_TIMEOUT` is the backstop for a step that hangs for another
reason — a debconf prompt with no tty, a sudo password prompt, apt blocking on
the dpkg lock. The second one was found by writing the test for the first.

**Invert the failure signal's default.** Write it at the start of the run and
remove it only on verified success. The old design wrote it on failure, which
means every unanticipated exit path was silent by construction.

**Report the conclusion, keep the history.** `summary.json` records both attempts
of a retried step, because "this needed retrying" is itself the signal that the
network was flaky rather than the tool being broken. `setup-status` collapses
them and reports the outcome. The record is for machines; the tool is for people.

**Mark derived failures as skipped, not failed.** `09-uv.sh` failing produced two
entries in the FAILED banner — uv, and `18-azure-cli.sh` failing *because* uv was
missing — with nothing saying which was the cause. This was unreachable before
continue-on-failure existed, so it is regression work created by PR #50 rather
than pre-existing debt.

**A gate ships with a test proving it goes red.** `ci/lint-conventions.sh` exists
because a script violating all seven documented conventions at once — including
the exact `.bak`-into-a-scanned-directory bug `CLAUDE.md` records as having
already happened — passed every existing gate green. Its fixtures prove each rule
can fail, and it caught a real unretried `apt-get install` on its first run
against the real scripts.

## 4. What was deliberately not done

- **No checksum verification of downloads.** Staging plus functional guards stop
  a corrupt artifact being installed or mistaken for installed, which is the
  failure that was actually hit. Checksums add authenticity rather than
  integrity, and need per-upstream URL work for nine tools. Worth doing; a
  separate change.
- **No lock file for the concurrent double-run.** The run id makes the two runs
  legible and the apt lock timeout stops them aborting each other, but a real
  "one run at a time" guarantee is a separate design question.
- **`ci/lint-conventions.sh` does not check idempotency.** It is a behavioural
  property; a grep for it would be a check that cannot fail, which is worse than
  no check.

## 5. Still open

- The installers are still executed by nothing in CI. A container smoke test
  against `mcr.microsoft.com/devcontainers/base:ubuntu` is the largest remaining
  gap — it would have caught three of the four defects above.
- CI is still advisory: `main` has no branch protection and no rulesets, so every
  gate here blocks nothing until that changes. That is a repo-settings change.
- Whether the `tee` flush race is real on Linux is unsettled. The harness already
  works around it with a polling loop; either that workaround is unnecessary or
  the race is real, and nobody knows which.
