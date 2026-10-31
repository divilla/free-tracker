#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
runner_pid=''
cleanup() {
	if [[ -n $runner_pid ]]; then
		kill -TERM "$runner_pid" 2>/dev/null || true
		wait "$runner_pid" 2>/dev/null || true
	fi
	rm -rf -- "$test_root"
}
trap cleanup EXIT
repo="$test_root/repo with spaces"
mkdir -p "$repo/scripts" "$repo/agent" "$repo/nested"
cp "$script_dir/codex-plan-run.sh" "$repo/scripts/"
cp "$script_dir/../agent/PLAN.md" "$repo/agent/"
cp "$repo/agent/PLAN.md" "$test_root/original-plan"
runner="$repo/scripts/codex-plan-run.sh"
export PLAN_TEST_CALLS="$test_root/calls" PLAN_TEST_REPO="$repo"
export PLAN_TEST_READY="$test_root/ready" PLAN_TEST_STOPPED="$test_root/stopped"
cat >"$repo/scripts/codex-flow-run.sh" <<'FLOW'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 1 && $PWD == "$PLAN_TEST_REPO" ]]
printf '%s\n' "$1" >>"$PLAN_TEST_CALLS"
if [[ ${PLAN_TEST_TTY:-0} == 1 ]]; then
	[[ -t 0 && -t 1 ]]
	printf 'Recovery answer: '
	read -r answer </dev/tty
	[[ $answer == continue ]]
fi
if [[ ${PLAN_TEST_INPUT:-0} == 1 ]]; then
	read -r answer
	[[ $answer == piped-input ]]
fi
if [[ ${PLAN_TEST_HOLD:-0} == 1 ]]; then
	trap 'touch "$PLAN_TEST_STOPPED"; exit 143' TERM
	touch "$PLAN_TEST_READY"
	sleep 30 &
	wait $!
fi
if [[ $1 == "${PLAN_TEST_FAIL_SLUG:-}" ]]; then
	exit 37
fi
FLOW
chmod +x "$repo/scripts/codex-flow-run.sh"
git -C "$repo" init -q -b dev
git -C "$repo" config user.name 'Plan Runner Test'
git -C "$repo" config user.email 'plan-runner@example.invalid'
git -C "$repo" config commit.gpgsign false
git -C "$repo" add .
git -C "$repo" commit -q -m initial
git -C "$repo" update-ref refs/remotes/origin/dev HEAD

# PLAN-RUN-ORDER: independently enumerate all 25 inventory changes, not phases,
# gates, authoring summaries, or incidental references elsewhere in PLAN.
cat >"$test_root/expected" <<'SLUGS'
001-build-scaffold
002-setup-decisions
003-workflow-run-state
004-workflow-review-merge
005-app-test-foundation
006-android-tracking-spike
007-measurement-contract
008-reference-replay-baseline
009-sqlite-tour-repository
010-outdoor-measurement
011-indoor-calibration-rules
012-automatic-pause-rules
013-durable-recording-coordinator
014-interruption-recovery
015-android-recording-integration
016-start-active-tour-experience
017-guided-calibration
018-tour-history-details
019-settings-localized-about
020-zero-cost-route-maps
021-privacy-retention-policy
022-device-endurance-hardening
023-held-out-accuracy-validation
024-signed-build-handover
025-play-release-readiness
SLUGS

run() {
	: >"$PLAN_TEST_CALLS"
	status=0
	(cd -- "$test_root" && bash "$runner" "$@") >"$test_root/output" 2>"$test_root/error" || status=$?
}
reject() {
	local expected_status=$1
	shift
	run "$@"
	[[ $status -eq $expected_status && ! -s $PLAN_TEST_CALLS ]]
}
progress_log() {
	sed -n 's/^codex-plan-run: progress log: //p' "$test_root/error"
}

# PLAN-RUN-PREVIEW: listing performs no workflows or Git-metadata writes and
# still works without an executable helper or a clean tree.
chmod -x "$repo/scripts/codex-flow-run.sh"
run --list
[[ $status -eq 0 && ! -s $PLAN_TEST_CALLS ]]
cmp "$test_root/expected" "$test_root/output"
[[ ! -e "$repo/.git/codex-plan-runs" ]]
chmod +x "$repo/scripts/codex-flow-run.sh"

# PLAN-RUN-INPUT: background supervision must not discard piped standard input.
: >"$PLAN_TEST_CALLS"
printf 'piped-input\n' | PLAN_TEST_INPUT=1 bash "$runner" --from 025-play-release-readiness \
	>"$test_root/input-output" 2>"$test_root/input-error"
[[ $(cat "$PLAN_TEST_CALLS") == 025-play-release-readiness ]]

# PLAN-RUN-TERMINAL: the real interactive recovery path can open /dev/tty,
# read an answer, and return normally. Python is a test-only PTY dependency.
PLAN_TEST_TTY=1 python3 - "$runner" <<'PY'
import os
import pty
import select
import signal
import sys
import time

pid, terminal = pty.fork()
if pid == 0:
    os.execlp('bash', 'bash', sys.argv[1], '--from', '025-play-release-readiness')
output = b''
try:
    os.write(terminal, b'continue\n')
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if select.select([terminal], [], [], 0.1)[0]:
            try:
                chunk = os.read(terminal, 65536)
            except OSError:
                break
            if not chunk:
                break
            output += chunk
    else:
        os.kill(pid, signal.SIGKILL)
        raise AssertionError('Interactive recovery timed out')
    _, status = os.waitpid(pid, 0)
    assert os.waitstatus_to_exitcode(status) == 0, output.decode(errors='replace')
    assert b'Recovery answer:' in output and b'Completed 1 plan change workflow' in output, output
finally:
    os.close(terminal)
PY

# PLAN-RUN-ORDER / PLAN-RUN-STATE: all changes run once in order from any cwd.
for directory in "$repo" "$repo/nested" "$test_root"; do
	: >"$PLAN_TEST_CALLS"
	(cd -- "$directory" && bash "$runner") >"$test_root/output" 2>"$test_root/error"
	cmp "$test_root/expected" "$PLAN_TEST_CALLS"
	log=$(progress_log)
	[[ -f $log ]]
	[[ $(awk -F '\t' '$1 == "queued" {n++} END {print n+0}' "$log") -eq 25 ]]
	[[ $(awk -F '\t' '$1 == "succeeded" && $4 == 0 {n++} END {print n+0}' "$log") -eq 25 ]]
	[[ $(awk -F '\t' 'NR == 2 {print $6}' "$log") == $(git -C "$repo" rev-parse HEAD) ]]
	[[ $(awk -F '\t' 'NR == 2 {print $7}' "$log") == $(git -C "$repo" rev-parse origin/dev) ]]
	[[ $(awk -F '\t' 'NR == 2 {print $8}' "$log") == $(git -C "$repo" hash-object agent/PLAN.md) ]]
	[[ -z $(git -C "$repo" status --short) ]]
done

# PLAN-RUN-RESTART: --from is inclusive and exact; it never infers completion.
run --from 012-automatic-pause-rules
[[ $status -eq 0 ]]
tail -n 14 "$test_root/expected" >"$test_root/remaining"
cmp "$test_root/remaining" "$PLAN_TEST_CALLS"
[[ $(awk -F '\t' '$1 == "queued" {n++} END {print n+0}' "$(progress_log)") -eq 14 ]]
reject 1 --from 012-wrong-name
reject 2 --from ''
reject 2 --from
reject 2 unexpected
reject 2 --list extra
reject 2 --from 001-build-scaffold extra

# PLAN-RUN-FAILURE: first, middle and last failures preserve the child's exit
# status, retain progress, do not announce completion, and never run later work.
for index in 1 13 25; do
	export PLAN_TEST_FAIL_SLUG
	PLAN_TEST_FAIL_SLUG=$(sed -n "${index}p" "$test_root/expected")
	run
	[[ $status -eq 37 ]]
	head -n "$index" "$test_root/expected" >"$test_root/attempted"
	cmp "$test_root/attempted" "$PLAN_TEST_CALLS"
	grep -Fq "$PLAN_TEST_FAIL_SLUG failed (exit 37)" "$test_root/error"
	! grep -q '^Completed ' "$test_root/output"
	[[ $(awk -F '\t' '$1 == "failed" {print $3 ":" $4}' "$(progress_log)") == "$PLAN_TEST_FAIL_SLUG:37" ]]
done
unset PLAN_TEST_FAIL_SLUG

# PLAN-RUN-VALIDATION: validate even the final row before dispatching anything.
for invalid in missing empty no_rows bad_slug bad_id bad_path duplicate unsorted malformed; do
	cp "$test_root/original-plan" "$repo/agent/PLAN.md"
	case "$invalid" in
		missing) rm "$repo/agent/PLAN.md" ;;
		empty) printf '# No inventory\n' >"$repo/agent/PLAN.md" ;;
		no_rows) sed '/^| S[0-9]/d' "$test_root/original-plan" >"$repo/agent/PLAN.md" ;;
		bad_slug) sed 's/`025-play-release-readiness`/`025-UPPERCASE`/' "$test_root/original-plan" >"$repo/agent/PLAN.md" ;;
		bad_id) sed 's/| S025 \/ /| S099 \/ /' "$test_root/original-plan" >"$repo/agent/PLAN.md" ;;
		bad_path) sed 's@changes/025-play-release-readiness.md@changes/025-wrong.md@' "$test_root/original-plan" >"$repo/agent/PLAN.md" ;;
		duplicate) awk '{print} /^\| S025 / {print}' "$test_root/original-plan" >"$repo/agent/PLAN.md" ;;
		unsorted) awk '/^\| S001 / {row=$0; next} /^\| S002 / {print; print row; next} {print}' "$test_root/original-plan" >"$repo/agent/PLAN.md" ;;
		malformed) sed '/^| S025 /s/ |$//' "$test_root/original-plan" >"$repo/agent/PLAN.md" ;;
	esac
	reject 1
	grep -q '^codex-plan-run:' "$test_root/error"
	! grep -q 'progress log:' "$test_root/error"
done
cp "$test_root/original-plan" "$repo/agent/PLAN.md"

# PLAN-RUN-PREFLIGHT: missing helper / dirty work cannot start a workflow.
chmod -x "$repo/scripts/codex-flow-run.sh"
reject 1
grep -q 'missing executable workflow' "$test_root/error"
chmod +x "$repo/scripts/codex-flow-run.sh"
touch "$repo/unrelated.txt"
reject 1
grep -q 'uncommitted work detected' "$test_root/error"
rm "$repo/unrelated.txt"

# PLAN-RUN-LOCK / PLAN-RUN-INTERRUPT: concurrent invocations cannot dispatch;
# termination stops the child and records an interruption, not a success.
: >"$PLAN_TEST_CALLS"
PLAN_TEST_HOLD=1 bash "$runner" >"$test_root/held-output" 2>"$test_root/held-error" &
runner_pid=$!
for ((attempt=0; attempt<200; attempt++)); do
	[[ ! -e $PLAN_TEST_READY ]] || break
	sleep 0.05
done
[[ -e $PLAN_TEST_READY ]]
reject 1
grep -q 'another plan run is active' "$test_root/error"
kill -TERM "$runner_pid"
status=0
wait "$runner_pid" || status=$?
runner_pid=''
[[ $status -eq 143 && -e $PLAN_TEST_STOPPED ]]
log=$(sed -n 's/^codex-plan-run: progress log: //p' "$test_root/held-error")
[[ $(awk -F '\t' '$1 == "interrupted" {print $3 ":" $4}' "$log") == '001-build-scaffold:143' ]]
! grep -q '^Completed ' "$test_root/held-output"

# PLAN-RUN-SOURCE: names come from the current inventory, not a hard-coded list.
sed 's/025-play-release-readiness/025-alternative/g' "$test_root/original-plan" >"$repo/agent/PLAN.md"
git -C "$repo" add agent/PLAN.md
git -C "$repo" commit -q -m 'Change last planned slug'
run
[[ $status -eq 0 && $(tail -n 1 "$PLAN_TEST_CALLS") == 025-alternative ]]
[[ $(wc -l <"$PLAN_TEST_CALLS") -eq 25 ]]
printf '%s\n' 'codex-plan-run tests passed: inventory/order, preview, restart, failure, validation, state, preflight, locking, interruption and interactive/piped input'
