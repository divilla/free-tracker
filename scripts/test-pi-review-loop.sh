#!/usr/bin/env bash
set -euo pipefail
export COLUMNS=80

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
review_tmp="$test_root/review-tmp"
mkdir -p "$review_tmp"
export TMPDIR="$review_tmp"

cleanup() {
	local status=$?
	if [[ $status != 0 ]]; then
		printf 'pi review-loop integration failed; captured output follows\n' >&2
		for captured in "$test_root"/*output "$test_root"/*error; do
			[[ ! -f "$captured" ]] || tail -n 20 "$captured" >&2
		done
	fi
	rm -rf -- "$test_root"
}
trap cleanup EXIT

repo="$test_root/repo"
remote="$test_root/origin.git"
fake_bin="$test_root/bin"
change='agent/changes/001-test-change.md'
branch='change/001-test-change'
mkdir -p "$repo/scripts/lib/mch" "$repo/agent/changes" "$fake_bin"
cp "$script_dir/pi-review-loop.pl" "$repo/scripts/pi-review-loop.pl"
cp "$script_dir/lib/mch/Progress.pm" "$repo/scripts/lib/mch/Progress.pm"
cp "$script_dir/lib/mch/CodexSession.pm" "$repo/scripts/lib/mch/CodexSession.pm"
cp "$script_dir/lib/mch/GitAuth.pm" "$repo/scripts/lib/mch/GitAuth.pm"
cp "$script_dir/git-auth.sh" "$repo/scripts/git-auth.sh"
cp "$script_dir/test-lib/ssh-add" "$fake_bin/ssh-add"
export MCH_GIT_SSH_KEY="$test_root/test-key"
printf '%s\n' '# Test change' >"$repo/$change"
printf '%s\n' '# Authoring progress' >"$repo/agent/PLAN.md"
printf '%s\n' 'initial' >"$repo/initial.txt"

git init --bare -q "$remote"
git -C "$repo" init -q -b master
git -C "$repo" config user.name 'Pi Review Loop Test'
git -C "$repo" config user.email 'pi-review-loop@example.invalid'
git -C "$repo" remote add origin "$remote"
git -C "$repo" add initial.txt scripts agent
git -C "$repo" commit -q -m initial
git -C "$repo" push -q -u origin master
git -C "$repo" branch -q dev
printf '%s\n' 'development base' >"$repo/dev.txt"
git -C "$repo" add dev.txt
git -C "$repo" commit -q -m 'development base'
git -C "$repo" push -q origin dev
git -C "$repo" checkout -q -b "$branch"
git -C "$repo" push -q -u origin "$branch"

cat >"$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ ${1-} == exec && ${2-} == review && ${3-} == --json ]]
shift 3
base=
output=
while [[ $# -gt 0 ]]; do
	case "$1" in
	--base)
		base=${2-}
		shift 2
		;;
	--model|-c)
		shift 2
		;;
	-o)
		output=${2-}
		shift 2
		;;
	*)
		printf 'unexpected Codex review argument: %q\n' "$1" >&2
		exit 1
		;;
	esac
done
[[ "$base" == "$CODEX_TEST_EXPECTED_BASE" ]]
[[ -n "$output" ]]
printf '{"type":"thread.started","thread_id":"review-session-%s"}\n' "$$"
if [[ -n ${CODEX_TEST_REVIEW_RESULT-} ]]; then
	printf '%s' "$CODEX_TEST_REVIEW_RESULT" >"$output"
	exit 0
fi
count=0
[[ ! -f "$CODEX_TEST_REVIEW_COUNT" ]] || count=$(<"$CODEX_TEST_REVIEW_COUNT")
((count += 1))
printf '%s\n' "$count" >"$CODEX_TEST_REVIEW_COUNT"
if ((count == 1)); then
	printf '%s\n' \
		'Validation mismatches terminate traversal.' \
		'' \
		'Full review comments:' \
		'' \
		'- [P2] Correct the acceptance criterion — agent/changes/001-test-change.md:1-1' \
		'  The document says implementation finished before code exists.' >"$output"
else
	printf '%s\n' 'No actionable defects found.' >"$output"
fi
EOF
chmod +x "$fake_bin/codex"

cat >"$fake_bin/pi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 7 ]]
[[ ${1-} == -p && ${2-} == --mode && ${3-} == json ]]
[[ ${4-} == --thinking && ${5-} == high && ${6-} == --approve ]]
prompt=${7-}
[[ "$prompt" == "$PI_TEST_EXPECTED_PROMPT" ]]
findings=$(cat)
[[ -n "$findings" ]]
printf '%s' "$findings" >"$PI_TEST_CAPTURED_FINDINGS"
printf '%s\n' '{"type":"session","version":3,"id":"fix-session.01","cwd":"'"$PWD"'"}'
if [[ ${PI_TEST_FAIL-} == 1 ]]; then
	printf '%s\n' 'simulated Pi fixer failure' >&2
	exit 43
fi
if [[ ${PI_TEST_OMIT_FINAL_RESPONSE-} == 1 ]]; then
	exit 0
fi
if [[ ${PI_TEST_INCOMPLETE_STOP-} == 1 ]]; then
	# Pi exited zero after an error response, having already made partial edits;
	# the provider failure is only reported in the structured errorMessage.
	printf '%s\n' 'Partially applied fix.' >>agent/changes/001-test-change.md
	printf '%s\n' '{"type":"message_end","message":{"role":"assistant","content":[],"stopReason":"error","errorMessage":"provider request failed: authentication expired"}}'
	exit 0
fi
if [[ "$prompt" == *' --code' ]]; then
	printf '%s\n' 'fixed code' >reviewed.txt
else
	printf '%s\n' 'Fixed acceptance criterion.' >>agent/changes/001-test-change.md
	printf '%s\n' 'Selected change authoring corrected; implementation pending.' >>agent/PLAN.md
fi
printf '%s\n' '{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"Applied all valid review findings.\n"}],"stopReason":"stop"}}'
EOF
chmod +x "$fake_bin/pi"

review_count="$test_root/review-count"
captured_findings="$test_root/captured-findings.md"
output="$test_root/document-output"
pinned_base=$(git -C "$repo" rev-parse origin/dev)
printf '%s\n' 0 >"$review_count"
(
	cd "$repo"
	PATH="$fake_bin:$PATH" \
		CODEX_TEST_REVIEW_COUNT="$review_count" \
		CODEX_TEST_EXPECTED_BASE="$pinned_base" \
		PI_TEST_EXPECTED_PROMPT='$mch-findings-fix' \
		PI_TEST_CAPTURED_FINDINGS="$captured_findings" \
		./scripts/pi-review-loop.pl
) >"$output"

findings_file=$(sed -n 's/^Findings: //p' "$output" | head -n 1)
findings_dir=${findings_file%/*}
[[ "$findings_file" == "$TMPDIR"/apih-review.*/findings.md ]]
settings=" -c 'model_reasoning_effort=\"high\"' -c 'service_tier=\"default\"'"
grep -Fxq "codex exec review --json --base $pinned_base --model gpt-6.1-sol$settings -o $findings_file" "$output"
grep -Fxq "pi -p --mode json --thinking high --approve '\$mch-findings-fix'" "$output"
grep -Fxq "< $findings_file" "$output"
[[ $(grep -Ec '^Codex session ID: review-session-[0-9]+$' "$output") -eq 2 ]]
[[ $(grep -Ec '^Pi session ID: fix-session\.01$' "$output") -eq 1 ]]
! grep -Fq '{"type":"message_end"' "$output"
grep -Fxq '=== Review pass 01 ===' "$output"
grep -Fxq '=== Fix findings 01 ===' "$output"
grep -Fxq 'Applied all valid review findings.' "$output"
grep -Fxq '=== Review pass 02 ===' "$output"
grep -Fxq 'Review complete: no review comments found.' "$output"
grep -Fxq 'Validation mismatches terminate traversal.' "$captured_findings"
grep -Fxq 'Full review comments:' "$captured_findings"
[[ $(git -C "$repo" log -1 --pretty=%s) == 'review fixes 01' ]]
[[ $(git -C "$repo" diff --name-only HEAD^ HEAD) == "$(printf '%s\n' agent/PLAN.md "$change")" ]]
[[ $(git -C "$repo" rev-parse "origin/$branch") == $(git -C "$repo" rev-parse HEAD) ]]
[[ -z $(git -C "$repo" status --short) ]]
[[ ! -e "$findings_dir" ]]

findings_fixture=$(printf '%s\n' \
	'Full review comments:' \
	'' \
	'- [P2] Simulated failure — agent/changes/001-test-change.md:1-1')
failed_output="$test_root/failed-fix-output"
failed_error="$test_root/failed-fix-error"
failed_captured_findings="$test_root/failed-captured-findings.md"
head_before=$(git -C "$repo" rev-parse HEAD)
set +e
(
	cd "$repo"
	PATH="$fake_bin:$PATH" \
		CODEX_TEST_REVIEW_RESULT="$findings_fixture" \
		CODEX_TEST_EXPECTED_BASE="$pinned_base" \
		PI_TEST_EXPECTED_PROMPT='$mch-findings-fix' \
		PI_TEST_CAPTURED_FINDINGS="$failed_captured_findings" \
		PI_TEST_FAIL=1 \
		./scripts/pi-review-loop.pl --base origin/dev
) >"$failed_output" 2>"$failed_error"
failed_status=$?
set -e
[[ $failed_status -eq 43 ]]
grep -Fxq 'Pi session ID: fix-session.01' "$failed_output"
grep -Fxq 'pi-review-loop: Pi command failed with exit code 43' "$failed_error"
grep -Fxq 'pi-review-loop: Pi command diagnostics:' "$failed_error"
grep -Fxq '  simulated Pi fixer failure' "$failed_error"
[[ "$findings_fixture" == "$(<"$failed_captured_findings")" ]]
[[ $(git -C "$repo" rev-parse HEAD) == "$head_before" ]]
[[ -z $(git -C "$repo" status --short) ]]
failed_findings_file=$(sed -n 's/^Findings: //p' "$failed_output" | head -n 1)
[[ ! -e "${failed_findings_file%/*}" ]]

missing_output="$test_root/missing-response-output"
missing_error="$test_root/missing-response-error"
set +e
(
	cd "$repo"
	PATH="$fake_bin:$PATH" \
		CODEX_TEST_REVIEW_RESULT="$findings_fixture" \
		CODEX_TEST_EXPECTED_BASE="$pinned_base" \
		PI_TEST_EXPECTED_PROMPT='$mch-findings-fix' \
		PI_TEST_CAPTURED_FINDINGS=/dev/null \
		PI_TEST_OMIT_FINAL_RESPONSE=1 \
		./scripts/pi-review-loop.pl --base origin/dev
) >"$missing_output" 2>"$missing_error"
missing_status=$?
set -e
[[ $missing_status -eq 1 ]]
grep -Fxq 'Pi session ID: fix-session.01' "$missing_output"
grep -Fxq 'pi-review-loop: Pi did not emit a final assistant response' "$missing_error"
[[ $(git -C "$repo" rev-parse HEAD) == "$head_before" ]]
[[ -z $(git -C "$repo" status --short) ]]
missing_findings_file=$(sed -n 's/^Findings: //p' "$missing_output" | head -n 1)
[[ ! -e "${missing_findings_file%/*}" ]]

incomplete_output="$test_root/incomplete-stop-output"
incomplete_error="$test_root/incomplete-stop-error"
incomplete_captured_findings="$test_root/incomplete-stop-captured-findings.md"
set +e
(
	cd "$repo"
	PATH="$fake_bin:$PATH" \
		CODEX_TEST_REVIEW_RESULT="$findings_fixture" \
		CODEX_TEST_EXPECTED_BASE="$pinned_base" \
		PI_TEST_EXPECTED_PROMPT='$mch-findings-fix' \
		PI_TEST_CAPTURED_FINDINGS="$incomplete_captured_findings" \
		PI_TEST_INCOMPLETE_STOP=1 \
		./scripts/pi-review-loop.pl --base origin/dev
) >"$incomplete_output" 2>"$incomplete_error"
incomplete_status=$?
set -e
[[ $incomplete_status -eq 1 ]]
grep -Fxq 'Pi session ID: fix-session.01' "$incomplete_output"
grep -Fxq "pi-review-loop: Pi final assistant response ended with stopReason 'error', not 'stop'" "$incomplete_error"
grep -Fxq 'pi-review-loop: Pi assistant error message:' "$incomplete_error"
grep -Fxq '  provider request failed: authentication expired' "$incomplete_error"
[[ $(git -C "$repo" rev-parse HEAD) == "$head_before" ]]
[[ $(git -C "$repo" rev-parse "origin/$branch") == "$head_before" ]]
grep -Fq 'Partially applied fix.' "$repo/$change"
[[ -n $(git -C "$repo" status --short) ]]
incomplete_findings_file=$(sed -n 's/^Findings: //p' "$incomplete_output" | head -n 1)
[[ ! -e "${incomplete_findings_file%/*}" ]]
git -C "$repo" checkout -q -- .
[[ -z $(git -C "$repo" status --short) ]]

code_output="$test_root/code-output"
code_captured_findings="$test_root/code-captured-findings.md"
printf '%s\n' 0 >"$review_count"
(
	cd "$repo"
	PATH="$fake_bin:$PATH" \
		CODEX_TEST_REVIEW_COUNT="$review_count" \
		CODEX_TEST_EXPECTED_BASE="$pinned_base" \
		PI_TEST_EXPECTED_PROMPT='$mch-findings-fix --code' \
		PI_TEST_CAPTURED_FINDINGS="$code_captured_findings" \
		./scripts/pi-review-loop.pl --code
) >"$code_output"

grep -Fxq "pi -p --mode json --thinking high --approve '\$mch-findings-fix --code'" "$code_output"
grep -Fxq 'Applied all valid review findings.' "$code_output"
[[ -f "$repo/reviewed.txt" ]]
[[ $(git -C "$repo" log -1 --pretty=%s) == 'review fixes 01' ]]
[[ $(git -C "$repo" diff --name-only HEAD^ HEAD) == 'reviewed.txt' ]]
[[ $(git -C "$repo" rev-parse "origin/$branch") == $(git -C "$repo" rev-parse HEAD) ]]
[[ -z $(git -C "$repo" status --short) ]]

printf '%s\n' 'pi-review-loop tests passed'
