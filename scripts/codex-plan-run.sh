#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
plan_path="$repo_root/agent/PLAN.md"
flow="$script_dir/codex-flow-run.sh"

fail() {
	echo "codex-plan-run: $*" >&2
	exit 1
}

usage() {
	echo 'Usage: codex-plan-run.sh [--list | --from <slug>]' >&2
}

mode=run
start_slug=''
case $# in
	0) ;;
	1) [[ $1 == --list ]] || { usage; exit 2; }; mode=list ;;
	2) [[ $1 == --from && -n $2 ]] || { usage; exit 2; }; start_slug=$2 ;;
	*) usage; exit 2 ;;
esac

# Parse and validate the entire inventory before starting any change. Other
# tables, roadmap phases, and incidental slug references are not work items.
command -v perl >/dev/null || fail 'Perl is required'
if ! inventory=$(perl - "$plan_path" <<'PERL'
use strict;
use warnings;
open my $plan, '<:encoding(UTF-8)', $ARGV[0]
    or die "codex-plan-run: cannot read $ARGV[0]: $!\n";
my (@slugs, %ids, %slugs);
my ($in_table, $separator, $previous) = (0, 0, -1);
while (my $line = <$plan>) {
    if (!$in_table) {
        next unless $line =~ /^\| Change \/ path \| Slug \| Dependencies \|/;
        $in_table = 1;
        next;
    }
    last unless $line =~ /^\|/;
    chomp $line;
    my @cells = split /\|/, $line, -1;
    shift @cells;
    pop @cells;
    s/^\s+|\s+$//g for @cells;
    die "codex-plan-run: malformed PLAN inventory row at line $.\n" unless @cells == 5;
    if (!$separator) {
        die "codex-plan-run: missing PLAN inventory separator\n"
            if grep { !/^:?-+:?$/ } @cells;
        $separator = 1;
        next;
    }
    my ($id, $number, $path) = $cells[0] =~ /^(S([0-9]{3,})) \/ `changes\/([^`]+)\.md`$/;
    my ($slug, $prefix) = $cells[1] =~ /^`(([0-9]{3,})-[a-z0-9_-]+)`$/;
    die "codex-plan-run: invalid ID, slug or change path at PLAN line $.\n"
        unless defined($id) && defined($slug) && $number eq $prefix && $path eq $slug;
    die "codex-plan-run: duplicate PLAN change: $slug\n" if $ids{$id}++ || $slugs{$slug}++;
    die "codex-plan-run: PLAN changes must be in increasing numeric order\n"
        unless $number > $previous;
    $previous = $number;
    push @slugs, $slug;
}
close $plan or die "codex-plan-run: cannot close PLAN: $!\n";
die "codex-plan-run: PLAN change inventory is missing or empty\n" unless @slugs;
print "$_\n" for @slugs;
PERL
); then
	exit 1
fi
mapfile -t slugs <<<"$inventory"
if [[ $mode == list ]]; then
	printf '%s\n' "${slugs[@]}"
	exit 0
fi

start=0
if [[ -n $start_slug ]]; then
	found=0
	for index in "${!slugs[@]}"; do
		if [[ ${slugs[index]} == "$start_slug" ]]; then
			start=$index
			found=1
			break
		fi
	done
	[[ $found -eq 1 ]] || fail "--from slug is not in PLAN: $start_slug"
fi

for tool in git flock setsid; do
	command -v "$tool" >/dev/null || fail "$tool is required"
done
[[ -x $flow ]] || fail "missing executable workflow: $flow"
cd -- "$repo_root"
git_dir=$(git rev-parse --absolute-git-dir) || fail 'repository is required'
common_dir=$(git rev-parse --git-common-dir) || exit $?
common_dir=$(cd -- "$common_dir" && pwd)
exec 9>"$common_dir/codex-plan-run.lock"
flock -n 9 || fail 'another plan run is active in this repository'
changes=$(git status --porcelain=v1 --untracked-files=all --ignore-submodules=none) || exit $?
[[ -z $changes ]] || fail 'uncommitted work detected; commit or stash it before running'
git rev-parse --verify HEAD >/dev/null || fail 'an initial commit is required'

# Git metadata survives branch switches and cannot be accidentally committed by
# a workflow helper. Keep each invocation separate; never infer gate completion.
mkdir -p -- "$git_dir/codex-plan-runs"
run_log=$(mktemp "$git_dir/codex-plan-runs/run.XXXXXXXX.tsv")
plan_hash=$(git hash-object "$plan_path")
printf 'event\ttime_utc\tslug\texit_status\tbranch\tcommit\torigin_dev\tplan_hash\n' >"$run_log"
record() {
	local event=$1 slug=$2 status=$3 branch commit baseline
	branch=$(git symbolic-ref --quiet --short HEAD) || branch=DETACHED
	commit=$(git rev-parse --verify HEAD) || commit=unknown
	baseline=$(git rev-parse --verify refs/remotes/origin/dev 2>/dev/null) || baseline=unavailable
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$event" "$(date -u +%FT%TZ)" \
		"$slug" "$status" "$branch" "$commit" "$baseline" "$plan_hash" >>"$run_log"
}
echo "codex-plan-run: progress log: $run_log" >&2
for ((index=start; index<${#slugs[@]}; index++)); do
	record queued "${slugs[index]}" -
done

active_pid=''
active_slug=''
interrupted() {
	local status=$1
	trap '' INT TERM
	if [[ -n $active_pid ]]; then
		# The workflow has its own process group, including its model processes.
		kill -TERM -- "-$active_pid" 2>/dev/null || kill -TERM "$active_pid" 2>/dev/null || true
		wait "$active_pid" 2>/dev/null || true
	fi
	record interrupted "$active_slug" "$status"
	echo 'codex-plan-run: interrupted; inspect the progress log and recover the active change before continuing' >&2
	exit "$status"
}
trap 'interrupted 130' INT
trap 'interrupted 143' TERM

for ((index=start; index<${#slugs[@]}; index++)); do
	active_slug=${slugs[index]}
	printf '\n[%d/%d] %s\n' "$((index + 1))" "${#slugs[@]}" "$active_slug"
	record started "$active_slug" -
	status=0
	if [[ -t 0 ]]; then
		# Codex may resume interactively to resolve authoring questions. Keep
		# its controlling terminal, and foreground its own process group.
		set -m
		"$flow" "$active_slug" <&0 &
		active_pid=$!
		fg '%+' || status=$?
		set +m
	else
		setsid "$flow" "$active_slug" <&0 &
		active_pid=$!
		wait "$active_pid" || status=$?
	fi
	active_pid=''
	if [[ $status -ne 0 ]]; then
		event=failed
		if [[ $status -eq 130 || $status -eq 143 ]]; then event=interrupted; fi
		record "$event" "$active_slug" "$status"
		echo "codex-plan-run: $active_slug failed (exit $status); later changes were not started" >&2
		echo 'Recover the failed phase using its script; after its merge succeeds, continue with --from <next-slug>.' >&2
		exit "$status"
	fi
	record succeeded "$active_slug" 0
done
trap - INT TERM
printf '\nCompleted %d plan change workflow(s). Product-validation and release gates remain separate.\n' \
	"$((${#slugs[@]} - start))"
