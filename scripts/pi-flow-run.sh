#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ $# -ne 1 || -z $1 ]]; then
	echo 'Usage: pi-flow-run.sh <slug>' >&2
	exit 2
fi

slug=$1
cd -- "$script_dir/.."
"$script_dir/create-change-branch.sh" "$slug"
"$script_dir/codex-change-write.pl"
"$script_dir/pi-review-loop.pl"
"$script_dir/pi-code-implement.pl"
"$script_dir/pi-review-loop.pl" --code
"$script_dir/merge-to-dev.pl"
