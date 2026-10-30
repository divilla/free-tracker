# SNNN — <Title>

> Copy to `agent/changes/<slug>.md`, using capture group 1 from the current branch matched against `^change/([0-9][0-9][0-9]+-[a-z0-9-_]+)$`. Keep the captured slug unchanged, including its numeric prefix. Replace placeholders; retain stable IDs. Finalize against current code and completed dependencies, not hypothetical implementations. Mark inapplicable sections with a reason.

| Metadata | Value |
| --- | --- |
| Change ID | `SNNN` (number matches slug prefix) |
| Slug / branch | `<slug>` / `change/<slug>` |
| Status / baseline | `<planned / ready / implementing / verifying / reviewing / merge-ready / merged / blocked>` / `<dev commit>` |
| Dependencies | `<change IDs, required gate/evidence links>` |
| Blocking decisions | `<Dxx: owner, resolution/evidence or blocker>` |
| Sources | `<PRD PR-xx/sections; PLAN Cxx; ARCHITECTURE sections; IMPLEMENT>` |

## 1. Brief

<Problem, intended outcome, and why this increment is needed. Distinguish confirmed behavior from decisions this change must resolve.>

## 2. Scope

- **In:** <bounded behavior and affected features/layers>
- **Out:** <explicit non-goals>
- **Integration:** <owner, existing components to wire/replace, next consumer>
- **Risks/prerequisites:** <uncertainties, resources, and evidence needed>

## 3. Requirements

Write observable, independently verifiable requirements, including acceptance behavior and unavailable/degraded states.

| ID | Source | Required behavior / acceptance outcome |
| --- | --- | --- |
| SNNN-R01 | PR-xx; Cxx | <Given … when … then …> |

## 4. Contracts

- **Reference architecture:** <actual S001 code files/patterns extended; justified deviations and ARCHITECTURE updates; for S001, define the executable reference template>
- **Ownership/boundaries:** <responsible feature/layer, dependencies, single recording owner where applicable>
- **Interfaces:** <commands/events/APIs; inputs, outputs, validation, errors, invariants>
- **Time/state:** <transitions, ordering, timestamps, interval boundaries, idempotence/concurrency>
- **Persistence:** <schema/migrations, atomicity, checkpoints/replay, durable vs provisional state>
- **Configuration/compatibility:** <defaults, units, versioning/snapshots, existing-data compatibility>

## 5. Failure paths and recovery

| Requirement | Trigger / failure point | Observable result and preserved state | Recovery / retry / cleanup |
| --- | --- | --- | --- |
| SNNN-R01 | <denial, unavailable input, write failure, interruption, etc.> | <honest status; no false success or lost committed data> | <next action, idempotence and resource release> |

## 6. Test cases and traceability

Expand each independently failing condition into a case, including normal, boundary, invalid-input, and failure/recovery paths. Name concrete tests/assertions—not only directories. Every requirement and case needs an identifiable unit test; user-facing scenarios also need E2E tests.

| Case ID | Requirement(s) / Cxx | Fixture, action, expected assertions | Unit test (`file :: name`) | Additional test / evidence |
| --- | --- | --- | --- | --- |
| SNNN-T01 | SNNN-R01; Cxx | <controlled inputs/clock/fault; action; exact expected result> | `<path> :: <test name>` | <named E2E / real SQLite / platform-device / field test> |

For documentation/infrastructure-only work, explain check applicability. Separate executable requirements from external evidence obligations: test validators/logic, but never present mocks or checklists as device/field proof.

## 7. Verification and completion gates

| Check | Exact command / procedure | Expected nonempty suite or evidence | Result / artifact |
| --- | --- | --- | --- |
| Unit + coverage | `make unit-test` | Application/domain/data tests; 100% handwritten application/domain/measurement line coverage; branch coverage separately where supported | <pending> |
| Real SQLite | <command, including how unit workflow invokes it> | Applicable mappings, transactions, rollback, recovery and migrations | <pending / justified N/A> |
| Android E2E | `make end-to-end-test` | Mapped user-facing success/failure/recovery cases; configured emulator/device | <pending / justified N/A> |
| Other | <analysis/build/device/field/document validation command or procedure> | <required assertions, environment/devices and evidence> | <pending / justified N/A> |

Record revision, command/exit status, environment/tool versions, coverage and artifact locations. Missing required tooling/devices, test failure or unexpectedly empty suites must fail; unavailable commands are not passes. Document narrow coverage exceptions with reasons; generated-code exclusions still require serialization/persistence/migration tests.

- [ ] **Ready:** dependencies/evidence checked, blocking decisions resolved, contracts and cases reviewed against current baseline.
- [ ] **Implemented:** scoped behavior integrated; every requirement/case mapped to actual tests; docs/migrations updated.
- [ ] **Verified:** applicable checks pass; required database/device/field evidence exists; no weakened assertions or skipped required tests.
- [ ] **Reviewed:** separate full-diff review completed; actionable findings fixed, checks rerun and fixes re-reviewed per IMPLEMENT.
- [ ] **Integrated:** latest `dev` incorporated; checks/review bound to exact final source and target commits; squash merge verified and recorded per IMPLEMENT.
- [ ] **Recorded:** PLAN/progress and affected decisions/contracts updated; remaining external validation obligations and next consumer identified. Merged is not automatically product-validated.
