# free-tracker — Architecture

**Status:** Adopted architectural direction; implementation and device validation are pending.

**Date:** 2026-10-30.

**Product authority:** [PRD.md](PRD.md).

## 1. Decision and scope

Use **Screaming Architecture** pragmatically: organize the app around recording, measuring, saving, and revisiting walking/running **tours**. Flutter is the presentation framework, not the organizing principle for the business rules.

The approach is **feature-first organization, a framework-independent measurement core, and thin platform adapters**. It does not require a heavyweight Clean Architecture template, a class for every use case, or identical layers in every feature.

This document defines module responsibilities, dependency boundaries, recording ownership, and verification expectations. The PRD remains authoritative for product behavior. Where the PRD identifies a proposal or unresolved engineering decision, this document does not silently promote it to a confirmed requirement. This document does not scaffold the app, choose dependency versions, or establish that background tracking works.

### Executable reference architecture

The first planned change, `001-build-scaffold` (S001 in [PLAN.md](PLAN.md)), must build a working code template embodying this architecture. It is not just a document, empty directory tree, or disposable demo. Include a minimal tested reference slice showing feature ownership, composition in `app/`, plain-Dart rules/application code, constructor-injected ports, and thin adapters without implementing future tour features or speculative frameworks.

That template code becomes the reference architecture for later application changes: extend its patterns and identify the concrete reference files in each change. Keep code and this document aligned; justify deviations with evidence and update the affected boundaries here. A successful template build does not prove background recording, persistence recovery, or measurement accuracy.

## 2. Architectural principles

1. **Expose the product vocabulary.** Use `Tour`, recording, calibration, and measurement in modules and APIs. Walk/Run is the activity type; Outdoor/Indoor is the measurement mode.
2. **Keep measurement independent.** Filtering, distance, step estimation, interval accounting, and pace must be testable without widgets, a map SDK, a database, or live sensors.
3. **Give recording one owner.** Screens and notifications submit commands to the same serialized recording coordinator. They never own competing tracking pipelines.
4. **Persist throughout recording.** Create a tour at Start, commit progress incrementally, and preserve committed data after interruption.
5. **Treat maps as presentation.** Map availability and widget lifetime must not affect recording or measurement.
6. **Introduce abstractions at real boundaries.** Sensor acquisition, durable storage, clocks, and service integration justify contracts. Trivial getters and ordinary internal classes do not automatically need interfaces or wrappers.
7. **Keep simple features simple.** Settings need not have the same internal layers as recording. Add structure when responsibilities justify it, not to fill a template.

## 3. Proposed source organization

The following is a responsibility map, not a requirement to create empty directories. Create files and subdivisions as they become necessary.

```text
lib/
  app/                         # Composition root, startup, navigation, theme
  tours/
    domain/                    # Tour, intervals, segments, quality, repository contract
    data/                      # SQLite implementation, migrations, bounded queries
    presentation/              # Tour history, details, route presentation
  recording/
    measurement/               # Deterministic outdoor and indoor measurement rules
    application/               # Recording coordinator, commands, state, recovery, ports
    adapters/                  # Location, steps, clock, Android service bridge
    presentation/              # Start/active-tour screens and UI state
  calibration/
    domain/                    # Activity-specific calibration rules and snapshots
    data/                      # Calibration persistence
    presentation/              # Guided calibration flow
  settings/                    # Preferences, persistence, settings/about UI
  shared/
    ui/                        # Genuinely reused widgets and route-rendering adapter
    ...                        # Small shared primitives only when actually needed
  l10n/                        # Localized strings and formatting resources

android/                       # Android host and focused native tracking code if needed
test/                          # Mirrors meaningful feature and rule boundaries
integration_test/              # App, persistence, and platform integration scenarios
```

`app/` constructs and connects implementations; it is not a home for business logic. Route presentation shared by the active-tour and tour-details screens can live in `shared/ui/`; no measurement or tour-storage code may depend on it.

Do not create top-level catch-all `controllers/`, `services/`, or `models/` directories. Do not allow `shared/` or a future `core/` to become a dumping ground for feature-owned behavior. Keep initial modules in one Flutter project; separate Dart packages only when there is a demonstrated need.

## 4. Responsibilities and dependency rules

| Module | Owns | Must not own |
| --- | --- | --- |
| Tours | Canonical tour records, storage contract, saved-tour queries, history/details | Sensor subscriptions or recording orchestration |
| Recording | Tour lifecycle, measurement, recording-time persistence coordination, interruption reconciliation | Map-driven distance or screen-owned tracking |
| Calibration | Validated Walk/Run calibration and immutable calibration snapshots | Retrospective rewriting of saved measurements |
| Settings | Units, automatic-pause preference, and other PRD-approved preferences | A second recording state machine |
| Platform/data adapters | Translation between application contracts and plugins, native APIs, or storage | Independent copies of measurement and lifecycle rules |
| Presentation | Rendering, user input, UI state, navigation, map display | Authoritative sensor processing, timing, or durable recording state |
| App | Dependency construction and application entry points | Feature rules |

Apply these dependency constraints:

- `tours/domain`, `calibration/domain`, and `recording/measurement` use plain Dart types. They do not import Flutter, state-management libraries, plugin types, SQLite bindings, or platform channels.
- `recording/application` depends on measurement rules, domain types, and narrow contracts for external operations. Concrete adapters implement those contracts and are supplied at construction time.
- Recording may use the tour repository contract and calibration snapshots. Tours and calibration domain code must not import recording implementation details; avoid circular feature dependencies.
- Presentation uses feature APIs and observes state. It does not import concrete database or sensor implementations to bypass those APIs.
- Cross-feature dependencies use intentional public contracts, not another feature's screen, controller internals, or private database tables.
- Convert plugin-specific positions, sensor events, and map coordinates at their boundaries. Do not pass SDK objects into measurement rules or persist map-specific geometry as the canonical route.

Use constructor injection by default. A dependency-injection or state-management package may help with wiring, but it must not become the source of truth for recording. Choose one consistent presentation state-management approach during implementation; this document does not select Riverpod, BLoC, Provider, or another library.

## 5. Recording ownership and execution

### Single tracking owner

One logical tracking owner controls acquisition, lifecycle command ordering, measurement state, durable updates, and the ongoing notification. The UI and any notification controls address that same owner.

The owner must run in a service-backed execution context proven to survive screen lock and Flutter screen destruction/recreation. A long-lived Dart singleton inside the UI process is not, by itself, proof of this property.

The early device spike must decide whether a maintained Flutter integration with a service-hosted engine/isolate is sufficient or whether a focused native Android tracking layer is needed. Native integration must not introduce a second independent measurement pipeline. If the spike requires relocating computation, explicitly document that decision and preserve deterministic replay tests and one authoritative implementation of each rule.

### Command and data flow

```text
UI / notification controls
           |
           v
serialized recording coordinator <--- normalized sensor events and timestamps
           |
           v
lifecycle + measurement rules
           |
           v
atomic repository commit / recoverable checkpoint
           |
           v
published recording snapshot ---> UI / notification / route presentation
```

Commands and samples are processed in a consistent order. Arrival order alone is insufficient for delayed sensor batches: measurement timestamps and persisted lifecycle boundaries determine interval assignment.

### Lifecycle contract

The owner distinguishes recording, manually paused, automatically paused, completed, and interrupted tours. Persist pause reasons separately where appropriate to the storage model.

- **Start:** check mode-specific readiness; establish ownership; persist the tour before acknowledging successful recording. Coordinate acquisition startup and persistence failures so a started tour is not silently lost or reported as recording when acquisition failed.
- **Pause:** record the boundary and reason; exclude paused intervals from distance, active duration, and counted indoor steps; flush consistent state.
- **Resume:** record the boundary; begin a new outdoor segment from a fresh usable fix, or establish an indoor sensor baseline; never bridge paused movement.
- **Automatic pause/resume:** initially disabled and explicitly opted into. Automatic detection cannot resume a manually paused tour. Retain only the sensing needed to determine automatic resumption while automatically paused.
- **End:** establish the final measurement cutoff, finalize and persist the same tour idempotently, then release tracking resources. Repeated commands cannot create duplicate tours or duplicate distance.
- **Interruption:** preserve committed measurements, mark unknown intervals honestly, and reconcile unfinished tours on the next launch. Do not fabricate an end time, missing route, or uninterrupted tracking after force-stop/reboot.

Storage failure must be visible. Do not acknowledge successful saving or successful finalization if the relevant commit failed. Serialize commands across UI and service entry points, not merely within one screen controller.

The UI subscribes to snapshots and sends intent. Rebuilding or disposing a screen must neither stop an ongoing tour nor start a second subscription pipeline.

## 6. Measurement core

Use separate outdoor and indoor strategies behind a small common result contract. Results include measurements, quality/availability, segment or interval effects, and configuration/version information. Never combine GPS distance and step-estimated distance for the same interval.

### Outdoor rules

- Consume normalized fixes with source timestamps and available quality metadata.
- Reject stale, duplicate, invalid, and unsuitable fixes according to a validated measurement contract.
- Calculate horizontal geodesic distance only within continuous accepted segments.
- Break segments at pauses, sustained signal gaps, permission loss, and interruptions. Do not invent straight-line distance across unknown paths.
- Keep raw diagnostic samples, accepted measurement geometry, and simplified rendering geometry conceptually separate. Display simplification never changes the measured total.
- Keep stationary-noise filtering separate from automatic-pause decisions.

### Indoor rules

- Use accepted step increments and the applicable Walk/Run calibration snapshot.
- Handle counter baselines, reset/reboot context, delayed batches, and pause boundaries explicitly.
- Without calibration, show steps and unavailable/awaiting-calibration distance; do not substitute an assumed step length.
- Without suitable step sensing, Indoor start is unavailable. Do not offer manual tour-distance entry or silently substitute GPS.
- Save estimated-distance status and counted steps. Show “Route unavailable indoors”; do not generate geometry or request location solely for indoor presentation.
- Calibration's known reference distance is an input to calibration, not a manually entered tour result. Later recalibration must not silently rewrite historical tours.

### Time, units, and reproducibility

- Store canonical distance in metres; convert only at presentation boundaries. Kilometres are the initial display default.
- Derive active duration from recording intervals excluding pauses, and elapsed duration from the start/end span. Use monotonic time within a boot session and wall timestamps for calendar display, with explicit reboot/session handling.
- Average pace uses active duration. Insufficient distance yields unavailable pace; incomplete distance also makes pace quality affected.
- Inject timestamps/clock readings into rules rather than reading ambient time inside measurement calculations. Replaying the same samples, lifecycle events, and configuration must reproduce the same results.
- Snapshot/version calibration, algorithm configuration, and automatic-pause settings sufficiently to explain recorded results.
- Do not impose a tour-duration limit. Use bounded processing buffers and incremental persistence.

**Still unresolved:** the PRD proposes continuing active time during GPS loss while marking distance incomplete. Finalize that measurement contract before implementing gap-time accounting. Filter thresholds, automatic-pause dwell times, and accuracy targets require reference trials; do not invent fixed values here.

## 7. Persistence and recovery

Use a local SQLite-backed repository, consistent with the PRD's proposed direction. Select the binding and migration tooling during implementation.

The logical records include tours, location/step samples as required, accepted route segments, lifecycle events, calibration/configuration snapshots, tracking checkpoints, and preferences. Exact tables and diagnostic retention remain implementation decisions.

- Commit measurements/events and corresponding totals atomically, or retain enough committed information for deterministic reconstruction. A generic event-sourcing framework is not required.
- Make the persisted recording position explicit through sequence IDs/checkpoints so replay or duplicate delivery cannot double-count measurements.
- Publish authoritative recorded totals after a consistent commit. Any provisional display state must be distinguishable and must not imply durable saving.
- Flush on pause, resume, and end; choose a bounded incremental commit policy during recording. Measure and document the possible uncommitted tail after abrupt termination.
- Reconcile unfinished tours against any actual running owner before declaring interruption or starting another pipeline. A screen reconnect is not a new recording session.
- Preserve required summaries and route geometry independently of map cache and optional diagnostic retention.
- Load history and long routes in bounded queries/chunks. Do not accumulate an entire long tour in memory just to update a map.
- Test migrations against existing tours. Surface storage exhaustion and write failures rather than silently losing data.
- Keep records in app-private storage and explicitly resolve Android backup behavior before release; “local” must not silently imply an unreviewed cloud-backup policy.

## 8. Flutter presentation and maps

Screens render feature state and forward user actions through view models/controllers or equivalent state holders. Presentation state may depend on Flutter; the measurement core may not.

The map receives accepted route segments and display metadata. It does not calculate authoritative distance, acquire location independently for recording, or reconstruct an imagined route between endpoints. Map failure must leave tracking, saved metrics, and stored geometry usable.

Keep the renderer behind a small presentation boundary sufficient for live and historical routes. Do not build a universal mapping framework. The PRD's map-provider candidates and zero-cost constraint remain in force; provider pricing, configuration, and device compatibility must be verified at integration/release time. Do not introduce a paid fallback or treat cached tiles as guaranteed offline maps.

When the basemap is unavailable, preserve saved metrics and render the locally stored outdoor route outline where possible, with an honest unavailable-basemap state. Indoor tours retain their explicit no-route state.

Externalize visible strings, including notification and permission text, from the first implementation. Keep persisted identifiers independent of English labels; use locale-aware dates, numbers, and unit formatting.

## 9. Verification and delivery gates

Architecture is useful only if its boundaries protect observable behavior.

| Level | Required evidence |
| --- | --- |
| Pure rule tests | GPS rejection/continuity, pause boundaries, indoor baselines, calibration, timing, pace, and deterministic replay |
| Coordinator tests | Serialized/idempotent commands, manual-pause precedence, delayed batches, single ownership, and storage-failure handling |
| Repository integration tests | Atomicity or replay consistency, interrupted recovery, duplicate protection, bounded queries, and migration preservation |
| Presentation tests | Mode-specific capability states, quality/estimate labels, units, saved-tour rendering, and map-unavailable behavior |
| Physical-device tests | Screen-off recording, UI recreation, sensor batching, permission changes, process death, force-stop/reboot, and committed-data recovery |
| Field validation | Independent outdoor and indoor references, held-out measurement results, battery/heat/storage behavior, and documented loss window |

First prove the Android tracking/service/persistence path on representative phones, before UI-heavy implementation. That spike must establish ownership, engine/service lifetime, required metadata, sensor capability, and recovery behavior. Mocked tests or an emulator alone do not establish screen-off reliability or measurement accuracy.

Then establish measurement replay and reference baselines, complete durable lifecycle/history, and add the full map/UI experience in the sequence defined by the PRD. Keep tests focused on meaningful behavior and boundary failures, not assertions that merely mirror folder names or trivial forwarding methods.

## 10. Deferred choices and guardrails

Resolve these with evidence during delivery:

- Flutter/plugin versions, supported Android API floor, and device matrix.
- Service-hosted Flutter integration versus a focused native tracking implementation.
- Presentation state management, SQLite binding, and exact storage/checkpoint schema.
- Map renderer/provider and non-Google-device behavior, within the zero-cost constraint.
- GPS-loss time policy, calibration/filter thresholds, automatic-pause parameters, diagnostic retention, and backup policy.

Use the publisher-confirmed Android application ID `com.bindefined.freetracker` (PRD §3; PLAN D01 resolved 2026-10-30) when scaffolding; do not substitute an invented publisher identity. This architecture does not authorize account/payment setup or publication.

Do not add accounts, cloud synchronization, route planning, wearables, manual indoor tour-distance entry, offline-map downloads, or other excluded product features. Do not create speculative plugin systems, separate packages for every feature, duplicate DTO/domain models without a useful distinction, or use-case classes that only forward a call.

When implementation evidence changes an architectural decision, update this document with the reason and affected boundaries. If a change affects confirmed product behavior, resolve it against the PRD rather than hiding it as an implementation detail.

## References

- [Product requirements](PRD.md) — product behavior, constraints, roadmap, and detailed acceptance criteria.
- [Robert C. Martin: Screaming Architecture](https://blog.cleancoder.com/uncle-bob/2011/09/30/Screaming-Architecture.html) — organize architecture around use cases rather than frameworks.
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) — separation of concerns and conditional use of additional domain/use-case layers.
