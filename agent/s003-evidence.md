# S003 — Local bootstrap implementation evidence

> **Current completion policy (2026-10-31):** This record preserves dated evidence. Current implementation/findings-fix completion requires both complete Make suites to pass and a distinct executed E2E test for every implemented change-case row; see [IMPLEMENT §4](IMPLEMENT.md#4-verification-and-completion-gates). Historical N/A/not-run results below are not exemptions.

Recorded 2026-10-30 UTC for [003-workflow-run-state](changes/003-workflow-run-state.md).
This is implementation/check evidence, **not** a review, merge, GW pass, or
product/device validation record. No commit, push, merge or real preparation run
was performed by this implementation skill.

## Identity and readiness

- Branch: `change/003-workflow-run-state` (explicitly resumed, never switched).
- HEAD: `4ee7a554d56aae1352537dd231ecdb885c56372e` plus this implementation diff.
- Local dev: `f9f8273b4ed76f00285dcd9b586b534c904d6bda`, unchanged.
- `git ls-remote origin refs/heads/dev` exited 0 on approved host execution and
  returned that exact dev commit. Initial sandbox execution exited 128 on system
  SSH configuration permissions. No remote ref was written or stale fallback used.
- Exactly one PLAN S003 row matches the complete slug/path/identity and C00 scope.
  Direct S002 integration has the exact subject `Implement change 002-setup-decisions`
  at dev above; its parent is transitive S001
  `cb54712a73847cd2d1f2d6bf5437782c975317d4`, exact subject
  `Implement change 001-build-scaffold`.
- Inspected the actual S001 composition/domain/loader/port/adapter, tests and
  genuine Make runners; S002 setup records, source checker and F01/F02 regression
  protections are present. Fresh scaffold/Python/app-unit checks below verify the
  consumed source contracts. Historical review receipts/handoff prose were not
  re-audited or used as dependency gates.
- Host/tool access (D02's applicable portion) was rechecked: Git 2.56.0,
  Perl v5.42.3, Python 3.14.8, Bash 5.3.0, with core JSON/file-sync/flock/fork
  support. App suites used the existing pinned Flutter/Dart setup. No new package
  or app dependency was introduced. Phone/account/field facts remain assigned to
  their later consumers, not certified by these tests.

## Implemented boundary and traceability

[CLI](../scripts/workflow-run.pl), [shared module](../scripts/lib/mch/WorkflowRun.pm)
and [usage/schema/audit](../scripts/README.md#durable-preparation--s003-not-delivery-automation)
implement start/status/preflight/resume only. No model/check/commit/review/merge
execution path is introduced. Existing helpers and immutable diagnostic receipts
are preserved; state holds content-bound diagnostic references, not inferred gates.

Schema 1 keeps authoritative runtime state/locks in common Git metadata and a
sanitized portable projection under `agent/progress/runs/`. Pending publication
is durable before portable replacement; prepared success is saved only after
the projection is durable. Exact generation/digests reconcile interruptions.
The earlier implementation bound the run owner through destination administration metadata; that mechanism is removed by the publisher's single-checkout correction. OS locks survive parent
death while a supervised Git child can still mutate; the supervisor drains output
after launcher death instead of exposing Git to a broken output pipe. Source or
target drift, changed configuration/evidence, unknown ownership and unrelated
dirty data block without resetting, staging or deleting user work.

Both suites use [shared fixtures/cases](../scripts/test-lib/RunStateTest.pm):

- [Unit suite](../scripts/test-unit-workflow-run-state.pl): `U :: S003_T01` through
  `U :: S003_T40`, exact authored names, 40 subtests / 413 assertions.
- [Real-Git suite](../scripts/test-workflow-run-state.pl): `G :: S003_T01` through
  `G :: S003_T40`, 40 subtests / 428 assertions, including subprocess CLI calls,
  temporary repositories, local bare remotes, actual permission failures and OS locks.
- Every S003-R01–R10/case mapping remains in the selected change. Tests exercise
  invalid/duplicate/absent inputs, scoped source/revision/result prerequisites,
  failed refresh, dirty/submodule preservation, nonforcing setup races, atomic
  write failures, post-rename reread, generation guards, exact projection dirt,
  stale/tampered publication, ownership, repeat resume, source/equal-tree/target
  drift, changed remote/evidence configuration, missing/moved/wrong-owner
  checkouts and read-only inspection. Real SIGINT/SIGTERM and SIGKILL include
  intent/Git/projection boundaries and active Git children, using FIFO barriers
  rather than timing-only sleeps. Required cases have no skips/TODOs. Recording
  command fixtures verify that preparation cannot dispatch later phases.

## Executed checks

All successful commands below returned **0**. Temporary logs are replaceable;
this tracked record retains the results and integrity identifiers.

| Command | Result / scope |
| --- | --- |
| `perl scripts/test-unit-workflow-run-state.pl` | Final module/owner-marker/publication implementation: 40/40 named cases, 413 assertions; `s003-unit-release.tap` SHA-256 `5305c6057a3a917581804181100db73317ffa679006f8796d31be6e556a60695` |
| `perl scripts/test-workflow-run-state.pl` | Final implementation: 40/40 named cases, 428 assertions; `s003-git-release.tap` SHA-256 `aa5a68a591ea12c4d8f26c9a688380d503c0e8fc4e9d480e0933b7461c6186af` |
| `make workflow-test` | Approved host run passed new suites and all existing evidence, implementation/review unit/real-Git, flow, merge/recovery, promotion, release initialization, auth, branch-creation and plan-dispatch regressions. Final S003 suites above were rerun after the final owner-marker/document-validator/clock-injection additions; unchanged legacy helpers were not modified. Host log `s003-workflow-host.log` SHA-256 `3938687ea6311e2e1dfdbaa19fa4f3117aacad5195529974c1819d68610a9f4b` |
| Legacy dirty-checkout suite (now `perl scripts/test-clean-checkout.pl`) | Existing 775 assertions passed; the legacy dirty-checkout log SHA-256 `cb2f00442182ee589c87f5aebabcfbfacddd526b1fc59dbba21efba6ed79c647` |
| `python3 tool/check_scaffold.py` | Existing S001/S002 architecture/setup contract valid |
| `python3 -m unittest discover -s tool/tests -v` | All 71 tests passed; `s003-python.log` SHA-256 `241eabb9858af88ab601c239505a4b9f333d5634e78c21699d19e0cd11461167` |
| `make unit-test` | Approved host run: 71 Python, 32 core Dart, 53 Flutter tests; handwritten Dart line coverage **103/103 (100%)**; branch coverage unavailable from the reporter. Source inventory SHA-256 `e6a21bdc34bdf8eff9b6c95d2b375d29ba6324e380045ac433b7aea2424283c6`; `build/test-results/unit/summary.json`, `coverage/lcov.info`; temporary host log SHA-256 `6e2d0acdf32b2b051d2dcc6ee63c51bf589d9cabf7906b770ba52950d4d76051` |
| `perl -c scripts/workflow-run.pl`; `perl -c scripts/test-unit-workflow-run-state.pl`; `perl -c scripts/test-workflow-run-state.pl` | All parse without warnings; imports also parse the shared module/fixtures |
| `git diff --check`; new-file whitespace/local-link/traceability audit | Passed; no generated app files or protected reference slice changed |

The initial sandbox `make unit-test` failed (exit 2) because the Flutter SDK
cache is read-only; the approved host retry passed. The initial sandbox
`make workflow-test` passed S003 and intervening regressions, then failed
(exit 2) when the existing authentication test could not bind its isolated
SSH-agent socket; the approved host retry passed. Neither sandbox failure was
relabeled as a pass. All fixture network/ref writes address disposable local
remotes; no real Codex, user remote mutation, key loading or release operation
was performed.

Final tooling content identity: sorted tracked plus nonignored untracked files
under `scripts/`, plus root Makefile; hash each filename, NUL, exact bytes, NUL.
SHA-256: `151597af19303ab8eb689c282c2c3f31fced07d3641ca8a628d5e9b7d4708d0c`.
This excludes this evidence document/PLAN/log, avoiding self-referential hashes.
The skill-prescribed implementation-log path classification counts `scripts/test-*`
files as code (they are not under a `test`/`tests` directory or named `*.test.*`);
the actual infrastructure test counts are reported above.
Infrastructure Perl line/branch coverage is **unmeasured**, not claimed 100%;
the mapped boundary/error/process tests do not grant an app coverage exception.

## Remaining gates and S004 handoff

S003's bounded implementation and applicable local checks are complete. Separate
full-diff review/fixes, commits, final integration checks and direct squash into
dev belong to the caller's bootstrap delivery workflow and are not claimed here.
GW remains unmet until S004 integrates/proves bounded check/review/fix/retry,
safe staging, final source/target evidence, integration and serialized merge
recovery using this schema/lock/publication contract.

No app/UI/SQLite/platform behavior changed. `make end-to-end-test`, real SQLite,
device/sensor/background, field/accuracy and release checks were **not run** and
are N/A to this infrastructure-only change, not passed or waived for their actual
consumers. No production prerequisite manifest/run/projection or delivery gate
was fabricated. The README defines the manifest representation; a future
consumer must supply truthful scoped source/check evidence before preparation.

## Per-case E2E policy update — 2026-10-31 local

Verified at **2026-10-30 23:21 UTC** (2026-10-31 Europe/Zagreb), on branch
`change/003-workflow-run-state`, HEAD
`16b8de1845c1de479ed90191740adfa20e3c00e1` plus the uncommitted policy/test changes;
local `dev` remained `f9f8273b4ed76f00285dcd9b586b534c904d6bda`. No remote
refresh, commit, push or merge was performed. The older infrastructure-only
E2E N/A observation above is historical, not the current completion policy.

Every implemented case row now has a distinct executable E2E mapping. The
implemented test inventory is S000–S003: **93 cases** (1 + 31 + 20 + 41).
Authoring future rows names convertible tests but does not activate unimplemented
code. This inventory is test configuration, not a delivery-status ledger.

| Command | Observed result and scope |
| --- | --- |
| `make unit-test` | Exit 0; 73 Python tooling, 32 pure-core and 53 Flutter tests; workflow unit suites and helper units also passed; executed unit names cover all 93 case rows |
| `make end-to-end-test ANDROID_DEVICE_ID=emulator-5554` | Exit 0; 77 host public-command/system E2E tests, 27 Android tests (legacy E01–E10/P01 plus 16 distinct Txx scenarios), and the complete retained workflow regression target; executed E2E file/name pairs cover all 93 rows |
| `flutter analyze` | Exit 0; no issues |
| `python3 tool/check_case_contract.py` | Exit 0; 93 unique named case mappings, distinct E2E names and existing implemented test files; this audit alone is not execution proof |
| `python3 tool/check_scaffold.py`; three edited skills' `quick_validate.py`; `git diff --check` | All exit 0 |

Handwritten Dart coverage remains **103/103 lines (100%)**. Branch coverage is
unavailable, not 100%. The unit and Android summaries have the same app/test/tool
source SHA-256:
`611f176bc34642f2c6dc330211012d91647f3760b8bead678959aee1620c7670`.
The broader 133-file source/test/contract inventory SHA-256 is
`24322d43b351566daad6e0b0055d41356585bdd581267f6b4c79f3a94e6ba4d2`:
sorted tracked plus nonignored untracked files under `.agents/skills/mch-*`,
`agent/changes/`, `agent/templates/`, `lib/`, `android/`, `test/`,
`integration_test/`, `end_to_end/`, `tool/`, `scripts/`, plus root AGENTS/Makefile,
PRD/ARCHITECTURE/PLAN/IMPLEMENT and app configuration files; hash filename, NUL,
exact bytes, NUL per file. Evidence records themselves are excluded.

New host E2E tests use actual subprocesses, real temporary Git repositories,
files and locks, with controlled SDK-boundary responses only for runner-policy
cases. They do not relabel unit calls as E2E or claim real app success from
fake SDK reports. The Android suite runs the app/feature scenarios on the
existing API 37 x86_64 emulator, including real metadata reads and expanded
localization at narrow width/200% text scaling. No physical sensing, background,
field accuracy, SQLite, maps or release validation is claimed.

Initial fixture failures (missing fake-SDK Git executable, a table-separator
mutation and a schema mutation that did not alter the fixture) and the outdated
two-Android-suite assertion were repaired without weakening production checks.
The final complete gates passed. Sandbox Flutter-cache/ADB access was denied;
approved host access was used, and the existing emulator was started. Local
replaceable reports are `build/test-results/{unit,e2e,change-unit,change-e2e}/`;
full command logs are `/tmp/free-tracker-per-case-unit-complete.txt`,
`/tmp/free-tracker-per-case-e2e-final.txt` and
`/tmp/free-tracker-per-case-analyze.txt`. This section retains the portable
summary if those local artifacts disappear.
