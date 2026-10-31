# S003 — Durable workflow preparation and run-state recovery

> **Current test policy (2026-10-31):** Every case row below requires its own named E2E test in addition to unit coverage. Both `make unit-test` and `make end-to-end-test` must run and pass before implementation or findings fixes are finished. Host CLI/system E2E covers tooling cases; Android E2E covers app cases. Historical N/A/not-run results remain historical, not current completion exemptions. See [IMPLEMENT](../IMPLEMENT.md) and [test scope](../../tool/test_scope.json).

> **Publisher correction (2026-10-31):** Factory execution uses one existing checkout. Preparation creates/selects its change branch there; no additional checkout, destination option or destination-owner record is supported. The updated Txx scenarios below supersede the earlier isolation contract. Dated verification remains historical until the updated suites pass.

**Current local implementation:** bounded preparation/state/locking/resume code and mapped tests are implemented and locally verified; see [S003 bootstrap evidence](../s003-evidence.md) for exact revisions, commands, content identity and limitations. Separate review/integration and S004/GW remain unfulfilled. The earlier bootstrap-only repair below is historical, not the current implementation boundary.

> **Applied bootstrap correction (not full S003 completion):** The publisher
> requested removal of predecessor review-history/handoff gates during this
> branch. Baseline: branch `change/003-workflow-run-state`, HEAD
> `ebc6c5dfaf7e43d07c0a9fac8a0ca8107f3322e7`, local `dev`
> `f9f8273b4ed76f00285dcd9b586b534c904d6bda`; no baseline switch or remote
> mutation. The legacy helpers now retain diagnostic observations and reject
> blocked implementation outcomes. This focused repair does not implement the
> preparation/locking/resume/projection requirements below or pass GW.

| Bootstrap repair ID | Behavior | Identifiable unit tests | Real-Git workflow checks |
| --- | --- | --- | --- |
| WF-EVIDENCE-R01 | Git integration and required contents determine downstream readiness; no predecessor review-receipt, caller-confirmation or handoff gate | `scripts/test-workflow-evidence.pl`: `WF-EVIDENCE-R01` subtests (missing records, integration without review records, stale handoff) | `scripts/test-codex-flow-run.sh`: `WF-EVIDENCE-R01` next complete workflow with archived predecessor receipts and unchanged historical note |
| WF-EVIDENCE-R02 | Preserve immutable commit-bound observations privately across cleanup, squash and branch switches | `scripts/test-workflow-evidence.pl`: `WF-EVIDENCE-R02` subtests | `scripts/test-codex-flow-run.sh`: `WF-EVIDENCE-R02` retained code review mapped to verified squash |
| WF-EVIDENCE-R03 | Explicit implementation outcome; zero-exit blocked/invalid model result cannot commit or continue | `scripts/test-workflow-evidence.pl`: `WF-EVIDENCE-R03` outcome validation | `scripts/test-codex-code-implement.sh`: blocked partial edit and missing outcome retain HEAD, return nonzero, no green completion |
| WF-EVIDENCE-R04 | Malformed, partial, failed or stale diagnostic observations cannot fabricate passing results; review diagnostics never undo integration | `scripts/test-workflow-evidence.pl`: both `WF-EVIDENCE-R04` subtests | `make workflow-test`: existing review/merge failure and direct merge recovery regressions |

Bootstrap validation: `make workflow-test`, `make unit-test`, skill frontmatter
validation and `git diff --check`. App E2E/device/SQLite checks are N/A for this
repair: no app/UI/storage/platform behavior changes. Retain their existing gates;
these tooling tests cannot substitute for them. Application/domain coverage policy
is unchanged; Perl infrastructure uses mapped observable/error/real-Git tests,
without claiming unmeasured Perl branch/line coverage. The observation contract
is documented in IMPLEMENT §5 and scripts/README; no additional handoff is used.

**Bootstrap repair verification, 2026-10-30 22:35 UTC:** At the HEAD/dev commits
above plus this uncommitted repair, `make workflow-test` exited 0 on the host
(unit, real temporary-Git workflow, review/fix, merge/recovery, promotion,
release initialization, authentication, branch creation and plan-run checks).
After the final diagnostic-error handling update, `perl
scripts/test-workflow-evidence.pl` passed all 9 named subtests and `bash
scripts/test-codex-flow-run.sh` passed again, including the next-change regression.
`make unit-test` exited 0 on the host: 71 Python, 32 core and 53 Flutter tests;
Dart line coverage 103/103, branch coverage unavailable. Final
`python3 tool/check_scaffold.py`, all 71 `tool/tests` tests, both edited skills'
`quick_validate.py` checks, and `git diff --check` passed. The sorted
`scripts/`, both edited skill directories and root Makefile inventory (filename,
NUL, bytes, NUL per file; tracked plus nonignored untracked) has SHA-256
`e7dd103ade864a0cad88bf913527d3c4e2d9f4a432999b198dc50b9f497d7e23`.
The app runner's separate source SHA-256 is
`59962427670026d8393c02845b7b3bebf0a1f9daec4b3dc3cd71aa3196dd50d3`.
Initial sandbox runs failed at the read-only Flutter SDK cache and prohibited
isolated SSH-agent socket respectively; approved host retries passed. No real
remote was refreshed/mutated, no app E2E/device/SQLite run is claimed, and nothing
was committed/pushed. Local replaceable logs are
`/tmp/free-tracker-cleaner-workflow-tests-host.txt`,
`/tmp/free-tracker-cleaner-unit-tests-host.txt`,
`/tmp/free-tracker-cleaner-evidence-tests.txt` and
`/tmp/free-tracker-cleaner-flow-tests.txt`; this paragraph retains the summary.

| Metadata | Value |
| --- | --- |
| Change ID | `S003` |
| Slug / branch | `003-workflow-run-state` / `change/003-workflow-run-state` |
| Status / baseline | `planned` / local `dev` and branch HEAD `f9f8273b4ed76f00285dcd9b586b534c904d6bda` at authoring; remote freshness not checked |
| Dependencies | S002 setup/tooling source at that baseline; [setup handoff](../setup-decisions.md), including its final F01/F02 limitations; transitive S001 [reference scaffold](../reference-scaffold.md) and [historical evidence](../s001-evidence.md) |
| Blocking decisions | No unresolved authoring decision. The publisher explicitly answered **yes** to authoring against current local `dev`, with S002's unresolved full-unit, remote-freshness and delivery gates retained as unmet. This is not permission to waive implementation gates. D02 host/tool access must be rechecked before implementation verification; phones/accounts and D03–D12 remain assigned to their existing consumers. |
| Sources | [PLAN](../PLAN.md) S003/S004 inventory, C00, GW, §§2/7/8; [IMPLEMENT](../IMPLEMENT.md) §§2–5; [AGENTS](../../AGENTS.md); [template](../templates/change-template.md); [ARCHITECTURE](../ARCHITECTURE.md) §§1/3/4/9; [PRD](../PRD.md) §§3/4/12/13 (infrastructure supports delivery, implements no new PR-xx behavior); [existing helper contracts](../../scripts/README.md) |

## 1. Brief

Provide a script-owned, durable and fail-closed **preparation** boundary for one planned change: validate identity/prerequisites, select an exact baseline, create and select the change branch in the existing checkout without overwriting user work, serialize ownership and reconcile interrupted preparation. Successful preparation is not successful implementation, review, merge or product validation. S004 consumes this boundary and owns the later execution loop.

The clean authoring baseline contains S001 app/tests and S002 setup/checker/tests. S002 reports earlier passing checks, followed by F01/F02 tooling passes but failed full `make unit-test` at the read-only Flutter SDK cache and failed remote verification. Those scoped historical results remain historical; verify current applicable prerequisites rather than treating a dated failure as permanent. Git integration does not prove required behavior; inspect actual source/contracts/tests. Review/fix enforcement belongs to each change's own delivery workflow, not to subsequent changes. S003 must not re-audit S001/S002 review history or require their historical receipts/caller confirmation. See [PLAN's bootstrap reconciliation](../PLAN.md#progress-ledger) and IMPLEMENT §2. An old handoff's delivery status is not a second gate. Concrete required source/test/tool evidence still must be verified. No GW/device/release completion is implied.

### Existing automation audit and reuse boundary

These observations are source inspection, not newly passing behavioral evidence:

| Existing component | Observed baseline behavior | S003 disposition / S004 handoff |
| --- | --- | --- |
| `scripts/create-change-branch.sh`, `scripts/branch-create.sh` | Clean-tree check, numbered slug, fetch and existing-branch rejection; release initializer can create/publish release branches; current checkout is switched | Reuse validation/Git invocation patterns where suitable; preparation must not call publishing initialization; it selects the new branch in the existing checkout. Keep intentional legacy helpers; document the single-checkout path rather than deleting them. |
| `scripts/codex-plan-run.sh` | Validates inventory; holds Git-directory `codex-plan-run.lock`; writes per-invocation TSV under checkout Git metadata `codex-plan-runs/`; stops on child failure | Preserve queue/TSV history and the plan-level lock. TSV is dispatch history, not an authoritative per-change gate/resume record. Add the run-state foundation without claiming that this existing sequencer enforces dependencies or GW. |
| `scripts/codex-flow-run.sh` | Always creates a branch, authors/reviews/implements/reviews/merges through legacy children | Cannot serve as preparation/resume: S003's preparation path must not dispatch it. S004 owns wiring a proven end-to-end consumer; existing flow remains explicitly unverified for unattended IMPLEMENT delivery. |
| `scripts/codex-code-implement.pl`, `scripts/codex-review-loop.pl` | Temporary output cleanup, broad `git add -A`, automatic commit/push; review pins a base but has no shared durable run ledger | S003 neither calls nor certifies them. S004 owns retained review evidence, staged-path gates, bounded retries and evidence-bound commits/review. |
| `scripts/lib/mch/Release.pm`, `scripts/merge-to-dev.pl` | Existing release helpers can publish refs and rewrite/publish the feature squash | Do not invoke from preparation. S004 owns direct squash into `dev`, merge serialization and bookkeeping recovery required by IMPLEMENT. |
| `scripts/lib/mch/Progress.pm`, `scripts/lib/mch/CodexSession.pm` | Terminal progress/session extraction, not durable workflow state | Preserve these responsibilities; do not mistake the name `Progress.pm` for a gate ledger or add workflow state to it. |
| `scripts/test-lib/ReleaseTest.pm`, `scripts/test-lib/WorkflowTest.pm`, `scripts/test-clean-checkout.pl`, `scripts/test-create-change-branch.sh`, `scripts/test-codex-plan-run.sh` | Temporary Git repositories, local remotes, recording/failing tools, dirty-tree and concurrency fixtures already exist | Extend suitable fixtures and retain legacy regression coverage; new S003 cases must assert state/ref/index preservation and recovery, not only command execution. |

The IMPLEMENT heading saying automation is not implemented is a historical adoption statement, not evidence that these helpers are absent. S003 implementation may reconcile that heading to **present but not GW-validated**, without advancing delivery gates. No such reference edit is performed by authoring this change.

## 2. Scope

- **In:** bounded preparation/status/resume CLI; explicit baseline configuration and prerequisite checks; exact PLAN/change identity; durable versioned per-change records and safe portable snapshots; in-place branch creation and selection; exclusive mutation locking for the existing checkout; interruption/fault reconciliation; usage/bootstrap documentation and mapped infrastructure tests.
- **Out:** model invocation, authoring automation, implementation dispatch, check execution/commit/review/fix loops, retry policy for those loops, actual integration/conflict resolution, squash/push/PR creation, promotion, cleanup of user branches/checkouts, app/UI/measurement/storage changes and GW completion. S004 owns those execution behaviors; S005 owns extending real SQLite/app test foundations.
- **Integration:** S003 owns the preparation entry point and shared state/lock primitives under `scripts/`, plus runtime/portable record consistency. Reuse Perl and existing Git fixture conventions; introduce only the preparation entry point/shared primitives missing from the inspected helpers. S004 is the next consumer and must reuse the identity, baseline, evidence invalidation and ownership contract rather than create a second competing ledger. Its target-wide merge lock is separate from S003's checkout mutation lock.
- **Risks/prerequisites:** Branch switching in the existing checkout; interruption between Git and file writes; stale remote refs; record files themselves making a checkout dirty; lock lifetime; malformed/unsupported or legacy artifacts; host/tool permissions. Required local tools are Git, Perl with core JSON/file/locking support, Bash for existing regression suites and Python 3 for existing tooling checks. No Codex, network account or Android device is required to test this preparation boundary with local remotes. Production remote access still needs the configured authentication and successful refresh.

## 3. Requirements

All requirements derive from **C00**, not a new product feature. Every success/failure case in §6 has a named unit test; real temporary-Git tests supplement them.

| ID | Source | Required behavior / acceptance outcome |
| --- | --- | --- |
| S003-R01 | PLAN §§2/4; IMPLEMENT §2; C00 | Accept only a valid complete numbered slug with exactly one consistent PLAN inventory row, matching ID/path and readable selected change/governing inputs. Reject malformed/missing/duplicate/conflicting input before Git mutation or child workflow dispatch. Never select the first pending change or a legacy spec alias. |
| S003-R02 | IMPLEMENT §§3/5; PLAN §7; C00 | Expose documented preparation, inspection, preflight and explicit resume operations from any working directory. Validate configuration/tool availability and dependency evidence before setup; unknown/unmet prerequisites block with a reason/owner/next action, not inferred completion from documents or commits. |
| S003-R03 | IMPLEMENT §3.1; C00 | Capture exact full baseline/source commits and refresh outcome under explicit remote or local mode. Failed refresh, missing `dev` or an unresolvable commit cannot silently fall back to stale refs; preparation cannot publish/init release branches. Preserve local `dev` when remote mode selects a different fetched tip. |
| S003-R04 | IMPLEMENT §§3.2/5; C00 | Fresh preparation creates and selects `change/<slug>` at the selected baseline in the existing checkout. The index remains unstaged and unrelated ignored files are preserved. Dirty tracked/staged/untracked/deleted/submodule input, an existing branch/run and creation races fail without reset, stash, forced checkout, deletion, staging or adoption. No destination argument or additional checkout is supported. |
| S003-R05 | IMPLEMENT §5; PLAN §8; C00 | Persist versioned machine-readable identity/configuration, baseline/source, phase, blockers/next action, evidence containers and merge placeholder with atomic replacement and durable preparation intent. Report write/corruption/version errors nonzero; never infer completion from absent or partial state. |
| S003-R06 | IMPLEMENT §5; PLAN §7; C00 | Reconcile Git-metadata artifacts with portable machine-readable `agent/progress/` records. Preserve legacy TSV/logs; raw output/secrets are never automatically staged. A missing/stale portable projection cannot claim a gate or override runtime state; projection failure prevents prepared success. |
| S003-R07 | IMPLEMENT §5; C00 | Enforce one mutating owner for the existing checkout, regardless of change slug, with an OS-backed repository lock. Contention fails before refresh/Git mutation. Lock metadata/PID/age is diagnostic only; no age-based stealing, lock-file deletion or child escape permits concurrent writers. The checkout mutation lock is separate from the outer plan-dispatch lock and future merge lock. |
| S003-R08 | IMPLEMENT §§3/5; C00 | Resume only an explicitly identified durable run after locking and comparing recorded identity, checkout, refs, source, configuration and refreshed target with actual Git. Reconcile partial setup idempotently; drift blocks/invalidate evidence as appropriate without overwriting user work, resetting baselines or rerunning later phases. |
| S003-R09 | IMPLEMENT §§4/5; C00 | SIGINT/SIGTERM, hard termination and storage/Git failures retain recoverable intent and last durable state. Successful preparation is recorded only after Git verification and portable publication. Failures return nonzero; a subsequent resume can reconcile without duplicate branch creation and selection. |
| S003-R10 | IMPLEMENT §§4/5; PLAN §§7/8; C00 | Report structured phase versus entire-run outcome, tested/observed revision and artifact locations. Preparation leaves checks/reviews/merge/product validation unfulfilled. Document manual bootstrap and actual legacy limitations; no hidden push, Codex call or unattended continuation is reachable from S003 commands. |
| S003-R11 | Publisher test policy; AGENTS; IMPLEMENT §4 | Every implemented case row has unit coverage and a distinct real-boundary E2E test executed by the stable Make targets; missing/empty/skipped/failed coverage blocks completion. |

## 4. Contracts

### Reference architecture and integration ownership

This is repository tooling, not an application feature. Leave S001's `lib/app/composition.dart`, `lib/settings/application/app_info_loader.dart`, `lib/settings/domain/app_info.dart` and `lib/settings/data/platform_app_info_repository.dart` unchanged. No Flutter/SQLite/sensor dependency is introduced into plain-Dart rules; the app's single recording owner is unaffected. Shared workflow primitives belong under `scripts/lib/mch/`, separate from terminal-only `Progress.pm`. Extend existing temporary Git fixture helpers where suitable; never run tests against the user's remote or real Codex.

S003 implementation documents the audit/dispositions above in `scripts/README.md`, including exact commands, prerequisites, artifact locations, local-versus-remote behavior, status/exit semantics, unsupported legacy resume and safe recovery. Necessary PLAN/IMPLEMENT reference reconciliation must preserve their gates. Do not remove/relocate maintained helpers. Existing legacy entry points are not silently relabeled as conformant; S004 must integrate later phases before unattended use.

### Preparation CLI

The following implemented preparation-only interface is the S004 handoff; see [usage and schema details](../../scripts/README.md#durable-preparation--s003-not-delivery-automation):

```text
perl scripts/workflow-run.pl start <slug> --remote <name>
perl scripts/workflow-run.pl start <slug> --local
perl scripts/workflow-run.pl status --run <run-id>
perl scripts/workflow-run.pl preflight --run <run-id>
perl scripts/workflow-run.pl resume --run <run-id>
```

Resolve the repository from the script location/Git directory, not the caller's working directory; persist a canonical repository identity. Exactly one of `--remote <name>` and `--local` is required on start. Local mode explicitly uses `refs/heads/dev`, records remote freshness **not checked**, and is not a workaround for a failed configured remote refresh. Remote mode validates the named configured remote, authenticates without copying credentials into records and fetches `refs/heads/dev` using an explicit refspec (including restricted-fetch clones). Select the refreshed commit, record observation/command/exit, then resolve it as a commit. No automatic `dev`/`stage`/`master` initialization or remote writes. Remote URL credentials must not appear in diagnostics or portable records; persist the remote name, not a credential-bearing URL.

The branch regex is `^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$`; the captured numbered slug is unchanged. Match the complete slug, numeric ID and `agent/changes/<slug>.md` resolved from the PLAN row. Start requires the authored readable selected change, unlike the legacy flow's author-before-implementation behavior. Missing/unreadable governing files, duplicate/mismatched inventory rows or unresolved authoring placeholders block. Dependencies come from the matched row and their transitive prerequisites. Verify the consuming contract's required source/evidence, not only ledger labels: require a scoped evidence reference, revision/content identity and result for executable prerequisites, or a recorded explicit publisher exception limited to the consuming gate. Unverified physical/account facts assigned to later changes remain visible, not falsely required for unrelated preparation. In particular, the S003 authoring exception above is not general implementation readiness.

Start checks complete checkout status (including hidden untracked files and dirty submodules regardless of user Git ignore-status configuration) before authentication/remote access. Branch/run identity must be absent and target refs resolvable. Recheck after refresh under the checkout mutation lock. Create and select the branch with ordinary non-forcing `git checkout --no-overwrite-ignore -b` at the recorded baseline. The caller's selected branch intentionally changes; no separate destination is created. Preserve unrelated ignored files and never stage them. An existing local or remote-tracking change branch or runtime record requires explicit resume/manual reconciliation, not fresh start. Never infer legacy-run completion or manufacture its record.

`status` is read-only and prints validated recorded state plus available Git observations, identifying an active writer and any pending reconciliation; it does not refresh, repair or acquire a mutating gate. A valid inspection may exit 0 even when reporting a blocked phase; its output must say `run_complete: false`. Malformed/missing state fails nonzero. `preflight` rechecks prerequisites/configuration/refs under the mutation lock and records observations without launching later phases. `resume` performs the same checks and reconciles only preparation. Neither restarts implementation/review/merge. Unsupported later phases report that S004's consumer is required, never a prepared/merged success.

Mutating phase commands return 0 only for their successfully completed named phase; invalid usage returns 2, other unmet gates/failures return nonzero (1 by default). SIGINT/SIGTERM return 130/143 after stopping active child work and best-effort durable interruption recording. JSON output includes run ID, slug, phase, phase result, `run_complete: false`, baseline/source, blockers, next action and runtime/portable paths; diagnostics go to stderr. A successful status/read is never approval to advance a workflow gate.

### State, paths and compatibility

**Reconciliation decision grounded in the audit:** preserve `codex-plan-runs/*.tsv` and `codex-plan-run.lock` in their existing Git-metadata locations. They remain plan-dispatch artifacts. Operational per-change state must also survive branch switches and cannot live only in an untracked branch-dependent file. Use the canonical `git rev-parse --absolute-git-dir` directory for private runtime records/locks; publish a sanitized machine-readable snapshot under `agent/progress/` to satisfy PLAN §8. This is one authoritative runtime record plus a portable projection, not two independently advancing gate ledgers.

| Record | Planned location / contract |
| --- | --- |
| Runtime record | Git directory: `codex-workflow-runs/<run-id>/state.json`; private permissions; authoritative for local preparation/resume |
| Owned evidence | Same run directory, outside automatic staging; record artifact relative paths/integrity identifiers, not raw payloads in PLAN |
| Checkout mutation lock | Git directory: `codex-workflow-locks/checkout.lock`; stable lock inode, nonblocking exclusive OS lock; owner diagnostic contains run ID/host/process |
| Portable projection | Prepared checkout: `agent/progress/runs/<run-id>.json`; safe versioned snapshot with runtime generation and content identity; no absolute host paths, raw command output, remote URL or secrets |
| Existing plan dispatch | Existing per-checkout Git `codex-plan-runs/` TSV and common `codex-plan-run.lock`; never imported as a clean check/review/merge |

Use an opaque unique run ID restricted to safe filename characters; reject traversal/separators, unsafe symlink artifact paths and paths escaping owned directories. New record creation is exclusive. Canonical repository/Git-directory and checkout identities are runtime-only; portable checkout location is a relative reference or explicitly local/unavailable marker, not a fabricated relocatable path. Only the exact run-owned projection is expected bookkeeping dirt; it is not permission to ignore all of `agent/progress/`. Unrelated pre-existing files there remain protected. S003 never stages or commits even its own projection; S004 owns explicit safe selection and final portable/PLAN publication. A new start may therefore leave the prepared checkout with that one uncommitted bookkeeping file, which status/preflight recognize by exact path/content/generation.

Schema version **1** requires these semantic fields (representation details must be documented/tested in implementation, not left to agent prose):

- Run ID, change ID, exact slug/branch/change path, repository/checkout identity, schema version and monotonically increasing record generation.
- Configuration snapshot: explicit local/remote mode, remote name when applicable, target `dev`, existing checkout and effective prerequisite/evidence references; identity/configuration cannot silently change on resume.
- Original baseline, observed latest target, observed source HEAD, initial caller branch/source and preparation-intent commit, all full object IDs validated in the actual repository. Original baseline is immutable; observed target/source changes do not rewrite history.
- Current phase, previous/resume phase, phase result, blockers with reason/owner/next action, UTC observation/update timestamps and next action. Sequence/generation orders transitions; wall-clock timestamps are not lock leases or evidence freshness guarantees.
- Check and review containers initially empty; merge commit initially null; implementation/review/merge/requirement-validation gates unset/unmet and entire-run completion false. S004 defines the later evidence-entry/findings schemas and phase transitions before producing them. Preserve supported extension fields; reject unsupported schema versions/phase transitions without dropping data or accepting approval.
- Artifact references and projection generation/content digest; references are not proof the referenced evidence passed. The runtime record stores SHA-256 of the exact published projection bytes. The projection carries run ID, generation and sanitized source identity, not a reciprocal hash of the full runtime record; avoid self-referential hashes. Preserve previous committed state on failed writes and keep failure diagnostics outside the corrupt/partial target.

S003 phases are `preparing`, `prepared`, `blocked` and `interrupted`. Blocked/interrupted records retain the last durable phase and recovery action. Acquire the checkout mutation lock before creating/mutating a run or refreshing refs. Validate configuration/dirty inputs first where read-only validation is possible. Persist preparation intent **before** branch creation and selection; verify the resulting branch and HEAD in place; publish the portable snapshot atomically; only then acknowledge `prepared`. Do not label a run `merged`, product-validated or complete in S003. Do not allocate fictitious checks/review rounds.

Use same-directory temporary files, checked writes/flush, file synchronization, atomic rename and directory synchronization for durable replacements on the supported host filesystem. Fail explicitly if required durability cannot be established. Serialize writers under the Git-directory lock and compare generation before replacement so an obsolete read cannot overwrite a newer record. Keep the last committed valid record through pre-rename failure. Runtime/projection writes are not one filesystem transaction: record intent/generation and reconcile a crash between them; a stale/missing projection cannot authorize success. Update only owned records, never sanitize arbitrary user files in place.

### Ownership, resume and next consumer

Use the same OS lock for start/preflight/resume in the existing checkout; PID/age metadata alone is not ownership. Hold it through active Git children and durable writes; do not release while a surviving child could mutate the run. A contender returns nonzero without replacing the first owner's record. Do not unlink an active lock file or use timeout-based lock stealing. When the kernel releases a dead owner's lock, resume first reconciles actual Git, even if metadata still says active. Keep the existing outer plan lock separate so a future plan dispatcher can own it while a child owns its checkout mutation lock. S004 owns target-wide merge serialization and deadlock-free lock ordering before any merge is enabled.

Resume validates the existing checkout path and selected branch, original baseline, observed source, fresh target (in remote mode), clean/recognized bookkeeping and immutable configuration. If the selected change branch matches the recorded intent, finish bookkeeping in place. If branch creation did not happen, explicit resume may create/select it only while the original caller branch/source is unchanged and the change branch is still absent. A changed branch, conflicting existing branch, repository/configuration/path mismatch, ambiguous Git result or dirty unrelated files blocks without switching back, resetting, deleting or overwriting user work. No destination ownership marker exists.

A changed source or target is an observation requiring revalidation, not a new trusted baseline or continued approval. Preserve original baseline and prior evidence, mark any source/target-bound evidence unusable and block pending S004's integration/check/review handling. S003 cannot resolve conflicts or declare stale evidence fresh. Even when the observed tree contents match, a different bound commit is not silently accepted. A record containing merge evidence/later phases is not proof a new merge is needed: S003 never merges, and routes that recovery to S004. Missing/corrupt/unsupported state or legacy TSV alone requires explicit operator reconciliation, never `start` over an existing branch.

No app persistence, serialization, migration, tour-time, unit or sensor contract changes are introduced. JSON workflow persistence is tested with real filesystem/Git faults; it is not an SQLite implementation or a substitute for S005/S009 database tests.

## 5. Failure paths and recovery

| Requirement | Trigger / failure point | Observable result and preserved state | Recovery / retry / cleanup |
| --- | --- | --- | --- |
| S003-R01/R02 | Invalid inventory/change/input/tool or dependency evidence absent | Nonzero diagnostic names the failed prerequisite and next action; no workflow child or ref change | Correct prerequisite/evidence and explicitly retry; do not accept authoring or source presence as gate completion |
| S003-R03 | Authentication/fetch failure, missing target or invalid object | Failed observation recorded where a run exists; no stale-baseline success, branch creation or remote writes | Repair access/target; retry same mode. Changing to local mode is a new explicit configuration decision, not automatic recovery |
| S003-R04/R07 | Dirty input, occupied path/branch/run or concurrent owner | Rejection preserves file bytes/index/refs and existing artifacts; lock contention does not alter owner state | Use existing run resume or manually reconcile; commit/stash only by the operator, never the runner |
| S003-R05/R06 | Short write, permission/full-disk/sync/rename failure or bad schema | Nonzero, no prepared acknowledgement; previous valid generation/intent retained; portable output cannot override it | Restore storage/access and resume; a completed rename with later failure must be reread/reconciled rather than assumed rolled back |
| S003-R08 | Actual source/target/configuration/checkout differs | Blocked with old/new observations, original baseline retained and bound evidence unusable; no reset/rebase/merge | S004 handles changed-candidate integration/revalidation; unexpected paths/identity require operator reconciliation |
| S003-R09 | Signal or hard kill before/after intent, Git creation, runtime replacement or projection | No complete-run claim; signal path nonzero, hard-kill may leave last durable `preparing`; Git/file outcome preserved | Acquire released lock, inspect actual Git and generations, resume only missing preparation/bookkeeping; never delete user files or a partially created branch |
| S003-R10 | Later phase, legacy TSV success or prose claims completion | Unsupported/unmet gate stays visible; no tests/review/merge fabricated and no hidden model/push invocation | Manual bootstrap until S004/GW proves the complete workflow; preserve legacy evidence without promoting its status |

## 6. Test cases and traceability

All S003 cases below are now implemented and executed; see [current results](../s003-evidence.md). `U` means `scripts/test-unit-workflow-run-state.pl`; `G` means `scripts/test-workflow-run-state.pl`. Each `U :: name` is a concrete named Perl `Test::More` subtest; include requirement/case IDs in TAP output. Every row inherits **C00**. `G :: name` is an additional real temporary-Git behavioral subtest, not Android app E2E. Unit fixtures inject clocks, Git results and file faults; G uses actual repos/local bare remotes, paths with spaces, isolated Git config and recording/failing tool stubs. No production remote, real Codex/SSH key or user Git index is accessed. Test TAP plans must be nonempty, all required cases executed, no skipped/todo required cases and any failed assertion/child nonzero must fail the suite. Subvariants below require distinct assertions/diagnostics, not a single broad rejection assertion.

| Case ID | Requirement(s) | Fixture, action, expected assertions | Unit test (`file :: name`) | Additional test / evidence | E2E test (`file :: name`) |
| --- | --- | --- | --- | --- | --- |
| S003-T01 | R01 | Valid exact slug, including a four-digit prefix and underscore variant; one row resolves exact ID/branch/path without normalization | `U :: S003_T01_exact_identity` | `G :: S003_T01_exact_identity` | `end_to_end/test_workflow.py :: test_S003_T01_e2e` |
| S003-T02 | R01 | Invalid slug, detached/nonrepository context and conflicting actual resume branch independently reject; no dispatch/mutation | `U :: S003_T02_invalid_identity` | `G :: S003_T02_invalid_identity` | `end_to_end/test_workflow.py :: test_S003_T02_e2e` |
| S003-T03 | R01 | Missing/unreadable/empty PLAN, zero match, duplicate exact match and conflicting ID/path independently reject, no number-only fallback | `U :: S003_T03_inventory_fail_closed` | `G :: S003_T03_inventory_fail_closed` | `end_to_end/test_workflow.py :: test_S003_T03_e2e` |
| S003-T04 | R01/R02 | Missing/unreadable change/governing document and unresolved authoring placeholder each block with path; do not choose another pending row or legacy alias | `U :: S003_T04_readiness_inputs` | `G :: S003_T04_readiness_inputs` | `end_to_end/test_workflow.py :: test_S003_T04_e2e` |
| S003-T05 | R02/R10 | Independently omit local/remote mode, combine modes, pass duplicate/unknown options or malformed run IDs; usage exits 2 without Git mutation | `U :: S003_T05_configuration_validation` | `G :: S003_T05_configuration_validation` | `end_to_end/test_workflow.py :: test_S003_T05_e2e` |
| S003-T06 | R02 | Independently omit required tool, dependency record, scoped evidence, evidence revision/result or transitive prerequisite; nonzero with owner/action, no setup | `U :: S003_T06_missing_prerequisites` | `G :: S003_T06_missing_prerequisites`; manual dependency truth audit | `end_to_end/test_workflow.py :: test_S003_T06_e2e` |
| S003-T07 | R02 | Document/commit/ledger-only dependency does not prove required evidence; properly scoped external deferred obligation stays deferred, not invented or globally blocked | `U :: S003_T07_evidence_not_prose` | Manual S002/PLAN source/result scope comparison | `end_to_end/test_workflow.py :: test_S003_T07_e2e` |
| S003-T08 | R02/R03 | Valid explicit local mode selects full local `dev` SHA, marks remote unchecked; from root/subdirectory/outside caller CWD gives same identity | `U :: S003_T08_local_preflight` | `G :: S003_T08_local_preflight` | `end_to_end/test_workflow.py :: test_S003_T08_e2e` |
| S003-T09 | R03 | Local dev stale versus bare remote; successful explicit refspec fetch selects exact remote SHA, preserves local dev/caller checkout; restricted fetch config works | `U :: S003_T09_remote_baseline` | `G :: S003_T09_remote_baseline` | `end_to_end/test_workflow.py :: test_S003_T09_e2e` |
| S003-T10 | R03 | Authentication, fetch and observation failure independently retain failure status; stale cached ref cannot create branch or turn into local mode | `U :: S003_T10_failed_refresh` | `G :: S003_T10_failed_refresh` | `end_to_end/test_workflow.py :: test_S003_T10_e2e` |
| S003-T11 | R03 | Missing local/remote dev, nonexistent/noncommit object independently fail; no release initializer, push or release-ref creation | `U :: S003_T11_missing_baseline` | `G :: S003_T11_missing_baseline` | `end_to_end/test_workflow.py :: test_S003_T11_e2e` |
| S003-T12 | R04 | Fresh run creates/selects only the exact change branch in the existing checkout at recorded SHA; index unstaged, ignored file bytes and remote refs preserved; no additional checkout is created | `U :: S003_T12_current_checkout_setup` | `G :: S003_T12_current_checkout_setup` | `end_to_end/test_workflow.py :: test_S003_T12_e2e` |
| S003-T13 | R04 | Staged, unstaged, deleted, hidden-untracked and dirty-submodule variants each reject before auth/fetch; assert refs/index/status/file bytes unchanged | `U :: S003_T13_dirty_input_preserved` | `G :: S003_T13_dirty_input_preserved`; retain `scripts/test-clean-checkout.pl` regressions | `end_to_end/test_workflow.py :: test_S003_T13_e2e` |
| S003-T14 | R04 | Existing local or remote-tracking change branch or existing runtime record independently rejects fresh start; current branch, refs, index and file bytes preserved | `U :: S003_T14_existing_setup_rejected` | `G :: S003_T14_existing_setup_rejected` | `end_to_end/test_workflow.py :: test_S003_T14_e2e` |
| S003-T15 | R04/R07 | Branch appears or caller becomes dirty during refresh; recheck/nonforcing creation rejects and preserves concurrent branch/file bytes | `U :: S003_T15_setup_races` | `G :: S003_T15_setup_races` | `end_to_end/test_workflow.py :: test_S003_T15_e2e` |
| S003-T16 | R05/R10 | New intent/state round-trip retains required identity/configuration/full SHAs, generation, UTC/next action; checks/reviews empty, merge null, completion false | `U :: S003_T16_state_round_trip` | `G :: S003_T16_state_round_trip` | `end_to_end/test_workflow.py :: test_S003_T16_e2e` |
| S003-T17 | R05 | Missing/duplicate field, malformed/truncated JSON, unsupported schema, invalid transition or unsafe artifact path each reject without overwriting original bytes | `U :: S003_T17_invalid_state` | `G :: S003_T17_invalid_state` | `end_to_end/test_workflow.py :: test_S003_T17_e2e` |
| S003-T18 | R05 | Inject create/write/short-write/flush/file-sync/rename failure independently; last valid record readable, nonzero/no success; temp not treated as state | `U :: S003_T18_atomic_write_failures` | `G :: S003_T18_atomic_write_failures` with actual permission/write faults | `end_to_end/test_workflow.py :: test_S003_T18_e2e` |
| S003-T19 | R05/R09 | Directory sync fails after successful rename; report nonzero, reread actual valid generation on resume, never assume previous file remains or erase new intent | `U :: S003_T19_post_rename_failure` | `G :: S003_T19_post_rename_failure` with injected filesystem boundary | `end_to_end/test_workflow.py :: test_S003_T19_e2e` |
| S003-T20 | R05/R07 | Stale generation attempts replacement after another valid update; rejected, newer state/evidence unchanged | `U :: S003_T20_generation_guard` | `G :: S003_T20_generation_guard` | `end_to_end/test_workflow.py :: test_S003_T20_e2e` |
| S003-T21 | R06 | Runtime plus portable generation/digest agree; portable fields sanitized, no raw logs/absolute paths/credential-bearing URL, no staged files | `U :: S003_T21_portable_projection` | `G :: S003_T21_portable_projection` | `end_to_end/test_workflow.py :: test_S003_T21_e2e` |
| S003-T22 | R06/R09 | Projection absent, stale, tampered or write fails independently: no prepared acknowledgement; valid runtime survives; resume repairs only owned projection | `U :: S003_T22_projection_reconciliation` | `G :: S003_T22_projection_reconciliation` | `end_to_end/test_workflow.py :: test_S003_T22_e2e` |
| S003-T23 | R06/R10 | Legacy TSV/log success, unrelated ignored raw output and secret sentinel present; preserved, not imported as gates, not included in portable JSON/output/index | `U :: S003_T23_legacy_and_private_artifacts` | `G :: S003_T23_legacy_and_private_artifacts` | `end_to_end/test_workflow.py :: test_S003_T23_e2e` |
| S003-T24 | R04/R06/R08 | Exact owned projection accepted as expected bookkeeping only at matching generation/content; unrelated progress file/edit still blocks unchanged | `U :: S003_T24_precise_bookkeeping_dirt` | `G :: S003_T24_precise_bookkeeping_dirt` | `end_to_end/test_workflow.py :: test_S003_T24_e2e` |
| S003-T25 | R07 | Concurrent owners of the same checkout, including different change slugs: exactly one wins; loser nonzero before refresh/mutation, first owner diagnostics unchanged | `U :: S003_T25_single_owner` | `G :: S003_T25_single_owner` with real child processes/OS locks | `end_to_end/test_workflow.py :: test_S003_T25_e2e` |
| S003-T26 | R07 | Misleading PID/old timestamp cannot steal a live lock; owner death releases OS lock but stale diagnostic requires reconciliation; child still mutating retains exclusion | `U :: S003_T26_lock_lifetime` | `G :: S003_T26_lock_lifetime` using held child and process death | `end_to_end/test_workflow.py :: test_S003_T26_e2e` |
| S003-T27 | R07 | Existing outer plan lock does not self-deadlock preparation; the checkout mutation lock serializes all change slugs independently of the plan lock | `U :: S003_T27_lock_domains` | `G :: S003_T27_lock_domains`; Git ref races remain nonforcing | `end_to_end/test_workflow.py :: test_S003_T27_e2e` |
| S003-T28 | R08 | Resume prepared unchanged run twice: same run/branch/checkout/baseline, no duplicate creation or later dispatch; only valid observation bookkeeping may change | `U :: S003_T28_idempotent_resume` | `G :: S003_T28_idempotent_resume` | `end_to_end/test_workflow.py :: test_S003_T28_e2e` |
| S003-T29 | R08/R09 | Durable intent but no Git creation: resume performs exactly recorded creation once and completes projection, preserving original baseline/config | `U :: S003_T29_resume_before_creation` | `G :: S003_T29_resume_before_creation` | `end_to_end/test_workflow.py :: test_S003_T29_e2e` |
| S003-T30 | R08/R09 | Git created and selected the branch but state/projection update interrupted: resume verifies owned result and repairs bookkeeping, no duplicate branch or deletion | `U :: S003_T30_resume_after_creation` | `G :: S003_T30_resume_after_creation` | `end_to_end/test_workflow.py :: test_S003_T30_e2e` |
| S003-T31 | R08 | Changed source commit (also equal-tree commit variant) blocks; old/new SHAs recorded, original baseline/evidence preserved but unusable; no reset/approval reuse | `U :: S003_T31_source_drift` | `G :: S003_T31_source_drift` | `end_to_end/test_workflow.py :: test_S003_T31_e2e` |
| S003-T32 | R03/R08 | Advanced/replaced target after refresh blocks for S004 integration/revalidation; original baseline immutable, no merge/rebase or stale approval | `U :: S003_T32_target_drift` | `G :: S003_T32_target_drift` | `end_to_end/test_workflow.py :: test_S003_T32_e2e` |
| S003-T33 | R08 | Changed selected branch, checkout path, source, configuration or repository identity independently blocks; no automatic branch switching or adoption | `U :: S003_T33_resume_identity_conflicts` | `G :: S003_T33_resume_identity_conflicts` | `end_to_end/test_workflow.py :: test_S003_T33_e2e` |
| S003-T34 | R08/R10 | Missing runtime, legacy TSV only and unsupported later/merged phase independently cannot restart/merge; diagnostic directs explicit reconciliation/S004 | `U :: S003_T34_no_inferred_resume` | `G :: S003_T34_no_inferred_resume` | `end_to_end/test_workflow.py :: test_S003_T34_e2e` |
| S003-T35 | R09 | SIGINT/SIGTERM at intent/Git/projection boundaries: return 130/143, stop active children, retain last durable state and release only inactive ownership | `U :: S003_T35_signal_recovery` | `G :: S003_T35_signal_recovery` with real signals | `end_to_end/test_workflow.py :: test_S003_T35_e2e` |
| S003-T36 | R09 | SIGKILL before intent commit, after intent, after Git creation, and between state/projection replacement: durable outcome unambiguous or blocked, resume never duplicates | `U :: S003_T36_hard_kill_recovery` | `G :: S003_T36_hard_kill_recovery` with fault barriers, no timing-only sleeps | `end_to_end/test_workflow.py :: test_S003_T36_e2e` |
| S003-T37 | R09 | Real nonforcing Git branch-creation failure and unwritable runtime/projection directories: nonzero, user/Git results preserved, no destructive cleanup or conflicting-branch adoption | `U :: S003_T37_git_and_storage_failure` | `G :: S003_T37_git_and_storage_failure` | `end_to_end/test_workflow.py :: test_S003_T37_e2e` |
| S003-T38 | R02/R10 | Status read-only: file bytes/refs/network unchanged, reports dirty checkout, active owner and reconciliation honestly; valid read may exit 0, invalid record exits nonzero | `U :: S003_T38_status_is_inspection` | `G :: S003_T38_status_is_inspection` | `end_to_end/test_workflow.py :: test_S003_T38_e2e` |
| S003-T39 | R10 | Start/preflight/resume phase success stays completion false; failure nonzero with blocker/action; recording stubs prove no Codex/check/commit/push/merge/PR/flow dispatch | `U :: S003_T39_preparation_only` | `G :: S003_T39_preparation_only` | `end_to_end/test_workflow.py :: test_S003_T39_e2e` |
| S003-T40 | R02/R10 | README names every entry/config/path/exit and bootstrap limitation; missing required contract or false GW/merge claim fails documentation fixture validator | `U :: S003_T40_usage_and_bootstrap_contract` | Manual review of actual commands and source; text check cannot prove workflow conformance | `end_to_end/test_workflow.py :: test_S003_T40_e2e` |
| S003-T41 | R11 | Invoke the case-contract CLI on valid mappings and a fixture with a missing E2E column; valid input passes, invalid input fails without mutation; executed coverage rejects omitted or misidentified cases | `tool/tests/test_case_contract.py :: test_S003_T41_required_per_row_execution` | Runner failure/skip checks plus actual complete Make runs | `end_to_end/test_case_contract.py :: test_S003_T41_e2e` |

`Rnn` means `S003-Rnn`. Existing tests cited in §1 remain baseline/regression tests, not substitutes for these planned S003 tests. S004 owns the remaining **C00** scenarios: test/review failures, stable finding dispositions, limits/no progress, final integrated evidence, conflicts, serialized squash and interrupted/duplicate merge bookkeeping. S003 supplies source/target drift detection and never executes those future transitions.

**Applicability:** no app-visible functionality or SQLite/adapter/sensor/background behavior changes. New Android E2E, real SQLite, platform/device and field cases are N/A for S003, not passed or waived for S005 onward. Command-line integration is verified with real temporary Git/filesystem tests. Preserve existing application unit coverage and test runners; if an implementation expands into app behavior, stop for a scoped contract update with all required unit/E2E/database/device coverage.

## 7. Verification and completion gates

### Authored implementation-check obligations — current results linked

No command in this table was claimed executed by authoring. The table retains its authoring-time result column below; those historical `Pending` values are superseded for local implementation checks by [the executed S003 evidence](../s003-evidence.md), not by inferred delivery gates. The scripts/tests are now present. Both new Perl suites must report nonempty TAP with no required skips/todo, fail on assertion/child errors and collectively execute all mapped cases. Unit tests alone do not prove actual Git/locking/interruption behavior.

| Check | Exact command / procedure | Expected nonempty suite or evidence | Result / artifact |
| --- | --- | --- | --- |
| Readiness | `git symbolic-ref --quiet --short HEAD`; `git status --short`; `git rev-parse HEAD dev`; inspect S002 F01/F02 evidence and successfully refresh configured remote where applicable | Exact source/target/content identity; dependencies/tools revalidated; inherited failures not silently waived | Pending implementation; run record plus portable summary |
| S003 unit cases | `perl scripts/test-unit-workflow-run-state.pl` | All S003 T01–T40 named unit subtests, explicit boundary/failure assertions, nonempty successful TAP | Pending; retain exit/TAP digest and revision in bootstrap evidence |
| Real Git/recovery | `perl scripts/test-workflow-run-state.pl` | Named G cases above, actual temporary repositories/local remotes/OS locks/signals/filesystem recovery, no live model/remote writes | Pending; run evidence outside staging, sanitized portable summary |
| Existing preparation/dispatch regressions | `perl scripts/test-clean-checkout.pl`; `bash scripts/test-create-change-branch.sh`; `bash scripts/test-codex-plan-run.sh`; `bash scripts/test-codex-flow-run.sh` | Existing nonempty suites keep published legacy contracts; no helper deletion, unannounced behavior change or presumed GW conformance | Pending; exact commands/status/environment |
| Existing launch/review regressions | `perl scripts/test-unit-codex-code-implement.pl`; `perl scripts/test-unit-codex-review-loop.pl`; `bash scripts/test-codex-code-implement.sh`; `bash scripts/test-codex-review-loop.sh` | Controlled unit/integration suites retain behavior; no actual Codex | Pending; needed if shared modules/contracts affected, otherwise record source-based N/A for unaffected suites |
| Scaffold/setup contract | `python3 tool/check_scaffold.py`; `python3 -m unittest discover -s tool/tests -v` | Existing S001/S002/tooling checks remain nonempty/passing; no setup constraint weakened | Pending implementation recheck |
| Unit + coverage | `make unit-test` | Existing nonempty application/domain/data and Python suites; 100% handwritten application/domain/measurement line coverage, branches separately where supported | Pending; existing `build/test-results/unit/summary.json` and `coverage/lcov.info`; command may fail on host SDK access, never a pass |
| Syntax/documentation | `perl -c scripts/workflow-run.pl`; `perl -c scripts/test-unit-workflow-run-state.pl`; `perl -c scripts/test-workflow-run-state.pl`; `git diff --check` | New Perl sources parse; review state schema/CLI/audit/docs/unique IDs/local links and complete traceability | Pending implementation |
| Real SQLite | No new database command: workflow JSON/Git is not tour storage | N/A; S005/S009 still owe real transactions/recovery/migrations through stable unit workflow | N/A, not passed |
| End-to-end | `make end-to-end-test` with configured `ANDROID_DEVICE_ID` | All S003 T01–T41 distinct public-CLI/system E2E cases execute; retained Android and workflow regressions also pass; no empty/skipped/missing mappings | Required current gate; host tests do not certify Android/physical behavior |
| Platform/device/field | S006/S022 physical lifecycle; S008/S023 independent references | No new adapters/measurement/background behavior; those gates remain assigned and unmet without actual proof | N/A to S003, not passed |

Keep root Make targets genuine and nonzero on missing tools/devices, empty/failed suites or coverage failure. Do not route these infrastructure-only tests through an unrelated app/device prerequisite as their only executable path; the exact independent commands above remain available. Infrastructure logic has mapped normal/error/decision-path unit and real-Git checks; this does not grant any application/domain coverage exception. No new generated exclusion or line-coverage exception is authorized. Report branch coverage separately where supported, explicitly unavailable otherwise; never equate 100% line coverage with branch completeness or correctness.

Record command/procedure, exit status, exact revision plus dirty-content identity where relevant, environment/tool versions, UTC observation, case counts/coverage, artifact digest/location and limitations. Keep a portable sanitized bootstrap summary linked from PLAN; ignored/temporary logs alone are not lasting review evidence. New runtime/projection schema files are implementation outputs, **not created by change authoring**.

### Manual bootstrap and S004 handoff

Until S003–S004 jointly pass **GW**, do not trust the new prepared result or legacy flow as full delivery automation. Verify latest baseline/dependencies manually, preserve existing branch/user work, implement only the selected contract, run applicable commands and commit the validated implementation with S003 identity. Arrange a separate full-diff review against the recorded baseline; persist findings and dispositions, fix/recheck/commit each round, re-review, incorporate changed dev and revalidate/re-review the exact final candidate. Serialize and verify a direct squash into dev, then record Git-confirmed merge/bookkeeping without duplicate merge. Missing prerequisites/failed checks remain unmet, not overridden by a clean review or agent prose. These are future execution obligations, not actions taken by authoring.

S004 consumes schema version, immutable original baseline, observed source/target, generation, artifact/projection rules, checkout mutation lock, preflight/resume outcomes and preparation-only exit semantics. It supplies real check/review/commit/retry/integration/merge transitions, target merge lock ordering, durable detailed review schemas and safe staging/publication. S003 cannot check GW merely because its foundation passes. No machine-readable run/progress state or execution status is fabricated in this document.

### Authoring verification record

Authoring uses the publisher-approved local baseline above; only this document and directly necessary PLAN baseline/authoring bookkeeping change. Checks executed on 2026-10-30 at approximately 22:10 UTC in the workspace sandbox with Python 3.14.8. None constitute S003 implementation evidence.

| Authoring check | Observed result |
| --- | --- |
| `git symbolic-ref --quiet --short HEAD`; `git status --short`; `git rev-parse HEAD dev` | Exit 0; exact selected branch and local source/dev commit above; initially clean tree. Remote freshness not rechecked or claimed. |
| `python3 tool/check_scaffold.py` | Exit 0; existing S001/S002 scaffold/setup contract valid. |
| `python3 -m unittest discover -s tool/tests -p test_scaffold_contract.py -v` | Exit 0; 37 existing scaffold/setup contract tests passed, no skips. Does not execute the 40 planned S003 cases or establish a new full-app coverage result. |
| Inline Python saved-document audit | Exact branch/one inventory row/metadata; seven sections; 10 unique requirements and 40 unique cases with named unit tests covering every requirement; existing local links; no checked execution gates, trailing whitespace or unresolved authoring placeholders. CLI/path metavariables are intentional contract notation. An initial overbroad placeholder check rejected that notation; the audit was corrected to distinguish it from unfilled template metadata. |
| Source/template/scope review; `git diff --check` | Source audit and S003/S004 ownership checked against current helpers, governing documents and template; whitespace check exit 0. Saved document and selected PLAN authoring entry rechecked after bookkeeping. |
| `make unit-test`; `make end-to-end-test`; planned S003 unit/real-Git suites; database/device/field/release checks | Not run for Markdown-only authoring. Existing Make commands are present, not unavailable placeholders or newly passing checks; future S003 suites do not yet exist. Implementation applicability and inherited failed/unverified gates remain as above. |

- [x] **Ready (local bootstrap):** exact dependency integration/source contracts, configured remote dev and applicable host/tool access rechecked; approved host unit/workflow retries passed. See the current evidence; no authoring exception waived a gate.
- [x] **Implemented:** bounded preparation/resume/state/lock behavior and docs integrated; all planned named cases exist.
- [x] **Verified:** applicable unit/real-Git/regression/app coverage checks pass with genuine evidence and no skipped required cases.
- [ ] **Reviewed:** separate full-diff review, findings fixes/rechecks/commits and re-review completed per IMPLEMENT.
- [ ] **Integrated:** exact final source/target checks/review and direct serialized squash into dev verified and recorded.
- [x] **Recorded:** genuine implementation progress/evidence linked; S004 handoff and remaining GW/device/database/release obligations explicit. Authoring satisfied none of these execution gates. Checked implementation/verification entries now refer only to the linked local bootstrap evidence; separate review/integration and machine-owned delivery gates remain unset.
