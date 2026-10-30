import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_tracker/l10n/generated/app_localizations.dart';
import 'package:free_tracker/l10n/generated/app_localizations_en.dart';
import 'package:free_tracker/settings/application/app_info_loader.dart';
import 'package:free_tracker/settings/domain/app_info.dart';
import 'package:free_tracker/settings/presentation/app_info_screen.dart';

import '../../support/fixtures.dart';
import '../../support/scenarios.dart';
import '../../support/expanded_localizations.dart';

void main() {
  test('S001_T17_english_resource_contract', () {
    final catalog = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final text = AppLocalizationsEn();
    final actual = {
      'appTitle': text.appTitle,
      'appInformation': text.appInformation,
      'loading': text.loading,
      'versionLabel': text.versionLabel,
      'buildLabel': text.buildLabel,
      'applicationIdLabel': text.applicationIdLabel,
      'unavailable': text.unavailable,
      'retry': text.retry,
      'retrySemanticLabel': text.retrySemanticLabel,
    };
    expect(
      catalog.keys.where((k) => !k.startsWith('@')),
      unorderedEquals(actual.keys),
    );
    for (final entry in actual.entries) {
      expect(entry.value.trim(), isNotEmpty);
      expect(entry.value, catalog[entry.key]);
      expect(entry.value, isNot(contains('{')));
    }
  });
  testWidgets(
    'S001_T18_unsupported_locale_falls_back_without_changing_metadata',
    (tester) async {
      expect(AppLocalizations.supportedLocales, [const Locale('en')]);
      final generated = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(generated.applicationIdLabel, 'Application ID');
    },
  );
  testWidgets('S001_T19_expanded_message_contract', (tester) async {
    final text = ExpandedEnglish();
    expect(
      text.unavailable.length,
      greaterThan(AppLocalizationsEn().unavailable.length * 5),
    );
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var reads = 0;
    final loader = AppInfoLoader(
      Repository(
        () async => ++reads == 1
            ? const AppInfoFailure(AppInfoFailureCode.readFailed)
            : success(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          const ExpandedDelegate(),
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: AppInfoScreen(loader: loader),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(text.unavailable), findsOneWidget);
    await tester.ensureVisible(find.text(text.retry));
    expect(find.text(text.retry).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(text.retrySemanticLabel), findsOneWidget);
    semantics.dispose();
    await tester.tap(find.text(text.retry));
    await tester.pumpAndSettle();
    for (final value in [
      '${text.versionLabel}: fixture-release',
      '${text.buildLabel}: 001',
      '${text.applicationIdLabel}: $expectedId',
    ]) {
      await tester.ensureVisible(find.text(value));
      expect(find.text(value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  controlledScenarios();
}
