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
run_setup() {
  local scripts_dir="$1" steps="$2" required="$3" home="$4"
  mkdir -p "${home}/.cache"
  RC=0
  env -i \
    HOME="${home}" \
    PATH="${PATH}" \
    SETUP_SCRIPTS_DIR="${scripts_dir}" \
    SETUP_STEPS="${steps}" \
    SETUP_REQUIRED="${required}" \
    RAN_MARKER="${RAN_MARKER}" \
    bash "${SETUP}" >/dev/null 2>&1 || RC=$?
  # setup.sh execs stdout through `tee` (a background process); give it a beat to
  # flush the log before we read it.
  local log="${home}/.cache/codespaces-setup.log"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
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
  log() { echo "[test] $*"; }
  # shellcheck source=/dev/null
  source "${LIB}"
  attempts=0
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
  log() { echo "[test] $*"; }
  # shellcheck source=/dev/null
  source "${LIB}"
  tries=0
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

echo ""
echo "== results: ${PASS} passed, ${FAIL} failed =="
if [[ "${FAIL}" -ne 0 ]]; then
  exit 1
fi
echo "ALL PASSED"
