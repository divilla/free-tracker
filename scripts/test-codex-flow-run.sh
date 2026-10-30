#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
repo="$test_root/repo with spaces"
mkdir -p "$repo/scripts" "$repo/nested"
cp "$script_dir/codex-flow-run.sh" "$repo/scripts/"
export FLOW_TEST_CALLS="$test_root/calls"
export FLOW_TEST_REPO="$repo"
export FLOW_TEST_SLUG='1000-fix_step-count'
for helper in create-change-branch.sh codex-change-write.pl codex-code-implement.pl codex-review-loop.pl merge-to-dev.pl; do
	cat >"$repo/scripts/$helper" <<'HELPER'
#!/usr/bin/env bash
set -euo pipefail
name=$(basename -- "$0")
case "$name" in
	create-change-branch.sh) [[ $# -eq 1 && $1 == "$FLOW_TEST_SLUG" ]] ;;
	codex-change-write.pl|codex-code-implement.pl|merge-to-dev.pl) [[ $# -eq 0 ]] ;;
	codex-review-loop.pl) [[ $# -eq 0 || ( $# -eq 1 && $1 == --code ) ]] ;;
esac
printf '%s%s\n' "$name" "${1:+ $1}" >>"$FLOW_TEST_CALLS"
stage=$(wc -l <"$FLOW_TEST_CALLS")
if [[ ${FLOW_TEST_FAIL_STAGE:-0} -eq $stage ]]; then
	exit "$((20 + stage))"
fi
change="$FLOW_TEST_REPO/agent/changes/$FLOW_TEST_SLUG.md"
case "$stage:$name" in
	1:create-change-branch.sh) [[ ! -e $change ]] ;;
	2:codex-change-write.pl)
		mkdir -p -- "$(dirname -- "$change")"
		printf '%s\n' '# Authored change' >"$change"
		;;
	3:codex-review-loop.pl) [[ $# -eq 0 && -f $change ]] ;;
	4:codex-code-implement.pl) [[ -f $change ]] ;;
	5:codex-review-loop.pl) [[ $# -eq 1 && $1 == --code && -f $change ]] ;;
	6:merge-to-dev.pl) [[ -f $change ]] ;;
	*) exit 99 ;;
esac
HELPER
	chmod +x "$repo/scripts/$helper"
done

printf '%s\n' "create-change-branch.sh $FLOW_TEST_SLUG" codex-change-write.pl \
	codex-review-loop.pl codex-code-implement.pl 'codex-review-loop.pl --code' merge-to-dev.pl >"$test_root/expected"

reset_run() {
	: >"$FLOW_TEST_CALLS"
	rm -f -- "$repo/agent/changes/$FLOW_TEST_SLUG.md"
}

# Fresh authoring has no pre-existing spec/change, from any working directory.
for directory in "$repo" "$repo/nested" "$test_root"; do
	reset_run
	(cd -- "$directory" && bash "$repo/scripts/codex-flow-run.sh" "$FLOW_TEST_SLUG")
	cmp "$test_root/expected" "$FLOW_TEST_CALLS"
done

# Every failed phase retains its exit status and prevents all following phases.
for stage in 1 2 3 4 5 6; do
	reset_run
	status=0
	FLOW_TEST_FAIL_STAGE=$stage bash "$repo/scripts/codex-flow-run.sh" "$FLOW_TEST_SLUG" || status=$?
	[[ $status -eq $((20 + stage)) ]]
	head -n "$stage" "$test_root/expected" >"$test_root/expected-failure"
	cmp "$test_root/expected-failure" "$FLOW_TEST_CALLS"
done

# Invalid invocation must not start branch creation.
for invocation in missing empty extra; do
	reset_run
	status=0
	case "$invocation" in
		missing) args=() ;;
		empty) args=('') ;;
		extra) args=("$FLOW_TEST_SLUG" extra) ;;
	esac
	bash "$repo/scripts/codex-flow-run.sh" "${args[@]}" 2>"$test_root/usage" || status=$?
	[[ $status -eq 2 && ! -s $FLOW_TEST_CALLS ]]
	grep -Fxq 'Usage: codex-flow-run.sh <slug>' "$test_root/usage"
done
printf '%s\n' 'codex-flow-run ordering, working directories, usage, and failure propagation passed'


# Exercise the real six-step workflow with a deterministic Codex adapter and
# real Git commits/pushes. Start without a specs or changes directory.
reset_run
for helper in create-change-branch.sh codex-change-write.pl codex-code-implement.pl codex-review-loop.pl merge-to-dev.pl git-auth.sh; do
	cp "$script_dir/$helper" "$repo/scripts/$helper"
done
mkdir -p "$repo/scripts/lib/mch" "$test_root/bin"
cp "$script_dir/lib/mch/Progress.pm" "$script_dir/lib/mch/GitAuth.pm" "$script_dir/lib/mch/Release.pm" "$repo/scripts/lib/mch/"
cp "$script_dir/lib/mch/CodexSession.pm" "$repo/scripts/lib/mch/"
cp "$script_dir/lib/mch/WorkflowEvidence.pm" "$repo/scripts/lib/mch/"
cp "$script_dir/workflow-evidence.pl" "$repo/scripts/"
cp "$script_dir/test-lib/ssh-add" "$test_root/bin/"
export PATH="$test_root/bin:$PATH"
export MCH_GIT_SSH_KEY="$test_root/test-key"
export COLUMNS=80
cat >"$test_root/bin/codex" <<'CODEX'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == exec ]]
shift
review=0
if [[ $1 == review ]]; then review=1; shift; fi
result=''
prompt=''
auto_approve=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		-o) result=$2; shift 2 ;;
		--base|--model|-c) shift 2 ;;
		--json) shift ;;
		--approve-for-me) auto_approve=1; shift ;;
		*) prompt=$1; shift ;;
	esac
done
[[ -n $result ]]
change="agent/changes/$FLOW_TEST_SLUG.md"
if [[ $review -eq 1 ]]; then
	[[ $auto_approve -eq 0 ]]
	[[ -r $change ]]
	printf '%s\n' review >>"$FLOW_TEST_CALLS"
	printf '%s\n' 'No issues found.' >"$result"
elif [[ $prompt == '$mch-change-write' ]]; then
	[[ $auto_approve -eq 0 ]]
	[[ ! -e $change ]]
	printf '%s\n' author >>"$FLOW_TEST_CALLS"
	if [[ ${FLOW_TEST_NO_AUTHOR:-0} == 0 ]]; then
		mkdir -p agent/changes
		printf '%s\n' '# Authored change' >"$change"
		printf '# Updated plan for %s\n' "$FLOW_TEST_SLUG" >agent/PLAN.md
	fi
	printf '%s' 'Done.' >"$result"
elif [[ $prompt == '$mch-code-implement' ]]; then
	[[ $auto_approve -eq 1 ]]
	[[ -r $change ]]
	printf '%s\n' implement >>"$FLOW_TEST_CALLS"
	if [[ -n ${FLOW_TEST_DEPENDENCY_SLUG:-} ]]; then
		# WF-EVIDENCE-R01: only Git integration and required contents matter
		# downstream; missing historical review receipts are not a gate.
		perl scripts/workflow-evidence.pl "$FLOW_TEST_DEPENDENCY_SLUG" dev |
			perl -MJSON::PP -0777 -e 'my $s=decode_json(<>); die unless $s->{integration} eq "verified" && $s->{review} eq "unverified";'
		[[ -r implementation.txt ]]
		grep -Fxq 'Review/commit/merge: not run' agent/historical-handoff.md
	fi
	printf 'Implemented behavior for %s\n' "$FLOW_TEST_SLUG" >implementation.txt
	printf '%s\n' 'Implementation complete.' >"$result"
	printf '%s\n' '{"schema":1,"outcome":"complete"}' >"$MCH_IMPLEMENTATION_OUTCOME_FILE"
else
	exit 99
fi
printf '%s\n' '{"type":"turn.completed"}'
CODEX
chmod +x "$test_root/bin/codex"
mkdir -p "$repo/agent"
printf '%s\n' 'Review/commit/merge: not run' >"$repo/agent/historical-handoff.md"
git init --bare -q "$test_root/origin.git"
git -C "$repo" init -q -b master
git -C "$repo" config user.name 'Flow Test'
git -C "$repo" config user.email 'flow@example.invalid'
git -C "$repo" config commit.gpgsign false
git -C "$repo" remote add origin "$test_root/origin.git"
git -C "$repo" add .
git -C "$repo" commit -q -m initial
git -C "$repo" push -q -u origin master
initial=$(git -C "$repo" rev-parse HEAD)
# Invalid slugs fail before authoring or changing branches.
for invalid_slug in plain 12-short 001-Uppercase 001-with/slash; do
	status=0
	bash "$repo/scripts/codex-flow-run.sh" "$invalid_slug" >"$test_root/invalid-output" 2>"$test_root/invalid-error" || status=$?
	[[ $status -eq 1 && ! -s $FLOW_TEST_CALLS ]]
	[[ $(git -C "$repo" branch --show-current) == master ]]
done
[[ ! -e "$repo/agent/changes/$FLOW_TEST_SLUG.md" ]]
(cd "$test_root" && bash "$repo/scripts/codex-flow-run.sh" "$FLOW_TEST_SLUG") >"$test_root/real-output" 2>"$test_root/real-error" || {
	cat "$test_root/real-output" "$test_root/real-error" >&2
	exit 1
}
printf '%s\n' author review implement review >"$test_root/expected-real"
cmp "$test_root/expected-real" "$FLOW_TEST_CALLS"
[[ $(git -C "$repo" branch --show-current) == dev ]]
[[ $(git -C "$repo" log -1 --format=%s) == "Implement change $FLOW_TEST_SLUG" ]]
[[ $(git -C "$repo" rev-parse HEAD^) == "$initial" ]]
[[ $(git -C "$repo" rev-list --count "$initial..HEAD") -eq 1 ]]
[[ $(git -C "$repo" rev-parse HEAD) == $(git --git-dir="$test_root/origin.git" rev-parse refs/heads/dev) ]]
[[ $(git -C "$repo" rev-parse HEAD) == $(git -C "$repo" rev-parse "refs/heads/change/$FLOW_TEST_SLUG") ]]
[[ -z $(git --git-dir="$test_root/origin.git" for-each-ref --format='%(refname)' "refs/heads/change/$FLOW_TEST_SLUG") ]]
[[ $(cat "$repo/agent/changes/$FLOW_TEST_SLUG.md") == '# Authored change' ]]
[[ $(cat "$repo/agent/PLAN.md") == "# Updated plan for $FLOW_TEST_SLUG" ]]
[[ $(cat "$repo/implementation.txt") == "Implemented behavior for $FLOW_TEST_SLUG" ]]
for release_branch in stage master; do
	[[ $(git --git-dir="$test_root/origin.git" rev-parse "refs/heads/$release_branch") == "$initial" ]]
done
[[ -z $(git -C "$repo" status --short) ]]

# WF-EVIDENCE-R02: results survive temporary-output cleanup and squash rewriting.
(cd "$repo" && perl scripts/workflow-evidence.pl "$FLOW_TEST_SLUG" dev) |
	perl -MJSON::PP -0777 -e 'my $s=decode_json(<>); die unless $s->{integration} eq "verified" && $s->{review} eq "verified"; die unless grep { ($_->{response}//"") =~ /No issues found/ } @{$s->{receipts}};'

# WF-EVIDENCE-R01: simulate a legacy dependency without retained review logs.
# The next complete workflow must run with its old handoff untouched.
export FLOW_TEST_DEPENDENCY_SLUG="$FLOW_TEST_SLUG"
mv "$repo/.git/mch-workflow-evidence/$FLOW_TEST_SLUG" "$test_root/archived-first-evidence"
export FLOW_TEST_SLUG='1004-next_dependency'
: >"$FLOW_TEST_CALLS"
bash "$repo/scripts/codex-flow-run.sh" "$FLOW_TEST_SLUG" >"$test_root/next-output" 2>"$test_root/next-error" || {
	cat "$test_root/next-output" "$test_root/next-error" >&2
	exit 1
}
cmp "$test_root/expected-real" "$FLOW_TEST_CALLS"
[[ $(git -C "$repo" branch --show-current) == dev ]]
grep -Fxq 'Review/commit/merge: not run' "$repo/agent/historical-handoff.md"
unset FLOW_TEST_DEPENDENCY_SLUG
printf '%s\n' 'WF-EVIDENCE-R01 next workflow accepts integrated dependency without predecessor review receipts'

# Done without an authored file must fail at document review, before either
# implementation or the final review can run.
export FLOW_TEST_SLUG='1001-missing_change'
: >"$FLOW_TEST_CALLS"
status=0
FLOW_TEST_NO_AUTHOR=1 bash "$repo/scripts/codex-flow-run.sh" "$FLOW_TEST_SLUG" >"$test_root/missing-output" 2>"$test_root/missing-error" || status=$?
[[ $status -eq 1 ]]
[[ $(cat "$FLOW_TEST_CALLS") == author ]]
grep -Fxq "codex-review-loop: change file not found or unreadable: agent/changes/$FLOW_TEST_SLUG.md" "$test_root/missing-error"
[[ $(git -C "$repo" rev-parse HEAD) == $(git -C "$repo" rev-parse origin/dev) ]]
printf '%s\n' 'codex-flow-run real-helper integration and missing-change gates passed'

# A rejected final dev push fails the flow without publishing dev or deleting
# the squashed change. Resume the merge directly, without rerunning Codex.
export FLOW_TEST_SLUG='1002-rejected_merge'
: >"$FLOW_TEST_CALLS"
dev_before=$(git --git-dir="$test_root/origin.git" rev-parse refs/heads/dev)
cat >"$test_root/origin.git/hooks/pre-receive" <<'HOOK'
#!/bin/sh
while read old new ref; do
	if [ "$ref" = refs/heads/dev ]; then
		echo 'flow test: dev push rejected' >&2
		exit 1
	fi
done
HOOK
chmod +x "$test_root/origin.git/hooks/pre-receive"
status=0
bash "$repo/scripts/codex-flow-run.sh" "$FLOW_TEST_SLUG" >"$test_root/rejected-output" 2>"$test_root/rejected-error" || status=$?
[[ $status -eq 1 ]]
cmp "$test_root/expected-real" "$FLOW_TEST_CALLS"
grep -Fq 'flow test: dev push rejected' "$test_root/rejected-error"
[[ $(git --git-dir="$test_root/origin.git" rev-parse refs/heads/dev) == "$dev_before" ]]
squash=$(git --git-dir="$test_root/origin.git" rev-parse "refs/heads/change/$FLOW_TEST_SLUG")
[[ $(git -C "$repo" rev-parse "$squash^") == "$dev_before" ]]
[[ $(git -C "$repo" log -1 --format=%s "$squash") == "Implement change $FLOW_TEST_SLUG" ]]
[[ -z $(git -C "$repo" status --short) ]]
rm -- "$test_root/origin.git/hooks/pre-receive"
git -C "$repo" checkout -q "change/$FLOW_TEST_SLUG"
(cd "$repo" && scripts/merge-to-dev.pl) >"$test_root/resume-output" 2>"$test_root/resume-error" || {
	cat "$test_root/resume-output" "$test_root/resume-error" >&2
	exit 1
}
[[ $(git -C "$repo" branch --show-current) == dev ]]
[[ $(git --git-dir="$test_root/origin.git" rev-parse refs/heads/dev) == "$squash" ]]
[[ -z $(git --git-dir="$test_root/origin.git" for-each-ref --format='%(refname)' "refs/heads/change/$FLOW_TEST_SLUG") ]]
cmp "$test_root/expected-real" "$FLOW_TEST_CALLS"
printf '%s\n' 'codex-flow-run merge failure propagation and direct merge recovery passed'
