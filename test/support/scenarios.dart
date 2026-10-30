import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:free_tracker/app/app.dart';
import 'package:free_tracker/app/composition.dart';
import 'package:free_tracker/settings/data/platform_app_info_repository.dart';
import 'package:free_tracker/settings/domain/app_info.dart';

import 'fixtures.dart';

void controlledScenarios() {
  testWidgets('S001_E02_controlled_success', (tester) async {
    final pending = Completer<AppInfoResult>();
    final repo = Repository(() => pending.future);
    await tester.pumpWidget(
      FreeTrackerApp(loader: createAppInfoLoader(repository: repo)),
    );
    expect(find.text('Loading app information…'), findsOneWidget);
    pending.complete(success());
    await tester.pumpAndSettle();
    expect(find.text('Version: fixture-release'), findsOneWidget);
    expect(find.text('Build number: 001'), findsOneWidget);
    expect(find.text('Application ID: $expectedId'), findsOneWidget);
    expect(find.text('free-tracker'), findsNWidgets(2));
    expect(repo.calls, 1);
  });
  testWidgets('S001_E03_invalid_metadata_is_unavailable', (tester) async {
    final loader = createAppInfoLoader(
      repository: PlatformAppInfoRepository(
        expectedApplicationId: expectedId,
        reader: () async => PackageInfo(
          appName: 'free-tracker',
          packageName: 'wrong',
          version: '1',
          buildNumber: '1',
        ),
      ),
    );
    await tester.pumpWidget(FreeTrackerApp(loader: loader));
    await tester.pumpAndSettle();
    expect(loader.state.failure, AppInfoFailureCode.invalidMetadata);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Application ID:'), findsNothing);
  });
  testWidgets('S001_E04_read_failure_then_retry_success', (tester) async {
    var reads = 0;
    final pending = Completer<PackageInfo>();
    final loader = createAppInfoLoader(
      repository: PlatformAppInfoRepository(
        expectedApplicationId: expectedId,
        reader: () {
          if (++reads == 1) throw PlatformException(code: 'private-exception');
          return pending.future;
        },
      ),
    );
    await tester.pumpWidget(FreeTrackerApp(loader: loader));
    await tester.pumpAndSettle();
    expect(
      find.text('App information is unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-exception'), findsNothing);
    expect(find.textContaining('Version:'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Loading app information…'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    pending.complete(
      PackageInfo(
        appName: 'free-tracker',
        packageName: expectedId,
        version: 'recovered',
        buildNumber: '2',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version: recovered'), findsOneWidget);
    expect(find.text('Build number: 2'), findsOneWidget);
    expect(reads, 2);
    expect(find.textContaining('unavailable'), findsNothing);
  });
  testWidgets('S001_E05_rebuild_does_not_duplicate_read', (tester) async {
    final pending = Completer<AppInfoResult>();
    final repo = Repository(() => pending.future);
    final loader = createAppInfoLoader(repository: repo);
    await tester.pumpWidget(FreeTrackerApp(loader: loader));
    await tester.pumpWidget(
      FreeTrackerApp(loader: loader, locale: const Locale('en')),
    );
    await tester.pump();
    expect(repo.calls, 1);
    pending.complete(success());
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
  });
  testWidgets('S001_E06_retry_failure_then_recovery', (tester) async {
    var reads = 0;
    final loader = createAppInfoLoader(
      repository: Repository(
        () async => ++reads < 3
            ? const AppInfoFailure(AppInfoFailureCode.readFailed)
            : success(),
      ),
    );
    await tester.pumpWidget(FreeTrackerApp(loader: loader));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Version:'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 3);
    expect(find.text('Version: fixture-release'), findsOneWidget);
  });
  testWidgets('S001_E07_close_pending_then_recreate', (tester) async {
    // Create the failing future in the reader's zone, just as a real adapter
    // does. Live Android bindings and the test callback use different error
    // zones; Dart deliberately does not transfer errors between those zones.
    late Completer<AppInfoResult> pending;
    final repo = Repository(() {
      pending = Completer<AppInfoResult>();
      return pending.future;
    });
    final loader = createAppInfoLoader(repository: repo);
    await tester.pumpWidget(FreeTrackerApp(loader: loader));
    expect(repo.calls, 1);
    expect(find.text('Loading app information…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('late private error'));
    await tester.pumpAndSettle();
    await loader.load();
    expect(repo.calls, 1);
    final fresh = Repository(() async => success(version: 'fresh'));
    await tester.pumpWidget(
      FreeTrackerApp(loader: createAppInfoLoader(repository: fresh)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version: fresh'), findsOneWidget);
    expect(fresh.calls, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('S001_E08_unsupported_metadata_retry', (tester) async {
    var reads = 0;
    final loader = createAppInfoLoader(
      repository: PlatformAppInfoRepository(
        expectedApplicationId: expectedId,
        reader: () async {
          if (++reads == 1) throw MissingPluginException('private');
          return PackageInfo(
            appName: 'free-tracker',
            packageName: expectedId,
            version: 'supported',
            buildNumber: '1',
          );
        },
      ),
    );
    await tester.pumpWidget(FreeTrackerApp(loader: loader));
    await tester.pumpAndSettle();
    expect(loader.state.failure, AppInfoFailureCode.unsupportedPlatform);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Version: supported'), findsOneWidget);
    expect(reads, 2);
  });
  testWidgets('S001_E09_unsupported_locale', (tester) async {
    await tester.pumpWidget(
      FreeTrackerApp(
        locale: const Locale('zz'),
        loader: createAppInfoLoader(
          repository: Repository(() async => success()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('App information'), findsOneWidget);
    expect(find.text('Build number: 001'), findsOneWidget);
    expect(find.text('Application ID: $expectedId'), findsOneWidget);
  });
  testWidgets('S001_E10_large_text_failure_and_retry', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    var reads = 0;
    await tester.pumpWidget(
      FreeTrackerApp(
        loader: createAppInfoLoader(
          repository: Repository(
            () async => ++reads == 1
                ? const AppInfoFailure(AppInfoFailureCode.readFailed)
                : success(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Build number: 001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
