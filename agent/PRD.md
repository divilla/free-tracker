# free-tracker — Product Requirements Document

**Status:** Confirmed product scope; engineering proposals and deferred setup are explicitly identified. Implementation has not been performed as part of this document task.  
**Product decisions recorded:** 2026-10-29–2026-10-30.  
**PRD created/updated:** 2026-10-30.

## Document purpose and requirement status

This is the self-contained product requirements document for **free-tracker**. It supersedes the earlier product-planning `PLAN.md` and retains its product decisions, detailed behavior, technical constraints and proposals, validation requirements, release roadmap, and reference links. No requirement or implementation decision depends on retaining that earlier file; it may be deleted after this PRD is adopted. The new [agent/PLAN.md](PLAN.md) has a separate role: the whole-app execution plan derived from this PRD, following [IMPLEMENT.md](IMPLEMENT.md).

- **Confirmed requirements** define the required product scope. Section 2 assigns stable `PR-xx` identifiers; later sections specify behavior and acceptance in detail.
- **Proposals and candidates** (including technology choices, the API floor, numerical accuracy targets, and GPS-loss timing policy) remain subject to the stated engineering validation. They must not be represented as confirmed user decisions or demonstrated results.
- **Deferred setup** is tracked in Section 3. The public app name is settled; the publisher's technical application ID is not.
- **External references** and dated pricing/platform/policy evidence are retained from the source material, not independently revalidated during this conversion. Recheck them at the implementation and release gates identified below.
- **Document-task boundary:** this change creates Markdown documentation only. It does not scaffold an app, install dependencies, build an APK, create accounts, configure payments, or publish anything. Those product deliverables are future roadmap work.

## 1. Product overview, goals, and terminology

Build **free-tracker**, a free, ad-free Android application using Flutter that measures walking and running distance as accurately as practical on broadly supported phone hardware and displays the recorded outdoor route on a zero-cost map. Indoor tracking is also required, with its measurement method and route-map limitations explicitly addressed rather than disguised as outdoor GPS tracking.

The map budget is a hard product constraint: **maps must cost nothing; paid mapping is excluded**. Google Maps and proprietary services remain acceptable only in a zero-charge configuration. Open source is not mandatory. Offline maps are not required.

A **tour** is one walk or run with a **start, end, distance, and map**. Use “tour” consistently in the interface, documentation, and data model: Start tour, Pause tour, Resume tour, End tour, Tour history, and Tour details. Walk and Run describe the tour's activity type; they are not alternative names for a saved tour.

Every tour must be saved on the phone and reopenable with its start, end, distance, and map section. The user has confirmed the indoor exception: count steps, estimate distance using calibration, and display “Route unavailable indoors” instead of a route map. Never invent indoor geometry. Accuracy must be demonstrated through repeatable measurements, not inferred from a smooth-looking line or the number of displayed decimal places.

### Intended users and core needs

People who walk or run with an Android phone need to record a tour, understand its distance and pace, and revisit its history without paying for the app, seeing advertisements, or depending on a cloud account. Outdoor users need a recorded geographic route; indoor users need honest, calibrated step-based estimates without fabricated route geometry.

### Product goals

- Deliver accurate, independently validated outdoor distance and clearly labeled indoor estimates.
- Preserve every started tour locally, including usable data from interrupted tours.
- Make recording usable with the screen off on the broadest practical supported device range.
- Keep the app free and ad-free, and keep map-service expenditure at zero.
- Deliver a validated APK and prepare for eventual public Play distribution.

Success is evaluated through the metrics and verification matrix in Section 11 and the release acceptance checklist in Section 13, not through unverified accuracy claims.

## 2. Confirmed product requirements

- **PR-01:** Android application built with Flutter.
- **PR-02:** App name: **free-tracker**. The app is free to users and contains no advertisements.
- **PR-03:** Support walking and running tours outdoors and indoors.
- **PR-04:** Indoor tours count steps and approximate distance using calibrated step-based measurement; show “Route unavailable indoors.” Dedicated treadmill integration is not required.
- **PR-05:** No indoor fallback and no manual tour-distance entry. If suitable step sensing is unavailable, indoor tracking is unavailable; outdoor tracking remains independently usable.
- **PR-06:** Aim for the broadest practical Android device coverage, not one phone model.
- **PR-07:** Start, manually pause, resume, and end a tour; also provide optional automatic pause, **initially off**, with manual controls always available.
- **PR-08:** No app-imposed tour-duration limit. Battery, storage, and Android lifecycle restrictions remain practical constraints, not a configured maximum tour length.
- **PR-09:** Display live distance, duration, and average pace.
- **PR-10:** Show both total elapsed time and active time in Tour details; average pace uses active time excluding pauses.
- **PR-11:** Provide user-selectable kilometres and miles, with kilometres as the default.
- **PR-12:** Measure horizontal outdoor distance, without adding noisy GPS elevation to distance.
- **PR-13:** Filter GPS measurements to reduce false distance.
- **PR-14:** Prioritize accuracy over battery economy; higher battery consumption is accepted, but must still be measured and bounded by practical device behavior.
- **PR-15:** Continue recording with the screen off, with an ongoing tracking notification.
- **PR-16:** Use online maps at **zero cost**, with no paid mapping plans or chargeable features; Google Maps is acceptable only under its no-charge configuration. No offline map downloads are required.
- **PR-17:** Save every tour locally in an embedded SQLite database in Android's private app storage, outside cache directories; history must survive closing and reopening the app and supported app upgrades. Tour persistence requires no server, cloud account, or internet connection.
- **PR-18:** Open any saved tour to see its start, end, distance, and map of the tour.
- **PR-19:** Deliver an installable Android APK and prepare for eventual public Google Play release.
- **PR-20:** Use English initially, with an architecture that allows future translations.


## 3. Product decisions and deferred setup

### User decisions received on 2026-10-30

| Decision | Confirmed answer | Product consequence |
| --- | --- | --- |
| Supported devices | As many as practical | Select the lowest maintained Android/API level compatible with the chosen Flutter stack; test a representative device matrix. Do not promise every phone or identical sensor quality. |
| Distribution | Eventual public/Play Store release | Include APK, Android App Bundle, signing, store preparation, and release testing. |
| Offline maps | Not required | Online basemap only; no region downloads or offline-map management. Local tour data remains independent of connectivity. |
| Measurement environment | Outdoor and indoor; calibrated step-based indoor distance accepted | Outdoor GPS measurement; indoor step count and approximate distance. Show “Route unavailable indoors” for indoor tours; no indoor geographic route is required. |
| Units | User-selectable km/miles; km default | Store canonical metres; convert display and pace without altering historical measurements. |
| Indoor fallback | None; no manual entry | Disable indoor tracking when suitable step sensing is unavailable; never substitute manual tour distance or another measurement method. |
| Pausing | Optional automatic pause, initially off; manual controls always available | Persist the user's opt-in preference, distinguish automatic/manual pause reasons, and show both active and total elapsed time. |
| Battery | Higher use accepted for accuracy | Use an accuracy-first acquisition profile and validate heat/endurance on older and newer phones. |
| Tour duration | No app-imposed limit | No automatic ending or truncation based on elapsed time. Long-running reliability and battery measurements are engineering tests, not a user-defined duration cap. |
| App identity | free-tracker | Use this exact public app name; defer the unique Android application ID to release setup without inventing publisher ownership. |
| App pricing/advertising | Free with no ads | No paid access, advertising SDKs, or ad placements. |
| Map licensing/provider | Zero cost only; Google Maps permitted | No paid plans, overage charges, or paid map features. Recommend only the no-charge native Maps SDK configuration; any OSM alternative must also meet the zero-cost constraint. |
| Distance semantics | Horizontal-distance recommendation accepted | Do not add elevation noise to outdoor distance. |
| Pace semantics | Active-duration recommendation accepted | Exclude manual and enabled automatic pauses from average pace; show total elapsed time separately. |
| Language | English, with future translations possible | Externalize text and locale-sensitive formatting from the first implementation. |
| Local storage | On-device SQLite storage accepted | Use one embedded database in Android's private app storage, not a cache directory or text-file store. Save incrementally with transactions and recoverable checkpoints; no database server, hosting, or cloud account is required. |

### Deferred implementation and release setup

The indoor fallback, automatic-pause default, maximum tour length, app name, map budget, and SQLite storage choice are settled as recorded above; do not reopen them as unanswered product preferences.

- **Android application ID:** the public name is confirmed as `free-tracker`; the unique technical package identifier is not yet supplied. Confirm it with the publisher before app scaffolding/signing; do not invent a domain or treat the display name as the package ID. This is a setup dependency, not an unresolved public app name.
- **Map account setup:** the recommended no-charge Google configuration still requires a billing-enabled account, as disclosed in Section 9. This PRD does not authorize account creation or payment setup; if that setup is unsuitable later, evaluate only a zero-cost alternative.

Implementation-time engineering decisions, rather than unanswered user preferences: exact supported API floor, dependency versions, calibration thresholds, test-device selection, and map integration details. Choose them from evidence within the confirmed broad-compatibility and accuracy goals.

### Engineering decisions to resolve during delivery

| Decision | Current direction or constraint | Resolution gate |
| --- | --- | --- |
| Supported API floor, versions, architectures, and device matrix | Lowest maintained compatible stack; API 24 is a proposal, not a confirmed requirement. | Compatibility spike, before committing to support claims. |
| Tracking ownership and adapters | One durable tracking owner; evaluate Flutter plugins and use a focused native layer if needed. | Screen-off and recovery spike, before UI-heavy work. |
| Map integration and non-Google device coverage | Recommended no-map-ID native Google configuration; evaluate only zero-cost alternatives and verify account suitability. | Compatibility/integration spike and release pricing verification. |
| GPS-loss active-time policy | Proposed behavior is to continue active time while recording, with incomplete distance and affected pace labeled. | Finalize the measurement contract before implementation of gap handling. |
| Filters, calibration, and automatic-pause settings | Thresholds, dwell times, and numerical tolerances must come from reference trials. | Measurement baseline and held-out validation. |
| Start/end presentation | Proposed date/time plus geographic markers when available; timestamps and first/last valid fixes may differ. | UX and measurement-contract review. |
| Data retention and backup behavior | Keep required summaries/routes; decide diagnostic retention and explicitly configure Android backup. | Persistence/privacy review before release. |
| SQLite implementation | SQLite is confirmed; select the maintained binding, physical schema, migration tooling, and bounded commit/checkpoint policy. | Persistence implementation and recovery validation. |
| Notification controls | Reopen action required; evaluate Pause/Resume and End actions through the shared command handler. | Background-recording integration. |
| Signing and public-release setup | Publisher application ID, key ownership, account requirements, disclosures, and testing must be recorded. | Application ID before scaffolding/signing; remaining release prerequisites before distribution. |

## 4. Release scope and non-goals

### Core release

The confirmed requirements in Section 2, including optional automatic pause, calibrated indoor step counting with approximate distance, online maps for outdoor tours, selectable units, translation-ready English UI, and the reliability work necessary to avoid losing tours or reporting invented distance. Indoor tours show “Route unavailable indoors”; numerical indoor accuracy targets will be established through reference testing.

### Release sequencing

- First produce a validated installable APK covering the confirmed app scope.
- Prepare and test an Android App Bundle for eventual public Play Store release; public distribution is part of the roadmap, not an unrequested extra.
- Publishing, creating billed accounts, and configuring real payment credentials are separate future actions, not authorized by this document.

### Out of scope

Accounts, cloud synchronization, social sharing, route planning, turn-by-turn navigation, wearables, calories, GPX import/export, and offline map downloads. Do not add these to the initial implementation without a scope decision. Advertisements, paid app access, paid maps, and manual indoor tour-distance entry are explicitly excluded, not merely unrequested.

## 5. User journeys and functional behavior

| Screen | Required contents and behavior |
| --- | --- |
| Start tour | Walk/Run and Outdoor/Indoor selection; mode-specific location/sensor readiness; automatic-pause setting; Start tour action; access to history. Explain permission, calibration, or capability problems with a relevant recovery action. |
| Active tour | Large distance in selected units, active duration, average pace, route/measurement status, Pause/Resume, and End tour. Indoor tours also show step count, approximate-distance labeling, and “Route unavailable indoors.” Clearly distinguish manually paused from automatically paused. Map gestures must not interrupt recording. |
| Tour history | Locally saved tours, ordered by start date; show activity type, start, duration, distance, and completion/interruption state. Tap to reopen. |
| Tour details | Start and end date/time; distance; total elapsed time and active time; average pace; outdoor route map and start/end markers where coordinates exist; pause boundaries and recording gaps; measurement method and estimate status. Indoor tours show saved step count, approximate distance, and “Route unavailable indoors.” |
| Settings/about | km/miles (km default); optional automatic pause (off on first install; persist later choices); indoor calibration; mapping attribution; concise explanation of measurement and background operation. No offline-download or manual tour-distance controls. |

Use localization resources for all visible strings, including notification and permission text. Keep persisted enums/identifiers independent of English labels; use locale-aware dates, numbers, plurals, and unit labels. Future translations must not require changing measurement/storage logic.

### Saving and reopening a tour

1. Persist the tour record when the tour starts; do not wait until End tour to create it.
2. Persist measurement and lifecycle changes during recording.
3. End tour finalizes and saves that same record automatically; a second Save action must not be required for preservation.
4. The tour immediately appears in history and opens in Tour details.
5. Reopening uses the saved route and measurements, not a newly calculated route between endpoints.
6. A tour with no usable GPS fixes is still saved. Show unavailable route/quality information rather than inventing a map trace or interpreting an unmeasured distance as a verified zero. Indoor distance may still be available from its separately identified measurement method; absence of GPS must not erase that estimate.
7. An interrupted tour remains recoverable and visibly marked incomplete. Never fabricate an end timestamp or silently discard its recorded portion.

**Proposed start/end representation:** show date/time and geographic markers when available. The temporal start of a tour and its first valid location may differ; the same applies to the end and last valid location.

## 6. Technical constraints and proposed architecture

Use a separation between recording, measurement, storage, and presentation. The tracking pipeline must not depend on whether a Flutter screen or map widget is mounted.

| Component | Responsibility | Proposed direction |
| --- | --- | --- |
| Flutter presentation | Tour controls, live metrics, history, map, and permission guidance | Flutter/Dart with one consistent state-management approach selected during implementation planning. |
| Tracking owner | Location/sensor subscriptions, serialized lifecycle commands, ongoing notification, and durable updates | One tracking owner using Android foreground-service types appropriate to the active mode; verify ownership and Flutter-engine lifecycle in an early device spike. |
| Location adapter | Expose coordinates, fix age, accuracy, speed metadata, and reliable timestamps | Evaluate `geolocator`; use a focused Android bridge if required metadata or lifecycle behavior is missing. |
| Indoor sensor adapter | Expose step events/counts, timestamps, availability, and permission status | Evaluate Android step-counter/step-detector access for the confirmed calibrated step-based method. |
| Measurement engine | Outdoor fix filtering and indoor estimation; motion detection; distance and pace | Separate deterministic strategies with explicit measurement-source and calibration/filter versions; never add competing distance estimates together. |
| Local repository | Atomic tour/sample/event persistence and recovery | **Confirmed:** embedded SQLite in private on-device app storage. Select a maintained binding and migration strategy during implementation. |
| Map renderer | Display stored/live outdoor geometry independently of measurement | Recommend `google_maps_flutter` using the native Android SDK without a map ID; evaluate `flutter_map` as the OSM alternative. |
| Map source | Supply the online basemap | Standard Google Maps under the Maps SDK no-charge configuration; confirm pricing/configuration before release. See Section 9. |

`flutter_map` is an open-source Flutter map client; it does not itself provide a tile service. `geolocator` exposes Android location and foreground-notification settings, but package support must be verified against the required service lifecycle and metadata. Do not assume a live position stream proves process-recovery reliability. Sources: [flutter_map documentation](https://docs.fleaflet.dev/), [geolocator documentation](https://pub.dev/packages/geolocator).

### Early technical decision gate

Before building the full UI, prove on a target phone that the proposed stack can:

- Record while the screen is locked and the Flutter UI is detached/recreated.
- Persist points without a map or active screen.
- Expose reliable sample timestamps and quality metadata.
- Avoid duplicate subscriptions and duplicate tour records.
- Recover committed data after unexpected termination.

If the selected Flutter plugin cannot satisfy this gate, plan a small native Android tracking layer with Flutter as the UI. This is still a Flutter application. Select one owner for location, notification, and lifecycle commands; do not layer competing tracking services.

### Broad-device compatibility strategy

- **Proposed baseline:** Android 7.0/API 24 and newer, based on current Flutter and `google_maps_flutter` support. Recheck at implementation time; choose the lowest maintained compatible floor rather than artificially restricting devices. This is an engineering proposal, not a user-specified minimum. Sources: [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms), [Google Maps Flutter plugin](https://pub.dev/packages/google_maps_flutter).
- Support ARM64 and ARM32 where maintained dependencies permit; retain x86_64 for suitable emulator/device testing. A bundle can deliver device-appropriate binaries.
- Test older/low-memory devices and recent devices across several manufacturers, Android versions, and battery-management implementations. Include slow/weak GNSS and missing step-sensor cases.
- Do not make an optional step sensor an installation requirement for the entire app. Report indoor capability separately so outdoor tours can remain usable.
- Google Maps relies on its supported Google services environment. Detect unavailable services and preserve tracking/history; assess an OSM renderer fallback for full map coverage on non-Google devices before claiming universal map support.
- Use current Play-required target SDK and current compatible tooling at release; minimum supported API and target SDK serve different purposes.

Pin compatible stable Flutter, Dart, Android SDK, and dependency versions at implementation time. Report a tested support matrix and capability-specific limitations rather than claiming every Android phone works identically.

## 7. Measurement requirements and proposed accuracy strategy

### 7.1 Define the measurement contract

- Persist distance internally in metres at full calculation precision; round only when presenting it.
- For outdoor tours, sum accepted geodesic segments on the Earth's surface for the confirmed horizontal-distance mode. Do not measure screen pixels or distances in the map projection. Indoor tours use their separate measurement strategy, not a GPS segment sum.
- Distinguish raw fixes, accepted measurement geometry, and simplified display geometry.
- Never recompute measurement distance from a simplified map polyline.
- Never snap the recorded route to roads or request a routing service to replace measured distance; walking tours may use unmapped paths and cross open spaces.
- Describe degraded or missing measurements explicitly. A missing path cannot be recovered accurately just by drawing a line between its endpoints.

### 7.2 Acquire usable location data

- Request precise location and high-accuracy acquisition for outdoor tracking; the user has accepted higher battery consumption in pursuit of accuracy.
- Treat approximately one update per second as an initial experiment, not a delivery guarantee or a fixed final setting.
- Avoid a large operating-system distance filter that could remove short turns and slow walking before the app can evaluate them.
- Check fix freshness when starting and resuming; do not use an old cached location as the start of a new segment.
- Record available horizontal accuracy, speed and speed accuracy, source timestamps, provider information, and mock-location status for evaluation.
- Use elapsed-realtime timestamps for ordering and duration within a boot cycle; store wall-clock timestamps for dates shown to the user. Account for reboot boundaries separately.

Android reports horizontal accuracy as an estimated 68th-percentile radius, not a guarantee of route-distance error. Its elapsed-realtime clock is monotonic within a boot cycle and includes deep sleep. Source: [Android Location reference](https://developer.android.com/reference/android/location/Location).

### 7.3 Filter without systematically undercounting

1. **Validate:** reject invalid coordinates, stale fixes, duplicate fixes, and non-increasing measurement timestamps. Process delayed batches by measurement time and lifecycle boundaries, not callback arrival time.
2. **Evaluate quality:** use horizontal uncertainty and recent consistency to distinguish usable, degraded, and unusable fixes. Determine thresholds from field data.
3. **Reject isolated outliers:** evaluate implied speed, acceleration, elapsed time, and uncertainty. Use activity type as context, not a brittle cutoff that rejects a legitimate sprint.
4. **Control stationary drift:** evaluate several samples and available speed evidence before accumulating apparent movement. Keep this separate from automatic pause: filtering stationary noise must not silently change the timer.
5. **Preserve slow motion and corners:** do not discard every step shorter than its reported accuracy radius. That approach can erase genuine slow walking. Compare a multi-sample approach with a simple baseline.
6. **Evaluate smoothing:** compare minimal filtering with an uncertainty-aware estimator. Adopt the more complex method only if it improves held-out distance measurements without cutting corners or delaying movement excessively.
7. **Accumulate accepted segments:** calculate geodesic distance only within an uninterrupted valid recording segment. Maintain stable totals consistently across live view and saved details.
8. **Handle uncertainty honestly:** show quality and gap indicators; do not claim that an instantaneous GPS accuracy radius is the total tour's error bound.

All filter constants are calibration outputs, not settled product requirements. Preserve enough local diagnostic data during validation to replay identical tours through candidate algorithms; establish production retention before release.

### 7.4 Pause and signal-loss rules

- Explicitly paused intervals add neither distance nor active duration.
- Outdoor resume starts a new route segment after a fresh usable fix. Movement while paused must never be connected into measured distance. Indoor resume establishes a new sensor baseline instead of waiting for GPS.
- A briefly rejected outlier may be skipped only if the neighboring accepted fixes still satisfy temporal and motion continuity checks.
- A sustained GPS gap, permission loss, or tracking interruption breaks the segment. Do not add a straight-line bridge across the unknown path.
- During GPS loss while the tour is still recording, the proposed active timer continues; distance is marked incomplete rather than treating signal loss as a user pause. Confirm this duration policy in the measurement contract.
- On reacquisition, restart from a trustworthy anchor and preserve the gap in stored geometry.
- Implement optional automatic pause, off by default until the user enables it, with separate pause/resume thresholds and dwell times; validate slow walking and keep manual pause authoritative. Automatic detection must never resume a manually paused tour. Remember the user's preference across launches; do not enable it silently during an upgrade.
- Save pause reason and boundaries. During automatic pause, continue only the sensing needed to detect resumption; calibration must assess resume latency and avoid systematically losing initial movement.
- Select detection inputs by mode: reliable motion/location evidence outdoors and step/cadence evidence indoors. A stationary or unavailable GPS position must not pause an indoor tour while steps are being detected.
- Decide pause boundaries from timestamped evidence, with a bounded buffer if necessary, so delayed sensor batches are not allocated to the wrong interval. Keep any reconciliation consistent in live and saved totals.

### 7.5 Duration and pace

Confirmed definitions:

- **Elapsed duration:** wall span between tour start and end, including pauses.
- **Active duration:** accumulated recording intervals, excluding manual pauses and enabled automatic pauses.
- **Average pace:** active duration divided by measured distance, formatted as minutes per selected distance unit.
- Show an unavailable pace for zero/insufficient valid distance; do not divide by zero.
- If distance is incomplete because of a gap, label pace as affected too.
- Derive durations from persisted interval boundaries and a monotonic clock while running, not from the number of UI timer callbacks.
- Impose no duration cap, timed automatic ending, or history truncation based on tour length. Keep in-memory buffers bounded and persist incrementally so long tours do not require holding all samples in RAM; load and render saved routes in bounded chunks or levels of detail without changing measured totals.
- Kilometres are the initial display default; users can switch to miles. Show pace as min/km or min/mile accordingly, without modifying the stored metre-based measurement.

### 7.6 Indoor measurement — confirmed calibrated step-based approach

The user confirmed indoor step counting, approximate distance calculated using calibration, and “Route unavailable indoors.” No indoor geographic positioning or dedicated treadmill integration is required. Detailed sensor selection and calibration parameters remain engineering decisions to validate.

- Offer explicit Indoor mode; do not silently switch an outdoor tour into step-estimated distance whenever GPS becomes weak.
- Use phone-carried step sensing with separate calibrated walking and running step lengths. Estimate distance from accepted step increments and the applicable calibration. Avoid an uncalibrated height-based formula presented as precise measurement.
- Provide calibration over a known-distance course: collect steps for the selected Walk/Run activity and derive distance per step from the reference distance divided by counted steps. Validate nonzero inputs, allow recalibration, and assess speed-dependent step-length changes and repeatability. Before calibration is available, show steps but mark distance as awaiting calibration rather than substituting an assumed personal step length.
- Explain that the phone must move with the person; a phone left on a stationary surface cannot measure the person's steps reliably. Missing sensors or denied activity-recognition permission must produce an honest capability state, not invented distance.
- When suitable step sensing is unavailable, make Indoor start unavailable with a clear explanation; do not offer manual distance entry or a substitute measurement method. If sensing becomes unavailable during a tour, preserve collected data and mark the interruption without inventing additional steps or distance. Calibration's known reference distance is a calibration input, not manual entry of a tour's result.
- Use cumulative-counter deltas with explicit baselines and reset/reboot handling. Prefer timestamped step events where necessary to allocate movement around pauses and enable prompt automatic resume. Sensor batching/latency must be measured; do not assign an entire delayed count to its delivery time.
- Do not add indoor step distance to outdoor GPS distance for the same interval. Store the measurement method and calibration snapshot with each tour; future calibration must not silently rewrite old tour totals.
- Label indoor distance and pace as estimated. Agree separate indoor accuracy criteria after reference trials; outdoor GPS error targets do not apply to indoor estimation.
- Display and save the tour's step count as well as its approximate distance. Exclude steps taken during manual or enabled automatic pauses from the tour's counted steps and distance, using the same timestamped interval rules.
- Step counts do not provide geographic path geometry. Show a map section saying “Route unavailable indoors,” not a drawn indoor route. This exception to the original map requirement is explicitly accepted.
- Treat full inertial indoor positioning, floor plans, Bluetooth beacons, wearables, and treadmill integrations as separate scope, not an implied part of basic indoor tracking.

Android provides step-counter and step-detector sensor types, with activity-recognition permission on Android 10 and later. Their documented latency differs; test both capability and screen-off delivery on supported phones. Sources: [Android motion sensors](https://developer.android.com/develop/sensors-and-location/sensors/sensors_motion), [Sensor reference](https://developer.android.com/reference/android/hardware/Sensor).

## 8. Background recording and permission requirements

For outdoor tours, start a location-type foreground service as part of the user's Start tour action while the activity is visible. Declare the appropriate foreground-service and location permissions for the supported Android versions. Do not request all-the-time location solely because the screen can turn off: Android supports while-in-use location through an appropriately started foreground service. Validate the chosen integration against current platform rules. Sources: [foreground location access](https://developer.android.com/training/permissions/requesting), [foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [service-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).

For the confirmed step-based indoor mode, evaluate a health-type foreground service with activity-recognition permission where required. Android lists activity recognition as a qualifying permission for this service type. Do not require GPS permission, heart-rate access, body sensors, or Health Connect merely to count steps. Use only the service types needed for the active tracking mode and verify older-version behavior. Source: [Android health foreground services](https://developer.android.com/develop/background-work/services/fgs/service-types#health).

Required behavior and implementation evaluations:

- Provide an ongoing tour notification with clear recording/paused state and an action to reopen the tour. Evaluate Pause/Resume and End actions through the same serialized command handler as the UI.
- On Android versions requiring notification permission, explain and request it. Denial can hide the foreground-service notification from the notification drawer even though Android still exposes the service through its task manager; do not promise a visible notification without permission. Source: [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission).
- Handle approximate-only location, denied/revoked location or activity-recognition permission, unavailable sensors, location services being disabled, battery saver, and loss of notification visibility explicitly. Only block the mode that needs the unavailable capability.
- Use wake locks only where device testing proves they are necessary; keep them scoped to recording and release them reliably.
- End tour stops acquisition and releases tracking resources after final persistence.
- A recording service is not an immortality guarantee. Test UI removal, process death, system stop, manufacturer power management, and explicit force-stop separately.
- Explicit force-stop or reboot must not be described as uninterrupted tracking. Preserve committed data and show an interrupted tour on next launch; automatic background restart is not a confirmed requirement.
- Do not use periodic work scheduling as the live GPS recording mechanism.

## 9. Zero-cost online maps and saved tour rendering

**Hard constraint:** map-service expenditure must remain zero. Exclude paid subscriptions, paid map features, expiring trial credits, and metered free tiers that automatically incur overage charges. The app is free and ad-free; advertising must not be introduced to fund maps.

### Recommended primary option: native Google Maps

Use `google_maps_flutter` with the standard Android Maps SDK, **without a map ID**, for ordinary basemap display, local route polylines, and start/end markers. The user explicitly permits Google Maps; an open-source map provider is no longer mandatory.

Pricing evidence recorded in the source material on 2026-10-30 (not revalidated in this document conversion): Google's Maps SDK SKU lists an unlimited free-usage cap. Native map loads without a map ID use this SKU; native map loads with a map ID trigger the separately priced Dynamic Maps SKU. Sources: [Google pricing table](https://developers.google.com/maps/billing-and-pricing/pricing), [SKU triggers](https://developers.google.com/maps/billing-and-pricing/sku-details#maps-sdk).

Implementation constraints for the no-charge recommendation:

- A billing-enabled Google Cloud project and restricted Android API key are still required. No-charge map usage does not mean no account setup. Source: [Maps SDK Android usage and billing](https://developers.google.com/maps/documentation/android-sdk/usage-and-billing).
- Do not configure a map ID, cloud-based styling that requires one, Street View, Places, geocoding, Routes, or other paid APIs for this feature set. Verify actual SKU usage in the billing console during the integration test.
- Draw the locally recorded tour directly; no paid route-calculation API is needed to connect its accepted points.
- Restrict keys to the intended API, Android package name, and signing certificate fingerprints; include the Play app-signing certificate for distributed builds.
- Disable unnecessary APIs and add billing alerts. Alerts are not hard spending caps; use supported quotas where applicable and do not depend on alerts to prevent charges.
- Recheck pricing and SDK behavior before release and during maintenance. If a provider changes terms so this configuration would incur charges, stop using the affected service and evaluate only zero-cost replacements; never silently accept charges. If no compliant zero-cost source is available, preserve tracking/history and show the saved route outline with basemap-unavailable status. This degraded view is not a substitute for satisfying the online-map release requirement.

### OSM-based alternative and compatibility fallback

Evaluate `flutter_map` with a compliant OpenStreetMap-derived online source if Google services are unavailable on devices the app aims to support, account setup is unsuitable, or pricing changes. Keep route storage and measurement independent of the renderer so this does not require rewriting tour data.

The standard OSM public raster service is a possible low-volume, policy-compliant source, not guaranteed hosting for an arbitrarily large public app; access is best-effort and can be blocked. It requires attribution, app identification, and compliant caching, and forbids bulk downloads/prefetch. Evaluate any alternative against permitted public-app usage and zero expenditure; do not assume free map data makes third-party or self-hosted tile delivery free. No paid provider fallback is allowed. Sources: [flutter_map documentation](https://docs.fleaflet.dev/), [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/).

Decide during the compatibility spike whether to ship both renderers or document the Google-services requirement. Broad compatibility is the goal; do not claim full map support on non-Google devices without testing the fallback.

### Shared behavior

- Draw the accepted tour geometry, current location where relevant, and start/end markers.
- Fit a completed tour to the viewport; preserve multiple segments across pauses and gaps.
- Keep visible map-data attribution and any provider-required attribution.
- Make tile failures nonfatal: recording, statistics, local history, and saved route geometry must remain usable.
- Store coordinates in the tour database, not only in a screenshot or map cache.
- Map providers receive map requests and may process additional SDK data; audit the selected SDK's disclosures for the public release. Distinguish this from uploading the saved tour database. Do not add a route-upload service.
- Indoor tours display “Route unavailable indoors” as confirmed in Section 7.6; do not request location permission or load a basemap solely to fill that section.

### Connectivity and caching

- Select a provider whose terms fit the expected use and scale.
- Let the native Google SDK manage its map content; do not extract/cache Google tiles through a separate map client. For an OSM-based renderer, implement provider-compliant request identification and caching with bounded disk use.
- An offline-opened tour still displays saved metrics and outdoor route geometry, using a simple local route-outline view if the map SDK cannot render without its basemap. Disclose when background maps are unavailable.
- Do not promise that a previously viewed route has a complete offline basemap merely because some tiles were cached.
- Do not build downloadable regions, offline-map packages, or download-management screens; offline maps are explicitly not required.

## 10. Data, persistence, privacy, and recovery requirements

### Accepted storage decision

Use **one embedded SQLite database stored on the Android device in private app storage, outside cache directories**, as the authoritative store for tours, route points/segments, recording events/checkpoints, calibration, and preferences. This is local file-backed storage, not a separate database service: saving and reopening tours requires no server, database hosting, cloud account, or internet connection. Online basemap access remains a separate concern.

SQLite is selected over plain JSON/JSONL text files because the app must incrementally record long tours, keep measurements and lifecycle state consistent, recover committed progress after interruption, and query history without loading every route. Transactions and indexed queries provide the foundation without implementing custom text-file indexing and transactional recovery. The exact tables, indexes, binding, migration tooling, and commit/checkpoint cadence remain engineering decisions; the logical records below define the required information rather than a fixed physical schema.

Persist progress during recording and make consistent commits at pause, resume, and end. SQLite does not eliminate the possible loss of uncommitted measurements: bound and measure that window, and never claim a failed write succeeded. Normal app restarts and supported upgrades must preserve history. Android removes app-specific storage when the app is uninstalled; this decision does not promise survival after uninstall or clearing app data. Backup behavior remains an explicit implementation/release decision, and export is not added to scope. References: [SQLite as an application file format](https://www.sqlite.org/appfileformat.html), [Android app-specific storage](https://developer.android.com/training/data-storage/app-specific).

### Logical records

| Record | Required information (logical model) |
| --- | --- |
| Tour | Stable ID; Walk/Run type; Outdoor/Indoor mode; recording/paused/completed/interrupted status and pause reason; start/end timestamps with display timezone context; active/elapsed duration; indoor counted steps; measured/estimated distance and source; route-availability state; quality/gap summary; measurement algorithm/configuration version; automatic-pause configuration snapshot. |
| Location sample | Tour ID; sequence ID; wall and monotonic timestamps with boot/session context; coordinates; available uncertainty/speed metadata; acceptance decision and reason; segment ID. |
| Indoor sample/calibration | Timestamped step events/counter deltas, reset context, active-interval assignment, activity-specific calibration and reference method, immutable calibration snapshot/version used for the tour. |
| Route segment | Tour ID; ordered accepted positions or references to samples; boundary reason such as initial fix, resume, or signal reacquisition. |
| Lifecycle event | Start, manual/automatic pause, manual/automatic resume, end, interruption, and permission/provider changes with timestamps and ordering information. |
| Tracking checkpoint | Last committed sequence and consistent metric/filter state, or sufficient state to replay from a known checkpoint. |
| Preferences | Selected km/miles (initial km); automatic-pause preference (initially off, then persist the user's choice); translation-ready locale preference structure without requiring additional translations now. |

### Persistence requirements

- Atomically commit samples/events and corresponding totals, or replay deterministically from the committed journal. Avoid a displayed total that cannot be recovered from stored data.
- Make lifecycle commands idempotent: repeated End tour events must not duplicate or corrupt a tour.
- Serialize ownership of an active tour and prevent two concurrent recording pipelines.
- Flush state at pause, resume, and end. Measure and document the maximum possible uncommitted tail after abrupt termination; never promise zero loss without proving it.
- On launch, reconcile any unfinished tour, preserve its committed data, and clearly present recovery/end options without fabricating missing distance or duration.
- Define database migrations and verify that app upgrades preserve existing tours.
- Handle storage exhaustion and database-write failure visibly; never claim a tour is safely saved when persistence failed.
- Keep tour data in app-private phone storage. Explicitly configure Android backup behavior so “local” is not silently treated as cloud backup; decide retention and any future deletion/export features separately.
- Retain completed tour summaries and route geometry for reopening. Raw rejected samples and verbose diagnostics may have a separate retention policy; never prune required route geometry under the guise of clearing map cache.

## 11. Success metrics and validation requirements

### Establish a reference

Use a reliably measured route such as a measured course, a carefully followed marked track lane, or a route measured independently with a suitable reference. Record the actual path followed, phone placement, environment, pace, and device configuration. Another consumer GPS app is a comparison, not ground truth.

Evaluate walking and running separately, including slow walking, sharp turns, repeated loops, and stop/start behavior. Split tuning tours from held-out validation tours; do not calibrate and report success on the same routes only.

For indoor tours, use independently measured indoor courses and compare detected steps with an independent observed step count. Evaluate calibration on different tours, speeds, and phone placements, including pockets, phone-in-hand, and a stationary phone to verify honest failure behavior. Test with and without automatic pause. Indoor estimate error must be reported separately; do not reuse outdoor GPS accuracy claims.

### Metrics

- Signed distance error and absolute percentage error against the reference.
- Median and worst/tail errors by device, activity, environment, and phone placement.
- Stationary false-distance accumulation.
- Missed initial movement, corner-cutting, and slow-walking undercount.
- Gap duration, rejected-fix fraction, and reacquisition time.
- Battery drain per hour, temperature, and storage growth.
- Committed-data loss window after interruption and saved/live-total consistency.

### Candidate accuracy targets and mandatory behavioral checks

The numerical outdoor accuracy targets below are proposals, not guarantees; confirm or revise them after selecting devices and collecting baseline measurements. Indoor and automatic-pause tolerances remain to be established. Behavioral checks such as excluding paused movement, preserving saved values, and never bridging gaps remain mandatory regardless of numerical tuning.

| Scenario | Candidate target or required validation |
| --- | --- |
| Open-sky, measured tours of at least 1 km | Median absolute distance error at most 2%; aim for at most 5% at the 95th percentile only when the sample count supports that statistic. Report sample size and worst case. |
| Stationary phone under open sky | At most 10 m of false accumulated distance over 10 minutes. |
| Indoor steps and distance | Validate step count against observed steps and approximate distance against measured courses; set numerical targets after baseline reference trials. Save/reopen both values unchanged; display “Route unavailable indoors.” No GPS-level precision promise. |
| Automatic pause | Correctly distinguish stopping from slow walking and indoor stepping; report false-pause rate, pause/resume latency, and resulting distance/time error. Set numeric tolerances from the validation baseline. |
| Manually paused movement | Exactly zero distance and active-duration contribution from the paused interval. |
| GPS gap or resume | No counted connector across a declared gap or pause; clearly mark incompleteness. |
| End and reopen | Saved distance matches the final live value at displayed precision; start/end and route remain available after relaunch. |
| Long-running screen-off recording | Run progressively longer physical-device sessions and long-duration data replays; record tested durations, recording gaps, memory/storage growth, and recovery results. Verify no app-imposed timeout or duration overflow. Finite test sessions are not a maximum supported tour length. |
| Battery | Accuracy-first/higher drain is accepted. Measure battery drain per hour and heat across the device matrix to characterize behavior and detect regressions; no user-defined battery budget or longest-tour target is required. |

Urban canyons, tree cover, tunnels, and indoor spaces require separately reported results. Do not promise the open-sky target in environments where the phone cannot observe a reliable path. Do not hide failed runs or tune away difficult cases.

### Verification matrix

| Layer | Essential cases |
| --- | --- |
| Measurement replay tests | Stationary noise; slow motion; normal walk/run; sharp corners; isolated jumps; stale/duplicate/out-of-order fixes; delayed batches; long gaps; manual/automatic pause interaction; zero-distance pace; clock changes; indoor step counter resets and delayed events; unchanged historic estimates after calibration changes. |
| Persistence tests | Start/end saved automatically; repeated commands; interrupted writes; process restart; storage failure; migration of existing tours; no duplicate accumulation after replay. |
| UI/integration tests | Start/pause/resume/end; automatic pause initially off and persisted after opt-in; indoor unavailable without suitable sensing and no manual-entry fallback; notification commands; tour history/detail; absent route; permission denial/revocation; map-network failure; preserved route geometry; km default and km/mile switching; both durations; translation resources and text expansion. |
| Physical-device tests | Locked screen; background/foreground transitions; UI removal; battery saver; app/process/system stop; force-stop; reboot; phone carried in hand and pocket; long tours. |
| Map tests | Correct start/end markers; separated segments; attribution; provider/API-key failure; no unintended paid Google SKU; no map ID; no-network route-outline fallback; non-Google-services behavior; confirmed indoor “Route unavailable indoors” state without fabricated geometry. |
| Release tests | Install release APK on representative phones; complete and reopen outdoor and indoor tours; upgrade without losing history; verify signing and supported architectures; install Play-delivered bundle builds through a test track. |

## 12. Delivery roadmap and release requirements

These milestones sequence delivery of the requirements. They are future work, not evidence of an implemented or released app. [PLAN.md](PLAN.md) starts with `001-build-scaffold`: a working code template used as the reference architecture by later changes, not a product-feature implementation. Confirm the publisher application ID before generating its Android shell; carry remaining setup work forward without duplicating the scaffold.

| Phase | Work | Exit condition |
| --- | --- | --- |
| 0 — Confirm implementation setup | Carry forward the settled requirements: free-tracker, no indoor fallback/manual entry, automatic pause initially off, no app-imposed duration limit, free/ad-free app, zero-cost maps. Confirm the publisher's technical application ID before scaffolding and verify map-account prerequisites. | Setup details recorded without reopening answered product questions or introducing paid maps. |
| 1 — Prove Android tracking and compatibility | Foreground-service/location/sensor/persistence spike on representative phones; examine metadata, sensor availability, Google services, and lifecycle limits; select adapters and supported API floor. | Screen-off recording and durable recovery demonstrated for supported modes; capability matrix and architecture chosen from evidence. |
| 2 — Establish measurement baseline | Capture outdoor and selected indoor reference tours; implement baselines/replay; compare GPS filters, indoor calibration, and automatic-pause detection; document tuning. | Reproducible mode-specific error/battery measurements and initial calibrated measurement strategies. |
| 3 — Complete tour lifecycle/storage | Durable Start/Pause/Resume/End, consistent timers, recovery, history, and migrations. | Every started tour is preserved; completed tours reopen with correct start/end/distance. |
| 4 — Add maps and complete UX | Online live/historical maps; confirmed indoor presentation; markers; quality states; notification integration; attribution; km/mile controls; both durations; localization resources. Verify no-charge Google configuration. | Every saved tour opens with stored measurements and its available route or agreed indoor state; map failures never stop recording. |
| 5 — Field validation/hardening | Held-out route tests and lifecycle/device matrix; tune only with documented evidence; finalize filter settings; document long-running reliability, battery drain, and heat without imposing a tour-duration limit. | Agreed release gates pass, with limitations documented and no unresolved tour-loss defect. |
| 6 — Package and hand over | Signed release APK and Play-ready Android App Bundle; version/build instructions; installation guide; accuracy/device report; dependency and map notices. | APK and test-track bundle installs pass end-to-end tour/reopen tests on the supported matrix. |
| 7 — Prepare eventual public release | Play listing, privacy disclosures, app-content declarations, signing/account setup, required testing, and staged release preparation. | Publication package and required tests are complete; actual publication is a separate future action, not authorized by this document. |

Dependencies: Phase 0 precedes affected technology commitments; Phase 1 precedes UI-heavy work; Phase 2 precedes accuracy claims; Phase 3 precedes complete history/map integration; Phase 5 precedes release. Public-release account/testing lead time can be prepared earlier once implementation is authorized. Do not estimate calendar dates until deferred setup, engineering decisions, test resources, and account-specific release requirements are known.

For the eventual APK and App Bundle, define ownership and secure storage of signing/upload keys, keep credentials out of the repository, and preserve the signing identity needed for upgrades. Distinguish the Play app-signing key from the upload key, including map API-key restrictions for each installed build. Source: [Flutter Android release documentation](https://docs.flutter.dev/deployment/android).

### Public Play Store preparation

- Prepare the Android App Bundle under the confirmed app name **free-tracker**, the publisher-confirmed application ID, store description/screenshots, content rating, support contact, and distribution settings. List the app as free and accurately declare that it contains no ads.
- Recheck then-current target SDK, native dependency/architecture compatibility, and Play foreground-service requirements before release.
- Publish a privacy policy and complete accurate Data safety and applicable foreground-service declarations. Account for local location/activity storage and the map SDK's data practices; local tour storage does not prove every dependency is network-free.
- Complete the Health apps declaration for activity/fitness tracking. Source: [Google Play health declaration](https://support.google.com/googleplay/android-developer/answer/14738291).
- Include an in-app privacy policy and public policy URL appropriate to the fitness functionality. Source: [Google Play health/privacy requirements](https://support.google.com/googleplay/android-developer/answer/18258653).
- Determine developer-account type, verification, fees, and testing obligations at release preparation. The source material recorded on 2026-10-30 that qualifying newer personal accounts required at least 12 opted-in closed testers continuously for 14 days before applying for production access; do not assume this applies to every account or guarantees approval. Source: [Play account testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).
- Test upgrades and recovery using Play-distributed builds, review crash/ANR results, then prepare staged rollout and rollback instructions.
- Track any publisher-account or hosting costs separately from map API usage. This PRD does not authorize account creation, purchases, or app publication.

## 13. Release acceptance checklist

- [ ] The user can start, pause, resume, and end a walking or running **tour**.
- [ ] Optional automatic pause is initially off, remembers the user's choice, and works in each supported mode; manual pause cannot be overridden by automatic resume.
- [ ] Indoor tours count and save steps, estimate distance using calibration, and display “Route unavailable indoors”; calibration/capability limits and estimate labels are documented.
- [ ] Kilometres are the default; miles are selectable without rewriting historical measurements.
- [ ] Tour details show total elapsed time and active time; average pace uses active time.
- [ ] Live distance, duration, and average pace follow the agreed measurement definitions.
- [ ] GPS filtering improves independently measured accuracy without unacceptable slow-motion or corner undercount.
- [ ] Screen-off recording passes documented long-running device tests and provides the expected ongoing notification when permission is granted; there is no app-imposed tour-duration limit.
- [ ] Indoor tracking is unavailable without suitable step sensing; no fallback/manual tour-distance entry is offered.
- [ ] **Every tour is saved on the phone and can be reopened with start, end, and distance; outdoor tours show their recorded route map, while indoor tours show saved steps, approximate distance, and “Route unavailable indoors.”**
- [ ] Pauses and missing GPS sections do not produce invented connecting distance.
- [ ] Interrupted and no-fix tours remain visible with truthful status and missing-data information.
- [ ] Saved tour geometry survives relaunch, app upgrades, and map-cache clearing.
- [ ] Tours and recording progress are persisted in the on-device SQLite database outside cache storage; transaction/recovery tests verify consistent committed state and document the maximum uncommitted loss window.
- [ ] Online maps generate zero map-service charges, with no paid features or paid fallback; attribution and provider terms are satisfied. Offline map downloads are not required.
- [ ] The app is named **free-tracker**, is free to users, and contains no ads or advertising SDKs.
- [ ] English text and formatting are translation-ready, including notifications.
- [ ] Accuracy, reliability, and battery results are documented for supported devices.
- [ ] A signed installable APK passes the final physical-device smoke test.
- [ ] A Play-ready App Bundle and eventual public-release preparation are completed according to the staged roadmap.
