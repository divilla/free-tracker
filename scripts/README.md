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

Missing dev or stage branches are normal setup conditions, not errors. Worktree
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
perl scripts/test-worktree.pl
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
serializes plan invocations across the repository's linked worktrees.

The first workflow failure stops execution and preserves its exit status.
There are no retries or automatic skips. Each invocation records queued,
started, succeeded, failed or interrupted changes, timestamps, branch/commit,
observed `origin/dev` and plan hash in a TSV file under the worktree's
Git metadata directory, `codex-plan-runs/`; its exact path is printed at startup.
The common Git directory holds `codex-plan-run.lock`. These files survive branch
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
until S003–S004 audit and prove the underlying automation. It does not authorize
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
prerequisites, concurrent invocations (including linked worktrees), interruption
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

### Dependency readiness and retained workflow observations

Dependency readiness is integration plus the code/contracts and validation
needed by the current stage. **Subsequent changes do not re-audit predecessor
review/fix history.** Each change's own delivering workflow enforces its review
loop. Find the exact `Implement change <slug>` commit reachable from the selected
`dev` baseline and inspect required contents. A subject line alone is not proof
of required behavior or device/product validation. Old handoff `not run` notes
and missing historical receipts are not additional downstream delivery gates;
no replacement handoff or publisher confirmation is required.

Read-only optional diagnostics, from the repository/worktree:

```shell
perl scripts/workflow-evidence.pl 002-setup-decisions dev
```

The JSON reports the exact resolved baseline, `integration` (`verified`,
`unverified`, or `ambiguous` if multiple exact change commits exist), optional
review diagnostics, and retained receipts. Exit 0 means inspection succeeded,
not that all delivery/product gates passed. Git integration is independent of
review receipts. A clean diagnostic code review requires the latest code-review
receipt to match the squash tree and parent baseline; document review never
substitutes for code review. Unknown/stale/failed review diagnostics do not undo
integration or become downstream prerequisites. Missing required code/contracts
or current-stage validation still block, with a concrete requirement/reason.

The implementation/review/merge helpers now append private schema-1 JSON
observations beneath `git rev-parse --git-common-dir`, in
`mch-workflow-evidence/<slug>/<unique-observation>/receipt.json`. They retain
responses, exact source/tree/baseline where applicable, review mode/pass/outcome,
implementation command outcome and any available app check-summary contents,
and the verified published merge SHA. Check reports retain their own revision
and dirty-content digest; presence/model prose does not certify them. Inspect
scope and content identity before using a report as check evidence. Temporary
output can be removed without losing these observations. They remain local,
are shared across linked worktrees, are not automatically staged/pushed, and
must be explicitly archived for portability. Missing observations for older
runs need no backfill. Interrupted observations stay incomplete; malformed or
conflicting receipts produce explicit diagnostic errors and unverified review
status, without overriding Git integration or inventing passing observations.

These receipts are diagnostics, not S003's authoritative run-state/projection
schema or a claim of GW conformance. S003/S004 must reuse/import their evidence.
No new lock/retry/unattended-merge guarantees are implied.

Run the mapped unit and real-Git regressions with `make workflow-test`. They
use deterministic Codex adapters and temporary local remotes; no real Codex,
publisher remote or device is used.

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
success and printed on failure. The caller sets a private
`MCH_IMPLEMENTATION_OUTCOME_FILE`; the skill must write
`{"schema":1,"outcome":"complete"}`, or `blocked`/`failed` as appropriate.
Missing, malformed, blocked or failed outcomes stop nonzero before any commit or
subsequent workflow phase, even if Codex exits 0 or leaves partial edits. The
implementation progress line shows failure for those attempts. No prose parsing
or green process exit substitutes for an explicit completed outcome. On complete,
the script also requires a final response and repository changes. It prints the final response between the
progress line and the changed-file list, then commits and pushes the changes as
`Implement code <slug>`. Temporary output stays outside the repository
and is removed on exit after retaining the observation receipt.

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

# Durable preparation — S003 (not delivery automation)

From **any working directory**, use the script's actual repository path:

```shell
perl scripts/workflow-run.pl start 004-workflow-review-merge --worktree /new/path --local
perl scripts/workflow-run.pl start 004-workflow-review-merge --worktree /new/path --remote origin
perl scripts/workflow-run.pl status --run r-0123456789abcdef0123456789abcdef
perl scripts/workflow-run.pl preflight --run r-0123456789abcdef0123456789abcdef
perl scripts/workflow-run.pl resume --run r-0123456789abcdef0123456789abcdef
```

The example S004 change must first be authored and its prerequisites verified;
these commands do not select pending work or author documents. Exactly one of
`--local`/`--remote NAME` is required. Git, Perl (core JSON::PP, IO::Handle,
Digest::SHA, Fcntl), Bash and Python 3 are required. The supported host must provide
POSIX flock, fork/process groups, atomic rename and file/directory fsync.
Local mode explicitly selects local `refs/heads/dev` and records remote freshness
**not checked**. Remote mode uses configured authentication noninteractively and
an explicit `+refs/heads/dev:refs/remotes/NAME/dev` fetch, even in restricted clones.
It preserves local dev. Authentication/fetch failure never falls back to cached
refs/local mode. Diagnostics suppress raw child output and credential-bearing URLs.
Resume binds the effective remote URL by a private digest, never the URL itself;
changed remote configuration blocks before fetching.
No release branches are initialized; no remote refs are written.

Start requires a clean caller checkout (including hidden untracked files and
dirty submodules), a unique exact PLAN/change identity, absent change branch/run
and nonexistent destination with a real existing parent. It never resets,
stashes, switches, stages, commits, pushes, invokes Codex or dispatches a legacy
flow. It creates only `change/<slug>` and its isolated worktree. Non-forcing
checks repeat after refresh. Symlink/traversal destinations are rejected.

## Prerequisite evidence representation (schema 1)

For consumers with dependencies, an operator supplies the reviewed, scoped
`agent/progress/prerequisites/<consumer-slug>.json` in the caller repository.
It is an input, not a producer's review receipt or a gate inferred from prose.
It must contain `schema: 1`, `consumer`, and a `dependencies` object keyed by
**every direct and transitive dependency slug**. Each value contains:

- `integration`: the unique full commit with exact subject
  `Implement change <dependency-slug>`, reachable from the selected baseline.
- `sources`: nonempty mapping of consumer-required repository-relative source
  paths to SHA-256 of their exact Git blob bytes at the selected baseline.
- `checks`: nonempty array of scoped observations: `scope`, full tested
  `revision`, `result: "passed"`, numeric `exit: 0`, relative `artifact` and its
  `sha256`. Each tested revision must exist and contain the same required source
  bytes. The artifact must be readable and match its digest.

The operator must choose the sources, commands/results and scope from the
consuming contract, including concrete tool/device gates when applicable.
The runner verifies identity, integration, contents and reported results; it
cannot certify arbitrary assertions or that a manually supplied artifact is
truthful. Unknown/failed/missing evidence blocks with owner/action. This format
does not implement publisher exceptions: unmet prerequisites require actual
evidence or a separately authorized contract amendment. Deferred phone/account
obligations assigned to later consumers are not invented as current gates.
Historical review receipts/handoffs are not required. No prerequisite record is
fabricated by start. Diagnostic observations in `mch-workflow-evidence/` remain
immutable and separate; their review labels are not readiness authority.

## Runtime, projection and recovery contract (schema 1)

Private authoritative runtime: common Git directory
`codex-workflow-runs/<run-id>/state.json`; per-change stable OS lock:
`codex-workflow-locks/<slug>.lock`. Run IDs are `r-` followed by 32 lowercase
hexadecimal characters. Runtime directories/files use private permissions.
Linked worktrees share identity and locks. Lock PID/host/time are diagnostics,
not leases. Never delete a lock to steal ownership. A supervisor holds inherited
ownership until active Git children exit, even after parent death. Plan dispatch
locks and future S004 target merge locks are separate domains.
Each prepared worktree's Git administration directory also retains a private
`codex-workflow-owner.json` binding run/repository/branch/intent/path. A changed
or missing established owner blocks. Only an explicit resume of initial creation
intent may finish a missing marker after verifying the exact Git outcome.

State retains identity/configuration, full original baseline/source/target/intent
commits, generation, UTC timestamps, phase/previous_phase/phase_result, blockers
(reason/owner/next action), prerequisites, observations, artifacts and projection
metadata. Supported phases: `preparing`, `prepared`, `blocked`, `interrupted`.
Checks/reviews start empty, merge null, implementation/review/merge/requirement
gates `unmet`, `run_complete: false`. Supported extension fields are retained;
unsupported schema/later evidence/phase, duplicate keys or corrupt JSON fail
closed. Original baseline/configuration/identity cannot change on replacement.
Generation comparison prevents stale replacement. Same-directory temporary
write, checked full write/flush/fsync, atomic rename and directory fsync establish
durability, including synchronization of newly created parent directories.
Post-rename failure requires rereading disk; rollback is not assumed.

Portable projection: prepared worktree
`agent/progress/runs/<run-id>.json`. Runtime holds SHA-256 of its exact bytes and
the matching generation. Projection holds sanitized identity/commits, local-only
worktree marker, mode/freshness and unmet gates, never raw logs, host paths,
remote URLs or secrets. Runtime reserves the snapshot before publication; a
crash between them is explicitly unreconciled, not prepared success. Pending
publication has its own generation/digest; `prepared`/`passed` is persisted only
after the portable bytes are durable. Only exact
run-owned projection bytes (current digest or retained prior publication digest)
are permitted bookkeeping dirt. A tampered or unrelated progress file blocks
and is never overwritten. Nothing is automatically staged. Legacy
`codex-plan-runs/*.tsv`, plan lock, raw output and observation receipts are
preserved, not imported as passing gates.

`status` is read-only: no fetch, repair or file/ref mutation; it reports an
active owner, cached Git observations and pending reconciliation. A valid blocked
inspection may return 0; that is not approval. `preflight` locks, rechecks
prerequisites and refreshes the configured target, recording observations without
creating missing Git setup. `resume` additionally reconciles recorded intent:
create once if no Git effect exists, or verify the owned branch/path/HEAD and
finish publication after interruption. It never resets a baseline or restarts
later phases. Changed source commits (even equal trees), changed target,
missing/moved worktrees, configuration conflicts or ambiguous partial Git
results block for operator/S004 reconciliation. Missing/corrupt runtime or legacy
TSV alone cannot authorize resume. Inspect and preserve user work before any
manual repair; never delete/reset a branch/worktree merely to retry start.

JSON output separates `phase_result` from `run_complete: false`, naming run,
slug, phase, baseline/source/target, blockers, next action and runtime/portable
paths. Exit 0 means only the named phase/read passed; usage errors return 2,
other failures 1, SIGINT 130, SIGTERM 143 after stopping active child work and
best-effort interruption bookkeeping. SIGKILL can leave durable `preparing` or
an unreconciled projection; explicitly resume, do not infer completion.

## Bootstrap audit and S004 handoff

S003 is preparation only; GW remains unmet until S004 proves the execution loop.
Use **manual bootstrap** per agent/IMPLEMENT.md: verify baseline/dependencies,
implement/check, separate full-diff review with durable finding dispositions,
fix/recheck/re-review, then revalidate exact final source/target and serialize a
direct squash into dev. The implementing skill does not commit/push/merge.

Existing branch-create/create-change helpers switch the caller checkout and may
initialize/publish release branches: not used here. `codex-plan-run.sh` retains
queue TSV history and its outer plan lock, not a per-change gate ledger.
`codex-flow-run.sh`, implementation/review launchers and Release.pm remain legacy
helpers, not certified unattended IMPLEMENT delivery. S004 must wire this state
and lock contract into bounded check/review/fix/retry/integration/merge recovery,
safe staging and portable/PLAN publication. Progress.pm remains terminal-only;
CodexSession.pm remains session extraction. No helper is deleted or silently
relabeled conformant. Source/target drift invalidation cannot be bypassed by
legacy success artifacts. Preparation tests do not prove app, SQLite, device,
accuracy, publication or release gates.

Independent deterministic checks (temporary Git repositories/local remotes,
no live model or production remote):

```shell
perl scripts/test-unit-workflow-run-state.pl
perl scripts/test-workflow-run-state.pl
make workflow-test
```
