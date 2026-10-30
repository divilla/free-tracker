#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
repo="$test_root/repo with spaces"
mkdir -p "$repo/scripts/lib/mch" "$test_root/bin"
cp "$script_dir/change-review.md" "$repo/scripts/"
cp "$script_dir/lib/mch/CodexSession.pm" "$repo/scripts/lib/mch/"
git -C "$repo" init -q -b master
git -C "$repo" config user.name 'Session Test'
git -C "$repo" config user.email 'session@example.invalid'
git -C "$repo" add .
git -C "$repo" commit -qm initial
export PATH="$test_root/bin:$PATH"
export SESSION_TEST_COUNT="$test_root/count"
export SESSION_TEST_READY="$test_root/ready"

cat > "$test_root/bin/codex" <<'CODEX'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 7 && $1 == exec && $2 == review && $3 == --json && $4 == --ephemeral ]]
[[ $5 == --output-last-message && $7 == - ]]
result=$6
cat >/dev/null
count=0
[[ ! -f "$SESSION_TEST_COUNT" ]] || count=$(<"$SESSION_TEST_COUNT")
((count += 1))
printf '%s\n' "$count" > "$SESSION_TEST_COUNT"
printf '%s\n' 'diagnostic on stderr' >&2
printf '%s\n' 'invalid JSON' 'null' '{"type":"item.completed","thread_id":"wrong"}'
if [[ ${SESSION_TEST_MODE:-success} != no-session ]]; then
    printf '%s' '{"type":"thread.st'
    printf 'arted","thread_id":"legacy-%s"}\n' "$count"
fi
if [[ ${SESSION_TEST_MODE:-success} == fail || ${SESSION_TEST_MODE:-success} == no-session ]]; then
    exit 42
fi
if [[ ${SESSION_TEST_MODE:-success} == interrupt ]]; then
    trap 'exit 0' TERM
    touch "$SESSION_TEST_READY"
    while true; do sleep 0.1; done
fi
if [[ $count -eq 1 ]]; then
    printf '%s\n' 'Review comment: sample finding' > "$result"
else
    printf '%s\n' NO_NEW_FINDINGS > "$result"
fi
CODEX
chmod +x "$test_root/bin/codex"

(cd "$repo" && bash scripts/change-review.md master 2 "$test_root/success") > "$test_root/output" 2> "$test_root/error"
[[ $(grep -c '^Codex session ID: legacy-' "$test_root/output") -eq 2 ]]
grep -Fxq 'Codex session ID: legacy-1' "$test_root/output"
grep -Fxq 'Codex session ID: legacy-2' "$test_root/output"
grep -Fxq 'Pass 1 Codex session ID: legacy-1' "$test_root/success/run-info.txt"
grep -Fxq 'Pass 2 Codex session ID: legacy-2' "$test_root/success/run-info.txt"
grep -Fxq 'Stopped with no new findings: true' "$test_root/success/run-info.txt"

for mode in fail no-session; do
    status=0
    (cd "$repo" && SESSION_TEST_MODE=$mode bash scripts/change-review.md master 1 "$test_root/$mode") > "$test_root/$mode-output" 2> "$test_root/$mode-error" || status=$?
    [[ $status -eq 42 ]]
    if [[ $mode == no-session ]]; then
        expected='Codex session ID: unavailable (no valid thread.started event)'
    else
        expected='Codex session ID: legacy-3'
    fi
    grep -Fxq "$expected" "$test_root/$mode-output"
    grep -Fxq "Pass 1 $expected" "$test_root/$mode/run-info.txt"
done

(cd "$repo" && exec env SESSION_TEST_MODE=interrupt bash scripts/change-review.md master 1 "$test_root/interrupt") > "$test_root/interrupt-output" 2> "$test_root/interrupt-error" &
pid=$!
for ((attempt = 0; attempt < 100; attempt++)); do
    [[ ! -f "$SESSION_TEST_READY" ]] || break
    sleep 0.05
done
[[ -f "$SESSION_TEST_READY" ]]
kill -TERM "$pid"
status=0
wait "$pid" || status=$?
[[ $status -eq 130 ]]
grep -Fxq 'Codex session ID: legacy-5' "$test_root/interrupt-output"
grep -Fxq 'Pass 1 Codex session ID: legacy-5' "$test_root/interrupt/run-info.txt"
[[ -z $(git -C "$repo" status --short) ]]
printf '%s\n' 'change-review session capture tests passed (success, failure, missing session, interruption)'
