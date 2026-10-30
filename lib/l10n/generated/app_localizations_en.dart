// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'free-tracker';

  @override
  String get appInformation => 'App information';

  @override
  String get loading => 'Loading app information…';

  @override
  String get versionLabel => 'Version';

  @override
  String get buildLabel => 'Build number';

  @override
  String get applicationIdLabel => 'Application ID';

  @override
  String get unavailable => 'App information is unavailable. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get retrySemanticLabel => 'Retry loading app information';
}
