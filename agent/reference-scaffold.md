# Executable reference scaffold

S001 resumes `change/001-build-scaffold` at `4fbda4b`; readiness verified against
local and remote `dev` `4129ed7af7dbf063c8220ca13b8299779a61b09b` on 2026-10-30.
There is no predecessor dependency. GA is an output, not a prerequisite.
D01: the publisher selected `com.bindefined.freetracker`, recorded in [PRD](PRD.md).

## Decisions before generation

D03 provisional stack: Flutter 3.47.9 revision c197ca5199, Dart 3.13.7;
Java 21.0.12.1.1; AGP 8.13.2, Gradle 8.14 (Flutter minimum; initial 8.13 build rejected), Kotlin 2.2.20 (Flutter minimum); compile/target API 36,
minimum API 24; build-tools 35.0.0, NDK 28.2.13676358. Dependency
`package_info_plus` 10.2.2.
Exact resolved dependencies belong in the app lockfile. API 24 is the installed
Flutter stack's lowest maintained floor, not a physical-device support claim.
The debug build includes ARM32, ARM64 and x86_64; execution is tested on x86_64 only.

Primary compatibility sources checked 2026-10-30:
[Flutter platforms](https://docs.flutter.dev/reference/supported-platforms),
[plugin requirements](https://pub.dev/packages/package_info_plus/versions/10.2.2),
[AGP compatibility](https://developer.android.com/build/releases/agp-8-13-0-release-notes),
[localization](https://docs.flutter.dev/ui/internationalization).

D05 presentation: plain-Dart immutable state and a broadcast stream, bound by
Flutter's built-in StreamBuilder. Constructor injection, no service locator or
additional state/DI framework. The screen owns only its metadata loader lifetime;
this is **not** a future recording-owner pattern. SQLite selection remains S005.

## Extension points

- [Startup](../lib/main.dart) initializes bindings and calls the single
  [composition root](../lib/app/composition.dart); [shell](../lib/app/app.dart)
  owns theme/localization, not metadata rules.
- [Domain](../lib/settings/domain/app_info.dart) validates immutable metadata.
- [Port](../lib/settings/application/app_info_repository.dart) and
  [loader](../lib/settings/application/app_info_loader.dart) use only Dart.
  Loading coalesces; ready loads do nothing; unavailable explicitly retries;
  close ignores pending completions and terminates subscriptions.
- [Adapter](../lib/settings/data/platform_app_info_repository.dart) converts SDK
  objects immediately. Supply a reader for adapter tests or a repository to
  composition for feature tests. Production always defaults to the real reader.
- [Screen](../lib/settings/presentation/app_info_screen.dart) renders and sends
  retry intent. [English catalog](../lib/l10n/app_en.arb) generates bindings into
  `lib/l10n/generated/`; never hand-edit generated Dart.
- [Composition tests](../test/app/composition_test.dart),
  [unit/widget tests](../test), [Android scenarios](../integration_test), and
  [runner fault tests](../tool/tests) retain the S001 case IDs in the change.
- [Makefile](../Makefile), [runner](../tool/run_tests.py),
  [coverage guard](../tool/check_coverage.py), and
  [contract guard](../tool/check_scaffold.py) are app tooling, not workflow scripts.

Imports flow presentation → application → domain; data implements the application
port; app alone composes them. The contract checker traverses imports/exports to
reject transitive framework dependencies in the core and dependency cycles.
S002 carries identity/stack/setup evidence forward. S005 extends these runners
and project with real SQLite transactions/recovery/migrations; do not regenerate
a competing app. S019 extends the same app-information presentation.

## Verification and evidence

Before generation: `python3 tool/check_scaffold.py --pre-generation --application-id com.bindefined.freetracker`.
Then `flutter pub get`, `flutter gen-l10n`, `flutter analyze`,
`dart format --output=none --set-exit-if-changed lib test integration_test`,
`make unit-test`, `make end-to-end-test ANDROID_DEVICE_ID=emulator-5554`,
`flutter build apk --debug`. Unit includes tooling tests and plain-Dart core.
Reports live in `build/test-results/` and `coverage/lcov.info`; invocation reports
are replaced, never reused as current evidence. Missing tools/devices, empty,
skipped or failed suites and incomplete coverage fail. Branch coverage is reported
separately, explicitly unavailable when the Flutter LCOV reporter omits it.
All handwritten lib Dart is inventoried; only exact generator-owned localization
outputs are excluded. Generated localization is behavior-tested.

Current execution evidence will be recorded in [S001 evidence](s001-evidence.md).
Readiness host checks passed: Flutter doctor, remote baseline, ADB online/boot=1;
replacement AVD Free_Tracker_API_37, Android 17/API 37 x86_64, emulator 37.2.13.
SDK /home/vito/Android/Sdk; Flutter /home/vito/flutter. Host commands may need
approved escalation as explained in [environment](development-environment.md).

Manual bootstrap: verify baseline/readiness, implement and run actual required
checks, then caller commits; a separate full-diff review/fix/recheck/re-review
must precede caller integration and serialized verified squash merge. This skill
does not commit, push or merge, nor advance script-owned PLAN gates. Existing
workflow scripts have not passed GW and are not treated as trusted delivery gates.
No separate review or integration is claimed by implementation alone.

No tour, storage, permission, map, sensor, background service, signing, release,
physical-device or accuracy evidence is produced. Real SQLite is N/A **only**
because S001 has no storage behavior; S005/S009 must automate its checks.
Physical tracking gates remain S006/S022/S023. Emulator shell success is not
physical-device tracking validation.
