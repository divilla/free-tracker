# Repository Helper Scripts

This directory contains maintained, user-owned helpers for working with the mch repository. These files are intentional project tooling, not generated output or repository-hygiene candidates. Do not delete or relocate them without explicit user approval.

## Codex session IDs

Every `codex exec` invocation in `codex-change-write.pl`,
`codex-code-implement.pl`, `codex-review-loop.pl` (each review and fix), and the
Bash helper `change-review.md` uses JSON output and prints a separate line:

```text
Codex session ID: <codex-session-id>
```

The shared `lib/mch/CodexSession.pm` reads the first valid `thread.started`
event's `thread_id` from captured output. The ID is printed after command
progress finishes, before result handling or output cleanup, including failure
and interruption paths. Diagnostics, malformed JSON, unrelated events and
unsafe IDs are ignored. If no ID was emitted, the line explicitly reports
`unavailable (no valid thread.started event)`; no ID is invented or taken from
the parent environment, and the existing command exit status is preserved.
Authoring reuses the captured ID for interactive recovery as before.

`change-review.md` additionally records each pass's session ID in `run-info.txt`.
It retains its existing `--ephemeral` option: printing an ID does not make that
ephemeral session resumable. The flow/plan wrappers inherit IDs from their
child launchers; `codex-resume.sh` does not start a new `codex exec`.

The JSON event format is described in the
[official OpenAI documentation](https://learn.chatgpt.com/docs/non-interactive-mode).
Controlled checks (no live Codex calls) include:

```shell
perl scripts/test-codex-session.pl
bash scripts/test-change-review.sh
```

## Git authentication

Before running a workflow that fetches or pushes, load your SSH key into the
SSH agent available in your terminal:

```shell
bash scripts/git-auth.sh
```

This uses `$HOME/.ssh/divilla-github/id_ed25519` by default. Set
`MCH_GIT_SSH_KEY` to use another private-key path; its matching `.pub` file must
also be available. An SSH agent must already be running, with `SSH_AUTH_SOCK`
available in the terminal where you run these commands.

The merge, promotion, commit, branch-creation, branch-renaming, implementation,
and review workflows check that the current agent can use this specific key
before remote Git access or local changes. The Bash merge wrappers inherit
the check from the workflows they invoke. A missing agent or key stops the
workflow with exit `1` and an actionable error:

```text
error: Git authentication is not ready. Run 'bash /path/to/scripts/git-auth.sh' in this terminal to load your SSH key, then retry this command.
```

The check verifies current authentication readiness, not a persistent marker
that could outlive an agent. Run `git-auth.sh` again when the key is removed or
the agent is restarted. `bash scripts/git-auth.sh --check` performs the same
check without loading a key or prompting for its passphrase. Local Git merge
operations do not themselves require a password; the merge workflow needs this
check because it also fetches and pushes.

`perl scripts/test-git-auth.pl` tests setup with disposable keys and an isolated
SSH agent, and verifies that every guarded workflow stops before remote access
or repository changes. Other workflow tests use an SSH check stub and local Git
remotes, so they do not require your real key or contact an external service.

## Uncommitted work

Merge, promotion, branch-creation, branch-renaming, implementation, and review
workflows require a clean repository before authentication or remote Git access.
Staged changes, unstaged changes, deleted files, untracked files, and dirty
submodules all stop the workflow with exit `1`:

```text
error: Uncommitted work detected. Commit or stash your changes, then retry.
```

The check covers the entire repository, including when invoked from a
subdirectory. Promotions check this even when there is nothing to promote.
The wrappers report the error from their first failing workflow and stop.
`commit-user.pl` and `commit-agent.pl` remain exempt because their purpose is
to commit your pending work; both still require Git authentication.
Authentication setup and the interactive `codex-resume.sh` shortcut do not
require a clean repository.

## Implement a specification

Run the branch-creation, implementation, and review workflow with:

```shell
scripts/branch-create.sh agent/specs/000-domain-types.md &&
scripts/codex-code-implement.pl agent/specs/000-domain-types.md &&
scripts/codex-review-loop.pl --code
```

This creates and checks out the specification's change branch, uses
`$mch-code-implement` to implement the branch-selected change, commits that result, and then
starts the review loop in explicit code mode. The matching
`agent/changes/<slug>.md` must already exist. Each findings pass uses
`$mch-findings-fix --code` before the loop commits and pushes the resulting fixes.

## `commit-user.pl` and `commit-agent.pl`

Both scripts stage all repository changes, create a commit, and push the current branch to `origin`. Use `commit-user.pl` for user-authored changes; with no argument, its commit message defaults to `User commit`:

```shell
scripts/commit-user.pl
```

Use `commit-agent.pl` for agent-authored changes; with no argument, its commit message defaults to `Agent commit`:

```shell
scripts/commit-agent.pl
```

Pass either script one argument to provide a different commit message:

```shell
scripts/commit-user.pl "Initial commit"
scripts/commit-agent.pl "Implement runner"
```

Both scripts resolve the repository root from their own location, so they can be invoked from any working directory. They refuse to run from a detached `HEAD`.

## `branch-create.sh`

Create and check out a change branch for a specification:

```shell
scripts/branch-create.sh agent/specs/000-domain-types.md
```

The specification path must have the form `agent/specs/<spec-slug>.md`. The
script requires a clean working tree, fetches `origin`, and initializes missing
dev and stage branches as described below. It then creates and checks out
`change/<spec-slug>` directly from freshly fetched `origin/dev`,
without setting an upstream to dev. It stops if the change branch already
exists locally or as an `origin` remote-tracking ref. Local dev may be stale
or absent. On success, it prints the new branch name.

## Merge and promote changes

Run these helpers from the repository checkout. They require Git. The release
path is `dev` → `stage` → `master`. Branch creation, merging, and promotion
automatically ensure that **dev and stage exist both locally and on origin**:

When setup is needed, the initializer pulls `origin/master` into local `master`
with `--ff-only` (creating local master if needed). It then initializes **stage
from master, followed by dev from stage**. On a fresh setup, all three local and
remote branches start at the same latest production commit. The original branch
or detached checkout is restored after pulling master, including if the pull
fails. Unpublished or divergent local master commits must be resolved first.

| Existing copies of dev or stage | Initialization |
| --- | --- |
| Local and remote | Preserve both branch tips. |
| Remote only | Create the local branch from the remote tip. |
| Local only | Initialize from the release baseline below; preserve a different local tip in `backup/<branch>-before-init-<sha>`. |
| Neither | Create stage from updated master; create dev from stage's origin tip. |

Starting a completely missing stage at production preserves pending dev commits
for the requested promotion mode. A missing remote stage starts from updated
master; a missing remote dev starts from stage's origin tip. Local-only release
tips are not published because they may contain unsquashed change commits.
Their backup branches retain those commits. Existing published release history
is preserved. Once both branches
exist locally and remotely, setup does not pull master or reset either branch.
Remote creation uses a
lease requiring the branch to be absent, so it cannot overwrite a branch another
writer creates concurrently. Restricted fetch configurations are handled using
explicit refspecs when needed.

Missing dev or stage branches are normal setup conditions, not errors. Checkout
and authentication checks still run first. Actual Git failures still stop the
workflow. `origin/master` remains required whenever branch initialization is
needed, and as the destination for production promotion.

### `merge-to-dev.pl`

```shell
scripts/merge-to-dev.pl
```

Takes no arguments. The current branch must be a numbered
`change/<change-slug>` branch, have a clean working tree, and match its published
branch on `origin`. The merge always targets **dev** and requires no PR or `gh`.
The fetched dev tip must already be an ancestor of the change, otherwise rebase
the change first.

The script squashes the change with message `Implement change <change-slug>`,
publishes the squash using a lease on the remote change branch,
then fast-forwards and pushes dev. It reuses an existing squash with the expected
parent and message. After verifying the published dev SHA, it deletes the remote
change branch with a lease, keeps the local change branch, and leaves dev checked
out.

### `promote-to-stage.pl` and `promote-to-prod.pl`

| Script | Source | Destination |
| --- | --- | --- |
| `promote-to-stage.pl` | `dev` | `stage` |
| `promote-to-prod.pl` | `stage` | `master` |

Both scripts fetch `origin` and accept the same optional argument:

```shell
scripts/promote-to-stage.pl             # next pending commit
scripts/promote-to-stage.pl all         # source tip
scripts/promote-to-stage.pl <commit-sha> # through this commit
scripts/promote-to-prod.pl all
```

No argument promotes the oldest pending commit on the source's first-parent
release path after the destination. A merge commit brings its side-branch
ancestors with it. `all` promotes to the fetched source tip. A full or unambiguous
abbreviated commit SHA promotes through that exact commit, including all preceding
changes. Promotions preserve commit identities and push without force.

A supplied SHA is validated against the fetched source history first. If absent,
the script exits `1` with `<sha> does not exist in dev` (stage promotion) or
`<sha> does not exist in stage` (production promotion). Branch names and other
revision expressions are not SHA arguments. A valid SHA already in destination
history, or no pending commits, is a successful no-op with exit `0`.

Every promotion invocation requires a clean working tree before fetching or
checking its target SHA. An actual promotion also requires a fast-forward to the
selected SHA. Divergence, extra local destination commits, command failures, and
rejected pushes exit `1`. On success, the destination is checked out and its
remote tip is verified against the selected SHA. These scripts promote Git
branches; any deployment automation is separate.

### `merge-to-stage.sh` and `merge-to-prod.sh`

```shell
scripts/merge-to-stage.sh [all|<commit-sha>]
scripts/merge-to-prod.sh [all|<commit-sha>]
```

Both Bash wrappers first run `merge-to-dev.pl` without arguments. They then pass
their arguments unchanged to `promote-to-stage.pl`; `merge-to-prod.sh` also runs
`promote-to-prod.pl` with those same arguments. With no argument, each promotion
advances one pending commit, which may precede the change just merged. A SHA
argument must refer to the commit to promote, not a pre-squash change commit that
will be replaced by merging.

The wrappers stop at the first failed step, exit `1`, and report its invocation
line range, wrapper filename, and captured command stderr:

```text
error: lines 25-25 of file scripts/merge-to-prod.sh: <error-captured-from-command>
```

Completed steps remain in place; there is no rollback. Resume a failed promotion
by calling the corresponding promotion script directly. A rejected push can also
leave the local destination advanced while its remote remains unchanged.

### Tests

The Perl suites exercise shared logic and run the real scripts against temporary
local Git repositories, with a failing `gh` stub to detect accidental GitHub
dependencies. They do not contact GitHub or modify the working repository.
No separate wrapper test scripts are maintained.

```shell
perl scripts/test-merge-to-dev.pl
perl scripts/test-promote-to-stage.pl
perl scripts/test-promote-to-prod.pl
perl scripts/test-git-auth.pl
perl scripts/test-clean-checkout.pl
perl scripts/test-release-branches.pl
bash scripts/test-create-change-branch.sh
```

## `codex-plan-run.sh`

Execute all changes in the `agent/PLAN.md` inventory (currently S001–S025), in
order, through the existing per-change workflow:

```shell
scripts/codex-plan-run.sh --list
scripts/codex-plan-run.sh
```

`--list` previews the exact slugs without starting workflows, writing run state,
or requiring a clean Git checkout. Execution validates the entire inventory
first: missing/empty inventories, malformed rows, duplicate IDs/slugs,
inconsistent IDs/paths, or out-of-order changes fail before any dispatch. The
queue is snapshotted at startup; later inventory changes require a new invocation.
No change documents need to exist in advance. Bash 4+, Perl, Git, `flock` and
`setsid` (util-linux) are required to execute, along with the per-change tools.
The runner works from any directory, requires a clean committed checkout, and
serializes plan invocations in the existing checkout.

The first workflow failure stops execution and preserves its exit status.
There are no retries or automatic skips. Each invocation records queued,
started, succeeded, failed or interrupted changes, timestamps, branch/commit,
observed `origin/dev` and plan hash in a TSV file under the checkout's
Git metadata directory, `codex-plan-runs/`; its exact path is printed at startup.
The Git directory holds `codex-plan-run.lock`. These files survive branch
switches and are not staged by the workflow. SIGINT/SIGTERM stops the active
workflow process group and records an interruption (exit 130/143). Interactive
Codex recovery retains its controlling terminal; piped standard input is also
preserved.

Recover a failed change with the existing phase scripts; do not rerun its
branch-creation step. After that change is successfully merged, explicitly
continue at the **next** inventory slug, for example:

```shell
scripts/codex-plan-run.sh --from 006-android-tracking-spike
```

`--from` includes the exact selected slug and all later entries; earlier entries
are not marked complete. Confirm their required merge/dependency evidence
before choosing a restart point. A log left at `started` after a hard kill is
not completion evidence; reconcile the active change with Git before continuing.
This is a plan-level sequencer, not a replacement for per-change test, review,
dependency or merge gates, and it never infers product validation from workflow
exit status. PLAN §7's bootstrap/manual-equivalent obligations remain in force
until S004 audits and proves the underlying automation. It does not authorize
external account actions or publication and does not claim full IMPLEMENT
conformance of the existing helpers.

Controlled tests use a recording/failing per-change adapter and temporary Git
repositories, without calling Codex or pushing to a real remote. The terminal
recovery test also requires Python 3's standard-library PTY support:

```shell
bash scripts/test-codex-plan-run.sh
```

The `PLAN-RUN-*` cases cover all 25 slugs, working directories, preview/restart,
first/middle/last failure, invalid inventories, durable progress, dirty/missing
prerequisites, concurrent invocations in the same checkout, interruption
and interactive/piped input. These infrastructure checks do not substitute for
unavailable app unit, SQLite, E2E or device tests.

## `codex-flow-run.sh`

Run the complete author/review/implement/review/merge workflow for one slug:

```shell
scripts/codex-flow-run.sh 001-build-scaffold
```

The flow runs these steps in order, stopping at the first failure and retaining
its exit status:

1. `create-change-branch.sh <slug>`
2. `codex-change-write.pl`
3. `codex-review-loop.pl` (document mode)
4. `codex-code-implement.pl`
5. `codex-review-loop.pl --code`
6. `merge-to-dev.pl`

On success, the flow ends on `dev` with one published squash commit containing
the authored change and implementation. The remote change branch is deleted;
`stage` and `master` are not promoted. A failed merge returns nonzero and may
leave a published squash on the change branch or local `dev` ahead of origin.
After resolving the failure, check out the retained change branch and rerun
`merge-to-dev.pl` directly; do not restart the entire flow for that slug.

Branch creation and authoring do **not** require a pre-existing change file.
Both review calls and implementation require the readable branch-selected
`agent/changes/<slug>.md`; no legacy `agent/specs/` file is required or used.
The first review stops the flow if authoring returns without creating that file.
Only the branch-creation step accepts the slug; the later scripts derive it
from the current branch. The flow can be invoked from outside the repository.
It creates a new branch, not a resume of an existing branch. Resume a failed
phase by invoking its script directly on the existing change branch.

## `codex-change-write.pl`

Author the current branch's change, including when its file does not yet exist:

```shell
scripts/codex-change-write.pl
```

There is no positional document argument. The current branch must match
`^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$`; its captured slug selects
`agent/changes/<slug>.md`. The script requires a clean working tree and invokes
`$mch-change-write` through `codex exec --json` with `gpt-6.1-sol`, high reasoning,
and the standard (`default`) service tier.

A final response of exactly `Done.` (optionally followed by one line ending)
skips interactive mode. Other responses open `codex resume <session-id>` using
the ID from the execution's `thread.started` event. Resume inherits the terminal
and its exit code is ignored. Both paths commit and push repository changes as
`Write change <slug>`; if there are no changes, no commit/push is attempted.
Execution failures, a missing required resume ID, and Git failures remain
nonzero exits. Temporary results and logs are cleaned on exit.

## `codex-code-implement.pl`

Implement the current branch's already-authored change:

```shell
scripts/codex-code-implement.pl
```

There is no positional document argument. The current branch must match
`^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$`, and the selected
`agent/changes/<slug>.md` must exist and be readable before Codex starts.
The script requires a clean working tree so the automated commit cannot absorb
unrelated changes.

The startup context is printed in `Repository`, `Specification`, `Branch`
order, followed by an `=== Implementation ===` heading and the rendered Codex
command. In a color-capable terminal, labels remain white while repository,
specification, and branch values are blue, magenta, and green respectively.

The implementation runs as `codex exec --json` with `gpt-6.1-sol`, high reasoning,
and the standard (`default`) service tier set explicitly on its command line.
It also explicitly passes `--approve-for-me`: the implementation stays in the
workspace-write sandbox, but can request automatically reviewed escalation for
host Flutter SDK/cache writes, Android/ADB access, and remote baseline checks.
This prevents non-interactive runs from being unable to request the access
needed for prerequisite verification. It does not grant unrestricted access or
guarantee approval; managed policy and reviewer denials still apply. Use a Codex
CLI version supporting this flag; see the
[official non-interactive permissions documentation](https://learn.chatgpt.com/docs/non-interactive-mode)
and [automatic review](https://learn.chatgpt.com/docs/sandboxing/auto-review).
Sandbox-denied checks should be retried through that approval mechanism before
declaring host prerequisites unavailable; genuine missing/stale evidence still
blocks implementation. Authoring and review launch policies are unchanged.
It writes the final response with `-o <temporary-result>` and invokes
`$mch-code-implement` without a document-path argument. The skill matches the
current branch against `^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$` and uses
capture group 1 unchanged to select `agent/changes/<slug>.md`. An invalid
branch or missing change stops the script before Codex starts. The path is
derived from the branch for validation and context display, not passed to the
skill.
The command has the same elapsed-time, output-marker, activity-marker, success, failure, and
interrupt behavior as `codex-review-loop.pl`. Raw JSON output is suppressed on
success and printed on failure. When Codex succeeds, the script requires both a
final response and repository changes. It prints the final response between the
progress line and the changed-file list, then commits and pushes the changes as
`Implement code <slug>`. Temporary output stays outside the repository
and is removed on exit.

## `codex-review-loop.pl`

### Review an authored change (default)

On a branch matching `^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$`, run
`$mch-change-write` in Codex, then commit the resulting
`agent/changes/<slug>.md` and its `agent/PLAN.md` updates. Authenticate with
`bash scripts/git-auth.sh` if needed, then run:

```shell
scripts/codex-review-loop.pl --base dev
```

There is **no positional document argument**. The loop captures the complete
slug from the current branch and requires `agent/changes/<slug>.md` to exist.
Detached HEAD, invalid branches, missing changes, and a dirty working tree fail
before review. The default base is `origin/dev`; `--base BRANCH` overrides it.
Use an up-to-date local or remote-tracking base: the loop pins its current
commit at startup and does not fetch automatically.

Each pass reviews the entire branch diff against that pinned base using native
`codex exec review --base`, including commits made by earlier passes. This is
not a file-filtered review: keep the authoring branch focused on its change and
PLAN updates if you want only those documents reviewed.

When findings exist, the loop invokes `$mch-findings-fix` in a fresh Codex
session with the complete findings supplied on stdin. Document mode is the
default: the skill corrects only the selected change and its directly necessary
PLAN bookkeeping. It must not implement the feature, edit code/tests, or write
an implementation log. It validates document requirements, references, and
planned test coverage without claiming that planned tests have run.
The loop also checks the changed paths before committing: edits outside the
selected change and `agent/PLAN.md`, removal of the change, a branch switch,
or a fixer-created commit stop the run. Unexpected edits remain available for
inspection; the loop does not discard them or publish them.

Valid document fixes are automatically **committed and pushed to `origin` on
the current branch** as `review fixes NN`, then reviewed again. The loop stops
successfully only when the reviewer returns no comments. A failed review/fixer,
invalid reviewer output, or no-change fix pass stops with a nonzero status.
Rejected findings and blockers are printed, not silently treated as clean.
There is no automatic adjudication of a reviewer/fixer disagreement.

### Review implementation code (explicit)

After implementation, opt in to code fixes:

```shell
scripts/codex-review-loop.pl --code --base dev
```

This invokes `$mch-findings-fix --code`, enabling implementation and test changes
against the same branch-selected change. Code-mode fixes write review-fix
statistics to `implementation-log.md`; an absent matching block is created
without inventing prior implementation statistics. The document-only path
restriction does not apply. `codex-flow-run.sh` explicitly uses this mode after its
implementation step.

### Manual review and handoff

A review launched in another terminal does not automatically populate a Codex
conversation. Paste its findings after `$mch-findings-fix`, or capture and pass
them explicitly (the temporary file stays outside the checkout):

```shell
review_findings=$(mktemp)
codex exec review --base dev -o "$review_findings" &&
  codex exec '$mch-findings-fix' < "$review_findings"
rm -- "$review_findings"
```

Only invoke the fixer when there are findings to address. The manual skill
neither commits nor pushes. For code fixes use `$mch-findings-fix --code`.

### Options, output, and failure handling

Review options are forwarded to Codex, except the loop consumes `--code` and
pins `--base`. Every review and fresh fix session selects `gpt-6.1-sol`, high
reasoning, and the standard (`default`) service tier. An explicit review model
option overrides the review default. Custom review prompts (including `-` or
`--`), `--uncommitted`, and `--commit` are rejected: the loop requires a branch
range that includes its later commits. Output destinations are managed by the
loop, and `--output-schema` is rejected because native review ignores it.

Native review findings are detected by the exact `Review comment:` or
`Full review comments:` header, not verdict text embedded inside findings.
Empty output and known failed/interrupted reviewer responses are rejected.
Each invocation uses a private temporary directory outside the checkout,
preferring `TMPDIR`, `TMP`, `TEMP`, then `/tmp`; findings, fix responses, and
progress logs are cleaned on exit. Paths resolving inside the checkout are
skipped. The loop prints each final response and changed-file list. Its commit
operation is built into the running process, so a rewritten repository helper
is never executed to commit fixes.

The script requires Perl, Git, Codex, and a POSIX environment. Controlled
workflow tests use fake Codex responses and real temporary Git repositories
and local remotes; they never invoke the model or push to a real remote:

```shell
perl scripts/test-unit-codex-review-loop.pl
bash scripts/test-codex-review-loop.sh
perl scripts/test-unit-codex-change-write.pl
bash scripts/test-codex-change-write.sh
perl scripts/test-unit-codex-code-implement.pl
bash scripts/test-codex-code-implement.sh
bash scripts/test-codex-flow-run.sh
bash scripts/test-codex-plan-run.sh
perl scripts/test-git-auth.pl
```

Tests cover branch/path selection, default document scope, explicit code mode,
complete findings handoff, commit/push/re-review, authentication, dirty-tree
rejection, missing documents, invalid output, review/fix failures, no-change
fixes, scope violations, branch switching, temporary-file cleanup, and
interruption. These script checks do not replace application unit/E2E tests.

While Codex runs, its output is replaced by a progress line such as
`[ ] 00:00 •••••••••●`, containing elapsed minutes and seconds plus accumulated
output bullets, rate-limited to at most one bullet per second while output is
received. The activity marker is appended directly to the bullets without
intervening whitespace. In a terminal, Perl's timed I/O
multiplexing updates the activity marker every 250 milliseconds independently
of Codex output, without delivering asynchronous progress signals to the
process. The reusable implementation lives in `lib/mch/Progress.pm`. The
status resolves to `[✅]` on success or `[❌]` on failure or interruption; a
finished line looks like `[✅] 11:11 ••••••••••••`. Pressing Ctrl+C
terminates the active Codex command and the loop. Review startup output uses the
repository, change, and branch order, followed by the base, pinned base, review options, and
findings file. Additional values retain their established colors. All terminal
colors are disabled when `NO_COLOR` is set.
Before each run, the Codex command is printed with readable single-quoted
arguments between separator lines sized to its longest rendered line. The
fixer's stdin redirection is rendered on a separate line, so neither separator
extends into that line. Codex runs in JSON mode so progress events remain
streamable while their raw content is suppressed on success. If Codex fails,
its captured output is printed to standard error for diagnosis.
