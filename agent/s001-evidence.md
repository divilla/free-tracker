# S001 implementation evidence

Recorded 2026-10-30 21:17 UTC on Fedora 43 x86_64.
This is implementation/check evidence, not a script-owned delivery-gate update.

## Identity and readiness

- Resumed existing branch `change/001-build-scaffold`; clean tree before edits.
- Source HEAD: `4fbda4b01318ad37a1f8280294d790628c7132fa`, plus the uncommitted
  implementation. Both final runner reports bind to source/test/build-file SHA-256
  `066ceba6b64a239f9e427510c3d335860b9b935bf9911d902fa6bcbd682526b5` (the runner documents its inventory).
- Local `dev` and remote `refs/heads/dev`, verified before edits and again after
  checks: `4129ed7af7dbf063c8220ca13b8299779a61b09b`. Read-only `git ls-remote`
  exited 0; no baseline refresh, switch, commit, push or merge performed.
- Exactly one matching PLAN S001 row; no predecessor dependencies. GA is this
  change's output gate. D01 publisher confirmation is recorded in [PRD §3](PRD.md).
  D03/D05 provisional decisions and next-consumer guidance are in the
  [reference guide](reference-scaffold.md). SQLite selection remains S005.

## Exact environment

| Component | Tested value |
| --- | --- |
| Flutter stable | 3.47.9; framework `c197ca5199e9ee5661e865596c9c07294dfab51c` |
| Engine revision | `89c39edfdfae2949f6806e4a315c0c08522238b7` |
| Dart | 3.13.7 |
| Java | OpenJDK 21.0.12.1.1 |
| AGP / Gradle / Kotlin | 8.13.2 / 8.14 / 2.2.20 |
| Android minimum / compile / target | 24 / 36 / 36 |
| Build-tools / NDK | 35.0.0 / 28.2.13676358 |
| Metadata plugin | package_info_plus 10.2.2; all resolved hashes in app lockfile |
| ADB / emulator | 1.0.41 (platform-tools 37.0.1) / 37.2.13 |
| Android E2E selection | emulator-5554, Free_Tracker_API_37, API 37, x86_64 |
| APK ABIs inspected | arm64-v8a, armeabi-v7a, x86_64; execution on x86_64 only |

SDK and AVD paths/host escalation details remain in [environment](development-environment.md).
The guest API is not the app minimum/target. No physical-phone support claim.

## Executed final checks

All commands below exited **0** on the implementation above.

| Check | Exact command | Result / retained artifact |
| --- | --- | --- |
| Generation preflight | `python3 tool/check_scaffold.py --pre-generation --application-id com.bindefined.freetracker` | Publisher-selected ID accepted before template setup; wrong/missing identities covered by T02 |
| Dependencies | `flutter pub get` | 78 resolved dependencies; [lockfile](../pubspec.lock) |
| Generated resources | `flutter gen-l10n` | Exact two generated Dart outputs reproducible; runner compares bytes before/after regeneration |
| Analysis | `flutter analyze` | No issues |
| Format | `dart format --output=none --set-exit-if-changed lib test integration_test` | 19 files, no differences |
| Plain core | `dart test test/settings/domain test/settings/application --reporter expanded`; final runner uses `--reporter=json` | 22 domain + 10 application tests, no Flutter runtime |
| Unit + coverage | `make unit-test` | 43 Python tooling tests; 32 plain-Dart core tests; Flutter: 22 domain, 10 application, 6 data, 12 localization/widget, 3 composition tests |
| Configuration/boundaries/guide | `python3 tool/check_scaffold.py` | Identity, approved dependencies, transitive/conditional imports/exports, cycles, source-linked guide valid |
| Android E2E + real metadata | `make end-to-end-test ANDROID_DEVICE_ID=emulator-5554` | All E01–E10 plus P01 executed, no skips; real smoke uses production reader without SDK mocks |
| Production debug build | `flutter build apk --debug` | Rebuilt **after** integration tests, target lib/main.dart, not the integration-test entry point |
| APK metadata | `/home/vito/Android/Sdk/build-tools/35.0.0/aapt dump badging build/app/outputs/flutter-apk/app-debug.apk` | ID/name/version 1.0.0+1/API/ABIs confirmed; INTERNET for Flutter debugging and AndroidX internal receiver permission only; no location/activity/notification/foreground-service additions |
| Install and launch | `adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk`; `adb -s emulator-5554 shell am start -W -n com.bindefined.freetracker/.MainActivity` | Install Success; cold launch Status: ok |
| Whitespace | `git diff --check` | No errors |

Reports: [unit summary](../build/test-results/unit/summary.json),
[unit tooling](../build/test-results/unit/tooling.txt),
[plain core JSONL](../build/test-results/unit/core.jsonl),
[Flutter unit JSONL](../build/test-results/unit/flutter.jsonl),
[E2E summary](../build/test-results/e2e/summary.json),
[controlled Android JSONL](../build/test-results/e2e/android-0.jsonl),
[real Android JSONL](../build/test-results/e2e/android-1.jsonl),
[LCOV](../coverage/lcov.info). These generated build artifacts are local/ignored;
rerunning targets replaces them, and this checked-in summary preserves results.

Production APK: [app-debug.apk](../build/app/outputs/flutter-apk/app-debug.apk).
SHA-256: `ebf13db7a58b6c882a52af3a9b96a6e8ad9271c22a9032b3ca179d9d1ff869a0`.
No release signing or distribution evidence; release signing is unconfigured.

## Coverage and traceability

- **103 / 103 executable handwritten Dart lines (100%)** in seven sources,
  including main/composition/shell, domain, loader, adapter and presentation.
- The repository port is an exact pure abstract declaration with zero executable
  lines; the guard inventories it separately, and any added implementation
  immediately makes it require coverage. No handwritten executable logic is excluded.
- Only `lib/l10n/generated/app_localizations.dart` and
  `lib/l10n/generated/app_localizations_en.dart` are generator-owned exclusions.
  Regeneration drift fails; other generated-looking/manual files remain covered.
  Catalog/generated behavior, locale fallback, accessibility, failure/retry and
  expanded messages at 320×568/200% text are tested.
- **Branch coverage unavailable:** Flutter LCOV contains no branch records.
  This is not 100% branch coverage. Loader outcomes, duplicate requests,
  sync/async errors, retry/close variants, metadata boundaries and adapter failure
  classes have explicit behavioral assertions.
- All nine S001 requirements map to T01–T31 in the selected change and to those
  stable IDs in actual tests. Parameter variants retain their parent case ID.
  Shared controlled scenarios execute in both widgets and Android E2E; P01 uses
  no injected reader. T20–T28/T31 fault-inject tool, device, empty/stale/skipped,
  malformed/insufficient coverage and subprocess/Make failures.

## Corrections during verification and remaining gates

Initial builds rejected Gradle 8.13 and Kotlin 2.2.0 against this Flutter SDK's
minimums. Raised to 8.14/2.2.20; no dependency-validation bypass used. The final
compatible stack still emits future-deprecation advice for Gradle/AGP/Kotlin;
re-evaluate when upgrading Flutter. Initial SDK downloads installed the selected
NDK and build-tools. Raw build logs are local `/tmp/free-tracker-s001-build-final.txt`;
APK badging is `/tmp/free-tracker-s001-apk-badging.txt`.

Android E07 initially failed because its fault future was created in the test
callback's different error zone. The live binding cannot transfer Dart errors
between error zones. Create the future inside the injected reader, matching
real I/O creation; retain explicit pending/read-count/close/recreate assertions.
Both complete suites then passed. No assertion weakened or scenario skipped.

Implementation self-check inspected the complete added/modified implementation,
traceability, generated inventory, architecture boundaries, final artifact and
unrelated-file preservation. It is not the separate IMPLEMENT PR-style review.
Caller still owns committing, independent full-diff review/fix/re-review and
latest-dev integration/verified squash merge. PLAN/script-owned gates were not
advanced and no review/merge success is fabricated.

Real SQLite checks are N/A only because S001 introduces no storage. S005/S009
must automate real transactions/recovery/migrations. Tour recording, maps,
sensing, permissions, background behavior, device/field accuracy and release
validation remain future scope. Emulator metadata tests do not satisfy those
physical-device gates.
