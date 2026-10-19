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
# Later scenarios extend the same approach to the UPDATE path — `--only` /
# `--group` selection and the self-update — because that path is a selector over
# the very same STEPS array, not a second runner:
#
#   14. A selection runs exactly the named steps, in STEPS order; an unknown
#       name or flag is a hard error rather than a silent full run; dependency
#       skipping still applies; and a clean PARTIAL run does not clear a failure
#       signal left by an earlier run, because it never attempted those steps.
#   15. setup.sh fetches and fast-forwards its own checkout before running, and
#       survives every case that actually occurs: already current, uncommitted
#       local edits (never discarded), an unreachable origin, a shallow clone,
#       a non-git directory, and the explicit opt-out.
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

# run_setup <scripts_dir> <steps> <required> <home> [args...] — returns setup.sh
# exit code in RC, and leaves its log at ${home}/.cache/codespaces-setup.log.
# Arguments after <home> are passed to setup.sh itself (--only/--group/...).
# SKIP_VERIFY defaults to 1: these scenarios drive the runner over FAKE steps
# that install nothing, so the end-of-run tool verification would (correctly)
# report every tool missing, which is not what they are measuring. Scenario 5
# sets it to 0 to cover that block itself.
#
# SETUP_NO_SELF_UPDATE=1 throughout: setup.sh now fast-forwards its own checkout
# before running, and a test harness must never reach the network or mutate the
# working tree it is testing. Scenario 15 covers the self-update itself, against
# a local origin it builds for the purpose.
run_setup() {
  local scripts_dir="$1" steps="$2" required="$3" home="$4"
  shift 4
  local skip_verify="${SKIP_VERIFY:-1}"
  mkdir -p "${home}/.cache"
  RC=0
  env -i \
    HOME="${home}" \
    PATH="${PATH}" \
    SETUP_SCRIPTS_DIR="${scripts_dir}" \
    SETUP_STEPS="${steps}" \
    SETUP_REQUIRED="${required}" \
    SETUP_GROUPS="${GROUPS_SPEC:-}" \
    SETUP_NO_SELF_UPDATE=1 \
    SETUP_SKIP_VERIFY="${skip_verify}" \
    SETUP_LOG="${home}/.cache/codespaces-setup.log" \
    SETUP_LOG_DIR="${home}/.cache" \
    RAN_MARKER="${RAN_MARKER}" \
    FLAKY_MARK="${FLAKY_MARK:-/nonexistent}" \
    SETUP_RETRY_PASS="${RETRY_PASS:-1}" \
    SETUP_DEPS="${DEPS:-}" \
    SETUP_STEP_TIMEOUT="${STEP_TIMEOUT:-1200}" \
    bash "${SETUP}" "$@" >/dev/null 2>&1 || RC=$?
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
export SETUP_NO_SELF_UPDATE=1
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
  SETUP_REQUIRED="" SETUP_SKIP_VERIFY=1 SETUP_RETRY_PASS=0 SETUP_NO_SELF_UPDATE=1 \
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

echo "== scenario 12: a step that declines the platform is SKIPPED, not failed =="
# A step exiting 3 (SETUP_SKIP_RC) means "deliberately not installed here" — an
# unsupported platform, not a defect. Recording it as a failure would be wrong
# twice over: nothing is broken, and re-running cannot change it. Ubuntu 20.04
# cannot run Neovim/yazi/stylua at all (glibc 2.31), which is what this is for.
WORK="$(mktemp -d)"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
make_fixture "${WORK}/scripts" "01-ok:0" "02-unsupported:3" "03-broken:1"
HOME12="${WORK}/home"
mkdir -p "${HOME12}"
run_setup "${WORK}/scripts" \
  "01-ok.sh|Fine;02-unsupported.sh|Needs a newer platform;03-broken.sh|Genuinely broken" \
  "" "${HOME12}"
LOG="${HOME12}/.cache/codespaces-setup.log"

assert_contains "the unsupported step is reported as skipped" "${LOG}" \
  "Skipped    : Needs a newer platform"
assert_contains "the summary says re-running will not help" "${LOG}" \
  "declined to install on this platform"
assert_absent "the unsupported step is NOT listed as failed" "${LOG}" \
  "✗ FAILED     : Needs a newer platform"
assert_contains "a genuine failure is still reported as failed" "${LOG}" \
  "✗ FAILED     : Genuinely broken"
if grep -q "Retrying   : Needs a newer platform" "${LOG}"; then
  bad "the retry pass re-ran a step that declined the platform"
else
  ok "the retry pass leaves an unsupported step alone"
fi
rm -rf "${WORK}"

echo "== scenario 13: upstream Neovim wrappers preserve PATH, retries and status =="
WORK="$(mktemp -d)"
NVIM_HOME="${WORK}/home"
mkdir -p "${NVIM_HOME}/.config/nvim/scripts" "${NVIM_HOME}/.local/bin"
git -C "${NVIM_HOME}/.config/nvim" init -q
printf 'committed lockfile\n' >"${NVIM_HOME}/.config/nvim/lazy-lock.json"
git -C "${NVIM_HOME}/.config/nvim" add lazy-lock.json
git -C "${NVIM_HOME}/.config/nvim" -c user.name=Test -c user.email=test@example.invalid commit -qm fixture
cat >"${NVIM_HOME}/.local/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${HOME}/sudo-calls"
EOF
cat >"${NVIM_HOME}/.local/bin/nvim" <<'EOF'
#!/usr/bin/env bash
echo 'NVIM v0.12.6'
EOF
cat >"${NVIM_HOME}/.config/nvim/scripts/bootstrap-linux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${PREFIX}" == "${HOME}/.local" ]]
[[ "${PATH%%:*}" == "${HOME}/.local/bin" ]]
[[ "${PWD}" == "${HOME}/.config/nvim" ]]
[[ "${NODE_EXTRA_CA_CERTS}" == /etc/ssl/certs/ca-certificates.crt ]]
[[ "${RETRY_TIMEOUT}" == 300 ]]
printf 'bootstrap\n' >>"${HOME}/calls"
EOF
cat >"${NVIM_HOME}/.config/nvim/scripts/sync-plugins" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${PATH%%:*}" == "${HOME}/.local/bin" ]]
[[ "${PWD}" == "${HOME}/.config/nvim" ]]
grep -qx 'committed lockfile' lazy-lock.json
printf 'sync\n' >>"${HOME}/calls"
case "${SYNC_TEST_MODE:-ok}" in
  fail) exit 2 ;;
  hang)
    printf 'interrupted drift\n' >lazy-lock.json
    sleep 60 &
    printf '%s\n' "$!" >>"${HOME}/children"
    wait
    ;;
  flaky)
    if [[ ! -f "${HOME}/retried" ]]; then
      touch "${HOME}/retried"
      printf 'failed attempt drift\n' >lazy-lock.json
      exit 1
    fi
    ;;
esac
EOF
chmod +x "${NVIM_HOME}/.local/bin/nvim" "${NVIM_HOME}/.local/bin/sudo"
NVIM_ENV=(env HOME="${NVIM_HOME}" PATH="${PATH}" RETRY_BASE_DELAY=0 RETRY_MAX_DELAY=0)
if "${NVIM_ENV[@]}" bash "${REPO_DIR}/scripts/03-neovim.sh" >"${WORK}/bootstrap.log" 2>&1; then
  ok "bootstrap uses upstream checkout, forced user-local prefix, PATH and proxy trust"
else
  bad "bootstrap did not honor its upstream contract"
fi
assert_contains "bootstrap repairs the system nvim link" "${NVIM_HOME}/sudo-calls" \
  "ln -sfn ${NVIM_HOME}/.local/bin/nvim /usr/local/bin/nvim"
assert_contains "bootstrap removes only the obsolete installation" "${NVIM_HOME}/sudo-calls" \
  "rm -rf /opt/nvim-v0.11.5"
if "${NVIM_ENV[@]}" bash "${REPO_DIR}/scripts/13-nvim-plugins.sh" >"${WORK}/sync.log" 2>&1; then
  ok "upstream sync succeeds"
else
  bad "upstream sync failed"
fi
STATUS="${NVIM_HOME}/.cache/nvim-setup.status"
assert_contains "successful sync records ok" "${STATUS}" "ok"
CALLS_BEFORE="$(grep -c '^sync$' "${NVIM_HOME}/calls")"
if "${NVIM_ENV[@]}" SYNC_TEST_MODE=fail bash "${REPO_DIR}/scripts/13-nvim-plugins.sh" >"${WORK}/sync.log" 2>&1; then
  bad "upstream refusal incorrectly reported success"
else
  ok "upstream refusal returns nonzero"
fi
assert_contains "upstream refusal records incomplete" "${STATUS}" "incomplete"
assert_contains "upstream exit code is retained" "${STATUS}" "exit 2"
if [[ "$(grep -c '^sync$' "${NVIM_HOME}/calls")" == "$((CALLS_BEFORE + 1))" ]]; then
  ok "upstream refusal is not retried"
else
  bad "upstream refusal was retried"
fi
if "${NVIM_ENV[@]}" SYNC_TEST_MODE=flaky bash "${REPO_DIR}/scripts/13-nvim-plugins.sh" >"${WORK}/sync.log" 2>&1; then
  ok "transient upstream sync failure recovers"
else
  bad "sync retry failed"
fi
assert_contains "recovered sync clears incomplete status" "${STATUS}" "ok"
if "${NVIM_ENV[@]}" SYNC_TEST_MODE=hang NVIM_SYNC_TIMEOUT=1 \
  bash "${REPO_DIR}/scripts/13-nvim-plugins.sh" >"${WORK}/sync.log" 2>&1; then
  bad "hanging sync incorrectly reported success"
else
  ok "hanging upstream sync is bounded"
fi
assert_contains "timed out sync records incomplete" "${STATUS}" "exit 124"
while read -r child; do
  if kill -0 "${child}" 2>/dev/null && [[ "$(ps -o stat= -p "${child}")" != Z* ]]; then
    bad "timeout left upstream child ${child} running"
  else
    ok "timeout stops upstream child before retry"
  fi
done <"${NVIM_HOME}/children"
if "${NVIM_ENV[@]}" bash "${REPO_DIR}/scripts/13-nvim-plugins.sh" >"${WORK}/sync.log" 2>&1; then
  ok "a later sync repairs lockfile drift left by the final timeout"
else
  bad "final timeout poisoned a later sync"
fi
rm "${NVIM_HOME}/.config/nvim/scripts/sync-plugins"
if "${NVIM_ENV[@]}" bash "${REPO_DIR}/scripts/13-nvim-plugins.sh" >"${WORK}/sync.log" 2>&1; then
  bad "missing upstream sync incorrectly reported success"
else
  ok "missing upstream sync fails"
fi
assert_contains "missing script records incomplete, never ok" "${STATUS}" "incomplete"
rm -rf "${WORK}"

echo "== scenario 14: --only / --group select a subset of STEPS =="
# The update path is a SELECTOR over STEPS, never a second list of things to do.
# These checks pin the four properties that make that claim true rather than
# merely intended: the selection runs exactly what was named, in STEPS order;
# an unknown name is a hard error rather than a silent full run; dependency
# skipping still applies inside a selection; and — the subtle one — a clean
# partial run does NOT clear a failure signal left by an earlier full run.
WORK="$(mktemp -d)"
RAN_MARKER="${WORK}/ran.txt"
: >"${RAN_MARKER}"
make_fixture "${WORK}/scripts" "01-a:0" "02-b:0" "03-c:0" "04-d:0"
STEPSPEC="01-a.sh|Step A;02-b.sh|Step B;03-c.sh|Step C;04-d.sh|Step D"
HOME14="${WORK}/home"
mkdir -p "${HOME14}"

run_setup "${WORK}/scripts" "${STEPSPEC}" "" "${HOME14}" --only 03-c.sh 01-a.sh
LOG="${HOME14}/.cache/codespaces-setup.log"

if [[ "${RC}" -eq 0 ]]; then ok "--only run exited 0"; else
  bad "--only run exited ${RC}, expected 0"
fi
# Exactly the named steps, and nothing else.
if [[ "$(sort "${RAN_MARKER}" | tr '\n' ' ')" == "01-a 03-c " ]]; then
  ok "--only ran exactly the named steps"
else
  bad "--only ran '$(tr '\n' ' ' <"${RAN_MARKER}")', expected '01-a 03-c'"
fi
# STEPS order, not the order they were typed. The numeric prefixes are labels;
# STEPS is the only thing that knows what has to run before what, so a selection
# that honoured argv order would silently reorder a dependency.
if [[ "$(tr '\n' ' ' <"${RAN_MARKER}")" == "01-a 03-c " ]]; then
  ok "--only preserves STEPS order, not the order given on the command line"
else
  bad "--only ran in argv order: '$(tr '\n' ' ' <"${RAN_MARKER}")'"
fi
assert_contains "a partial run says so in its banner" "${LOG}" "SETUP (PARTIAL)"
assert_contains "a clean partial run gets its own banner" "${LOG}" "SELECTED STEPS COMPLETE"
assert_absent "a partial run never prints the full COMPLETE banner" "${LOG}" "SETUP COMPLETE"
if grep -q '"filtered": true' "${HOME14}/.cache/latest.json"; then
  ok "the run record marks the run as filtered"
else
  bad "the run record does not mark the run as filtered"
fi

# --group resolves through STEP_GROUPS (overridden here, exactly as SETUP_STEPS
# overrides STEPS, so the harness tests the real resolution over fake steps).
: >"${RAN_MARKER}"
HOME14B="${WORK}/home_b"
mkdir -p "${HOME14B}"
GROUPS_SPEC="pair|04-d.sh,02-b.sh" \
  run_setup "${WORK}/scripts" "${STEPSPEC}" "" "${HOME14B}" --group pair
if [[ "$(tr '\n' ' ' <"${RAN_MARKER}")" == "02-b 04-d " ]]; then
  ok "--group runs its members, in STEPS order"
else
  bad "--group ran '$(tr '\n' ' ' <"${RAN_MARKER}")', expected '02-b 04-d'"
fi

# An unknown name is a HARD ERROR. Before argv was parsed at all, every typo'd
# flag was silently a full run, which is the most expensive possible way to
# misunderstand a command.
: >"${RAN_MARKER}"
HOME14C="${WORK}/home_c"
mkdir -p "${HOME14C}"
run_setup "${WORK}/scripts" "${STEPSPEC}" "" "${HOME14C}" --only 99-nope.sh
if [[ "${RC}" -ne 0 ]]; then
  ok "an unknown step name exits non-zero (${RC})"
else
  bad "an unknown step name was accepted — the run proceeded"
fi
if [[ ! -s "${RAN_MARKER}" ]]; then
  ok "an unknown step name runs nothing at all"
else
  bad "an unknown step name still ran: $(tr '\n' ' ' <"${RAN_MARKER}")"
fi
: >"${RAN_MARKER}"
HOME14D="${WORK}/home_d"
mkdir -p "${HOME14D}"
run_setup "${WORK}/scripts" "${STEPSPEC}" "" "${HOME14D}" --group nope
if [[ "${RC}" -ne 0 && ! -s "${RAN_MARKER}" ]]; then
  ok "an unknown group name is rejected and runs nothing"
else
  bad "an unknown group name was not rejected (rc=${RC})"
fi
: >"${RAN_MARKER}"
HOME14E="${WORK}/home_e"
mkdir -p "${HOME14E}"
run_setup "${WORK}/scripts" "${STEPSPEC}" "" "${HOME14E}" --frobnicate
if [[ "${RC}" -ne 0 && ! -s "${RAN_MARKER}" ]]; then
  ok "an unknown FLAG is rejected rather than silently running everything"
else
  bad "an unknown flag did not abort (rc=${RC})"
fi

# Dependency skipping still applies inside a selection: selecting a dependent
# whose dependency failed must still skip it, not run it into a derived failure.
: >"${RAN_MARKER}"
HOME14F="${WORK}/home_f"
mkdir -p "${HOME14F}"
make_fixture "${WORK}/scripts2" "09-dep:1" "18-needs-dep:0"
DEPS="18-needs-dep.sh:09-dep.sh" RETRY_PASS=0 \
  run_setup "${WORK}/scripts2" \
  "09-dep.sh|Dependency;18-needs-dep.sh|Dependent;20-other.sh|Other" \
  "" "${HOME14F}" --only 09-dep.sh 18-needs-dep.sh
LOG="${HOME14F}/.cache/codespaces-setup.log"
assert_contains "dependency skipping still applies in a selected run" "${LOG}" \
  "Skipped    : depends on 09-dep.sh"
if grep -qx "18-needs-dep" "${RAN_MARKER}"; then
  bad "the dependent ran inside a selection despite its dependency failing"
else
  ok "the dependent did not run inside a selection"
fi

# A step that was dependency-SKIPPED must not be forgotten when its blocker
# recovers on the retry pass. It is not in FAILED_STEPS, so the retry loop never
# considers it — and a FILTERED run skips the whole-environment verification that
# would otherwise notice, so nothing else can catch it either. Left alone, the
# run reports "SELECTED STEPS COMPLETE" and exits 0 having never run a step it
# was explicitly asked to run: a half-built environment reporting success, which
# is the single failure this whole runner exists to prevent.
: >"${RAN_MARKER}"
HOME14H="${WORK}/home_h"
mkdir -p "${HOME14H}"
FLAKY_MARK="${WORK}/dep-flaky.mark"
export FLAKY_MARK
rm -f "${FLAKY_MARK}"
make_flaky "${WORK}/scripts3" "09-dep"
make_fixture "${WORK}/scripts3" "18-needs-dep:0"
DEPS="18-needs-dep.sh:09-dep.sh" \
  run_setup "${WORK}/scripts3" \
  "09-dep.sh|Dependency;18-needs-dep.sh|Dependent" \
  "" "${HOME14H}" --only 09-dep.sh 18-needs-dep.sh
if grep -qx "18-needs-dep" "${RAN_MARKER}"; then
  ok "a dependency-skipped step is re-attempted once its blocker recovers"
else
  bad "the skipped step never ran even though its dependency recovered"
fi
if [[ "${RC}" -eq 0 ]]; then
  ok "...and the run is then genuinely clean"
else
  bad "the run exited ${RC} after everything recovered"
fi
rm -f "${FLAKY_MARK}"
unset FLAKY_MARK

# The same situation with the retry pass DISABLED: nothing recovers, so the
# dependent is still skipped — and the verdict must say so rather than calling
# a run that never ran a selected step "complete".
: >"${RAN_MARKER}"
HOME14I="${WORK}/home_i"
mkdir -p "${HOME14I}"
make_fixture "${WORK}/scripts4" "09-dep:1" "18-needs-dep:0"
DEPS="18-needs-dep.sh:09-dep.sh" RETRY_PASS=0 \
  run_setup "${WORK}/scripts4" \
  "09-dep.sh|Dependency;18-needs-dep.sh|Dependent" \
  "" "${HOME14I}" --only 09-dep.sh 18-needs-dep.sh
if [[ "${RC}" -ne 0 ]]; then
  ok "a run with a step that never ran does not report success"
else
  bad "a run that silently skipped a selected step exited 0"
fi
assert_contains "the durable signal names the step that never ran" \
  "${HOME14I}/.cache/codespaces-setup.failed" "Never ran"

# An EMPTY selection is a malformed selection, not an absent one. `--only=` and
# `--only ""` name nothing, and falling through to a full run would be the
# silent-widening failure reached from the other side: the user asked for a
# subset and got all of everything, plus a cleared failure signal, silently.
for _empty in "--only=" "--group=" "--only=,"; do
  : >"${RAN_MARKER}"
  HOME14J="${WORK}/home_j"
  rm -rf "${HOME14J}"
  mkdir -p "${HOME14J}"
  run_setup "${WORK}/scripts" "${STEPSPEC}" "" "${HOME14J}" "${_empty}"
  if [[ "${RC}" -ne 0 && ! -s "${RAN_MARKER}" ]]; then
    ok "'${_empty}' is rejected rather than silently running everything"
  else
    bad "'${_empty}' ran '$(tr '\n' ' ' <"${RAN_MARKER}")' (rc=${RC})"
  fi
done
: >"${RAN_MARKER}"
HOME14K="${WORK}/home_k"
mkdir -p "${HOME14K}"
run_setup "${WORK}/scripts" "${STEPSPEC}" "" "${HOME14K}" --only ""
if [[ "${RC}" -ne 0 && ! -s "${RAN_MARKER}" ]]; then
  ok "--only '' is rejected rather than silently running everything"
else
  bad "--only '' ran '$(tr '\n' ' ' <"${RAN_MARKER}")' (rc=${RC})"
fi

# THE SUBTLE ONE. A successful partial run must leave an earlier failure signal
# alone: it only knows about the steps it selected, so clearing the file would
# silence a real, unfixed breakage on the strength of evidence about something
# else — and the quickest, most repeated command in the kit would be the one
# that hides a broken Codespace.
: >"${RAN_MARKER}"
HOME14G="${WORK}/home_g"
mkdir -p "${HOME14G}/.cache"
echo "stale failure from an earlier full run" >"${HOME14G}/.cache/codespaces-setup.failed"
run_setup "${WORK}/scripts" "${STEPSPEC}" "" "${HOME14G}" --only 01-a.sh
if [[ "${RC}" -eq 0 ]]; then ok "the partial run itself succeeded"; else
  bad "the partial run exited ${RC}"
fi
if [[ -f "${HOME14G}/.cache/codespaces-setup.failed" ]]; then
  ok "a clean PARTIAL run leaves an existing failure signal in place"
  assert_contains "the pre-existing signal is untouched" \
    "${HOME14G}/.cache/codespaces-setup.failed" "stale failure from an earlier full run"
else
  bad "a clean partial run DELETED the failure signal — it would hide a broken Codespace"
  bad "the pre-existing signal is untouched (file was removed)"
fi
# And the contrast that proves the rule is about filtering, not about luck: the
# same clean run WITHOUT a filter does clear it (scenario 3 covers this too, but
# pairing them here is what makes the asymmetry legible).
run_setup "${WORK}/scripts" "${STEPSPEC}" "" "${HOME14G}"
if [[ ! -f "${HOME14G}/.cache/codespaces-setup.failed" ]]; then
  ok "a clean FULL run still clears the signal"
else
  bad "a clean full run no longer clears the signal"
fi
rm -rf "${WORK}"

echo "== scenario 15: setup.sh refreshes its own checkout before running =="
# The actual missing piece. setup.sh never updated its own clone, and under the
# dotfiles mechanism that clone is frozen at Codespace creation — so `bash
# setup.sh` faithfully re-applied the version the VM was born with and looked
# like a no-op. Driven here against a LOCAL origin, so it is still fully
# headless: no network, and nothing outside the temp dir is touched.
if command -v git >/dev/null 2>&1; then
  WORK="$(mktemp -d)"
  ORIGIN="${WORK}/origin"
  git init -q --bare "${ORIGIN}"
  # `git init --bare` picks its default branch name from the local git config,
  # which varies by version and machine. Pin it, or the clones below check out
  # nothing and every assertion here becomes a confusing git error.
  git --git-dir="${ORIGIN}" symbolic-ref HEAD refs/heads/main

  # make_marker_step <path> <marker> — a fake step that appends <marker> to the
  # harness's RAN_MARKER file, proving WHICH version of the step ran.
  # shellcheck disable=SC2016  # ${RAN_MARKER} must expand in the CHILD, not here.
  make_marker_step() {
    printf '#!/usr/bin/env bash\nprintf "%s\\n" >>"${RAN_MARKER}"\n' "$2" >"$1"
  }

  # A miniature repo whose "setup.sh" is the real one, so the self-update block
  # under test is the shipped code rather than a copy of it.
  SEED="${WORK}/seed"
  mkdir -p "${SEED}/scripts"
  cp "${SETUP}" "${SEED}/setup.sh"
  make_marker_step "${SEED}/scripts/01-a.sh" v1
  # A second step, so a SELECTION during a self-update is observable: with one
  # step, "ran everything" and "ran only what I asked for" look identical.
  make_marker_step "${SEED}/scripts/02-b.sh" b
  git -C "${SEED}" init -q
  git -C "${SEED}" symbolic-ref HEAD refs/heads/main
  git -C "${SEED}" add -A
  git -C "${SEED}" -c user.name=T -c user.email=t@example.invalid commit -qm one
  git -C "${SEED}" remote add origin "${ORIGIN}"
  git -C "${SEED}" push -q origin main

  # Take the shallow clone NOW, while v1 is the tip — that is what `--depth=1`
  # against a moving branch actually leaves behind, and constructing it after
  # the fact would need a server that allows fetching an arbitrary sha.
  SHALLOW="${WORK}/shallow"
  git clone -q --depth=1 "file://${ORIGIN}" "${SHALLOW}" 2>/dev/null || true

  # A second commit, which neither clone below will have.
  make_marker_step "${SEED}/scripts/01-a.sh" v2
  git -C "${SEED}" add -A
  git -C "${SEED}" -c user.name=T -c user.email=t@example.invalid commit -qm two
  git -C "${SEED}" push -q origin main
  NEWEST="$(git -C "${SEED}" rev-parse --short HEAD)"

  # run_clone <dir> <home> [env assignments...] — run setup.sh from a checkout,
  # WITHOUT SETUP_NO_SELF_UPDATE, so the self-update block actually executes.
  # SETUP_SCRIPTS_DIR is deliberately NOT set: the point is that the steps come
  # from the (possibly updated) checkout itself.
  run_clone() {
    local dir="$1" home="$2" a
    shift 2
    # Trailing arguments are split: NAME=value is an environment assignment,
    # anything else is forwarded to setup.sh as a command-line argument.
    local -a envs=() args=()
    for a in "$@"; do
      if [[ "${a}" == [A-Za-z_]*=* ]]; then envs+=("${a}"); else args+=("${a}"); fi
    done
    mkdir -p "${home}/.cache"
    RC=0
    env -i HOME="${home}" PATH="${PATH}" \
      RAN_MARKER="${RAN_MARKER}" \
      SETUP_STEPS="01-a.sh|Step A;02-b.sh|Step B" \
      SETUP_REQUIRED="" SETUP_SKIP_VERIFY=1 SETUP_RETRY_PASS=0 \
      SETUP_LOG="${home}/.cache/codespaces-setup.log" \
      SETUP_LOG_DIR="${home}/.cache" \
      ${envs[@]+"${envs[@]}"} \
      bash "${dir}/setup.sh" ${args[@]+"${args[@]}"} >/dev/null 2>&1 || RC=$?
  }

  # (a) A stale clone fast-forwards, re-execs, and runs the NEW steps.
  CLONE="${WORK}/clone"
  git clone -q "${ORIGIN}" "${CLONE}"
  git -C "${CLONE}" reset -q --hard HEAD~1
  RAN_MARKER="${WORK}/ran.txt"
  : >"${RAN_MARKER}"
  run_clone "${CLONE}" "${WORK}/home_a"
  if grep -qx "v2" "${RAN_MARKER}"; then
    ok "a stale checkout fast-forwards and runs the UPDATED step"
  else
    bad "a stale checkout ran '$(tr '\n' ' ' <"${RAN_MARKER}")' — it did not update"
  fi
  if [[ "$(git -C "${CLONE}" rev-parse --short HEAD)" == "${NEWEST}" ]]; then
    ok "the checkout is left at origin/main"
  else
    bad "the checkout was not fast-forwarded"
  fi
  # Exactly one hop. The re-exec is guarded so a repo that somehow never
  # converged could not loop forever.
  if [[ "$(grep -c '^v2$' "${RAN_MARKER}")" == "1" ]]; then
    ok "the re-exec happens exactly once (no loop)"
  else
    bad "the step ran $(grep -c '^v2$' "${RAN_MARKER}") times — the re-exec looped"
  fi
  if grep -q '"self_update": "updated' "${WORK}/home_a/.cache/latest.json"; then
    ok "the run record says what the self-update did"
  else
    bad "the run record does not record the self-update"
  fi
  if grep -q "\"commit\": \"${NEWEST}\"" "${WORK}/home_a/.cache/latest.json"; then
    ok "the run record names the commit the run was built from"
  else
    bad "the run record does not name the commit"
  fi

  # (a2) A SELECTION SURVIVES THE RE-EXEC. This is the case that makes the
  #      self-update and the selector safe together, and it is not implied by
  #      (a): the re-exec is a fresh `bash setup.sh ...`, so if the restart drops
  #      the arguments, `--group claude` on an out-of-date checkout silently
  #      becomes a FULL run — the exact "silently a full run" failure the
  #      unknown-argument error exists to prevent, firing on the first run after
  #      every upstream change. It also wrongly clears the failure signal, since
  #      the run now believes it was a full one.
  SELCLONE="${WORK}/selclone"
  git clone -q "${ORIGIN}" "${SELCLONE}"
  git -C "${SELCLONE}" reset -q --hard HEAD~1
  : >"${RAN_MARKER}"
  run_clone "${SELCLONE}" "${WORK}/home_a2" --only 02-b.sh
  if [[ "$(tr '\n' ' ' <"${RAN_MARKER}")" == "b " ]]; then
    ok "a selection survives the self-update re-exec"
  else
    bad "the re-exec widened '--only 02-b.sh' to '$(tr '\n' ' ' <"${RAN_MARKER}")'"
  fi
  if [[ "$(git -C "${SELCLONE}" rev-parse --short HEAD)" == "${NEWEST}" ]]; then
    ok "...and the checkout was still updated"
  else
    bad "the selected run did not update the checkout"
  fi
  assert_contains "a selected run that self-updated still reports itself PARTIAL" \
    "${WORK}/home_a2/.cache/codespaces-setup.log" "PARTIAL"

  # (b) An up-to-date clone does not re-exec, and says so.
  : >"${RAN_MARKER}"
  run_clone "${CLONE}" "${WORK}/home_b"
  if [[ "$(grep -c '^v2$' "${RAN_MARKER}")" == "1" ]]; then
    ok "an already-current checkout runs its steps once"
  else
    bad "an already-current checkout ran the step $(grep -c '^v2$' "${RAN_MARKER}") times"
  fi
  assert_contains "an already-current checkout says so" \
    "${WORK}/home_b/.cache/codespaces-setup.log" "already current"

  # (c) LOCAL EDITS ARE NEVER DISCARDED. Running slightly old code is
  #     recoverable; deleting work that exists nowhere else is not.
  DIRTY="${WORK}/dirty"
  git clone -q "${ORIGIN}" "${DIRTY}"
  git -C "${DIRTY}" reset -q --hard HEAD~1
  make_marker_step "${DIRTY}/scripts/01-a.sh" mine
  : >"${RAN_MARKER}"
  run_clone "${DIRTY}" "${WORK}/home_c"
  if grep -qx "mine" "${RAN_MARKER}"; then
    ok "a dirty checkout is NOT reset — the local edit still runs"
  else
    bad "a dirty checkout discarded a local edit"
  fi
  assert_contains "a dirty checkout explains why it did not update" \
    "${WORK}/home_c/.cache/codespaces-setup.log" "uncommitted changes"

  # (d) An unreachable origin must never be the reason setup fails. An update is
  #     an improvement to the run, not a precondition for it.
  OFFLINE="${WORK}/offline"
  git clone -q "${ORIGIN}" "${OFFLINE}"
  git -C "${OFFLINE}" remote set-url origin "${WORK}/does-not-exist"
  : >"${RAN_MARKER}"
  run_clone "${OFFLINE}" "${WORK}/home_d"
  if [[ "${RC}" -eq 0 ]] && grep -qx "v2" "${RAN_MARKER}"; then
    ok "an unreachable origin is survivable — the run continues on the code on disk"
  else
    bad "an unreachable origin broke the run (rc=${RC})"
  fi
  assert_contains "an unreachable origin is reported, not hidden" \
    "${WORK}/home_d/.cache/codespaces-setup.log" "could not reach origin"

  # (e) A shallow clone — what `--depth=1` leaves behind, and the case a plain
  #     fetch cannot fast-forward, because the grafted history shares no commit
  #     with the fetched tip. It was taken above, while v1 was still the tip.
  if [[ -d "${SHALLOW}" ]] &&
    [[ "$(git -C "${SHALLOW}" rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]]; then
    : >"${RAN_MARKER}"
    run_clone "${SHALLOW}" "${WORK}/home_e"
    if grep -qx "v2" "${RAN_MARKER}"; then
      ok "a shallow (--depth=1) checkout is deepened and fast-forwarded"
    else
      bad "a shallow checkout did not update: ran '$(tr '\n' ' ' <"${RAN_MARKER}")'"
    fi
  else
    skip "shallow clone: could not construct a shallow checkout to test against"
  fi

  # (f) Not a git checkout at all (a bind-mount, an extracted tarball). Nothing
  #     to update, and not a problem.
  PLAIN="${WORK}/plain"
  mkdir -p "${PLAIN}/scripts"
  cp "${SETUP}" "${PLAIN}/setup.sh"
  make_marker_step "${PLAIN}/scripts/01-a.sh" plain
  make_marker_step "${PLAIN}/scripts/02-b.sh" b
  : >"${RAN_MARKER}"
  run_clone "${PLAIN}" "${WORK}/home_f"
  if [[ "${RC}" -eq 0 ]] && grep -qx "plain" "${RAN_MARKER}"; then
    ok "a non-git directory runs normally"
  else
    bad "a non-git directory broke the run (rc=${RC})"
  fi
  assert_contains "a non-git directory says why it did not update" \
    "${WORK}/home_f/.cache/codespaces-setup.log" "not a git checkout"

  # (g) The opt-out, which .devcontainer/post-create.sh relies on.
  : >"${RAN_MARKER}"
  run_clone "${CLONE}" "${WORK}/home_g" SETUP_NO_SELF_UPDATE=1
  assert_contains "SETUP_NO_SELF_UPDATE=1 disables the self-update" \
    "${WORK}/home_g/.cache/codespaces-setup.log" "SETUP_NO_SELF_UPDATE=1"

  rm -rf "${WORK}"
else
  skip "self-update: git is not available"
fi

echo "== scenario 16: the devcontainer path opts out of the self-update =="
# post-create.sh runs at container creation, from whatever ref the Codespace was
# created from — commonly a PR branch or a detached HEAD. Pulling there would
# run code the user did not ask for, and there is nothing to update anyway.
if grep -q 'SETUP_NO_SELF_UPDATE=1' "${REPO_DIR}/.devcontainer/post-create.sh"; then
  ok "post-create.sh disables the self-update"
else
  bad "post-create.sh does NOT disable the self-update"
fi

echo ""
if ((SKIP > 0)); then
  echo "== ${SKIP} check(s) SKIPPED — they did not run, and did not pass =="
fi
echo "== results: ${PASS} passed, ${FAIL} failed =="
if [[ "${FAIL}" -ne 0 ]]; then
  exit 1
fi
echo "ALL PASSED"
