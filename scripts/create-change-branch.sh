#!/usr/bin/env bash
set -euo pipefail

usage() {
	echo "usage: scripts/create-change-branch.sh <slug>" >&2
}

fail() {
	echo "branch-create: $*" >&2
	exit 1
}

ensure_clean_worktree() {
	local changes
	changes=$(git status --porcelain=v1 --untracked-files=all --ignore-submodules=none)
	if [[ -n "$changes" ]]; then
		echo 'error: Uncommitted work detected. Commit or stash your changes, then retry.' >&2
		exit 1
	fi
}

if [[ $# -ne 1 ]]; then
	usage
	exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null) || \
	fail "scripts directory is not inside a git repository"
cd "$repo_root"

slug=$1
pattern='^[0-9][0-9][0-9]+-[a-z0-9_-]+$'
if [[ "$slug" =~ $pattern ]]; then
    branch="change/$slug"
else
    fail "invalid slug - doesn't match pattern: $pattern"
fi

ensure_clean_worktree
git fetch --prune origin 1>&2
ensure_clean_worktree

perl -I "$script_dir/lib" -Mmch::Release=run_cli,ensure_release_branches \
	-e 'run_cli(sub { ensure_release_branches() })' 1>&2

if git show-ref --verify --quiet "refs/heads/$branch"; then
	fail "branch already exists: $branch"
else
	status=$?
	[[ $status -eq 1 ]] || fail "cannot inspect branch $branch"
fi

if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
	fail "branch already exists: origin/$branch"
else
	status=$?
	[[ $status -eq 1 ]] || fail "cannot inspect origin/$branch"
fi

git checkout -b "$branch" origin/dev 1>&2
ensure_clean_worktree
printf '%s\n' "$branch"
