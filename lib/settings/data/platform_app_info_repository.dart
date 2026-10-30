import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../application/app_info_repository.dart';
import '../domain/app_info.dart';

final class PlatformAppInfoRepository implements AppInfoRepository {
  PlatformAppInfoRepository({
    required this.expectedApplicationId,
    Future<PackageInfo> Function()? reader,
  }) : _reader = reader ?? PackageInfo.fromPlatform;

  final String expectedApplicationId;
  final Future<PackageInfo> Function() _reader;

  @override
  Future<AppInfoResult> load() async {
    try {
      final sdk = await _reader();
      return AppInfo.validate(
        appName: sdk.appName,
        applicationId: sdk.packageName,
        version: sdk.version,
        buildNumber: sdk.buildNumber,
        expectedApplicationId: expectedApplicationId,
      );
    } on MissingPluginException {
      return const AppInfoFailure(AppInfoFailureCode.unsupportedPlatform);
    } on UnsupportedError {
      return const AppInfoFailure(AppInfoFailureCode.unsupportedPlatform);
    } catch (_) {
      return const AppInfoFailure(AppInfoFailureCode.readFailed);
    }
  }
}
