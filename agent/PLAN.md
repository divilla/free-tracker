# free-tracker — Whole-app execution plan

**Status:** Whole-app roadmap and S001–S002 change documents authored; other inventory documents remain pending. S001 code and historical check evidence are present on local `dev`; S002 setup/tooling and local check evidence are present in its implementation worktree. Separate workflow delivery gates remain unverified; other implementation remains planned.

**Updated:** 2026-10-30.  
**Next action:** S002's [setup handoff](setup-decisions.md) carries forward the S001 identity/stack and inventories remaining prerequisites, with local consistency tests. Preserve separate review/workflow delivery gates; S003 must audit existing scripts before trusting them. Revalidate physical, account, source and release evidence before their owning consumers.

## 1. Purpose, authority, and baseline

This plan decomposes the entire app into bounded changes that will drive implementation. It is not an implementation change, an accuracy claim, or evidence that any delivery gate has passed.

Governing documents, all used as references:

- [PRD.md](PRD.md): product authority for `PR-01`–`PR-20`, detailed behavior, proposals, exclusions, and release acceptance.
- [ARCHITECTURE.md](ARCHITECTURE.md): feature boundaries, plain-Dart measurement core, one recording owner, durable storage, and presentation-independent maps.
- [IMPLEMENT.md](IMPLEMENT.md): script-owned implementation, verification, review/fix, and squash-merge workflow.
- [AGENTS.md](../AGENTS.md): mandatory unit, coverage, real-SQLite, end-to-end, and device/field testing policy.

Use [templates/change-template.md](templates/change-template.md) to author each change, alongside these governing documents and the repository instructions. Their external references are not revalidated by this planning task. Recheck changing platform requirements, dependencies, map terms, and release policies using current primary sources at the gates below.

The local baseline is now `cb54712a73847cd2d1f2d6bf5437782c975317d4` on `dev` and `change/002-setup-decisions`: S001 Flutter source, Android project, app/test tooling and genuine Make targets exist. The publisher approved using this baseline and [S001's recorded implementation/check evidence](s001-evidence.md) in place of the earlier no-app/unavailable-suite statements. That evidence reports passing unit/coverage, Android shell E2E and debug-build checks on its identified implementation; it is historical, not a fresh run on this commit. See the [reference scaffold](reference-scaffold.md) for provisional stack/presentation decisions. Separate IMPLEMENT review/verified-merge evidence, physical-device tracking and release gates remain unverified; Git source presence does not certify them. The older [environment record](development-environment.md) is a dated pre-implementation snapshot, not current app-test status. Existing `scripts/` conformance to IMPLEMENT remains unaudited here: S003–S004 must inspect and reuse/adapt suitable tooling before adding anything. Preserve unrelated working-tree changes.

### Fixed scope

Deliver **free-tracker**, a free, ad-free Flutter Android app for Walk/Run × Outdoor/Indoor tours. Include manual lifecycle controls; opt-in automatic pause initially off; calibrated indoor steps/estimates; live metrics; active and elapsed durations; km/miles with km default; local SQLite history/details; online zero-cost maps; screen-off recording; recovery; translation-ready English; a signed APK; a tested App Bundle; and eventual public-release preparation.

Do not reopen settled choices: no indoor fallback/manual tour-distance entry, no app-imposed duration limit, no paid maps or advertisements, and SQLite in private storage outside cache. Do not add accounts, cloud sync, social features, route planning/navigation, wearables, calories, GPX import/export, offline-map downloads, indoor positioning/floor plans/beacons, or treadmill integration. Calibration reference distance is not manual tour-distance entry.

This documentation task performs no future implementation or external release actions. Publishing, account creation, payment setup, and purchases remain separate actions. Do not assign calendar estimates before setup, resources, and external lead times are known.

## 2. Rules for authoring changes

### Identity and scope

- IDs are `S001`, `S002`, etc. Every `<slug>` includes its matching zero-padded number and descriptive name, starting with `001-build-scaffold`, then `002-setup-decisions`. Paths are `agent/changes/<slug>.md`; branches are `change/<slug>`. For example, S001 uses `agent/changes/001-build-scaffold.md` and `change/001-build-scaffold`. Keep the complete numbered slug identical in the inventory, filename, and branch.
- This planning revision inserts S001 and resequences the previously unimplemented inventory to S002–S025, updating all dependencies and coverage owners. No authored change requirement/test IDs or implementation evidence are being renumbered.
- Preserve IDs once referenced. If a change is too large, retain its ID for one bounded portion and append IDs for split work; update dependencies and coverage without renumbering or dropping scope.
- Finalize detailed changes only against current code and completed dependency evidence. The inventory is a whole-app outline, not a request to write every detailed change against an imaginary implementation.
- Apply IMPLEMENT's context heuristic: roughly half the usable context for governing inputs, relevant code, implementation, and tests, leaving room for tools, debugging, and review. Split by independently verifiable behavior, not line count, and retain explicit integration ownership.
- Ship mandatory tests with their behavior. Later hardening/field changes add evidence; they do not excuse missing unit/E2E tests in earlier changes.

### Required change contents

1. Stable ID, title, slug, status, baseline commit, dependencies, blocking decisions, and source sections.
2. Scope/non-goals and stable requirements such as `S010-R01`, linked to originating `PR-xx` and §6 scenario IDs.
3. Observable behavior, acceptance scenarios, failure/recovery and degraded/unavailable states; clearly distinguish confirmed behavior from decisions resolved by the change.
4. Interfaces, feature ownership, dependency boundaries, affected storage/migrations, event ordering/time semantics, and configuration/versioning.
5. Stable cases such as `S010-T01`, fixtures and boundary conditions; a mapping from **every requirement and every specified test case** to an identifiable unit test. Add mapped E2E for user-facing behavior and real-database, platform, and field evidence as applicable. These levels do not replace each other.
6. Exact validation commands, expected nonempty suites, coverage scope, devices/environments, evidence artifacts, and completion gates.
7. Integration/migration responsibilities, risks, unresolved prerequisites, and the next consumer of the resulting contracts/evidence.

Use actual named tests/assertions, not just test-directory links. Expand each independently failing condition in a scenario family into specific cases. Preserve both case IDs and actual test identifiers in traceability tables.

Documentation/infrastructure-only changes must explain check applicability as IMPLEMENT requires. Separate executable requirements from external evidence obligations: unit-test validators and handwritten logic, but retain device/manual evidence for facts code cannot prove. A checklist or mocked result is not a physical-device test. This distinction must never exempt implemented application behavior from mandatory testing.

## 3. Open decision and prerequisite register

Entries remain **open** unless explicitly resolved below. Owners identify responsible changes, not completed implementation. On resolution record outcome, date, rationale, alternatives, current source links, tested revisions/devices, evidence, and affected changes. Update the PRD/architecture when a decision changes their documented direction; never silently override confirmed behavior.

| ID | Decision/input | Owner and blocking point | Resolution evidence/constraint |
| --- | --- | --- | --- |
| D01 | Publisher's unique Android application ID | S001; before Android shell generation or signing; S002 carries the record forward | **Resolved 2026-10-30:** publisher explicitly selected `com.bindefined.freetracker` in this conversation; see [PRD §3](PRD.md#deferred-implementation-and-release-setup). Rationale: use publisher-selected identity, not an invented default; no alternative selected. Affects S001 scaffolding and S002/release identity records. No build/device validation or domain-ownership verification is claimed. |
| D02 | Phones, test environment, map-account suitability | S002; before affected spike/integration | **Partial evidence 2026-10-30:** [replacement Android API 37 x86_64 emulator](development-environment.md) and historical [S001 checks](s001-evidence.md). S002's [resource inventory](setup-decisions.md#resources-and-support) records physical-device/capability, independent-reference and authorized map-account facts as unknown with owners/actions. S006/S022 phone proof and S020 suitability remain open; no payment/account creation implied. |
| D03 | Versions, API floor, ABIs, support matrix | S001 provisional, S005 extends, S006 final; before support claims | **Provisional S001 evidence 2026-10-30:** [reference stack](reference-scaffold.md) and [recorded checks](s001-evidence.md): Flutter 3.47.9/Dart 3.13.7, AGP 8.13.2/Gradle 8.14/Kotlin 2.2.20, minimum/compile/target API 24/36/36. ARM32/ARM64/x86_64 packaged, execution on x86_64 API 37 emulator only. No final phone-support claim; S005 extends and S006 validates the support decision. Assess older/low-memory/recent multi-vendor devices and recheck target SDK at release. |
| D04 | Service ownership and sensor/location adapters | S006; before production recording/UI-heavy work | Real-phone screen-off/UI-detachment/recovery proof; service-hosted Dart versus focused native bridge. One owner and one implementation per rule. Any computation relocation requires architecture update and deterministic replay. |
| D05 | Presentation state management and SQLite binding | S001 establishes template patterns, S005 selects SQLite binding, S006/S009 validate; before production consumers | **Partial S001 evidence 2026-10-30:** [reference scaffold](reference-scaffold.md) establishes immutable plain-Dart state/broadcast stream with Flutter StreamBuilder and constructor injection; no extra state/DI framework. SQLite binding/migration tooling remains S005, with S006/S009 validation; do not mark this combined decision fully resolved. |
| D06 | GPS-loss time, endpoints, interruption semantics | S007; before gap/time/recovery implementation | Resolve proposed continuing active time during GPS loss; define unknown intervals, clock/reboot handling, first/last fix versus temporal endpoints, and recovery/end options without fabricated end/path/time. |
| D07 | Filtering/calibration/automatic-pause parameters and tolerances | S008 baseline, S010–S012 implementation, S023 validation | Independent reference trials and tuning/held-out split; separate activity/mode targets and latency. PRD numerical candidates are not guarantees. |
| D08 | Schema, commit cadence, buffering, durable/provisional display | S009/S013; before durable recording acceptance | Atomicity or replay consistency, bounded buffers, sequence deduplication, failure policy and measured uncommitted tail. |
| D09 | Map provider and non-Google-device behavior | S006 assessment, S020 integration; before online-map acceptance | Current zero-charge terms/configuration/actual usage; dual renderer or documented Google-services limit. No compliant provider means the release gate remains unmet. |
| D10 | Notification controls and mode/API service types | S006 feasibility, S015 production | Reopen required; evaluate Pause/Resume and End through shared commands. Resolve denied permissions without unnecessary indoor location/body-sensor access. |
| D11 | Diagnostic retention and Android backup/privacy | S021; before release | Preserve summaries/routes; explicit backup rules and SDK disclosures; no silent cloud backup or new deletion/export/route-upload feature. |
| D12 | Signing ownership, accounts, disclosures and release testing | S002 identify, S024/S025 fulfill; before distribution | S002 [identifies prerequisites](setup-decisions.md#release-prerequisites), not fulfillment: signing owner/custody/upgrade identity, separate upload/app-signing certificates, account-specific obligations, support/policy/declarations, compatibility and artifact tests remain unknown. S021 retains privacy ownership; S024/S025 fulfill before distribution with separate external-action authorization. |

D01 is resolved; use `com.bindefined.freetracker` for app scaffolding. Missing phones blocks the physical spike, not deterministic test preparation. Missing map-account access allows evaluating a compliant zero-cost alternative, never a paid fallback or invented billing verification.

## 4. Delivery gates and change inventory

| Gate | PRD phase | Required exit evidence |
| --- | --- | --- |
| GA — Reference architecture | Supporting infrastructure | S001 buildable, tested code template with composition, feature/layer boundaries, injected adapters and extension guidance; reference baseline for all later app changes. D01 resolved before Android shell generation. |
| G0 — Setup | 0 | S002 setup record carries forward S001 identity/stack choices; remaining resource/account blockers visible. |
| GW — Workflow | Supporting infrastructure | S003–S004 behavioral tests prove durable, fail-closed, resumable review/merge automation before unattended delivery. |
| GT — Test foundation | Supporting infrastructure | S005 extends S001 code/test scaffolding with nonempty layer suites, real SQLite harness and verified coverage/failure behavior through stable Make commands. |
| G1 — Android feasibility | 1 | S006 physical-device single-owner, screen-off, metadata/sensor and recovery proof; architecture/support decisions before UI-heavy work. |
| G2 — Measurement baseline | 2 | S007 contract, S008 reproducible reference/replay baseline, and S010–S012 evidence-based strategies. No simulation-only accuracy claims. |
| G3 — Durable recording | 3 | S009/S013–S015 consistent commits, serialized lifecycle, honest recovery and resource release with integrated tests. |
| G4 — Complete experience | 4 | S016–S021 start/active, calibration, history/details, settings/about, online maps and privacy; mapped E2E failure/recovery coverage. |
| G5 — Validated product | 5 | S022–S023 accepted device/field results, documented limitations/loss window and no unresolved tour-loss defect. |
| G6 — Deliverables | 6 | S024 signed APK/AAB, install/upgrade evidence and handover reports; S025 supplies Play-delivered test-track verification. |
| G7 — Public-release readiness | 7 | S025 current declarations/listing, required account testing, Play-build verification and rollout/rollback preparation. Actual publication remains separate. |

Only a small shell and experimental harness precede G1, to make the spike testable. The spike may use provisional SQLite tables but must demonstrate actual phone persistence. S009 owns production replacement/migration; do not silently ship an experimental store. Public-release prerequisite research may begin earlier without claiming packaging or authorization to publish.

All inventory rows start **planned**. Paths are relative to `agent/`; branches are `change/<slug>`. Dependencies include their transitive prerequisites. A dependency is satisfied only when its consumer's required evidence exists, not merely because a branch/document exists. Verification includes §7's universal policy in addition to the named scenarios.

| Change / path | Slug | Dependencies | Output and integration ownership | Specific verification |
| --- | --- | --- | --- | --- |
| S001 / `changes/001-build-scaffold.md` | `001-build-scaffold` | —; D01 resolved: `com.bindefined.freetracker` | Build a minimal executable Flutter/Dart code template implementing ARCHITECTURE: feature-first organization, composition in `app/`, plain-Dart application/domain/measurement boundaries, constructor-injected ports and thin data/platform adapters. Include a small tested reference slice, localization-ready shell, stable Make runners and extension guidance linking actual code. This code is the reference architecture for later changes, not merely documentation, empty folders or a disposable demo. No tour recording, sensor/service feasibility, production schema or map implementation. | Analyze/build the template; observable unit tests for the reference slice and adapter success/failure paths, shell Android E2E, coverage and runner failure checks. Enforce AGENTS policy for all handwritten logic; no placeholder passes. C01, C30, C36. |
| S002 / `changes/002-setup-decisions.md` | `002-setup-decisions` | S001 | Carry forward confirmed publisher identity and template stack; record resources, remaining decisions/evidence, support/release prerequisites and source-verification procedure. No duplicate scaffold or invented thresholds. | Setup/applicability evidence; C01, C02, C35. |
| S003 / `changes/003-workflow-run-state.md` | `003-workflow-run-state` | S002 | Script entry points/configuration, durable state, worktree/branch setup, baseline capture, ownership locking, resume/preflight. | Temporary-Git-repo tests for dirty/unrelated files, existing runs, failed refresh, concurrent runs and interruptions; C00. |
| S004 / `changes/004-workflow-review-merge.md` | `004-workflow-review-merge` | S003 | Script test/commit/review/fix loop, evidence binding, retries, refresh/integration and serialized squash/bookkeeping; usage docs. | Failed/empty/malformed review, failed tests, finding disposition, exhausted loops/no progress, changed dev/source, conflicts, stale evidence, interrupted/duplicate merge; C00. |
| S005 / `changes/005-app-test-foundation.md` | `005-app-test-foundation` | S001, S002, S004 | Extend the S001 reference code and existing Make runners; do not regenerate a competing shell/architecture. Expand navigation/localization and injected test seams as needed; add real SQLite harness, data-layer mapping/transaction tests and full layer-suite enforcement. No screen-owned recording. | Nonempty layer suites, real SQLite round-trip/rollback, shell E2E, runner failure/coverage enforcement; C01, C02, C27, C30. |
| S006 / `changes/006-android-tracking-spike.md` | `006-android-tracking-spike` | S005 | Minimal service-backed single-owner sensor/notification/persistence harness; adapter/native comparison and compatibility decision. No full UI/map. | Actual phones: locked screen, UI recreation, metadata/batching, no duplicate subscriptions, termination/recovery; C02, C08, C18–C20, C22. |
| S007 / `changes/007-measurement-contract.md` | `007-measurement-contract` | S006 | Canonical Tour/interval/segment/quality models, normalized clock/sensor contracts, time/pace/units, versioning and D06 decision; narrow coordinator/repository contracts. | Pure interval-boundary, clock/boot-session, unavailable-versus-zero, unit/pace and metadata tests; C03, C05, C12, C24, C27. |
| S008 / `changes/008-reference-replay-baseline.md` | `008-reference-replay-baseline` | S006, S007 | Bounded deterministic capture/replay tooling, fixture metadata, simple outdoor/indoor baselines, independent references, tuning/held-out split and target/battery protocol. | Repeatability, invalid/duplicate fixture handling, reference calculations and baseline phone trials; C09–C15, C17, C32, C33. |
| S009 / `changes/009-sqlite-tour-repository.md` | `009-sqlite-tour-repository` | S006, S007 | One private SQLite store: schema/indexes/migrations, mappings, tours/events/samples/segments/checkpoints/calibration/preferences, bounded queries and failures. | Real SQLite rollback/atomicity, deduplication/replay, migration preservation, write faults, chunked reads/cache independence; C21–C26, C28. |
| S010 / `changes/010-outdoor-measurement.md` | `010-outdoor-measurement` | S008 | Plain-Dart outdoor strategy: validated fixes, horizontal geodesics, quality/drift/outliers, continuity/gaps, measurement versus display geometry and versioned settings. | Boundary/adversarial replay, baseline comparison; C09–C12. |
| S011 / `changes/011-indoor-calibration-rules.md` | `011-indoor-calibration-rules` | S008, S009 | Walk/Run calibration and persistence, immutable snapshots, counter/event strategy, interval allocation, reset/reboot and unavailable-distance states. | Pure calibration/step cases and actual snapshot persistence/reload; C13–C15, C28. |
| S012 / `changes/012-automatic-pause-rules.md` | `012-automatic-pause-rules` | S010, S011 | Mode-specific thresholds/dwell, timestamp reconciliation, manual precedence and configuration snapshots. S013 owns lifecycle wiring. | Slow walk/indoor cadence, hysteresis, batches, resume latency/movement and manual precedence; C16, C17. |
| S013 / `changes/013-durable-recording-coordinator.md` | `013-durable-recording-coordinator` | S009–S012 | One serialized owner integrates strategies/repository/acquisition: Start/Pause/Resume/End, snapshots, idempotence, checkpoints/flush/cutoff and startup/finalization errors. | Controlled sensors/clocks, races/faults, real SQLite save/reopen equality, minimal exposed-control E2E; C03–C07, C16, C21, C23, C24. |
| S014 / `changes/014-interruption-recovery.md` | `014-interruption-recovery` | S013 | Reconcile unfinished database tour with actual owner, reconnect or truthful recovery/end options, bounded replay/session boundaries and write retries. | Restart, duplicate delivery, live-owner reconnect, unknown intervals, failed recovery commit, app E2E; C22, C23, C25. |
| S015 / `changes/015-android-recording-integration.md` | `015-android-recording-integration` | S006, S013, S014 | Production service/sensor/clock bridges, permissions/capabilities, mode service types, notifications and resource ownership. Replace spike wiring. | Real adapter/device permissions, batching, screen-off and notification tests; controlled E2E command routing; C08, C18–C20. |
| S016 / `changes/016-start-active-tour-experience.md` | `016-start-active-tour-experience` | S015 | Four activity/mode combinations, readiness/guidance, durable live metrics, pause reasons/quality and indoor estimates/no-route. Renderer seam for S020. | Unit/widget and E2E journeys/errors/background reconnect; C03–C08, C12, C14, C16, C18, C20. |
| S017 / `changes/017-guided-calibration.md` | `017-guided-calibration` | S011, S016 | Guided known-distance Walk/Run calibration, phone-carry explanation, validation/cancel/retry/recalibration. Define active-tour interaction without changing its snapshot. | Unit/E2E zero/invalid inputs, sensor denial/loss, interruption, separate activities and unchanged existing tours; C13–C15, C28. |
| S018 / `changes/018-tour-history-details.md` | `018-tour-history-details` | S014, S016 | Bounded local history/date ordering, immediate reopening without Save, both durations/pace, quality/boundaries/endpoints, steps and route seam; truthful no-fix/interrupted states. | Unit/DB/E2E completion, no-fix/recovery, pagination, offline relaunch and display-precision equality; C21, C22, C24–C26. |
| S019 / `changes/019-settings-localized-about.md` | `019-settings-localized-about` | S016–S018 | Persistent units/automatic pause, calibration entry, measurement/background explanations, attribution/privacy entry seams; locale formatting and English/notification string audit. | Unit/E2E first-install/relaunch/upgrade defaults, live/historic conversion and text expansion; C16, C27, C30. |
| S020 / `changes/020-zero-cost-route-maps.md` | `020-zero-cost-route-maps` | S006, S018, S019; D09 | Live/saved renderer, segments/location/markers/fit, attribution, compliant zero-cost provider and non-Google behavior, local-outline fallback; never indoor basemap for no-route section. | Deterministic renderer E2E plus real provider/key/network/device tests, SKU/config evidence, offline/cache/gestures; C29. |
| S021 / `changes/021-privacy-retention-policy.md` | `021-privacy-retention-policy` | S009, S019, S020 | Explicit backup, bounded diagnostic retention separate from summaries/routes, SDK/data/dependency audit, in-app privacy/limits and release policy content. | Unit/configuration checks, real retention/migrations, platform backup checks, policy/about E2E; C26, C28, C30, C31. |
| S022 / `changes/022-device-endurance-hardening.md` | `022-device-endurance-hardening` | S017, S020, S021 | Cross-feature lifecycle/device matrix and fixes, long replays/physical tours, bounded memory/query/rendering, measured tail/battery/heat/storage and support limits. | Screen lock/battery saver/vendor restrictions, UI/process/system stop, force-stop/reboot, storage faults/cleanup; C18–C23, C26, C32. |
| S023 / `changes/023-held-out-accuracy-validation.md` | `023-held-out-accuracy-validation` | S008, S022 | Held-out outdoor/indoor/automatic-pause evaluation, accepted tolerances and filter comparison; document failed runs and use fresh held-out data after tuning. | Separate device/activity/environment/placement metrics, sample sizes/worst/tail errors; C09–C17, C33. |
| S024 / `changes/024-signed-build-handover.md` | `024-signed-build-handover` | S023; signing inputs D12 | Reproducible version/build/signing, signed APK/AAB, key procedures, installation/upgrade instructions, notices and device/accuracy reports. No committed credentials. | Release APK phone smoke for all modes, upgrade/history, ABIs/signing/map restrictions; C34. |
| S025 / `changes/025-play-release-readiness.md` | `025-play-release-readiness` | S024; account inputs D12 | Listing/screenshots/declarations, policy URL, current account/platform obligations, required tests, Play-build validation and rollout/rollback handover. External uploads/submissions need separate authorization. | Account/policy evidence, test-track install/upgrade/reopen, crash/ANR review and complete release checklist; C35. No public production publication. |

## 5. Confirmed requirement coverage

This is a planning map, not passing-test evidence. PRD §§5–13 refine `PR-xx`; §6 below carries their detailed acceptance conditions into changes.

| Requirement | Implementation/evidence owners | Scenario families |
| --- | --- | --- |
| PR-01 Flutter Android | S001, S005, S006, S015, S024 | C01, C02, C19, C34 |
| PR-02 Name, free, no ads | S001, S002, S005, S021, S025 | C01, C31, C35 |
| PR-03 Walk/Run, Outdoor/Indoor | S007, S010–S017 | C03, C09–C17 |
| PR-04 Calibrated indoor estimates/no route | S011, S016–S018 | C13–C15, C24, C28 |
| PR-05 No indoor fallback/manual entry | S011, S015–S017 | C08, C14, C18 |
| PR-06 Broad practical compatibility | S002, S006, S015, S020, S022, S024 | C02, C08, C18–C20, C29, C32, C34 |
| PR-07 Manual/automatic pause | S012–S016, S019, S023 | C03–C07, C16, C17, C20, C27 |
| PR-08 No duration limit | S007, S009, S013, S018, S020, S022 | C26, C32 |
| PR-09 Live metrics | S007, S010–S013, S016 | C03, C09, C12, C14, C24 |
| PR-10 Both durations/active pace | S007, S013, S018 | C05, C12, C24 |
| PR-11 km default/miles selectable | S007, S019 | C27 |
| PR-12 Horizontal distance | S007, S010 | C09 |
| PR-13 GPS filtering | S008, S010, S023 | C09–C12, C33 |
| PR-14 Accuracy first, measured battery | S006, S008, S015, S022, S023 | C09–C11, C19, C32, C33 |
| PR-15 Screen-off/notification | S006, S015, S022 | C19, C20, C32 |
| PR-16 Zero-cost online maps | S002, S006, S020, S025 | C29, C35 |
| PR-17 Local private SQLite | S009, S011, S013–S015, S018, S021, S022, S024 | C21–C23, C25, C26, C28, C31, C34 |
| PR-18 Reopen every tour | S014, S018, S020 | C21, C22, C24–C26, C29 |
| PR-19 APK/eventual Play preparation | S002, S024, S025 | C34, C35 |
| PR-20 Translation-ready English | S001, S005, S015–S021 | C30 |

Architecture/workflow requirements also need traceability: S001 owns the reference code template and C36; S003–S004 own C00; S005/S007 enforce pure-rule boundaries and external-type conversion; S009/S013–S015 own single-owner/durability contracts; S020 owns map isolation. They do not introduce extra product features. Enforce feature-first organization, not top-level catch-all services/controllers/models; keep Flutter/SDK/database types outside plain-Dart domain/measurement code, composition in `app/`, and cross-feature dependencies through intentional contracts without cycles.

## 6. Detailed acceptance and test-scenario catalog

Stable `Cxx` IDs supplement the PRD without modifying it. Each names a scenario family, **not an implemented test**. Expand all applicable conditions into `Snnn-Tnn` cases, map each to unit tests, and add E2E for user-facing behavior. Preserve parent IDs when splitting changes.

Additional evidence labels: **E** deterministic Android app E2E; **DB** real SQLite; **P** real adapters/platform/devices; **F** physical field/reference trials; **R** configuration/release records. Unit coverage is required for every executable change requirement/case, including those validated at other levels. Widget tests supplement but do not replace E2E. Documentation/external-evidence applicability follows §2 and IMPLEMENT.

| ID | Source | Required conditions and outcomes | Additional evidence |
| --- | --- | --- | --- |
| C00 | IMPLEMENT §§2–5 | Safe branch/resume/exact baseline; test/review failures cannot advance; stable findings and justified dispositions; bounded retries/no progress; stale evidence invalidated; serialized squash; interruption around merge/bookkeeping without duplicate merge; unrelated files/raw logs/secrets not staged. | Temporary Git repos, injected failures, R |
| C01 | PRD §§1–4, 12–13 | Exact name, Flutter Android, publisher ID, free/no-ad build and excluded-feature guardrails. Pin stack; distinguish minimum API from target SDK. | E, R |
| C02 | PRD §§3, 6, 8 | Lowest practical maintained floor and tested ABIs/device matrix; old/low-memory/recent/multi-vendor devices; absent step sensor not an install blocker; non-Google claims bounded by evidence. | P, R |
| C03 | PRD §§5, 10 | Start all four activity/mode combinations after mode readiness; persist before success; startup acquisition/write failure cannot appear as recording or silently erase created data. | E, DB, P |
| C04 | PRD §§5, 10; architecture §5 | Repeated/racing UI/notification Start/Pause/Resume/End, delayed callbacks and screen recreation use one serialized owner; no duplicate subscriptions, tours or totals. | E, DB, P |
| C05 | PRD §§7.4–7.6 | Manual pause adds exactly zero distance, active time and counted indoor steps; resume uses fresh outdoor anchor/indoor baseline; elapsed includes pauses; delayed samples allocated by measurement time. | E, DB |
| C06 | PRD §§5, 8, 10 | End cutoff finalizes same tour without a Save step, retries idempotently, releases resources after successful persistence; failed End remains visibly unsaved/recoverable. | E, DB, P |
| C07 | PRD §§7, 10 | Exact interval boundaries, stale/non-increasing/duplicate timestamps, delayed/out-of-order batches and replay cannot double-count or cross pause/end cutoffs; bounded reconciliation policy explicit. | DB, P |
| C08 | PRD §§3, 6–8 | Missing/denied/lost sensing disables only Indoor or honestly interrupts its measurements; Outdoor remains independently usable. No manual entry or silent GPS/step fallback. | E, P |
| C09 | PRD §§7.1–7.3 | Horizontal geodesics, full-precision metres, normalized metadata/timestamps; invalid/stale/duplicate fixes rejected. Elevation, screen/map projection, simplified polylines and road snapping/routing never determine distance. | DB, F |
| C10 | PRD §§7.3, 11 | Stationary drift, isolated jumps, poor accuracy and legitimate fast movement; evidence-based simple/complex filter comparison. Accuracy radius is not tour-error bound. Noise filtering alone never changes timers. | F |
| C11 | PRD §§7.3, 11 | Slow walking, corners, loops and initial motion retained; do not discard all displacement below accuracy radius. Complex smoothing needs held-out improvement without undercount. | F |
| C12 | PRD §§5, 7.4–7.5 | Short outlier skipping requires valid continuity; sustained gap/permission loss/interruption breaks geometry with no connector. Fresh reacquisition, D06 timer policy, incomplete distance/affected pace; no-fix not verified zero, insufficient distance yields unavailable pace. | E, DB, P, F |
| C13 | PRD §7.6 | Known-distance calibration and separate Walk/Run lengths; valid nonzero reference/steps, invalid/cancel/interrupted retry, recalibration/persistence. Explain phone-carried measurement; evaluate speed/placement repeatability. | E, DB, F |
| C14 | PRD §§5, 7.6 | Before calibration save/show steps and awaiting-calibration distance, not assumed length; afterwards label distance/pace estimated. No indoor geometry/location request/basemap solely for no-route section. Stationary phone cannot claim to sense an absent person's motion. | E, DB, P, F |
| C15 | PRD §7.6 | Counter baselines/reset/reboot, delayed batches/step timestamps across pauses, no GPS+step distance for same interval; immutable method/activity calibration snapshots prevent retrospective rewriting. | DB, P, F |
| C16 | PRD §§3, 5, 7.4 | Automatic pause initially off; opt-in survives relaunch/upgrade; distinct reasons/manual controls; automatic detection never resumes manual pause. | E, DB |
| C17 | PRD §§7.4, 11 | Separate mode inputs/thresholds/dwell; slow walking/indoor cadence not false pauses, indoor stepping ignores GPS absence; minimal auto-resume sensing, delayed boundaries, initial-movement loss and latency measured. | E, P, F |
| C18 | PRD §8 | Approximate-only/denied/revoked location, provider disabled, denied/revoked activity recognition, unavailable sensor, battery saver and notification denial have specific guidance/recovery. Block only dependent mode; no unnecessary all-the-time location or indoor body/heart/Health Connect permission. | E, P |
| C19 | PRD §§6, 8 | Correct per-mode service/start while visible; locked screen, foreground/background, UI removal/recreation and batching; scoped wake locks only if proven necessary, End cleanup. Periodic work is not live tracking; UI singleton is not service proof. | P, F |
| C20 | PRD §§5, 8 | Ongoing recording/paused notification and reopen reconnect; chosen Pause/Resume/End actions use shared handler. Explain/request notification permission; denial cannot falsely promise drawer visibility or lose data. | E, P |
| C21 | PRD §§5, 10 | Create at Start, incremental and transition commits; atomic samples/events/totals or deterministic reconstruction, durable acknowledged metrics or explicit provisional state. Immediate history, final live/reopen equality at display precision. | E, DB |
| C22 | PRD §§5, 8, 10 | Reconcile running owner first; process death/system stop/force-stop/reboot differ. Recover committed portion with truthful recovery/end options and unknown intervals; no fabricated end/path/time or uninterrupted restart promise. | E, DB, P |
| C23 | PRD §10 | Storage exhaustion, failed/interrupted writes, rollback/retry and failed end/recovery visible; no false saving, double accumulation or inconsistent checkpoint. Bound/measure uncommitted tail. | E, DB, P |
| C24 | PRD §§5, 7.5, 10 | History sorted by start with activity/duration/distance/status; details endpoints, both durations, active pace, method/quality/estimate/steps/boundaries. Temporal endpoints differ from first/last fix; clock/timezone/reboot contract, not UI tick counting. | E, DB, P |
| C25 | PRD §§5, 10 | No-fix, uncalibrated, interrupted and completed tours reopen offline without account/network. Preserve migrations of values/geometry/calibration/configuration/preferences; retain interrupted records. | E, DB |
| C26 | PRD §§7.5, 9–10 | Bounded buffers/indexed history/chunked route rendering, no time cap/overflow/truncation; relaunch/upgrades/map-cache clearing preserve summaries/geometry; authoritative private database outside cache. | E, DB, P |
| C27 | PRD §§3, 5, 7.5 | First-install km; persistent km/miles changes live/historical display and min/km or min/mile only, never stored metres. Unavailable pace safe; locale units/plurals/numbers correct. | E, DB |
| C28 | PRD §§7.6, 10 | Persist method/steps, calibration/algorithm/automatic-pause snapshots, boot/session and sequence/checkpoint state; serialization/round-trip/migrations preserve meaning, including generated code. | DB |
| C29 | PRD §9 | Accepted segmented route, current location, endpoint markers/fit, attribution; gestures/widget lifetime never affect recording. Provider/key/network/Google-services failures nonfatal, offline outline/metrics and honest basemap status; explicit indoor no-route. Verify no map ID/paid APIs/trial/overage fallback, restricted API/package/certificate keys and actual Google SKU usage; alerts not spending caps, disable unnecessary APIs/use applicable quotas. OSM needs zero-cost scale/terms, identification and bounded compliant caching/no bulk prefetch; Google content stays SDK-managed. Recheck pricing; disable chargeable service rather than pay silently. Outline fallback alone does not satisfy online-map release gate. | E, DB, P, R |
| C30 | PRD §§5, 13 | English resources from first UI including notification/permission strings; persisted IDs language-independent; locale formatting/plurals/text expansion; about explains measurement/background limits, attribution/privacy. | E, P, R |
| C31 | PRD §§9–10, 12 | Explicit backup/retention and private data; SDK network audit distinguished from tour upload; no ads/route-upload service. Accurate in-app/public privacy disclosure; no uninstall/data-clear survival promise. | E, DB, P, R |
| C32 | PRD §§8, 11, 13 | Progressively longer phone screen-off sessions and long replays: durations/gaps/memory/storage/battery per hour/heat/loss window and power limits recorded. Finite trial lengths are not a configured duration cap. | P, F |
| C33 | PRD §11 | Independent measured course/observed steps and path/placement/pace/configuration records; tuning/held-out and activity/mode/environment splits. Signed/absolute error, median/worst/tail with sample size, drift, slow/corner/initial-motion loss, rejected fraction/gaps/reacquisition, false-pause/latency/time error. Another GPS app is not truth. Candidate 2% median/5% tail and 10 m/10 min remain provisional; indoor criteria separate. Report failed/urban/tree/tunnel cases, not only open sky. | F, R |
| C34 | PRD §12 | Signed APK install, all-mode completion/reopen and upgrade history on phones; ABIs/version/signing/map-key restrictions. Reproducible instructions, secure keys, artifacts/notices/device/accuracy reports and AAB delivery. | E, DB, P, R |
| C35 | PRD §§12–13 | Current target SDK/native compatibility/FGS/account rules; listing/screenshots/contact/distribution/free-no-ads/content rating; public/in-app policy and Data safety/health/FGS declarations; required testing. Authorized Play test-track install/upgrade/reopen, crash/ANR review, rollout/rollback. Check current account-specific obligations, not assumed historical tester counts; publisher costs separate from zero map usage, actual publication separate from preparation. | P, R |
| C36 | ARCHITECTURE §§2–3; PLAN §4 | Buildable reference code demonstrates feature-first composition, plain-Dart rules/application code, constructor-injected ports, adapter conversion and observable success/failure tests. Later changes identify the reference files/patterns they extend; deviations require rationale and an ARCHITECTURE update. No empty-directory-only scaffold, competing architecture, or demo presented as working tour recording. | E, R |

### PRD release-checklist reconciliation

S025 must attach evidence for every PRD §13 checkbox. The mapping follows its current order; preserve descriptive/scenario references if the order changes.

| Checklist item(s) | Scenario evidence |
| --- | --- |
| 1 lifecycle; 2 automatic pause | C03–C07; C16–C17 |
| 3 indoor; 4 units; 5 durations; 6 live metrics | C13–C15; C27; C05/C24; C03/C09/C12/C14 |
| 7 filtering; 8 screen-off/no limit; 9 indoor capability | C09–C11/C33; C19/C20/C26/C32; C08/C18 |
| 10 every tour reopened; 11 no connectors; 12 interrupted/no-fix honesty | C21/C24/C25/C29; C05/C12; C12/C22/C25 |
| 13 geometry survives; 14 SQLite/recovery/tail; 15 zero-cost maps | C25/C26/C34; C21–C23/C28/C32; C29 |
| 16 name/free/no ads; 17 translations; 18 accuracy/reliability/battery | C01/C31/C35; C30; C32/C33 |
| 19 signed APK; 20 bundle/public-release preparation | C34; C35 |

## 7. Verification policy and bootstrap

### Required commands and evidence

- `make unit-test`: application, domain/measurement and data unit suites, fail on unexpectedly empty required suites, enforce **100% line coverage by default** for handwritten application/domain/measurement logic. Explicitly document any narrow exception/reason. Exercise decisions and report branch coverage separately where supported; line coverage is neither branch coverage nor correctness proof.
- Exclude genuinely generated code only, while testing its serialization/persistence/migrations. Manually maintained generated code is handwritten. Never weaken assertions, exclude logic or skip cases to meet coverage.
- Include real SQLite checks in `make unit-test`, optionally through a documented `make database-test` target it invokes: actual transactions/faults/rollback, reopen/recovery, migration fixtures and bounded queries. Supplement host tests with Android binding/private-path verification; mocks alone are insufficient.
- `make end-to-end-test`: mapped suite on configured Android emulator/device; missing tooling/device/configuration, test failure or unexpectedly empty suite must return nonzero, never a placeholder pass.
- Controlled sensors/clocks/faults make app E2E deterministic. Separate adapter/notification/background/lifecycle tests and actual field trials remain mandatory where specified; simulation cannot certify accuracy, steps or locked-screen reliability.
- Every behavior-changing change supplies tests before completion. Also run applicable static analysis/build checks. Required phone/field gates stay unmet without actual evidence.
- Record command, exit status, revision, environment/tool versions, device/configuration, results/coverage and evidence location. Intended commands are not executed results.

### Bootstrap without circular claims

1. S001 builds and tests the reference code template first, using a documented manual equivalent of IMPLEMENT until automation is proven. D01 is resolved: generate the Android shell with `com.bindefined.freetracker`; do not substitute an identity or claim device feasibility. Introduce stable Make targets with genuine template unit/coverage and Android shell E2E suites; report missing tooling/device as failure. S002 then validates setup records and remaining prerequisites without rebuilding the template.
2. S003–S004 audit existing scripts against IMPLEMENT, then adapt/complete and validate automation before relying on it to own delivery. Document a manual equivalent of IMPLEMENT's branch, checks, separate review/fix and merge gates for missing or unproven capabilities. Test with temporary repositories/injected tools and record bootstrap revision evidence. Reconcile existing script artifact conventions with the ledger contract before choosing paths. Do not claim unavailable/unverified scripts or app tests passed. Separate PR-style review need not be a hosted PR.
3. After S004 passes GW, scripts own subsequent sequencing/durable records. Prose cannot override failed gates. Split bootstrap changes if needed without losing tests/integration responsibility.
4. S005 extends S001's genuine Flutter suites/Make targets with real SQLite integration and full layer-suite checks, verifies failure propagation and coverage enforcement, then passes actual commands. Missing required device/tooling keeps its gate unmet.
5. S006 proves actual service feasibility before full UX/production adapter commitments. Missing physical proof cannot be waived by a successful emulator or mocked test.

## 8. Execution, progress, and completion

Follow [IMPLEMENT.md](IMPLEMENT.md) for every change:

1. Verify readiness, dependencies, tools/devices and exact latest `dev` baseline; refresh configured remote when applicable and surface refresh failure.
2. Create or explicitly resume `change/<slug>`, preferably in an isolated worktree; preserve unrelated changes. Implement/integrate code, tests/docs, check and commit with the change ID.
3. Separately review the complete diff against baseline. Persist finding IDs/severity/location/rationale/disposition. Fix every actionable finding, check, commit that fix round and review again; invalid findings need evidence/reason, deferral is not resolution.
4. Enforce retries/no-progress limits. Empty/malformed/failed review is not clean. Stop nonzero with durable evidence on unmet gates, never weaken requirements.
5. Incorporate changed `dev`, resolve conflicts, revalidate/re-review exact final source/target commits. Serialize merges and verify neither commit changed; stale evidence returns to integration/checks/review.
6. Squash directly into `dev`, one implementation commit per change, without first rewriting the feature branch. Verify and record merge ID, preserve review history, then optionally clean up. Interrupted bookkeeping resumes without merging twice.

Remote pushing/hosted PR creation is not implicit; scripts must configure it explicitly. App publication is outside the merge loop.

### Progress ledger

The inventory remains the initial workflow ledger; authoring does not advance its implementation/check/review/merge/requirement-validation fields. **S001 code is present on local `dev` at `cb54712`, with historical [passing implementation/check evidence](s001-evidence.md); separate review/verified-merge and later device/release gates remain unverified.** Make targets run real suites, not unavailable placeholders. This reconciliation records the publisher-approved baseline without inventing workflow completion or fresh execution results. Future scripts must maintain machine-readable records under `agent/progress/` (schema/entry points owned by S003–S004) and link concise summaries here. Keep raw sensor data, large logs and secrets outside automatic staging; record stable artifact locations/integrity identifiers as appropriate.

| Per-change field | Meaning / initial state |
| --- | --- |
| Identity | ID, change path, slug and derived branch from §4. |
| Authoring status | `pending` until the change document is written and checked; then `authored`. This is not implementation or delivery evidence. |
| Scope mapping | `PR-xx`, `Cxx`, stable change requirement/case IDs and actual tests; detailed IDs pending authoring. |
| Prerequisites | Dependency/gate evidence, applicable Dxx entries, explicit blockers and next action. |
| Implementation status | Initially `planned`; then `ready`, `implementing`, `verifying`, `reviewing`, `merge-ready`, `merged`; `blocked` includes reason/next action, never implies success. |
| Run state | Run/worktree/branch, baseline/source commits, phase, ownership lock and resume state; unset. |
| Checks | Initial workflow fields remain unset; historical S001 command/status/scope evidence is linked above, not relabeled as a current run. |
| Review | Rounds/findings/dispositions and clean-review evidence bound to source/target commits; absent. |
| Merge | Verified squash commit and bookkeeping state; unset. |
| Requirement validation | `pending`, `partial`, `validated`, with remaining obligations; all pending. |
| Next action | Consume S002's [setup handoff](setup-decisions.md); separately review/fix/integrate this implementation, then S003 audits workflow bootstrap. Missing phone/account/release evidence stays assigned to its actual consumers; no delivery gate is advanced by local validation. |

For document-authoring bookkeeping, maintain the **Change authoring progress** table below with columns `Change ID`, `Change file`, and `Authoring status`. Add or update only the selected change, using its exact §4 ID and a link to `changes/<slug>.md`, with status `authored`. Unlisted inventory changes remain `pending`. This table is a document-only summary, not the future machine-readable workflow schema. Authoring must not advance implementation, check, review, merge or requirement-validation status. Keep directly affected aggregate statements consistent when a document is authored.

### Change authoring progress

| Change ID | Change file | Authoring status |
| --- | --- | --- |
| S001 | [changes/001-build-scaffold.md](changes/001-build-scaffold.md) | authored |
| S002 | [changes/002-setup-decisions.md](changes/002-setup-decisions.md) | authored |

Only machine-verified workflow gates advance automatically. Merged does not mean product-validated: indoor arithmetic may be integrated while its field-accuracy obligation remains pending. Keep missing device/account evidence visible, with separate implementation and requirement-validation status.

### Whole-app completion

Require implementation and passing evidence for every confirmed requirement/detailed acceptance case, all PRD §13 items reconciled, applicable G0–G7 gates satisfied, and no unresolved actionable findings or tour-loss defects. Deliver source, automated workflow/test commands, signed APK, tested AAB, build/install/signing guidance, accuracy/device/battery/loss-window report, dependency/map notices, and public-release preparation evidence.

If access or authorized external actions are missing, report the exact unmet deliverable/gate. Do not equate a ready APK with Play-tested readiness, policy text with a published policy URL, or a local outline with required zero-cost online maps. Public production publication remains a separate future action.
