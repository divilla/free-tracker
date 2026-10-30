# Setup decisions and prerequisite handoff — S002

Recorded 2026-10-30 UTC. This is a local consistency/resource inventory, not proof
of phone support, account suitability, accuracy, release readiness or workflow delivery.
S002 extends the [existing scaffold](reference-scaffold.md) under the
[selected change](changes/002-setup-decisions.md), [PRD](PRD.md),
[architecture](ARCHITECTURE.md), [PLAN](PLAN.md) and [IMPLEMENT](IMPLEMENT.md).

## Identity and constraints

| Field | Value |
| --- | --- |
| Public name | free-tracker |
| Application ID | com.bindefined.freetracker |
| Platform | Flutter Android |
| Pricing | free; no ads |
| Modes | Walk/Run × Outdoor/Indoor |
| Indoor | calibrated steps; Route unavailable indoors; no fallback; no manual tour-distance input |
| Automatic pause | initially off; optional; manual controls always available |
| Units | km default; miles selectable; canonical metres |
| Duration | no app-imposed duration cap |
| Storage | private SQLite outside cache; local; no server or account |
| Maps | zero-cost online maps; no paid fallback; no offline downloads |
| Language | translation-ready English |
| Delivery | APK; eventual public Play preparation; publication separate |
| Excluded | accounts; cloud sync; social; route planning/navigation; wearables; calories; GPX; indoor positioning; treadmill integration |

Identity matches the [Android manifest](../android/app/src/main/AndroidManifest.xml),
[Android app configuration](../android/app/build.gradle.kts) and
[composition](../lib/app/composition.dart). D01 is the publisher's explicit choice,
not inferred domain ownership. Calibration reference input is not manual tour distance.
These are product obligations, not features implemented by this metadata shell.

## Stack and architecture

| Field | Value |
| --- | --- |
| Flutter | 3.47.9 |
| Flutter revision | c197ca5199e9ee5661e865596c9c07294dfab51c |
| Dart | 3.13.7 |
| Host Java | 21.0.12.1.1 |
| AGP | 8.13.2 |
| Gradle | 8.14 |
| Kotlin | 2.2.20 |
| Java source target | 17 |
| Java bytecode target | 17 |
| Kotlin JVM target | 17 |
| Minimum API | 24 |
| Compile API | 36 |
| Target API | 36 |
| Build-tools | 35.0.0 |
| NDK | 28.2.13676358 |
| package_info_plus | 10.2.2 |
| Presentation | constructor injection; immutable plain-Dart state; broadcast stream; StreamBuilder; no extra state/DI framework |
| Support | provisional; S005 extends; S006 validates; no final phone or Play support claim |
| Packaged ABIs | armeabi-v7a; arm64-v8a; x86_64 |
| Executed ABIs | x86_64 only; emulator, not physical-phone proof |
| Emulator | Free_Tracker_API_37; Android 17; API 37; emulator-5554 historically |
| SQLite | not selected; S005 selects; S006/S009 validate |
| Historical coverage | 103/103 handwritten Dart lines; 100% lines; branch coverage unavailable |

Sources: [SDK pin](../.flutter-version), [pubspec](../pubspec.yaml),
[resolved dependency lockfile](../pubspec.lock), [Android plugins](../android/settings.gradle.kts),
[Gradle wrapper](../android/gradle/wrapper/gradle-wrapper.properties),
[portable S001 evidence](s001-evidence.md). Pubspec lower bounds do not pin an installed
SDK revision. Host Java is not the JVM bytecode target; guest API 37 is not minimum,
compile or target API. Packaging an ABI does not establish executed support.

Extend the [domain](../lib/settings/domain/app_info.dart),
[port](../lib/settings/application/app_info_repository.dart),
[loader](../lib/settings/application/app_info_loader.dart),
[adapter](../lib/settings/data/platform_app_info_repository.dart),
[screen](../lib/settings/presentation/app_info_screen.dart) and
[English catalog](../lib/l10n/app_en.arb). The metadata screen owns its loader only,
not a service-backed recording owner. S005 selects SQLite; S006 proves actual phones.

S001 source/test/build inventory was recomputed before S002 edits and matched its
recorded SHA-256 `066ceba6b64a239f9e427510c3d335860b9b935bf9911d902fa6bcbd682526b5`.
Historical S001 source was `4fbda4b01318ad37a1f8280294d790628c7132fa` plus the
then-uncommitted implementation, subsequently present in approved dev `cb54712a73847cd2d1f2d6bf5437782c975317d4`.
This confirms the source handoff, not independent review or verified squash procedure.

## Resources and support

| Resource | State | Evidence and limits | Owner / blocking gate | Next action |
| --- | --- | --- | --- | --- |
| Host/toolchain | partial | 2026-10-30; scope: Fedora 43 x86_64, Python 3.14.8 and Flutter/Dart paths present; S001 tested versions above; limits: sandbox SDK cache writes require reviewed host execution; see environment record | S003; before workflow checks; S005 before app checks | Recheck installed tools and run applicable suites with reviewed host access when required |
| Configured emulator | partial | 2026-10-30; scope: S001 historically executed on Free_Tracker_API_37, API 37 x86_64, emulator-5554; limits: not probed live for S002, not phone sensing or screen-off proof | S005; before Android checks; S006 before feasibility | Recheck ADB device, AVD identity and boot completion before selecting current ID |
| Physical phones | unknown | Unknown: no authorized phone inventory or trials supplied; model/vendor, Android/API, memory class, ABI, Google services and step/location capability all untested; planned older/low-memory and recent/multi-vendor matrix, suitable/missing step sensing, Google/non-Google services | S006; before physical feasibility; S022 before device/endurance acceptance | Obtain non-secret device access/capability records and perform real adapter/screen-off/recovery trials; do not infer phones from packaged ABIs |
| Reference course/observed steps | unknown | Unknown: no independently measured course or observed-step resources supplied; no accuracy/tolerance evidence | S008; before baseline trials; S023 before held-out acceptance | Identify independent outdoor/indoor references and observers, document path/placement/pace and tuning versus held-out split |
| Map-account access | unknown | Unknown: publisher account/project suitability, billing setup and authorized usage-console access not supplied | S020; before provider integration/online-map acceptance; S006 assessment | Obtain non-secret authorized suitability/access evidence or assess only zero-cost alternatives; do not create accounts |

[Dated environment record](development-environment.md) is pre-implementation history;
its no-app statements do not describe current source. The original AVD was not repaired.
Missing physical/reference resources block their consumers, not this truthful inventory.

## Decisions

| ID | State / outcome | Evidence / absence | Owner / blocking point | Next action |
| --- | --- | --- | --- | --- |
| D01 | resolved; publisher-selected com.bindefined.freetracker on 2026-10-30 | PRD §3 explicit publisher instruction; no alternative selected; affects S001/S002/release | S001; before Android shell generation or signing; S002 carries the record forward | Carry exact identity into release signing, not a generated default |
| D02 | partial; inventory complete, physical/account facts unknown | Dated environment and S001 evidence; resource limits above | S002; before affected spike/integration | S006 collect physical proof; S020 obtain authorized suitability evidence |
| D03 | provisional; S001 stack only, S005 extends, S006 support decision | Historical S001 stack/build/emulator evidence; no phone matrix | S001 provisional, S005 extends, S006 final; before support claims | Extend compatible stack in S005; validate phones in S006 and release SDK/native compatibility later |
| D04 | unresolved; recording owner/adapters not selected | No screen-off, detached-UI or recovery phone evidence | S006; before production recording/UI-heavy work | S006 compare service-hosted Dart and focused native bridge; retain one owner/rule implementation |
| D05 | partial; presentation established; SQLite not selected | S001 immutable state/broadcast stream/StreamBuilder and constructor injection; no database evidence | S001 establishes template patterns, S005 selects SQLite binding, S006/S009 validate; before production consumers | S005 select binding/migrations; S006/S009 validate production consumers |
| D06 | unresolved; GPS-loss timing/endpoints/recovery contract pending | PRD active-time continuation is a proposal, not implemented | S007; before gap/time/recovery implementation | S007 resolve clock/reboot/unknown intervals and first/last fix versus temporal endpoints |
| D07 | unresolved; thresholds and tolerances pending | No independent trials or held-out proof; candidate numbers are not guarantees | S008 baseline, S010–S012 implementation, S023 validation | S008 collect baseline; S010–S012 implement; S023 validate separately by activity/mode |
| D08 | unresolved; physical schema/commit cadence/buffering pending | SQLite confirmed as product storage, not a binding/schema decision | S009/S013; before durable recording acceptance | S009/S013 define transactions/replay, deduplication, bounded buffering and measured uncommitted tail |
| D09 | unresolved; provider and non-Google coverage not selected | Recommendation only; no current account/configuration/SKU proof | S006 assessment, S020 integration; before online-map acceptance | S006 assess zero-cost compatibility; S020 integrate and verify actual usage before online-map acceptance |
| D10 | unresolved; notification controls and service types pending | Reopen required; no service/permission feasibility evidence | S006 feasibility, S015 production | S006 prove per-mode service feasibility; S015 resolve shared-command controls and permission denial |
| D11 | unresolved; retention/backup/privacy pending | No persistence/SDK audit or configured backup policy | S021; before release | S021 define retention/backup/disclosures without silent cloud backup or route-upload feature |
| D12 | unresolved; prerequisites identified, fulfillment unknown | No publisher signing/account/contact/policy/testing evidence supplied | S002 identify, S024/S025 fulfill; before distribution | S024/S025 fulfill secure signing, account-specific tests and disclosures with separate external-action authority |

No combined decision is fully resolved by partial evidence. D01's date, rationale,
alternatives and affected changes remain in PLAN. Other unresolved owners/blocking
points are unchanged; no algorithm, service, SQLite, privacy or map choice is invented.

## Maps

| Field | Value |
| --- | --- |
| Budget | zero expenditure; no paid APIs, trial or automatic overage fallback |
| Google recommendation | no-map-ID native SDK recommendation, not selected integration or verified pricing; billing-enabled account prerequisite is separate from no-charge usage |
| Restrictions | attribution; restrict API key by API, package and signing certificate, including Play app-signing certificate |
| Usage verification | S020 must verify actual configuration and SKU usage; alerts are not hard spending caps; disable unnecessary APIs; use applicable quotas |
| Alternatives | S006/S020 evaluate zero-cost-only alternatives if unsuitable; terms, identification, bounded compliant caching, scale and non-Google behavior; no bulk prefetch; Google content SDK-managed |
| Failure | disable chargeable service; preserve history/outline; outline is not the online-map release gate substitute; no compliant provider leaves gate unmet |
| Authorization | separate authorization for account creation, payment setup, purchases, uploads and publication; none performed in S002 |

### Inventory

| Resource | State | Evidence and limits | Owner / blocking gate | Next action |
| --- | --- | --- | --- | --- |
| Account/project suitability | unknown | Unknown: no authorized publisher account/project/billing suitability evidence; public pricing pages cannot prove account facts | S020; before integration; S006 assessment | Obtain authorized non-secret evidence; if unsuitable assess zero-cost alternatives only |
| Usage/configuration access | unknown | Unknown: no authorized console/configuration inspection or actual usage observation | S020; before online-map acceptance | Inspect SDK configuration and actual SKU usage under separately authorized access; recheck terms at release |
| Signing-restriction evidence | unknown | Unknown: no release/upload/Play certificate restrictions configured or inspected | S020; before map integration; S024/S025 before distribution | Restrict intended API/package/certificates for actual installed builds; do not copy keys into repository |

The constraints above carry PRD §9 forward, not a newly verified Google/OSM offer.
No provider has been selected and no account, payment or key action was performed.

## Release prerequisites

| Field | Value |
| --- | --- |
| Custody procedure | publisher chooses owner and approved secret store; secure custody, backup and upgrade identity continuity; no keys, passwords, tokens or payment details in repository |
| Certificate distinction | upload certificate is not Play app-signing certificate; map restrictions must cover each installed APK and Play-delivered signing identity |
| Artifact distinction | debug APK is not release evidence; separately test signed APK, AAB and Play-delivered install/upgrade/reopen |
| Authorization | separate authorization for account creation, payment setup, purchases, uploads and publication; none performed in S002 |

### Inventory

| Resource | State | Evidence and limits | Owner / blocking gate | Next action |
| --- | --- | --- | --- | --- |
| Signing owner/custody/backup | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S024/S025; before distribution | Publisher identifies responsible role and approved secure store/backup procedure without exposing credentials |
| Upgrade continuity | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S024/S025; before distribution | Preserve confirmed application ID and signing identity; validate supported upgrades |
| Upload/app-signing certificates | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S024/S025; before distribution | Record non-secret certificate fingerprints separately and apply correct map restrictions |
| Play account/type/verification/cost/testing | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S024/S025; before distribution | Inspect current authorized account-specific requirements; do not assume historic tester counts or create/purchase account |
| Support contact | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S024/S025; before distribution | Publisher supplies public support contact, not login credentials |
| Public/in-app privacy policy | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S021; S025; before declarations/distribution | S021 prepares accurate in-app/public policy; S025 obtains authorized public HTTPS URL and verifies accessibility |
| Data safety/health/foreground-service declarations | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S021; S025; before declarations/distribution | S021 audits local activity/location and SDK networking; S025 completes current applicable declarations with authorization |
| Target SDK/native ABI compatibility | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S024/S025; before distribution | Recheck current target/native compatibility against exact versions before distribution |
| APK/AAB/Play install/upgrade | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S024/S025; before distribution | S024 proves release APK/AAB; S025 separately verifies authorized Play-track install, upgrade, recovery and history |
| Listing/free-no-ads/content rating/rollout/rollback | unknown | Unknown: no authorized current publisher evidence or completed release artifact supplied | S024/S025; before distribution | S025 prepares listing/screenshots/free-no-ads/rating, required tests, crash/ANR review and rollout/rollback |

Publisher account/hosting costs are separate from map usage. Public production
publication remains a separate action. Missing release inputs block distribution,
not setup documentation. No secret material was requested or recorded.

## Source verification

| Topic | State | Checked date / scope | Primary source | Outcome / evidence | Recheck owner / gate |
| --- | --- | --- | --- | --- | --- |
| Stack/support | unverified | 2026-10-30; scope: exact installed versions and maintained API/ABI compatibility | [Flutter support](https://docs.flutter.dev/reference/supported-platforms), [metadata plugin](https://pub.dev/packages/package_info_plus/versions/10.2.2), [AGP](https://developer.android.com/build/releases/agp-8-13-0-release-notes) | Unverified: no current primary-page/account observation in S002; historical S001/PRD claims are not refreshed; next: read primary pages and authorized account evidence at owning gate | S005/S006; before stack extension/support claims |
| Android service/permissions | unverified | 2026-10-30; scope: mode/API permissions and actual background/notification behavior | [Service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [background restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) | Unverified: no current primary-page/account observation in S002; historical S001/PRD claims are not refreshed; next: read primary pages and authorized account evidence at owning gate | S006/S015; before feasibility/production service |
| Maps/terms/usage | unverified | 2026-10-30; scope: current no-charge configuration, provider terms/scale and authorized actual usage | [Pricing](https://developers.google.com/maps/billing-and-pricing/pricing), [SKU triggers](https://developers.google.com/maps/billing-and-pricing/sku-details#maps-sdk), [billing prerequisites](https://developers.google.com/maps/documentation/android-sdk/usage-and-billing), [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/) | Unverified: no current primary-page/account observation in S002; historical S001/PRD claims are not refreshed; next: read primary pages and authorized account evidence at owning gate | S006/S020; before provider integration/online-map acceptance and release |
| Release/account obligations | unverified | 2026-10-30; scope: current target/native/service/account-specific testing and privacy obligations | [Flutter Android release](https://docs.flutter.dev/deployment/android), [account testing](https://support.google.com/googleplay/android-developer/answer/14151465), [health declaration](https://support.google.com/googleplay/android-developer/answer/14738291), [health/privacy](https://support.google.com/googleplay/android-developer/answer/18258653) | Unverified: no current primary-page/account observation in S002; historical S001/PRD claims are not refreshed; next: read primary pages and authorized account evidence at owning gate | S024/S025; before distribution |

Procedure: read the primary pages against the exact version/configuration/account
in use; record the UTC observation, scoped claim/outcome and relevant URL, including
redirects/replacements. Record unavailable access and unanswered facts as unverified
with the reason and next action. Public pages never prove publisher account status.
Only mark verified after actual observation, not from a URL or the validator's pass.
Recheck on relevant version/configuration/policy changes and at integration/release;
no arbitrary expiry or assumed historic testing rule. Historical S001 source review
remains historical. No new external claim is asserted verified here.

## Checks and handoff

This is dated implementation-stage evidence, not the current delivery ledger.
The review/merge row below was written before the caller's subsequent workflow.
See [PLAN bootstrap reconciliation](PLAN.md#progress-ledger) for the publisher's
confirmation and Git integration. Keep this historical row intact; do not use it
as a veto on later delivery evidence or require this handoff to be synchronized
after every merge. Resource/support/physical/release obligations remain scoped
to their actual consumers.

| Check | State | Command / procedure | Result | Observed UTC | Source / scope | Environment | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S001 baseline | recorded historical | Inspect source inventory and portable S001 summary | Historical: S001 analysis/build/unit/E01–E10/P01 passed on its identified content; not rerun as S002 | 2026-10-30 21:38 UTC | revision cb54712a73847cd2d1f2d6bf5437782c975317d4; scope: S001 source handoff, SHA-256 066ceba6b64a239f9e427510c3d335860b9b935bf9911d902fa6bcbd682526b5 | Fedora 43; API 37 x86_64 emulator | [portable evidence](s001-evidence.md) |
| Remote baseline | executed in S002 | git symbolic-ref --quiet --short HEAD; git status --short; git rev-parse HEAD dev; git ls-remote origin refs/heads/dev | exit 0; selected branch, initially clean tree; remote/local dev exactly cb54712a73847cd2d1f2d6bf5437782c975317d4 | 2026-10-30 21:38 UTC | revision dc491eda39dd53fd1060d65f0aab2e7e73fe063f; scope: readiness, no fetch/switch/reset | Fedora 43; restricted SSH first exited 128; reviewed host retry exited 0 | Read-only ls-remote confirmed baseline; no remote mutation |
| Setup contract | executed in S002 | python3 tool/check_scaffold.py | exit 0; scaffold identity/boundaries/guide plus complete read-only S002 record valid | 2026-10-30 21:49 UTC | revision dc491eda39dd53fd1060d65f0aab2e7e73fe063f; scope: uncommitted S002 source/test/build inventory SHA-256 e4fc822e5f0b4f6c3ce58145ae95537e5903933273b1b5bbee3e939bb4c86917; setup payload SHA-256 31f88cfa6d4dd8c1244d050c098d6b2069c1cc5ea93e781a5114ab01a9fe4120 | Python 3.14.8; workspace | [checker](../tool/check_scaffold.py) |
| Tooling units | executed in S002 | python3 -m unittest discover -s tool/tests -p test_scaffold_contract.py -v | exit 0; 29 scaffold/setup tests, including every S002 T01–T20 plus S001 regressions; no skips | 2026-10-30 21:49 UTC | revision dc491eda39dd53fd1060d65f0aab2e7e73fe063f; scope: uncommitted S002 source/test/build inventory SHA-256 e4fc822e5f0b4f6c3ce58145ae95537e5903933273b1b5bbee3e939bb4c86917; setup payload SHA-256 31f88cfa6d4dd8c1244d050c098d6b2069c1cc5ea93e781a5114ab01a9fe4120 | Python 3.14.8; temporary repository fixtures | [mapped tests](../tool/tests/test_scaffold_contract.py) |
| Unit + coverage | executed in S002 | make unit-test | exit 0; 63 Python tooling, 32 pure-Dart core and 53 Flutter tests; 103/103 handwritten Dart lines (100%); branches unavailable, not 100% | 2026-10-30 21:49 UTC | revision dc491eda39dd53fd1060d65f0aab2e7e73fe063f; scope: uncommitted S002 source/test/build inventory SHA-256 e4fc822e5f0b4f6c3ce58145ae95537e5903933273b1b5bbee3e939bb4c86917; setup payload SHA-256 31f88cfa6d4dd8c1244d050c098d6b2069c1cc5ea93e781a5114ab01a9fe4120 | Fedora 43 x86_64; Python 3.14.8; S001 Flutter/Dart stack; reviewed host execution | [runner](../tool/run_tests.py), [Makefile](../Makefile) |
| Android E2E | N/A | make end-to-end-test ANDROID_DEVICE_ID=emulator-5554 (confirm actual ID before use) | N/A: no app/UI/adapter behavior changes in S002; no fresh Android run | 2026-10-30 21:38 UTC | revision dc491eda39dd53fd1060d65f0aab2e7e73fe063f; scope: S002 setup/tooling only; S001 scenarios historical | Device not probed live; S001 emulator only | [historical S001 E01–E10/P01](s001-evidence.md) |
| Real SQLite | N/A | S005/S009 automate real transaction/recovery/migration checks in make unit-test | N/A: no storage/binding/schema/mapping changes; no database pass | 2026-10-30 21:38 UTC | revision dc491eda39dd53fd1060d65f0aab2e7e73fe063f; scope: no persistence in shell | No database introduced | [PLAN obligations](PLAN.md) |
| Physical/field | N/A | S006/S022 actual phones; S008/S023 independent reference trials | N/A: no new sensing/measurement/background behavior; those gates remain blocked without physical evidence | 2026-10-30 21:38 UTC | revision dc491eda39dd53fd1060d65f0aab2e7e73fe063f; scope: S002 inventory only | No phone/reference evidence supplied | [resource obligations](PLAN.md) |
| Source/resource audit | executed in S002 | Inspect setup entries against PRD, PLAN, S001 source/evidence and environment record | exit 0; local baseline consistent; phones/accounts/signing/current policy observations remain unknown/unverified | 2026-10-30 21:38 UTC | revision dc491eda39dd53fd1060d65f0aab2e7e73fe063f; scope: checked-in sources and local non-secret facts, not live accounts/pages | Python 3.14.8 and source inspection | [setup contract](changes/002-setup-decisions.md) |
| Review/merge | not run | Caller commits; separate full-diff review/fix/recheck/re-review and serialized verified squash merge per IMPLEMENT | Not run: no independent review, commit, push, merge or script-owned gate advancement | 2026-10-30 21:38 UTC | revision dc491eda39dd53fd1060d65f0aab2e7e73fe063f; scope: manual bootstrap until S003/S004 GW proof | Existing scripts unaudited; not trusted delivery evidence | [IMPLEMENT](IMPLEMENT.md), [PLAN bootstrap](PLAN.md#bootstrap-without-circular-claims) |

S002 executable evidence is updated only after commands execute. Ignored
`build/test-results/` reports and `coverage/lcov.info` are local, replaceable
artifacts, not required portable links or independent review evidence. Optional
S001 raw logs/APK may be absent without changing the historical summary.

Next consumers: S003 audits existing scripts and bootstrap prerequisites; S005
extends this app/test infrastructure with SQLite; S006 consumes physical/support
blockers; S020 consumes maps/account constraints; S021/S024/S025 fulfill privacy
and release inputs. S001 checks do not advance S002, GW or G1–G7. The caller owns
separate review/fix/integration; this setup checker never writes or advances gates.

Final verification summary: `make unit-test` started at 2026-10-30 21:49:00 UTC
and exited 0. The runner's SHA-256 inventories app/test/build/tool files, not docs;
the setup payload hash above covers this document before `## Checks and handoff`
(the evidence table itself is excluded to avoid a self-referential hash). All
checks ran at the recorded HEAD plus the implementation worktree, not a new commit.
The unchanged S001 application retains 103/103 covered executable lines; its pure
abstract port and exact generator-owned exclusions remain unchanged. Python tooling
has mapped normal/error/boundary tests; no app coverage exception was added.

Local current reports: `build/test-results/unit/summary.json`, `tooling.txt`,
`core.jsonl`, `flutter.jsonl` in that directory, and `coverage/lcov.info`.
Standalone mapped tests also passed (29 cases, no skips), with local optional log
`/tmp/free-tracker-s002-contract-tests.txt`. The tables above are the portable
summary if ignored/temporary files disappear. `git diff --check` and Python
syntax compilation passed; no Dart/Android source or generated output changed.

Earlier attempts are not erased: restricted `make unit-test` exited 2 because
Flutter could not write its SDK cache. Approved host execution then reached the
new tooling tests and exited 2 due to a T16 fixture column-index defect (32 failed
subtests, 8 errors); the fixture was corrected, mapped tests passed, and the full
final host workflow passed. No assertion was weakened or suite skipped.

Implementation self-check reviewed the complete source/document/test diff and
S002 requirement/case mappings. It is not the separate IMPLEMENT review. Android
E2E, real SQLite, live adapters/phones, field accuracy and release checks were not
run or represented as passing; their applicability/blockers remain as above.

Final self-check also tightened local configuration matching so commented-out SDK
settings cannot stand in for the actual configuration, with a T05 regression case.
Section ordering remains editorial, tested by T18; malformed tables and removed
required source references fail closed. All 29 mapped contract/regression tests
and the full 63-tooling/32-core/53-Flutter workflow passed again after this change.

### Review fix F01 — active Gradle configuration (2026-10-30 21:54 UTC)

Validated the supplied P2 finding against S002-R08: a block-commented baseline
and a conflicting later assignment both bypassed the original guard. The checker
now ignores line/nested block comments and string-literal examples, requires one
active baseline-valued assignment per pinned app setting, and diagnoses the path
and field. Unterminated block comments fail closed. Five new `S002_T05_R08` test
methods cover those cases, valid inline comments and read-only behavior.

Checks on HEAD `6510be4d9760efbbba67f3369fa063ccebf6d3d2` plus this review-fix
worktree: `python3 -m unittest discover -s tool/tests -v` passed all 68 tests;
`python3 tool/check_scaffold.py` and `git diff --check` passed. `make unit-test`
exited 2 at `flutter gen-l10n`: the SDK cache under `/home/vito/flutter` is
read-only. No fresh Dart coverage or app-suite pass is claimed. Android E2E and
SQLite remain N/A to this tooling-only fix as scoped above. Remote `dev`
verification failed first on system SSH configuration permissions, then DNS with
`ssh -F /dev/null`; local `dev` is exactly
`cb54712a73847cd2d1f2d6bf5437782c975317d4`, with S001 code/evidence unchanged.
Remote freshness, full unit verification and delivery gates remain unverified.

### Review fix F02 — Gradle setter overrides (2026-10-30 21:58 UTC)

Validated the supplied P2 finding against S002-R08: `minSdk = 24` followed by
`minSdkVersion(37)` passed the assignment-only guard. The bounded checker now
rejects setter calls for pinned fields, including SDK `*Version` aliases,
explicit `setX` forms and `Property.set`, regardless of value or ordering; one
baseline-valued assignment remains required. Comments and literal examples are
ignored. Two new `S002_T05_R08` regression methods cover overrides before/after
assignments, qualified and same-line calls, comment/whitespace variants, and
non-executable examples, with field/path diagnostics and read-only assertions.

Checks on HEAD `50afec530567b6007af7f1c2177d1ca8986449b4` plus this review-fix
worktree: the new rejection regression failed before the code fix and passed
after it; `python3 -m unittest discover -s tool/tests -v` passed all 70 tests;
`python3 tool/check_scaffold.py` and `git diff --check` passed. `make unit-test`
exited 2 at `flutter gen-l10n` because `/home/vito/flutter/bin/cache` is read-only;
no fresh Dart coverage, branch coverage or app-suite pass is claimed. Android
E2E and real SQLite remain N/A to this tooling-only fix, with no app/configuration
or persistence changes. Local `dev` remains exactly
`cb54712a73847cd2d1f2d6bf5437782c975317d4`; S001 app/test/build sources are
unchanged versus that baseline. Read-only remote verification with
`git -c core.sshCommand='ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=10' ls-remote origin refs/heads/dev`
exited 128 because GitHub DNS resolution failed. Remote freshness, full unit
verification and delivery gates remain unverified; no commit, push or merge.
