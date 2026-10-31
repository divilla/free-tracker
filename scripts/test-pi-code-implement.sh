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

printf '%s\n' '{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"Implementation complete."}]}}'
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
