# free-tracker
Free Tracker is a free, ad-free, open-source Android app for tracking walking and running tours, measuring distance, and viewing outdoor routes on a map.

## Testing

```shell
make unit-test
make end-to-end-test ANDROID_DEVICE_ID=emulator-5554
```

Use Flutter 3.47.9 (Dart 3.13.7), run `flutter pub get` and `flutter gen-l10n`
before analysis/build. Select the actual current Android ID explicitly for E2E;
the example is the local replacement emulator. Missing tools/devices and empty
or failing suites return nonzero.

The current app is a localized installed-app-information reference slice, not
tour recording. Unit runs tooling fault checks, plain-Dart domain/application
tests and Flutter layer/widget tests, with 100% executable handwritten Dart line
coverage. Android E2E includes controlled failure/recovery and real metadata.
SQLite is not yet introduced; S005/S009 must add real-database integration checks.
See [extension/setup guide](agent/reference-scaffold.md) and
[execution evidence](agent/s001-evidence.md) for commands, versions and limits.
The [setup handoff](agent/setup-decisions.md) records remaining phone, account,
map and release prerequisites. `python3 tool/check_scaffold.py` checks its local
consistency read-only; a pass does not verify unknown external facts.
