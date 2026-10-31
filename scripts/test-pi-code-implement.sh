#!/usr/bin/env bash
set -euo pipefail
export COLUMNS=80

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
repo="$test_root/repo"
remote="$test_root/origin.git"
fake_bin="$test_root/bin"
mkdir -p "$repo/scripts/lib/mch" "$repo/agent/changes" "$fake_bin"

cleanup() {
	rm -rf -- "$test_root"
}
trap cleanup EXIT

cp "$script_dir/pi-code-implement.pl" "$repo/scripts/pi-code-implement.pl"
cp "$script_dir/lib/mch/Progress.pm" "$repo/scripts/lib/mch/Progress.pm"
cp "$script_dir/lib/mch/GitAuth.pm" "$repo/scripts/lib/mch/GitAuth.pm"
cp "$script_dir/git-auth.sh" "$repo/scripts/git-auth.sh"
cp "$script_dir/test-lib/ssh-add" "$fake_bin/ssh-add"
export MCH_GIT_SSH_KEY="$test_root/test-key"
printf '%s\n' '# Domain types' >"$repo/agent/changes/000-domain-types.md"
printf '%s\n' '# Failing change' >"$repo/agent/changes/001-failing-change.md"
printf '%s\n' '# Incomplete response change' >"$repo/agent/changes/002-incomplete-response.md"
printf '%s\n' '# Switched branch change' >"$repo/agent/changes/003-switched-branch.md"
printf '%s\n' 'old production' >"$repo/production.go"

cat >"$fake_bin/pi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ ${1-} == -p ]]
[[ ${2-} == --mode ]]
[[ ${3-} == json ]]
[[ ${4-} == --thinking ]]
[[ ${5-} == high ]]
[[ ${6-} == --approve ]]
prompt=${7-}
[[ $# -eq 7 && "$prompt" == '$mch-code-implement' ]]

printf '%s\n' '{"type":"session","version":3,"id":"implementation-session","cwd":"/tmp"}'
if [[ ${PI_TEST_FAIL-} == 1 ]]; then
	printf '%s\n' 'simulated implementation failure' >&2
	exit 42
fi

if [[ ${PI_TEST_INCOMPLETE_STOP-} == 1 ]]; then
	# Pi exited zero after an error response, having already made partial edits;
	# the provider failure is only reported in the structured errorMessage.
	printf '%s\n' 'partial implementation' >production.go
	printf '%s\n' '{"type":"message_end","message":{"role":"assistant","content":[],"stopReason":"error","errorMessage":"provider request failed: rate limited"}}'
	exit 0
fi

if [[ ${PI_TEST_SWITCH_BRANCH-} == 1 ]]; then
	# Pi moved HEAD to another branch at the same commit while editing files.
	printf '%s\n' 'imposter implementation' >production.go
	git checkout -q -b imposter-branch
	printf '%s\n' '{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"Implementation complete."}],"stopReason":"stop"}}'
	exit 0
fi

printf '%s\n' '{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"Implementation complete."}],"stopReason":"stop"}}'
printf '%s\n' 'new production' >production.go
EOF
chmod +x "$fake_bin/pi"

git init --bare -q "$remote"
git -C "$repo" init -q -b master
git -C "$repo" config user.name 'Pi Implement Test'
git -C "$repo" config user.email 'pi-implement@example.invalid'
git -C "$repo" remote add origin "$remote"
git -C "$repo" add .
git -C "$repo" commit -q -m initial
git -C "$repo" push -q -u origin master
git -C "$repo" symbolic-ref HEAD refs/heads/master
git -C "$repo" checkout -q -b change/000-domain-types

output="$test_root/output"
initial_errors="$test_root/initial-errors"
set +e
(
	cd "$repo"
	PATH="$fake_bin:$PATH" ./scripts/pi-code-implement.pl
) >"$output" 2>"$initial_errors"
status=$?
set -e
[[ $status -eq 0 ]]
grep -Fxq 'Pi session ID: implementation-session' "$output"
grep -Fxq 'Implementation complete.' "$output"
grep -Fq 'pi -p --mode json --thinking high --approve' "$output"
! grep -Fq -- '--no-session' "$output"
[[ $(git -C "$repo" log -1 --format=%s) == 'Implement code 000-domain-types' ]]
[[ $(git -C "$repo" rev-parse change/000-domain-types) == \
	$(git -C "$repo" rev-parse origin/change/000-domain-types) ]]
[[ -z $(git -C "$repo" status --short) ]]

git -C "$repo" checkout -q master
git -C "$repo" checkout -q -b change/001-failing-change
failed_output="$test_root/failed-output"
failed_error="$test_root/failed-error"
set +e
(
	cd "$repo"
	PATH="$fake_bin:$PATH" PI_TEST_FAIL=1 ./scripts/pi-code-implement.pl
) >"$failed_output" 2>"$failed_error"
failed_status=$?
set -e
[[ $failed_status -eq 42 ]]
grep -Fxq 'Pi session ID: implementation-session' "$failed_output"
grep -Fxq 'pi-code-implement: Pi command failed with exit code 42' "$failed_error"
grep -Fxq '  simulated implementation failure' "$failed_error"

# PI-IMPLEMENT-INCOMPLETE: a zero exit with an unsuccessful final assistant
# stop reason must be rejected before any commit or push; partial edits stay
# uncommitted for inspection.
git -C "$repo" checkout -q master
git -C "$repo" checkout -q -b change/002-incomplete-response
incomplete_output="$test_root/incomplete-output"
incomplete_error="$test_root/incomplete-error"
set +e
(
	cd "$repo"
	PATH="$fake_bin:$PATH" PI_TEST_INCOMPLETE_STOP=1 ./scripts/pi-code-implement.pl
) >"$incomplete_output" 2>"$incomplete_error"
incomplete_status=$?
set -e
[[ $incomplete_status -eq 1 ]]
grep -Fxq 'Pi session ID: implementation-session' "$incomplete_output"
grep -Fxq "pi-code-implement: Pi final assistant response ended with stopReason 'error', not 'stop'" "$incomplete_error"
grep -Fxq 'pi-code-implement: Pi assistant error message:' "$incomplete_error"
grep -Fxq '  provider request failed: rate limited' "$incomplete_error"
[[ $(git -C "$repo" log -1 --format=%s) == initial ]]
! git -C "$repo" rev-parse --verify --quiet refs/remotes/origin/change/002-incomplete-response
[[ $(<"$repo/production.go") == 'partial implementation' ]]
[[ -n $(git -C "$repo" status --short) ]]

# PI-IMPLEMENT-BRANCH-SWITCH: Pi switching to another branch at the same commit
# must be rejected before staging; the implementation stays uncommitted and the
# change branch is never pushed.
git -C "$repo" checkout -q -- .
git -C "$repo" checkout -q master
git -C "$repo" checkout -q -b change/003-switched-branch
switched_output="$test_root/switched-output"
switched_error="$test_root/switched-error"
set +e
(
	cd "$repo"
	PATH="$fake_bin:$PATH" PI_TEST_SWITCH_BRANCH=1 ./scripts/pi-code-implement.pl
) >"$switched_output" 2>"$switched_error"
switched_status=$?
set -e
[[ $switched_status -eq 1 ]]
grep -Fxq 'Pi session ID: implementation-session' "$switched_output"
grep -Fxq 'Implementation complete.' "$switched_output"
grep -Fxq 'pi-code-implement: Pi changed branches; refusing to commit' "$switched_error"
[[ $(git -C "$repo" branch --show-current) == imposter-branch ]]
[[ $(git -C "$repo" log -1 --format=%s) == initial ]]
! git -C "$repo" rev-parse --verify --quiet refs/remotes/origin/change/003-switched-branch
[[ $(<"$repo/production.go") == 'imposter implementation' ]]
[[ -n $(git -C "$repo" status --short) ]]
[[ -z $(git -C "$repo" diff --cached --name-only) ]]

set +e
(
	cd "$repo"
	PATH="$fake_bin:$PATH" ./scripts/pi-code-implement.pl unexpected
) >/dev/null 2>"$failed_error"
invalid_status=$?
set -e
[[ $invalid_status -eq 1 ]]
grep -Fxq 'pi-code-implement: usage: pi-code-implement.pl' "$failed_error"

printf '%s\n' 'pi-code-implement tests passed'
