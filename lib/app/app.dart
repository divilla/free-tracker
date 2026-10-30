import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../settings/application/app_info_loader.dart';
import '../settings/presentation/app_info_screen.dart';

class FreeTrackerApp extends StatelessWidget {
  const FreeTrackerApp({super.key, required this.loader, this.locale});
  final AppInfoLoader loader;
  final Locale? locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: AppInfoScreen(loader: loader),
  );
}
