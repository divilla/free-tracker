# S003 — Enforce requirement and test-case coverage

| Metadata | Value |
| --- | --- |
| Change ID | `S003` |
| Slug / intended branch | `003-test-traceability` / `change/003-test-traceability` |
| Observed checkout | `old-change/003-workflow-run-state`; HEAD `236fb09241ba1dfc2c5da5269bfb524d27cff676`; local `dev` `f9f8273b4ed76f00285dcd9b586b534c904d6bda`; no branch switch, reset or remote refresh |
| Status | Test-only implementation in place; verification unfinished because the Android emulator crashes |
| Dependencies | Existing S000 layout, S001 app/test runners and S002 setup checker/tests |
| Sources | Publisher instruction; [AGENTS](../../AGENTS.md), [PLAN](../PLAN.md), [ARCHITECTURE](../ARCHITECTURE.md) §9, [IMPLEMENT](../IMPLEMENT.md) §4 |

## 1. Brief and scope

Every change requirement must have **at least one unit test**. Every specified
test case must have **at least one distinct end-to-end test**. Tests must assert
the required behavior, not just exist or execute. Keep unit coverage of case
rows as already required by AGENTS.

This replaces the former S003 workflow-run-state scope. Remove its preparation
CLI, durable state/projections, locks, resume/recovery implementation, diagnostic
receipts and their tests/evidence. Do not implement branch setup, workflow
execution, review/merge automation or app features in this change.

Only test-policy documentation, traceability checks/runners and the missing or
incorrectly mapped tests are in scope. Preserve existing application behavior,
coverage thresholds, unrelated files and historical S001/S002 evidence.

## 2. Requirements

| ID | Required behavior |
| --- | --- |
| S003-R01 | Every requirement has an identifiable unit-test mapping, directly through its associated case rows. `make unit-test` requires at least one of those unit tests to actually pass; missing requirements, mappings, files or executed identities fail. Keep case-row unit coverage too. |
| S003-R02 | Every case row has at least one distinct E2E test with its case ID in the name and an exact repository-relative `file :: test name` mapping. `make end-to-end-test` requires that test to actually pass. Android covers app behavior; real host-command tests cover tooling. Missing, wrong or shared mappings fail. |
| S003-R03 | Backfill and check all implemented changes, including this change, through the existing stable Make targets. Run all configured nonempty suites, preserve failure/skip/coverage enforcement, and report mapped requirement/case IDs and executed test identities. Future authored changes need valid mappings but do not require unimplemented suites to run. Test scope is an implementation inventory, not delivery status. |

## 3. Contracts

- [Test scope](../../tool/test_scope.json) lists implemented change slugs.
- Requirement and case IDs come from the change documents' tables. Case rows
  reference requirements and concrete unit/E2E files and names; abbreviated
  requirement references resolve within that change. Unknown/duplicate IDs and
  requirements without unit mappings are errors.
- [Contract checker](../../tool/check_case_contract.py) is a read-only command
  auditing mappings, not evidence that tests passed.
- [Make runners](../../Makefile) use actual successful test results, including
  file identity. Merely matching an ID substring, another file's test or a stale
  report cannot satisfy coverage. Failures, skips and empty suites remain errors.
- Reports under `build/test-results/change-unit/` and `change-e2e/` contain
  requirement and case mappings plus actual executed identities. Existing app
  reports and 100% handwritten application/domain line coverage remain in force.
- No database, app API, lifecycle, sensor, map or production storage behavior
  changes. Existing Android suites still run; future SQLite/device/field gates
  are neither implemented nor certified here.

## 4. Test cases and traceability

| Case ID | Requirement(s) | Fixture, action, expected assertions | Unit test (`file :: name`) | E2E test (`file :: name`) |
| --- | --- | --- | --- | --- |
| S003-T01 | S003-R01/R02/R03 | Complete fixture and repository contracts: audit mappings and successful identities; all requirements and cases are accounted for; audit leaves source unchanged | `tool/tests/test_case_contract.py :: test_S003_T01_complete_mappings` | `end_to_end/test_case_contract.py :: test_S003_T01_e2e` |
| S003-T02 | S003-R01 | Add an unmapped requirement or unknown requirement reference; validation fails with the offending ID, without writes | `tool/tests/test_case_contract.py :: test_S003_T02_unmapped_requirement` | `end_to_end/test_case_contract.py :: test_S003_T02_e2e` |
| S003-T03 | S003-R01 | Remove unit column/file or supply wrong/unexecuted unit identity; reject missing mapping/execution rather than inferring coverage | `tool/tests/test_case_contract.py :: test_S003_T03_unit_mapping_and_execution` | `end_to_end/test_case_contract.py :: test_S003_T03_e2e` |
| S003-T04 | S003-R02 | Remove E2E column/file, omit case ID or supply wrong/unexecuted E2E identity; reject instead of accepting unit/manual evidence | `tool/tests/test_case_contract.py :: test_S003_T04_e2e_mapping_and_execution` | `end_to_end/test_case_contract.py :: test_S003_T04_e2e` |
| S003-T05 | S003-R02 | Duplicate a case or map two cases to the same E2E test; reject duplicates/shared coverage | `tool/tests/test_case_contract.py :: test_S003_T05_distinct_cases` | `end_to_end/test_case_contract.py :: test_S003_T05_e2e` |
| S003-T06 | S003-R03 | Validate future authored mappings without requiring future files/execution; invalid/duplicate/empty or absent implemented scope fails | `tool/tests/test_case_contract.py :: test_S003_T06_implemented_scope` | `end_to_end/test_case_contract.py :: test_S003_T06_e2e` |
| S003-T07 | S003-R01/R02/R03 | Run real Make targets/runner with controlled child reports: valid mappings pass, wrong or missing unit/E2E execution, empty suite and child failure return nonzero; unit evidence cannot replace E2E | `tool/tests/test_case_contract.py :: test_S003_T07_exact_report_identities` | `end_to_end/test_case_contract.py :: test_S003_T07_e2e` |

Unit fixtures exercise policy decisions; E2E fixtures enter through public
commands. Controlled SDK/report adapters test runner failure policy only. Actual
app behavior is separately exercised by the retained Android suites, including
S001's distinct per-case scenarios and production metadata smoke test.

## 5. Verification

Required commands:

```sh
python3 tool/check_case_contract.py
make unit-test
make end-to-end-test ANDROID_DEVICE_ID=emulator-5554
git diff --check
```

Completion requires both full Make suites to pass, with no missing requirement
unit coverage or case E2E coverage. No review, merge, push or product/device
validation is implied by local test success. The former workflow-state evidence does not apply to this scope.

### Current verification — 2026-10-31 UTC

Observed on the HEAD/branch above plus this uncommitted replacement. No branch,
commit, merge, push or remote refresh was performed.

| Check | Actual result |
| --- | --- |
| `python3 tool/check_case_contract.py` | Pass: 21 requirements and 59 case rows across S000–S003; mappings are an audit, not executed E2E evidence |
| `make unit-test` (approved host execution) | Exit 0: 79 Python tooling, 32 core Dart and 53 Flutter tests; retained helper/session unit suites also pass. All 21 requirements and 59 case rows have executed unit mappings |
| Dart coverage | 103/103 handwritten executable lines, 100%; branch records unavailable, not claimed as 100% |
| Host E2E and retained workflow regressions inside `make end-to-end-test` | All 43 host E2E tests and retained regression suites pass |
| Standalone Android per-case suite | Exit 0: all 17 `S001_Txx_e2e` scenarios, including repository-error recovery; this does not replace the full Make gate |
| `make end-to-end-test ANDROID_DEVICE_ID=emulator-5554` | **Unfinished / failed (exit 2).** The configured `Free_Tracker_API_37` emulator repeatedly segfaults in graphics rendering, disappearing between Flutter launches; later attempts fail device discovery or ADB boot checks |
| `git diff --check` | Pass |

Sandbox SDK-cache/socket failures were retried with approved host access. For
Android, the existing AVD was tried with its normal host renderer, Vulkan
disabled, automatic software rendering and direct SwiftShader. A temporary
`/tmp/s003-sdk-bin/flutter` adapter additionally tried fresh renderer processes
between suites while forwarding all tests to real Flutter; that full Make run
also failed on the next AVD boot/ADB check. No test/assertion was skipped or
weakened. No emulator-management code or saved AVD setting change is included in
the project.

Reports: `build/test-results/unit/summary.json`,
`build/test-results/change-unit/summary.json` and the failed
`build/test-results/change-e2e/summary.json`. Temporary logs include
`/tmp/s003-unit-test-final.txt`, `/tmp/s003-e2e-test-final.txt` and
`/tmp/s003-android-cases.txt`; the table retains the results if logs disappear.
The full E2E gate remains unmet. Next action: restore a stable configured
Android emulator/device, then rerun the complete Make target. This is an external
host/device validation blocker, not completion or an infrastructure exemption.
