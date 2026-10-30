# Local development environment

> **Current completion policy (2026-10-31):** This record preserves dated evidence. Current implementation/findings-fix completion requires both complete Make suites to pass and a distinct executed E2E test for every implemented change-case row; see [IMPLEMENT §4](IMPLEMENT.md#4-verification-and-completion-gates). Historical N/A/not-run results below are not exemptions.

**Verified:** 2026-10-30, 20:30 UTC, on the local Fedora 43 x86_64 host.
**Scope:** environment recovery for S001, not app implementation or a delivery-gate pass.

## Repository and identity

- Selected change: [S001](changes/001-build-scaffold.md), branch `change/001-build-scaffold`.
- Checkout HEAD at verification: `9590cda0935f82f82da5e4a199158b3ce9847972`.
- Local `dev` and remote `refs/heads/dev`: `4129ed7af7dbf063c8220ca13b8299779a61b09b`.
- `git ls-remote origin refs/heads/dev` exited 0 and confirmed that remote value.
  This was a read-only verification, not a fetch, rebase, merge or branch reset.
  Reverify before implementation/integration; this snapshot does not freeze the remote.
- D01 is resolved: public name `free-tracker`, publisher-confirmed application ID
  `com.bindefined.freetracker`; see [PRD §3](PRD.md#deferred-implementation-and-release-setup).

## Observed tooling

These are installed versions, not a pinned or app-build-validated dependency stack.

| Component | Observed value |
| --- | --- |
| Flutter | Stable 3.47.9; framework revision `c197ca5199`; SDK `/home/vito/flutter` |
| Dart | 3.13.7 |
| Java | OpenJDK 21.0.12.1.1; `/usr/lib/jvm/java-21-openjdk/bin/java` |
| Android SDK | `/home/vito/Android/Sdk`; installed platform `android-36`, build-tools 36.0.0; licenses accepted |
| Android Emulator | 37.2.13, build 16740729 |
| ADB | 1.0.41; platform-tools version 37.0.1-15733141 |
| Guest image | Android 17 / API 37, `google_apis_playstore`, x86_64, image revision 7 |
| Host acceleration | `emulator -accel-check` reported KVM installed and usable |
| Host graphics | NVIDIA GeForce GTX 1660 SUPER; driver 580.178.04 |

The guest's API 37 is not the app's minimum, compile or target SDK decision.
D03 still requires compatible Flutter/plugin/Gradle/AGP selections, reproducible
pinning and build evidence. D05's presentation approach also remains pending.

## Sandbox restrictions and host execution

Inside the restricted agent sandbox, Flutter SDK cache writes failed with
`Read-only file system`, ADB could not create its listener (`Operation not
permitted`), and SSH rejected `/etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf`
permissions. Approved execution outside that sandbox succeeded for Flutter,
ADB and remote Git verification. No system SSH configuration permissions were
changed, and the sandbox restrictions themselves were not removed.

Use the execution environment's approval mechanism for commands that need host
SDK writes, ADB sockets, emulator/KVM access or host SSH configuration. Running
the same command inside the restricted sandbox can still fail; this is not
evidence that the host tooling is absent.

`scripts/codex-code-implement.pl` now explicitly launches Codex with
`--approve-for-me`, retaining the workspace-write sandbox while enabling
automatically reviewed escalation requests in the non-interactive implementation
run. Retry sandbox-denied prerequisite commands through that mechanism before
concluding the host environment is unavailable. This is not unconditional host
access: managed restrictions, genuine missing prerequisites and review denials
still apply. See [launcher documentation](../scripts/README.md#codex-code-implementpl).

## Emulator recovery and saved configuration

The original `Medium_Phone_API_37.0` AVD crashed with exit 139. Its SwiftShader
retry's core dump contained frames in `gles_swiftshader/libGLESv2.so`. Host-GPU
rendering avoided that crash, but the original AVD still boot-looped with repeated
zygote restarts and never established an online Android ADB connection.

A separate **`Free_Tracker_API_37`** AVD was created using the same installed image.
It booted successfully and was verified again after restarting with saved settings,
without temporary GPU, CPU, memory, camera or Vulkan overrides. The original AVD
and its data were retained, not wiped. A fresh AVD working with the same image
points to an original AVD data/configuration issue; its exact boot-loop cause
was not established, and the original AVD is not claimed repaired.

Saved replacement configuration:
`/home/vito/.android/avd/Free_Tracker_API_37.avd/config.ini`.
The pre-edit backup is `config.ini.before-emulator-fix` in the same directory.

| Setting | Saved value |
| --- | --- |
| `hw.gpu.enabled` | `yes` |
| `hw.gpu.mode` | `host` |
| `hw.ramSize` | `4096` (MB) |
| `hw.cpu.ncore` | `4` |
| `PlayStore.enabled` | `true` |

### Start and select the replacement

On this host, start it in a separate terminal if it is not already running:

```shell
"$HOME/Android/Sdk/emulator/emulator" -avd Free_Tracker_API_37 -no-window -no-audio -no-snapshot
```

Then check the device and select its current ID explicitly:

```shell
adb devices -l
export ANDROID_DEVICE_ID=emulator-5554
adb -s "$ANDROID_DEVICE_ID" emu avd name
adb -s "$ANDROID_DEVICE_ID" shell getprop sys.boot_completed
flutter devices --device-timeout 10
```

At verification the AVD was running as `emulator-5554`; IDs can change when other
emulators are running. Confirm the AVD name is `Free_Tracker_API_37`, the ADB state
is `device` (not `offline`/`unauthorized`), and boot completion is `1` before testing.
These host SDK/AVD paths are local setup, not files provisioned by cloning the repo.

## Executed checks and remaining work

| Command / check | Observed result |
| --- | --- |
| `flutter --version` | Exit 0; versions above |
| `flutter doctor -v` | Exit 0; no issues reported, Android toolchain/licenses recognized |
| `flutter devices --device-timeout 10` | Exit 0; Android `emulator-5554` recognized, in addition to desktop/browser targets |
| `adb version`; `adb devices -l` | Both exit 0; replacement online as Android x86_64 |
| `adb -s emulator-5554 shell getprop sys.boot_completed` | Exit 0, output `1` |
| `adb -s emulator-5554 shell getprop ro.product.cpu.abi` | Exit 0, output `x86_64` |
| `adb -s emulator-5554 shell am start -W -a android.settings.SETTINGS` | Exit 0, `Status: ok`; Settings resumed activity confirmed |
| Replacement restart with saved configuration | Emulator log reported boot completed in 11215 ms; screen capture succeeded |
| `git ls-remote origin refs/heads/dev` | Exit 0; exact remote baseline above |
| `make unit-test` | Exit 2; target exists but app suites/coverage enforcement are unavailable |
| `make end-to-end-test` | Exit 2; target exists but app/Android E2E suite is unavailable |

Local diagnostic artifacts (temporary, not portable or committed):
`/tmp/free-tracker-environment-checks.json`,
`/tmp/free-tracker-emulator-verified.log`, and
`/tmp/free-tracker-emulator-fixed.png`. The table above retains the observed
summary if those files are cleaned; rerun checks for fresh evidence.

This documentation update changes no application behavior. Documentation links
and whitespace are the applicable checks; the two Make invocations confirm
unavailability, not app-test success. No Flutter app, APK, coverage report,
production-adapter test or app E2E result exists yet. Environment recovery does
not satisfy S001's unchecked readiness/completion gates. D02 is only partially
evidenced by an emulator: physical phones, map-account suitability, screen-off
tracking, sensor accuracy and field validation remain unverified. S002 carries
these setup records forward; S006/S022/S023 retain their physical-device obligations.
