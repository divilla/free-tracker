import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:free_tracker/l10n/generated/app_localizations.dart';
import 'package:free_tracker/l10n/generated/app_localizations_en.dart';

class ExpandedEnglish extends AppLocalizationsEn {
  @override
  String get versionLabel => 'Version identifier of this installed application';
  @override
  String get buildLabel => 'Build identifier of this installed application';
  @override
  String get applicationIdLabel =>
      'Unique application identifier of this installation';
  @override
  String get unavailable => List.filled(8, super.unavailable).join(' ');
  @override
  String get retry => 'Retry loading the application information again';
  @override
  String get appInformation => 'Information about this installed application';
}

class ExpandedDelegate extends LocalizationsDelegate<AppLocalizations> {
  const ExpandedDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(ExpandedEnglish());
  @override
  bool shouldReload(ExpandedDelegate old) => false;
}
