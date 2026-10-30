# Project instructions

## Architecture and requirements

- Follow the architecture specified in [agent/ARCHITECTURE.md](agent/ARCHITECTURE.md).
- Product requirements are defined in [agent/PRD.md](agent/PRD.md); implementation changes live in `agent/changes/<slug>.md`, where `<slug>` includes its number, starting with `agent/changes/001-build-scaffold.md`.

## Change-authoring baseline policy

- For documentation-only change authoring, including `$mch-change-write`, there is standing authorization to use the observed local Git baseline without requesting confirmation on every change. Record the exact current branch, `HEAD` and local `dev` commits; do not switch/reset branches or assume they are identical.
- Inspect current code and dependency evidence. When Git and repository evidence explain an older PLAN baseline or stale aggregate status, reconcile only the directly affected baseline/reference wording automatically, preserving dated historical evidence. Such explainable drift is not an unresolved contradiction requiring a question. This policy takes precedence over the skill's blanket clarification rule for these cases.
- Failed/unavailable tests, unchecked remote freshness and unverified review/merge/device/release gates may remain explicitly unmet in an authored document when the code/contracts needed to specify its scope are available. Record their evidence, owner and blocking implementation/validation gate; do not repeatedly ask permission merely to carry those obligations forward. Authoring does not require refreshing a remote or rerunning app suites solely to obtain approval to write documentation; unexecuted checks remain unexecuted, never passing.
- Stop and ask when evidence cannot resolve a material authoring decision: invalid/ambiguous branch or PLAN identity, conflicting scope, divergent records without an evidential explanation, or missing dependency code/contracts/device findings necessary to define the change accurately. Never invent those contracts or promote predecessor documents/source presence into completed dependency evidence.
- This authorization applies only to authoring and necessary PLAN/reference bookkeeping. It does not waive implementation readiness, testing, review, merge or product-validation gates, or authorize implementation, commits, merges, pushes or external actions.

## Testing requirements

- Maintain unit tests for the application, domain/measurement, and data layers. Test observable behavior, boundary conditions, and failure paths—not merely that code executes.
- Require 100% line coverage by default for handwritten application and domain/measurement logic. Any exception must be narrow and explicitly documented with its reason. Exercise decision branches and report branch coverage separately where tooling supports it; line coverage is not branch coverage or proof of correctness.
- Exclude generated code from coverage thresholds, but verify its behavior through serialization, persistence, and migration tests. Treat manually maintained generated code as handwritten code.
- Test data-layer mappings, repository behavior, and error handling. Also use real SQLite integration tests for transactions, recovery, and migrations; mocks alone do not establish storage correctness.
- Every requirement in `agent/changes/001-build-scaffold.md` and subsequent changes must have at least one identifiable unit test. Every test case specified in those documents must also have at least one unit test. Reference stable requirement/test-case IDs in test names or a traceability mapping; add IDs if absent.
- Maintain end-to-end tests covering every implemented user-facing functionality and its specified acceptance scenarios, including failure/recovery behavior. Map these tests to the relevant requirements. Unit tests do not replace end-to-end coverage, and end-to-end tests do not replace the required unit tests.
- Cover tour start/pause/resume/end, automatic pause, outdoor/indoor measurement, calibration, history/details, units/preferences, permissions/capabilities, map availability, persistence, and interrupted-tour recovery as implemented.
- Use controlled sensor inputs for deterministic app tests and separate platform/device tests for real adapters, notifications, background recording, and lifecycle behavior. Keep physical-device and field validation for accuracy, step sensing, and screen-off reliability; simulated tests are not substitutes.
- Add or update tests with every behavior change. A requirement is not complete until its tests exist and pass. Do not weaken assertions, exclude handwritten logic, or silently skip required tests to satisfy a coverage target.

## Test commands

- Provide and maintain a root `Makefile` exposing these stable commands:
  - `make unit-test`: run application, domain, and data unit tests and enforce the coverage policy.
  - `make end-to-end-test`: run the end-to-end suite against the configured Android emulator/device.
- Document and automate real-database integration checks as part of the test workflow; passing only mocked unit tests is insufficient.
- Both Makefile targets must return nonzero on test failure. Missing required tooling/devices or an unexpectedly empty suite must be reported as a failure, not a passing placeholder.
- Run the applicable checks before declaring work complete; report commands, results, and any checks that could not run. Until the app and test infrastructure exist, report these commands as unavailable rather than claiming they pass.
