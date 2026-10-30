import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:free_tracker/app/app.dart';
import 'package:free_tracker/app/composition.dart';
import 'package:free_tracker/settings/application/app_info_loader.dart';
import 'package:free_tracker/settings/data/platform_app_info_repository.dart';
import 'package:free_tracker/settings/domain/app_info.dart';
import 'package:free_tracker/settings/presentation/app_info_screen.dart';
import 'package:free_tracker/l10n/generated/app_localizations.dart';

import '../test/support/fixtures.dart';
import '../test/support/expanded_localizations.dart';

PackageInfo metadata({
  String name = 'free-tracker',
  String id = expectedId,
  String version = 'release',
  String build = '001',
}) => PackageInfo(
  appName: name,
  packageName: id,
  version: version,
  buildNumber: build,
);

AppInfoLoader adapter(Future<PackageInfo> Function() read) =>
    createAppInfoLoader(
      repository: PlatformAppInfoRepository(
        expectedApplicationId: expectedId,
        reader: read,
      ),
    );

Future<void> mount(
  WidgetTester tester,
  AppInfoLoader loader, {
  Locale? locale,
}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(FreeTrackerApp(loader: loader, locale: locale));
  await tester.pumpAndSettle();
}

Future<void> unavailable(WidgetTester tester, PackageInfo value) async {
  final loader = adapter(() async => value);
  await mount(tester, loader);
  expect(loader.state.failure, AppInfoFailureCode.invalidMetadata);
  expect(find.text('Retry'), findsOneWidget);
  expect(find.textContaining('Application ID:'), findsNothing);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final cases = <int, Future<void> Function(WidgetTester)>{
    3: (tester) async {
      final injected = Repository(() async => success(version: 'injected'));
      await mount(tester, createAppInfoLoader(repository: injected));
      expect(find.text('Version: injected'), findsOneWidget);
      expect(injected.calls, 1);
      await mount(tester, createAppInfoLoader());
      expect(find.text('Version: 1.0.0'), findsOneWidget);
      expect(find.text('Application ID: $expectedId'), findsOneWidget);
    },
    5: (tester) async {
      await mount(
        tester,
        adapter(
          () async => metadata(
            name: ' free-tracker ',
            id: ' $expectedId ',
            version: ' opaque-release ',
            build: ' 001 ',
          ),
        ),
      );
      expect(find.text('Version: opaque-release'), findsOneWidget);
      expect(find.text('Build number: 001'), findsOneWidget);
      expect(find.text('Application ID: $expectedId'), findsOneWidget);
    },
    6: (tester) async {
      for (final value in [
        metadata(name: ''),
        metadata(name: ' '),
        metadata(name: 'wrong'),
        metadata(id: ''),
        metadata(id: ' '),
        metadata(id: 'wrong'),
        metadata(version: ''),
        metadata(version: ' '),
        metadata(build: ''),
        metadata(build: ' '),
      ]) {
        await unavailable(tester, value);
      }
    },
    7: (tester) async {
      for (final build in ['0', '00', '-1', '1.5', 'abc', '1 2']) {
        await unavailable(tester, metadata(build: build));
      }
      for (final build in ['1', '001']) {
        await mount(tester, adapter(() async => metadata(build: build)));
        expect(find.text('Build number: $build'), findsOneWidget);
      }
    },
    8: (tester) async {
      final pending = Completer<PackageInfo>();
      final loader = adapter(() => pending.future);
      expect(loader.state.phase, AppInfoPhase.idle);
      await tester.pumpWidget(FreeTrackerApp(loader: loader));
      await tester.pump();
      expect(find.text('Loading app information…'), findsOneWidget);
      pending.complete(metadata(version: 'observed-ready'));
      await tester.pumpAndSettle();
      expect(find.text('Version: observed-ready'), findsOneWidget);
    },
    9: (tester) async {
      var reads = 0;
      final loader = adapter(() async {
        if (++reads == 1) throw PlatformException(code: 'private');
        return metadata(version: 'retry-success');
      });
      await mount(tester, loader);
      expect(find.textContaining('Version:'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Version: retry-success'), findsOneWidget);
      expect(reads, 2);
    },
    10: (tester) async {
      final pending = Completer<PackageInfo>();
      var reads = 0;
      final loader = adapter(() {
        reads++;
        return pending.future;
      });
      await tester.pumpWidget(FreeTrackerApp(loader: loader));
      unawaited(loader.load());
      unawaited(loader.retry());
      await tester.pumpWidget(
        FreeTrackerApp(loader: loader, locale: const Locale('en')),
      );
      expect(reads, 1);
      pending.complete(metadata());
      await tester.pumpAndSettle();
      await loader.load();
      expect(reads, 1);
      expect(find.text('Build number: 001'), findsOneWidget);
    },
    11: (tester) async {
      var reads = 0;
      await mount(
        tester,
        adapter(() async {
          if (++reads < 3) throw StateError('private');
          return metadata(version: 'third-read');
        }),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Version:'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(find.text('Version: third-read'), findsOneWidget);
    },
    12: (tester) async {
      for (final fails in [false, true]) {
        late Completer<PackageInfo> pending;
        var reads = 0;
        final loader = adapter(() {
          reads++;
          pending = Completer<PackageInfo>();
          return pending.future;
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(FreeTrackerApp(loader: loader));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await loader.close();
        await loader.close();
        if (fails) {
          pending.completeError(StateError('late'));
        } else {
          pending.complete(metadata());
        }
        await tester.pumpAndSettle();
        await loader.load();
        expect(reads, 1);
        expect(tester.takeException(), isNull);
        await mount(tester, adapter(() async => metadata(version: 'fresh')));
        expect(find.text('Version: fresh'), findsOneWidget);
      }
    },
    13: (tester) async {
      final sdk = metadata(version: 'sdk-release', build: '009');
      final loader = adapter(() async => sdk);
      await mount(tester, loader);
      expect(loader.state.info!.version, sdk.version);
      expect(find.text('Version: sdk-release'), findsOneWidget);
      expect(find.text('Build number: 009'), findsOneWidget);
    },
    14: (tester) async {
      for (final value in [
        metadata(id: 'wrong.sdk'),
        metadata(version: ''),
        metadata(build: 'invalid'),
      ]) {
        await unavailable(tester, value);
        expect(tester.takeException(), isNull);
      }
    },
    15: (tester) async {
      for (final error in [
        MissingPluginException('private'),
        UnsupportedError('private'),
      ]) {
        var reads = 0;
        final loader = adapter(() async {
          if (++reads == 1) throw error;
          return metadata();
        });
        await mount(tester, loader);
        expect(loader.state.failure, AppInfoFailureCode.unsupportedPlatform);
        expect(find.textContaining('private'), findsNothing);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Version: release'), findsOneWidget);
      }
    },
    16: (tester) async {
      for (final error in [
        PlatformException(code: 'private'),
        StateError('private'),
      ]) {
        final loader = adapter(() async => throw error);
        await mount(tester, loader);
        expect(loader.state.failure, AppInfoFailureCode.readFailed);
        expect(find.textContaining('private'), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
      }
    },
    17: (tester) async {
      await mount(tester, adapter(() async => throw StateError('private')));
      expect(find.text('App information'), findsOneWidget);
      expect(
        find.text('App information is unavailable. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      await mount(tester, adapter(() async => metadata()));
      for (final label in [
        'Version: release',
        'Build number: 001',
        'Application ID: $expectedId',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    },
    18: (tester) async {
      await mount(
        tester,
        adapter(() async => metadata()),
        locale: const Locale('zz'),
      );
      expect(find.text('App information'), findsOneWidget);
      expect(find.text('Application ID: $expectedId'), findsOneWidget);
      expect(find.text('Build number: 001'), findsOneWidget);
    },
    19: (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      var reads = 0;
      final text = ExpandedEnglish();
      final loader = adapter(() async {
        if (++reads == 1) throw StateError('error');
        return metadata();
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: [
            const ExpandedDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppInfoScreen(loader: loader),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(text.unavailable), findsOneWidget);
      await tester.ensureVisible(find.text(text.retry));
      expect(find.text(text.retry).hitTestable(), findsOneWidget);
      await tester.tap(find.text(text.retry));
      await tester.pumpAndSettle();
      for (final label in [
        '${text.versionLabel}: release',
        '${text.buildLabel}: 001',
        '${text.applicationIdLabel}: $expectedId',
      ]) {
        await tester.ensureVisible(find.text(label));
        expect(find.text(label), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  };
  for (final entry in cases.entries) {
    testWidgets(
      'S001_T${entry.key.toString().padLeft(2, '0')}_e2e',
      entry.value,
    );
  }
}
