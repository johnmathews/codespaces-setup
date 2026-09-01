#!/usr/bin/env bash
# Resilience test for setup.sh + the shared retry helper (scripts/lib.sh).
#
# Fully headless (no network, no sudo, no LLM), so — like the drift-scan and the
# command-link check — it runs the REAL thing in CI, not a selftest. It drives
# the real setup.sh over a throwaway set of fake steps via the SETUP_* env hooks
# it exposes for exactly this purpose, and asserts the behaviour the problem
# statement demands:
#
#   1. A forced-fail (non-required) step does NOT abort the run — every
#      remaining step still executes.
#   2. The end-of-run summary names each failed step, and setup.sh exits non-zero.
#   3. The failure is left VISIBLE to someone who wasn't watching: a durable
#      signal file is written (the same file configs/.zshrc surfaces on shell
#      start).
#   4. A required step that fails DOES abort (the documented exception), and the
#      steps after it do not run.
#   5. A fully clean run exits 0, prints the COMPLETE banner, and removes any
#      stale signal file.
#   6. The retry helper retries transient failures and eventually gives up with
#      the command's own exit code.
#   7. A run whose steps all SUCCEED but whose tools are absent must not report
#      success — the defect that produced "not all the tools are installed" on a
#      run that printed the green COMPLETE banner and exited 0.
#   8. A step that fails once and works on the end-of-run retry pass leaves the
#      run green, and SETUP_RETRY_PASS=0 disables that pass.
#
# Usage: bash tests/setup-resilience/run.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP="${REPO_DIR}/setup.sh"
LIB="${REPO_DIR}/scripts/lib.sh"

PASS=0
FAIL=0
ok() {
  PASS=$((PASS + 1))
  echo "  ok: $*"
}
bad() {
  FAIL=$((FAIL + 1))
  echo "  FAIL: $*" >&2
}
SKIP=0
# Counted separately and reported loudly. A check that could not RUN is not a
# check that passed, and it is not a defect either — conflating either way makes
# the suite lie. Used only where the blocker is environmental (no pty available)
# and provably not a property of the code under test.
skip() {
  SKIP=$((SKIP + 1))
  echo "  SKIP: $*" >&2
}

# assert_contains <description> <file> <needle>
assert_contains() {
  if grep -qF -- "$3" "$2"; then ok "$1"; else
    bad "$1 (expected to find '$3' in $2)"
  fi
}
# assert_absent <description> <file> <needle>
assert_absent() {
  if grep -qF -- "$3" "$2"; then bad "$1 (unexpectedly found '$3' in $2)"; else
    ok "$1"
  fi
}

# make_flaky <dir> <base> — a step that fails the FIRST time it runs and succeeds
# on any later invocation. This is the shape the end-of-run retry pass exists
# for, and the fixture generator below cannot express it (it encodes one fixed
# exit code).
make_flaky() {
  local dir="$1" base="$2"
  mkdir -p "${dir}"
  cat >"${dir}/${base}.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "${base}" >>"${RAN_MARKER}"
if [[ -f "\${FLAKY_MARK}" ]]; then
  echo "second attempt: succeeding"
  exit 0
fi
touch "\${FLAKY_MARK}"
echo "first attempt: failing" >&2
exit 1
EOF
}

# make_hanging <dir> <base> <seconds> — a step that STALLS rather than failing.
# This is the slow-network failure mode: `retry` cannot act on it, because a
# stalled command never exits to be retried. Only a wall clock catches it.
make_hanging() {
  local dir="$1" base="$2" secs="$3"
  mkdir -p "${dir}"
  cat >"${dir}/${base}.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "${base}" >>"${RAN_MARKER}"
sleep ${secs}
EOF
}

# Build a throwaway scripts dir. Each fake step appends its own name to
# ${RAN_MARKER} (proving it ran) and exits with the code encoded in its name:
# *-ok.sh exit 0, *-fail.sh exit 1.
make_fixture() {
  local dir="$1"
  mkdir -p "${dir}"
  # $2.. are "name:rc" pairs, e.g. "01-a:0" "02-b:1"
  shift
  local spec base rc
  for spec in "$@"; do
    base="${spec%%:*}"
    rc="${spec##*:}"
    cat >"${dir}/${base}.sh" <<EOF
#!/usr/bin/env bash
echo "\${RAN_MARKER}" >/dev/null
printf '%s\n' "${base}" >>"${RAN_MARKER}"
exit ${rc}
EOF
  done
}

# run_setup <scripts_dir> <steps> <required> <home> — returns setup.sh exit code
# in RC, and leaves its log at ${home}/.cache/codespaces-setup.log.
# SKIP_VERIFY defaults to 1: these scenarios drive the runner over FAKE steps
# that install nothing, so the end-of-run tool verification would (correctly)
# report every tool missing, which is not what they are measuring. Scenario 5
# sets it to 0 to cover that block itself.
run_setup() {
  local scripts_dir="$1" steps="$2" required="$3" home="$4"
  local skip_verify="${SKIP_VERIFY:-1}"
  mkdir -p "${home}/.cache"
  RC=0
  env -i \
    HOME="${home}" \
    PATH="${PATH}" \
    SETUP_SCRIPTS_DIR="${scripts_dir}" \
    SETUP_STEPS="${steps}" \
    SETUP_REQUIRED="${required}" \
    SETUP_SKIP_VERIFY="${skip_verify}" \
    SETUP_LOG="${home}/.cache/codespaces-setup.log" \
    SETUP_LOG_DIR="${home}/.cache" \
    RAN_MARKER="${RAN_MARKER}" \
    FLAKY_MARK="${FLAKY_MARK:-/nonexistent}" \
    SETUP_RETRY_PASS="${RETRY_PASS:-1}" \
    SETUP_DEPS="${DEPS:-}" \
    SETUP_STEP_TIMEOUT="${STEP_TIMEOUT:-1200}" \
    bash "${SETUP}" >/dev/null 2>&1 || RC=$?
  # setup.sh execs stdout through `tee` (a background process); give it a beat to
  # flush the log before we read it.
  local log="${home}/.cache/codespaces-setup.log"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    grep -q "CODESPACES SETUP" "${log}" 2>/dev/null && break
    sleep 0.2
  done
}

echo "== scenario 1: a non-required step fails, the rest still run =="
WORK="$(mktemp -d)"
SCR="${WORK}/scripts"
HOME_DIR="${WORK}/home"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
make_fixture "${SCR}" "01-a:0" "02-b:1" "03-c:0" "04-d:1" "05-e:0"
run_setup "${SCR}" \
  "01-a.sh|Step A;02-b.sh|Step B;03-c.sh|Step C;04-d.sh|Step D;05-e.sh|Step E" \
  "" "${HOME_DIR}"
LOG="${HOME_DIR}/.cache/codespaces-setup.log"
FAILFILE="${HOME_DIR}/.cache/codespaces-setup.failed"

# 1. every step ran, including the ones after the failures
for s in 01-a 02-b 03-c 04-d 05-e; do
  if grep -qx "${s}" "${RAN_MARKER}"; then ok "step ${s} ran"; else
    bad "step ${s} did not run"
  fi
done
# 2. non-zero exit
if [[ "${RC}" -ne 0 ]]; then ok "setup exited non-zero (${RC})"; else
  bad "setup exited 0, expected non-zero"
fi
# 3. summary names the failed steps
assert_contains "summary names failed Step B" "${LOG}" "Step B"
assert_contains "summary names failed Step D" "${LOG}" "Step D"
assert_contains "summary names failing script 02-b.sh" "${LOG}" "02-b.sh"
assert_contains "INCOMPLETE banner shown" "${LOG}" "SETUP INCOMPLETE"
assert_absent  "COMPLETE banner NOT shown" "${LOG}" "SETUP COMPLETE"
# 4. durable signal file exists and names the failures (what .zshrc surfaces)
if [[ -f "${FAILFILE}" ]]; then ok "durable failure file written"; else
  bad "durable failure file missing at ${FAILFILE}"
fi
assert_contains "failure file names Step B" "${FAILFILE}" "Step B"
assert_contains "failure file names Step D" "${FAILFILE}" "Step D"
rm -rf "${WORK}"

echo "== scenario 2: a REQUIRED step fails and aborts the run =="
WORK="$(mktemp -d)"
SCR="${WORK}/scripts"
HOME_DIR="${WORK}/home"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
make_fixture "${SCR}" "01-req:1" "02-after:0"
run_setup "${SCR}" "01-req.sh|Required step;02-after.sh|After step" \
  "01-req.sh" "${HOME_DIR}"
LOG="${HOME_DIR}/.cache/codespaces-setup.log"
FAILFILE="${HOME_DIR}/.cache/codespaces-setup.failed"

if grep -qx "01-req" "${RAN_MARKER}"; then ok "required step ran"; else
  bad "required step did not run"
fi
if grep -qx "02-after" "${RAN_MARKER}"; then
  bad "step after required failure ran (should have aborted)"
else
  ok "run aborted after required failure (later step skipped)"
fi
if [[ "${RC}" -ne 0 ]]; then ok "setup exited non-zero on required failure (${RC})"; else
  bad "setup exited 0 on required failure"
fi
if [[ -f "${FAILFILE}" ]]; then ok "durable failure file written on required abort"; else
  bad "durable failure file missing on required abort"
fi
assert_contains "required-abort summary names the step" "${LOG}" "Required step"
rm -rf "${WORK}"

echo "== scenario 3: a fully clean run exits 0 and clears the signal =="
WORK="$(mktemp -d)"
SCR="${WORK}/scripts"
HOME_DIR="${WORK}/home"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
mkdir -p "${HOME_DIR}/.cache"
# Pre-seed a stale signal from a hypothetical earlier failed run.
echo "stale failure" >"${HOME_DIR}/.cache/codespaces-setup.failed"
make_fixture "${SCR}" "01-a:0" "02-b:0"
run_setup "${SCR}" "01-a.sh|Step A;02-b.sh|Step B" "" "${HOME_DIR}"
LOG="${HOME_DIR}/.cache/codespaces-setup.log"
FAILFILE="${HOME_DIR}/.cache/codespaces-setup.failed"

if [[ "${RC}" -eq 0 ]]; then ok "clean run exited 0"; else
  bad "clean run exited ${RC}, expected 0"
fi
assert_contains "COMPLETE banner shown on clean run" "${LOG}" "SETUP COMPLETE"
if [[ ! -f "${FAILFILE}" ]]; then ok "stale signal file removed on clean run"; else
  bad "stale signal file NOT removed on clean run"
fi
rm -rf "${WORK}"

echo "== scenario 4: retry helper (scripts/lib.sh) =="
# Each check runs in its own subshell (to source lib.sh with a local log()) and
# reports via its exit code, so the outer ok()/bad() keep the PASS/FAIL tally
# accurate.
if (
  # shellcheck disable=SC2317,SC2329  # invoked indirectly, via retry
  log() { echo "[test] $*"; }
  # shellcheck source=/dev/null
  source "${LIB}"
  attempts=0
  # shellcheck disable=SC2317,SC2329  # invoked indirectly, via retry
  flaky() {
    attempts=$((attempts + 1))
    [[ "${attempts}" -ge 3 ]]
  }
  RETRY_BASE_DELAY=0 retry flaky && [[ "${attempts}" -eq 3 ]]
); then
  ok "retry recovers a flaky command once it stops failing (3 tries)"
else
  bad "retry did not recover a flaky command"
fi

if (
  # shellcheck disable=SC2317,SC2329  # invoked indirectly, via retry
  log() { echo "[test] $*"; }
  # shellcheck source=/dev/null
  source "${LIB}"
  tries=0
  # shellcheck disable=SC2317,SC2329  # invoked indirectly, via retry
  countingfalse() {
    tries=$((tries + 1))
    return 7
  }
  rc=0
  RETRY_ATTEMPTS=3 RETRY_BASE_DELAY=0 retry countingfalse || rc=$?
  [[ "${rc}" -eq 7 && "${tries}" -eq 3 ]]
); then
  ok "retry gives up after RETRY_ATTEMPTS and returns the command's exit code"
else
  bad "retry give-up path wrong (wrong exit code or attempt count)"
fi

echo "== scenario 5: every step succeeds but the tools are missing =="
# The regression test for the defect that motivated this work. setup.sh used to
# print a cross for each missing tool, then print the green COMPLETE banner,
# delete the failure signal and exit 0 - so a half-built Codespace reported
# success and the shell-start notice never fired. HOME is a fresh temp dir, so
# none of the config artefacts the verification looks for exist.
WORK="$(mktemp -d)"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
make_fixture "${WORK}/scripts" "01-noop:0"
HOME5="${WORK}/home"
mkdir -p "${HOME5}"
SKIP_VERIFY=0 run_setup "${WORK}/scripts" "01-noop.sh|Installs nothing" "" "${HOME5}"
LOG="${HOME5}/.cache/codespaces-setup.log"
FAILFILE="${HOME5}/.cache/codespaces-setup.failed"

if [[ "${RC}" -ne 0 ]]; then
  ok "run with missing tools exits non-zero (${RC})"
else
  bad "run with missing tools exited 0 — the defect this work exists to fix"
fi
assert_contains "INCOMPLETE banner shown when tools are missing" "${LOG}" "SETUP INCOMPLETE"
assert_absent "COMPLETE banner NOT shown when tools are missing" "${LOG}" "SETUP COMPLETE"
# Scenario 5 is the every-step-succeeded case, so the summary must use the
# pointed wording. When a step HAS failed the wording is deliberately neutral,
# because claiming the step reported success would be false.
assert_contains "summary explains the tools-missing case" "${LOG}" \
  "missing even though every step reported success"
if [[ -f "${FAILFILE}" ]]; then
  ok "durable signal written when only tools are missing"
  assert_contains "signal file names the missing tools" "${FAILFILE}" "Missing after setup"
else
  bad "no durable signal written when tools are missing"
  bad "signal file does not name the missing tools"
fi
rm -rf "${WORK}"

echo "== scenario 6: a transient failure recovers on the end-of-run retry pass =="
# The flaky-network case the user described: a step fails early (the VM's network
# is not up yet) and would work moments later. Before the retry pass this left a
# permanently half-built Codespace even though nothing was actually wrong.
WORK="$(mktemp -d)"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
FLAKY_MARK="${WORK}/flaky.mark"
export FLAKY_MARK
make_fixture "${WORK}/scripts" "01-a:0"
make_flaky "${WORK}/scripts" "02-flaky"
HOME6="${WORK}/home"
mkdir -p "${HOME6}"
run_setup "${WORK}/scripts" "01-a.sh|Step A;02-flaky.sh|Flaky step" "" "${HOME6}"
LOG="${HOME6}/.cache/codespaces-setup.log"

if [[ "${RC}" -eq 0 ]]; then
  ok "a run whose only failure recovers exits 0"
else
  bad "run exited ${RC}; a recovered transient failure should end green"
fi
assert_contains "retry pass ran" "${LOG}" "RETRYING FAILED STEPS"
assert_contains "retry pass reports the recovery" "${LOG}" "1 recovered, 0 still failing"
assert_contains "COMPLETE banner after recovery" "${LOG}" "SETUP COMPLETE"
if [[ -f "${HOME6}/.cache/codespaces-setup.failed" ]]; then
  bad "signal file left behind after a full recovery"
else
  ok "no signal file after a full recovery"
fi

# And with the pass disabled, the same run must stay failed - proving the pass
# is what recovers it rather than something else.
rm -f "${FLAKY_MARK}"
HOME6B="${WORK}/home_b"
mkdir -p "${HOME6B}"
RETRY_PASS=0 run_setup "${WORK}/scripts" "01-a.sh|Step A;02-flaky.sh|Flaky step" "" "${HOME6B}"
if [[ "${RC}" -ne 0 ]]; then
  ok "with SETUP_RETRY_PASS=0 the same run stays failed"
else
  bad "SETUP_RETRY_PASS=0 did not disable the retry pass"
fi
unset FLAKY_MARK
rm -rf "${WORK}"

echo "== scenario 7: an interactive (TTY) run does not corrupt its own log =="
# The HAS_TTY branch of run_step was never exercised by this harness, which is
# how the following survived: on failure it echoed `tail -n 20` of the log to
# stdout, and stdout is redirected into `tee -a` on that SAME log. Each failure
# appended 20 lines of the log to itself and the next failure re-read the
# injected copy, so the log showed steps completing twice, out of order, with
# duplicated run headers - on precisely the run someone is reading.
if command -v script >/dev/null 2>&1; then
  WORK="$(mktemp -d)"
  RAN_MARKER="${WORK}/ran.txt"
  : >"${RAN_MARKER}"
  make_fixture "${WORK}/scripts" "01-a:0" "02-b:1" "03-c:0" "04-d:1"
  HOME7="${WORK}/home"
  mkdir -p "${HOME7}/.cache"
  LOG="${HOME7}/.cache/codespaces-setup.log"

  # `script` gives the child a real pty, so setup.sh takes HAS_TTY=1.
  cat >"${WORK}/inner.sh" <<INNER
#!/usr/bin/env bash
export HOME="${HOME7}"
export SETUP_SCRIPTS_DIR="${WORK}/scripts"
export SETUP_STEPS="01-a.sh|Step A;02-b.sh|Step B;03-c.sh|Step C;04-d.sh|Step D"
export SETUP_REQUIRED=""
export SETUP_SKIP_VERIFY=1
export SETUP_RETRY_PASS=0
export SETUP_LOG="${LOG}"
export SETUP_LOG_DIR="${HOME7}/.cache"
export RAN_MARKER="${RAN_MARKER}"
exec bash "${SETUP}"
INNER
  chmod +x "${WORK}/inner.sh"
  # BSD and GNU `script` take different arguments; try both. Then WAIT for the
  # log rather than sleeping a fixed amount: setup.sh writes it through `tee`, a
  # background process, so a loaded machine can outrun a fixed sleep. That was
  # the cause of an intermittent 3-assertion failure in this scenario.
  tty_attempt() {
    script -q /dev/null "${WORK}/inner.sh" >/dev/null 2>&1 ||
      script -q -c "${WORK}/inner.sh" /dev/null >/dev/null 2>&1 ||
      true
    local _i
    for _i in $(seq 1 25); do
      grep -q "CODESPACES SETUP" "${LOG}" 2>/dev/null && return 0
      sleep 0.2
    done
    return 1
  }

  if ! tty_attempt; then
    # One retry: pty allocation is the flaky part, not setup.sh.
    : >"${LOG}" 2>/dev/null || true
    : >"${RAN_MARKER}"
    tty_attempt || true
  fi

  if [[ -s "${LOG}" ]]; then
    HDRS="$(grep -c "CODESPACES SETUP START" "${LOG}" || true)"
    STEPA="$(grep -c "Completed  : Step A" "${LOG}" || true)"
    if [[ "${HDRS}" == "1" ]]; then
      ok "TTY run: the start banner appears exactly once (log not fed back into itself)"
    else
      bad "TTY run: start banner appears ${HDRS} times — the log is duplicating itself"
    fi
    if [[ "${STEPA}" == "1" ]]; then
      ok "TTY run: each completed step is recorded exactly once"
    else
      bad "TTY run: 'Completed : Step A' appears ${STEPA} times — log corrupted"
    fi
    assert_absent "TTY run: the tail-context block never reaches the log" \
      "${LOG}" "----- last 20 lines of"
  else
    # Could not get a pty. That says nothing about setup.sh, so it must not be
    # reported as a defect — but it must be loud, or a permanently-unrunnable
    # check would masquerade as a passing one.
    skip "TTY run: could not allocate a pty via 'script'; the TTY branch was NOT exercised"
  fi
  rm -rf "${WORK}"
else
  skip "TTY run: no 'script' command available to allocate a pty"
fi

echo "== scenario 8: a step whose dependency failed is SKIPPED, not failed =="
# Before continue-on-failure this was unreachable: the run died at the
# dependency, so the dependent never ran. Now it does, and it fails for a reason
# that has nothing to do with itself - producing two entries in the FAILED
# banner for one root cause, with nothing saying which is which.
WORK="$(mktemp -d)"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
make_fixture "${WORK}/scripts" "09-dep:1" "18-needs-dep:0" "20-unrelated:0"
HOME8="${WORK}/home"
mkdir -p "${HOME8}"
DEPS="18-needs-dep.sh:09-dep.sh" RETRY_PASS=0 run_setup "${WORK}/scripts" \
  "09-dep.sh|Dependency;18-needs-dep.sh|Dependent;20-unrelated.sh|Unrelated" \
  "" "${HOME8}"
LOG="${HOME8}/.cache/codespaces-setup.log"

assert_contains "the dependent is reported as skipped" "${LOG}" \
  "Skipped    : depends on 09-dep.sh"
assert_contains "the summary explains why it was skipped" "${LOG}" \
  "skipped because something they depend on failed"
if grep -qx "18-needs-dep" "${RAN_MARKER}"; then
  bad "the dependent actually RAN despite its dependency failing"
else
  ok "the dependent did not run"
fi
if grep -qx "20-unrelated" "${RAN_MARKER}"; then
  ok "an unrelated step still runs"
else
  bad "an unrelated step was wrongly skipped"
fi
# The root cause appears once, as a failure; the dependent does not appear as one.
if grep -q "✗ \[2\]" "${LOG}"; then
  bad "the dependent was listed as a FAILED step (duplicating one root cause)"
else
  ok "the dependent is not listed as a failed step"
fi
rm -rf "${WORK}"

echo "== scenario 9: a hanging step is bounded, not waited on forever =="
# The user asked for resilience to "flaky OR SLOW networks". The retry helper
# only ever addressed the first: it cannot act until the command EXITS, so a
# stalled TCP connection or a download trickling at 2 KB/s hung the whole run
# indefinitely on one step. Verified before the fix: a 25s hanging step ran to
# completion uninterrupted and the run still exited 0.
WORK="$(mktemp -d)"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
make_hanging "${WORK}/scripts" "01-hang" 60
make_fixture "${WORK}/scripts" "02-after:0"
HOME9="${WORK}/home"
mkdir -p "${HOME9}"

START="$(date +%s)"
STEP_TIMEOUT=3 RETRY_PASS=0 run_setup "${WORK}/scripts" \
  "01-hang.sh|A stalled download;02-after.sh|After" "" "${HOME9}"
ELAPSED=$(($(date +%s) - START))

if ((ELAPSED < 45)); then
  ok "a 60s hanging step was bounded (run took ${ELAPSED}s)"
else
  bad "the run waited ${ELAPSED}s on a hanging step — it is not bounded"
fi
if grep -qx "02-after" "${RAN_MARKER}"; then
  ok "the run continued past the stalled step"
else
  bad "the run did not reach the step after the stalled one"
fi
rm -rf "${WORK}"

echo "== scenario 10: two runs over the same HOME stay distinguishable =="
# `tee -a` appends forever with no timestamps and no run boundary, so
# `tail -n 200` - the command the failure file itself recommends - silently
# spliced two runs together and there was no way to tell today's rebuild from
# last week's.
WORK="$(mktemp -d)"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
make_fixture "${WORK}/scripts" "01-a:0"
HOME10="${WORK}/home"
mkdir -p "${HOME10}"
run_setup "${WORK}/scripts" "01-a.sh|Step A" "" "${HOME10}"
FIRST_ID="$(python3 -c "import json;print(json.load(open('${HOME10}/.cache/latest.json'))['run_id'])" 2>/dev/null || echo "")"
sleep 1
run_setup "${WORK}/scripts" "01-a.sh|Step A" "" "${HOME10}"
SECOND_ID="$(python3 -c "import json;print(json.load(open('${HOME10}/.cache/latest.json'))['run_id'])" 2>/dev/null || echo "")"

if [[ -n "${FIRST_ID}" && -n "${SECOND_ID}" && "${FIRST_ID}" != "${SECOND_ID}" ]]; then
  ok "each run has a distinct id (${FIRST_ID} then ${SECOND_ID})"
else
  bad "run ids are missing or identical ('${FIRST_ID}' vs '${SECOND_ID}')"
fi
if [[ -f "${HOME10}/.cache/latest.json" ]]; then
  ok "latest.json points at the most recent run"
else
  bad "no latest.json written"
fi
rm -rf "${WORK}"

echo "== scenario 11: an interrupted run leaves a durable signal =="
# The failure mode that used to leave NOTHING. write_failure_file was reachable
# from two in-flow paths only, so a SIGTERM - which is what the Codespaces
# creation-time budget does to postCreateCommand - exited with no signal, no
# banner and no record, indistinguishable from a clean run to every later shell.
WORK="$(mktemp -d)"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
make_hanging "${WORK}/scripts" "01-slow" 30
HOME11="${WORK}/home"
mkdir -p "${HOME11}/.cache"
env -i HOME="${HOME11}" PATH="${PATH}" \
  SETUP_SCRIPTS_DIR="${WORK}/scripts" \
  SETUP_STEPS="01-slow.sh|A stalled download" \
  SETUP_REQUIRED="" SETUP_SKIP_VERIFY=1 SETUP_RETRY_PASS=0 \
  SETUP_LOG="${HOME11}/.cache/codespaces-setup.log" \
  SETUP_LOG_DIR="${HOME11}/.cache" \
  RAN_MARKER="${RAN_MARKER}" \
  bash "${SETUP}" >/dev/null 2>&1 &
SETUP_PID=$!
sleep 3
kill -TERM "${SETUP_PID}" 2>/dev/null || true
wait "${SETUP_PID}" 2>/dev/null || true
sleep 1

FAILFILE="${HOME11}/.cache/codespaces-setup.failed"
if [[ -f "${FAILFILE}" ]]; then
  ok "a durable signal exists after SIGTERM"
  assert_contains "the signal names the interruption" "${FAILFILE}" "interrupted by TERM"
else
  bad "no durable signal after SIGTERM — an interrupted run left no trace"
  bad "the signal does not name the interruption (no file)"
fi
if [[ -f "${HOME11}/.cache/latest.json" ]]; then
  if grep -q '"outcome": "interrupted"' "${HOME11}/.cache/latest.json"; then
    ok "the run record says the run was interrupted"
  else
    bad "the run record does not record an interruption"
  fi
else
  bad "no run record written on interrupt"
fi
rm -rf "${WORK}"

echo ""
if ((SKIP > 0)); then
  echo "== ${SKIP} check(s) SKIPPED — they did not run, and did not pass =="
fi
echo "== results: ${PASS} passed, ${FAIL} failed =="
if [[ "${FAIL}" -ne 0 ]]; then
  exit 1
fi
echo "ALL PASSED"
