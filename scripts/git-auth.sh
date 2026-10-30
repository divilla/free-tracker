#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
key=${MCH_GIT_SSH_KEY:-"$HOME/.ssh/divilla-github/id_ed25519"}

if [[ $# == 1 && $1 == --check ]]; then
	if ssh-add -T "$key.pub" >/dev/null 2>&1; then
		exit 0
	fi
	printf "error: Git authentication is not ready. Run 'bash %s/git-auth.sh' in this terminal to load your SSH key, then retry this command.\n" "$script_dir" >&2
	exit 1
fi
if [[ $# != 0 ]]; then
	printf '%s\n' 'usage: scripts/git-auth.sh [--check]' >&2
	exit 1
fi
if [[ -z ${SSH_AUTH_SOCK:-} || ! -S $SSH_AUTH_SOCK ]]; then
	printf '%s\n' 'error: Make sure an SSH agent is running and SSH_AUTH_SOCK is available.' >&2
	exit 1
fi
if ! ssh-add "$key"; then
	printf 'error: Unable to load the Git SSH key: %s\n' "$key" >&2
	exit 1
fi
