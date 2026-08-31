# setup-resilience — the run-every-step + retry guarantees

A headless test that drives the **real** `setup.sh` and asserts the two
guarantees this repo's automatic (unattended) provisioning path depends on. It
uses no network, no `sudo`, and no model, so — like the
[drift-scan](../engineering-team-drift/) and the
[command-link check](../engineering-team-command-links/) — it runs the real thing
in CI, not a selftest.

## Why it exists

`setup.sh` is run automatically by GitHub Codespaces via the dotfiles mechanism
at codespace creation, where **nobody is watching the output**. It used to abort
the whole run the instant any step exited non-zero (`die`), so a single transient
failure (e.g. a flaky `curl … | sh` installer) left the remaining steps unrun and
the environment half-built — and, because it was unattended, unnoticed. This test
locks in the fix.

## What it checks

`run.sh` builds a throwaway `scripts/` dir of fake steps and drives the real
`setup.sh` over it through the env hooks `setup.sh` exposes for exactly this
purpose — `SETUP_SCRIPTS_DIR`, `SETUP_STEPS`, `SETUP_REQUIRED`,
`SETUP_LOG`/`SETUP_FAILURE_FILE` (via `HOME`). Scenarios:

1. **A non-required step fails → the run continues.** Two of five fake steps are
   forced to fail; all five must still run, `setup.sh` must exit non-zero, the
   end-of-run summary must name each failed step, and the `INCOMPLETE` banner (not
   `COMPLETE`) must show.
2. **The failure is left visible.** A durable signal file
   (`~/.cache/codespaces-setup.failed`) must be written naming the failures — the
   same file `configs/.zshrc` cats on the next interactive shell.
3. **A required step that fails aborts.** With `01-apt-packages.sh` marked
   required in the real run (it installs the tools every later step needs), a
   failing required step must abort and the step after it must not run.
4. **A clean run exits 0 and self-heals.** All steps pass → exit 0, `COMPLETE`
   banner, and any stale signal file from a previous failed run is removed.
5. **The retry helper** (`scripts/lib.sh`) recovers a flaky command and, when a
   command keeps failing, gives up after `RETRY_ATTEMPTS` returning that
   command's own exit code.

## Run locally

```bash
bash tests/setup-resilience/run.sh
```

Prints `ALL PASSED` and exits 0 on success; lists each failed assertion and exits
non-zero otherwise.
