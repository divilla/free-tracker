# free-tracker — Scripted implementation workflow

**Status:** Execution contract adopted; automation scripts are not yet implemented.

## 1. Purpose and ownership

[PLAN.md](PLAN.md) drives delivery of the entire app through bounded, dependency-ordered changes in `agent/changes/`. This document defines how each change is implemented, verified, reviewed, and merged.

Repository scripts in `scripts/` must execute the workflow: branch/worktree setup, code implementation, checks, commits, PR-style reviews, fixes, and squash-merge into `dev`. Scripts may invoke coding/review agents and development tools; the scripts own sequencing, durable state, and gate enforcement. Agent prose alone must not advance a gate. Script entry points and usage will be documented when implemented; this document does not claim that any command already exists.

The governing inputs are:

- [PRD.md](PRD.md): product requirements and acceptance criteria.
- [ARCHITECTURE.md](ARCHITECTURE.md): technical boundaries and constraints.
- [AGENTS.md](../AGENTS.md): repository instructions and mandatory testing policy.
- [PLAN.md](PLAN.md): delivery sequence, dependencies, requirement coverage, and progress.
- The selected change and current repository: the bounded implementation contract and integration context.

Changes and scripts must not silently override these inputs or convert unresolved proposals into confirmed requirements.

## 2. Change readiness and size

Before implementation, each change must identify its stable ID, unique numbered slug (`001-build-scaffold`, for example), scope/non-goals, dependencies, linked product requirements, interfaces, acceptance scenarios, failure/recovery behavior, and validation commands. Give requirements and test cases stable IDs and map them to identifiable tests as required by `AGENTS.md`.

The change document is `agent/changes/<slug>.md` and its branch is `change/<slug>`; `<slug>` includes the number and descriptive name unchanged. S001 (`001-build-scaffold`) establishes executable reference code, not just a directory layout. Later application changes must identify the reference files/patterns they extend and document any justified architectural deviation in ARCHITECTURE.

Outline the whole delivery in the plan, but finalize each detailed change against the current code and completed dependencies. Resolve blocking decisions before dependent implementation starts.

Bound a change by coherent behavior and independently verifiable completion, not generated code length. As a planning heuristic, target no more than roughly half the usable context for instructions, relevant documents, existing code, and anticipated implementation plus tests. Reserve headroom for tool output, debugging, revisions, and review. This is an estimate, not a guaranteed token cap. Split work when necessary without dropping required tests or leaving integration ownership undefined.

## 3. Per-change execution loop

```text
dependency-ready change + latest dev
  → create change/<slug>
  → implement + integrate within the app
  → test → fix until required checks pass
  → commit implementation
  → review the complete change against dev
      → fix actionable findings
      → run applicable checks
      → commit that review-fix round
      → review again
  → incorporate latest dev, if changed
  → revalidate and review the final integrated candidate
  → squash-merge into dev
  → record merge evidence and advance PLAN.md
```

### Prepare and implement

1. Verify prerequisites, change readiness, available tools/devices, and dependency completion. Establish the current `dev` baseline, refreshing from the configured remote when applicable. Record its exact commit; do not silently use a stale baseline after a refresh failure.
2. Create `change/<slug>` from that baseline, preferably in an isolated worktree. Preserve unrelated user changes. An existing branch/run must be explicitly recognized as a resume, not overwritten or reset.
3. Implement the change, its tests, and necessary documentation. Integration here means wiring the change into the existing app on the feature branch; it does not yet mean merging into `dev`.
4. Run required checks and repair failures. Commit the validated implementation to the feature branch with the change ID in the message.

### Review and fix

5. Invoke a separate PR-style review pass over the complete resulting diff against the recorded `dev` baseline, with access to relevant surrounding code and governing documents. Review behavior, architecture, requirement/test coverage, failure paths, and regressions—not only the latest commit.
6. Persist findings with stable identifiers, severity, location, rationale, and disposition. Fix every actionable finding; record a reason and evidence for any finding determined to be invalid. Do not mark an actionable finding resolved merely by deferring it.
7. Run applicable checks after the fixes and create one commit for that review-fix round, identifying addressed findings and validation evidence. Then review the complete change again, including possible regressions introduced by fixes. A clean review needs no empty commit.
8. Exit the review loop only after a successfully completed review reports **no unresolved actionable findings** and required checks pass. An empty response, reviewer/tool failure, or malformed report is not a clean review. A clean review is not proof of correctness and never replaces tests.

### Refresh and merge

9. Before final approval, check whether `dev` has advanced. If so, incorporate it into the feature branch, resolve conflicts, rerun affected checks and all required merge gates, and repeat review. Conflict resolution is itself a reviewable change.
10. Bind final review and validation evidence to the exact source commit and target baseline. Serialize merges and verify those commits have not changed before updating `dev`; stale evidence sends the run back to integration/validation/review.
11. Squash-merge directly into `dev`, producing one implementation commit per change. Do not first squash/rewrite the feature branch. The squash message must identify the change, summarize the change, and reference review and validation evidence.
12. Verify the merge result, record its commit ID, and update plan progress. Preserve round history and evidence before optional branch cleanup. Record `merged` only after Git confirms it; if a subsequent bookkeeping step fails, resume bookkeeping without merging again.

PR-style review does not require a hosted PR. Remote pushing or PR creation, if later configured, must be explicit script behavior rather than an undocumented side effect. App publication is not part of this merge workflow.

## 4. Verification and completion gates

Scripts must enforce the policy in `AGENTS.md`, including:

- `make unit-test`: application, domain/measurement, and data tests; 100% handwritten application/domain line coverage by default, with only explicitly documented narrow exceptions; branch coverage reported separately where supported.
- Real SQLite integration checks for transactions, recovery, and migrations, automated as part of the test workflow. Mock-only evidence is insufficient.
- `make end-to-end-test`: implemented user-facing functionality and its acceptance/failure/recovery scenarios on the configured Android emulator/device.
- Applicable static analysis, build, platform/device, and physical-device/field validation required by the change and architecture.

Every change requirement and specified test case needs identifiable unit-test coverage. User-facing behavior also needs mapped end-to-end coverage. Generated code exclusions do not remove serialization, persistence, or migration verification obligations.

Record each check's command, exit status, tested revision, environment/device, and evidence location. Missing required tools/devices, unexpectedly empty suites, failures, or absent required physical-device evidence leave the relevant gate unmet. Do not silently skip tests, weaken assertions, or treat unavailable checks as passing.

Documentation-only and infrastructure-only changes must state which checks apply and why; this cannot be used to exempt implemented application behavior. Until the app/test infrastructure exists, the two Make targets are **unavailable**, not passing placeholders. Future release/device gates must remain visible in the plan even when they do not block a particular earlier change.

A merged change is not automatically a completed product requirement. Mark a requirement complete only when all its implementation and validation obligations are satisfied. Whole-app completion additionally requires the PRD acceptance and release gates; a set of clean reviews is insufficient.

## 5. Script reliability and execution records

When added, the scripts must:

- Document entry points, prerequisites, configuration, artifact locations, and resume behavior under `scripts/`.
- Maintain durable, machine-readable run state: change/branch, baseline and source commits, current phase, review rounds/findings, checks/evidence, blockers, next action, and merge commit.
- Distinguish phase success from entire-run completion. Return nonzero for failed checks, unmet required gates, invalid review output, or exhausted review/retry limits; never report these as successful merges.
- Set an explicit configurable review/retry limit and detect lack of progress. On exhaustion or recurring disagreement, preserve evidence and stop for reassessment without weakening gates or merging.
- Resume safely after interruption by reconciling recorded state with Git. Prevent duplicate merges, concurrent ownership of the same run, and accidental staging of unrelated files or raw logs/secrets.
- Preserve review evidence outside ephemeral conversation context and link concise summaries from the plan. Changes to the candidate invalidate evidence as appropriate; scripts must not reuse approval for different code.
- Include behavioral tests for their gate enforcement and recovery, including failed tests/reviews, changed `dev`, exhausted loops, and interruption around merge/bookkeeping.

The automation itself must be implemented and validated before it is used for unattended app delivery. Bootstrap automation work must document how it is verified before the full workflow can run; it must not pretend to have executed unavailable scripts.
