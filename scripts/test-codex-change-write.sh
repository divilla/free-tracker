#!/usr/bin/env bash
set -euo pipefail
export COLUMNS=80

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
repo="$test_root/repo"
fake_bin="$test_root/bin"
mkdir -p "$repo/scripts/lib/mch" "$repo/agent/changes" "$fake_bin"
cp "$script_dir/codex-change-write.pl" "$repo/scripts/"
cp "$script_dir/lib/mch/Progress.pm" "$script_dir/lib/mch/GitAuth.pm" "$repo/scripts/lib/mch/"
cp "$script_dir/git-auth.sh" "$repo/scripts/"
cp "$script_dir/test-lib/ssh-add" "$fake_bin/"
export MCH_GIT_SSH_KEY="$test_root/test-key"
export CODEX_TEST_RESUMES="$test_root/resumes"
export CODEX_TEST_RESPONSE="$test_root/response"
export CODEX_TEST_RESULT_PATH="$test_root/result-path"
export CODEX_TEST_SESSION='0199a213-81c0-7800-8aa1-bbab2a035a53'
export PATH="$fake_bin:$PATH"
export TMPDIR="$test_root"

cat >"$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1-} == resume ]]; then
	[[ $# -eq 2 && $2 == "$CODEX_TEST_SESSION" ]]
	printf '%s\n' "$2" >>"$CODEX_TEST_RESUMES"
	# Verify that input/output are inherited, rather than piped into the monitor.
	read -r answer
	[[ $answer == 'interactive answer' ]]
	printf '%s\n' 'Interactive session output'
	exit "${CODEX_TEST_RESUME_EXIT:-0}"
fi
[[ $# -eq 11 && $1 == exec && $2 == --json ]]
[[ $3 == --model && $4 == gpt-6.1-sol ]]
[[ $5 == -c && $6 == 'model_reasoning_effort="high"' ]]
[[ $7 == -c && $8 == 'service_tier="default"' ]]
[[ $9 == -o && ${11} == '$mch-change-write' ]]
result=${10}
printf '%s\n' "$result" >"$CODEX_TEST_RESULT_PATH"
# Exercise fragmented JSON and stderr mixed into the JSON log.
printf '%s\n' 'Codex diagnostic' >&2
printf '%s\n' 'not JSON' 'null' '{"type":"item.completed","thread_id":"wrong-session"}'
if [[ ${CODEX_TEST_NO_SESSION:-0} == 0 ]]; then
	printf '%s' '{"type":"thread.st'
	printf 'arted","thread_id":"%s"}\n' "$CODEX_TEST_SESSION"
fi
if [[ ${CODEX_TEST_FAIL:-0} == 1 ]]; then
	printf '%s\n' 'simulated authoring failure' >&2
	exit 42
fi
if [[ ${CODEX_TEST_NO_RESULT:-0} == 0 ]]; then
	cp "$CODEX_TEST_RESPONSE" "$result"
fi
if [[ ${CODEX_TEST_WRITE:-0} == 1 ]]; then
	mkdir -p agent/changes
	printf '%s\n' "${CODEX_TEST_WRITE_CONTENT:-# Authored change}" >agent/PLAN.md
	printf '%s\n' '# Change document' >agent/changes/000-domain-types.md
fi
EOF
chmod +x "$fake_bin/codex"
git -C "$repo" init -q -b change/000-domain-types
git -C "$repo" config user.name 'Change Test'
git -C "$repo" config user.email 'change@example.invalid'
git -C "$repo" add .
git -C "$repo" commit -q -m initial
git init --bare -q "$test_root/origin.git"
git -C "$repo" remote add origin "$test_root/origin.git"
initial_head=$(git -C "$repo" rev-parse HEAD)

run_change() {
	local expected=$1
	local status=0
	(
		cd "$test_root"
		"$repo/scripts/codex-change-write.pl"
	) < <(printf '%s\n' 'interactive answer') >"$test_root/output" 2>"$test_root/error" || status=$?
	if [[ $status -ne $expected ]]; then
		cat "$test_root/output" "$test_root/error" >&2
		printf 'Expected exit %s, got %s\n' "$expected" "$status" >&2
		exit 1
	fi
	if [[ ${CODEX_TEST_EXPECT_COMMIT:-0} == 1 ]]; then
		[[ $(git -C "$repo" rev-parse HEAD^) == "$initial_head" ]]
		[[ $(git -C "$repo" log -1 --format=%s) == 'Write change 000-domain-types' ]]
		[[ $(git -C "$repo" rev-parse HEAD) == $(git --git-dir="$test_root/origin.git" rev-parse refs/heads/change/000-domain-types) ]]
		[[ $(git -C "$repo" rev-parse --abbrev-ref '@{upstream}') == origin/change/000-domain-types ]]
		[[ -z $(git -C "$repo" status --short) ]]
		initial_head=$(git -C "$repo" rev-parse HEAD)
	else
		[[ $(git -C "$repo" rev-parse HEAD) == "$initial_head" ]]
	fi
	if [[ -f "$CODEX_TEST_RESULT_PATH" ]]; then
		[[ ! -e $(cat "$CODEX_TEST_RESULT_PATH") ]]
		[[ ! -d $(dirname -- "$(cat "$CODEX_TEST_RESULT_PATH")") ]]
	fi
}

# Invalid branches and detached HEAD fail before starting authoring.
git -C "$repo" checkout -q -b invalid-branch
run_change 1
grep -Fxq 'codex-change-write: current branch must match ^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$' "$test_root/error"
[[ ! -e "$CODEX_TEST_RESULT_PATH" ]]
git -C "$repo" checkout -q --detach
run_change 1
grep -Fxq 'codex-change-write: current branch must match ^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$' "$test_root/error"
[[ ! -e "$CODEX_TEST_RESULT_PATH" ]]
git -C "$repo" checkout -q change/000-domain-types

# Exact success works without a pre-existing change or even a session ID.
[[ ! -e "$repo/agent/changes/000-domain-types.md" ]]
for response in 'Done.' $'Done.\n' $'Done.\r\n'; do
	printf '%s' "$response" >"$CODEX_TEST_RESPONSE"
	CODEX_TEST_NO_SESSION=1 run_change 0
	[[ ! -f "$CODEX_TEST_RESUMES" ]]
done

# Every other final response resumes the exact session, including empty output.
resume_count=0
for response in '' 'done.' 'Done' ' Done.' 'Done. ' $'Done.\n\n' $'Done.\nMore text' 'Questions and suggestions:'; do
	printf '%s' "$response" >"$CODEX_TEST_RESPONSE"
	run_change 0
	((resume_count += 1))
	[[ $(wc -l <"$CODEX_TEST_RESUMES") -eq $resume_count ]]
	grep -Fxq 'Interactive session output' "$test_root/output"
	grep -Fxq "codex resume $CODEX_TEST_SESSION" "$test_root/output"
done

# Missing result still resumes; a nonzero interactive exit still returns success.
CODEX_TEST_NO_RESULT=1 run_change 0
CODEX_TEST_RESUME_EXIT=37 run_change 0
((resume_count += 2))
[[ $(wc -l <"$CODEX_TEST_RESUMES") -eq $resume_count ]]

# A missing session fails explicitly instead of selecting a different session.
CODEX_TEST_NO_SESSION=1 run_change 1
grep -Fxq 'codex-change-write: cannot resume Codex: no session ID found in Codex output' "$test_root/error"
[[ $(wc -l <"$CODEX_TEST_RESUMES") -eq $resume_count ]]

# Execution errors remain failures, without opening an interactive session.
CODEX_TEST_FAIL=1 run_change 42
grep -Fq 'simulated authoring failure' "$test_root/error"
[[ $(wc -l <"$CODEX_TEST_RESUMES") -eq $resume_count ]]

# Done commits and pushes authored changes without requiring a session ID.
printf '%s' 'Done.' >"$CODEX_TEST_RESPONSE"
CODEX_TEST_WRITE=1 CODEX_TEST_EXPECT_COMMIT=1 CODEX_TEST_NO_SESSION=1 run_change 0
[[ -f "$repo/agent/PLAN.md" && -f "$repo/agent/changes/000-domain-types.md" ]]
[[ $(git -C "$repo" show HEAD:agent/PLAN.md) == '# Authored change' ]]
[[ $(wc -l <"$CODEX_TEST_RESUMES") -eq $resume_count ]]

# Interactive completion commits too, even when resume returns nonzero.
printf '%s' 'Questions and suggestions:' >"$CODEX_TEST_RESPONSE"
CODEX_TEST_WRITE=1 CODEX_TEST_WRITE_CONTENT='# Interactive change' CODEX_TEST_EXPECT_COMMIT=1 CODEX_TEST_RESUME_EXIT=37 run_change 0
((resume_count += 1))
[[ $(git -C "$repo" show HEAD:agent/PLAN.md) == '# Interactive change' ]]
[[ $(wc -l <"$CODEX_TEST_RESUMES") -eq $resume_count ]]

# A failed commit is reported and does not update the remote.
printf '%s\n' '#!/bin/sh' 'exit 1' >"$repo/.git/hooks/pre-commit"
chmod +x "$repo/.git/hooks/pre-commit"
printf '%s' 'Done.' >"$CODEX_TEST_RESPONSE"
CODEX_TEST_WRITE=1 CODEX_TEST_WRITE_CONTENT='# Commit fails' run_change 1
[[ $(git --git-dir="$test_root/origin.git" rev-parse refs/heads/change/000-domain-types) == "$initial_head" ]]
[[ $(git -C "$repo" status --short) == 'M  agent/PLAN.md' ]]

# Existing dirty-worktree guard remains in force.
run_change 1
grep -Fxq 'error: Uncommitted work detected. Commit or stash your changes, then retry.' "$test_root/error"
printf '%s\n' 'codex-change-write integration tests passed'
