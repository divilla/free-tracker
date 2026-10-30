import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:free_tracker/settings/data/platform_app_info_repository.dart';
import 'package:free_tracker/settings/domain/app_info.dart';

import '../../support/fixtures.dart';

void main() {
  test('S001_T13_sdk_metadata_converts_to_domain', () async {
    final sdk = PackageInfo(
      appName: 'free-tracker',
      packageName: expectedId,
      version: 'release',
      buildNumber: '001',
    );
    final result =
        await PlatformAppInfoRepository(
              expectedApplicationId: expectedId,
              reader: () async => sdk,
            ).load()
            as AppInfoSuccess;
    expect(result.info.appName, sdk.appName);
    expect(result.info.applicationId, sdk.packageName);
    expect(result.info.version, sdk.version);
    expect(result.info.buildNumber, sdk.buildNumber);
    expect(result.info, isNot(isA<PackageInfo>()));
  });
  test('S001_T14_invalid_sdk_metadata_is_typed_failure', () async {
    final result = await PlatformAppInfoRepository(
      expectedApplicationId: expectedId,
      reader: () async => PackageInfo(
        appName: 'free-tracker',
        packageName: 'wrong',
        version: '1',
        buildNumber: '1',
      ),
    ).load();
    expect((result as AppInfoFailure).code, AppInfoFailureCode.invalidMetadata);
  });
  for (final error in [
    MissingPluginException('secret'),
    UnsupportedError('secret'),
  ]) {
    test(
      'S001_T15_missing_or_unsupported_plugin_is_typed_failure ${error.runtimeType}',
      () async {
        final result = await PlatformAppInfoRepository(
          expectedApplicationId: expectedId,
          reader: () => throw error,
        ).load();
        expect(
          (result as AppInfoFailure).code,
          AppInfoFailureCode.unsupportedPlatform,
        );
      },
    );
  }
  for (final error in [
    PlatformException(code: 'secret'),
    StateError('secret'),
  ]) {
    test(
      'S001_T16_reader_errors_are_typed_failures ${error.runtimeType}',
      () async {
        final result = await PlatformAppInfoRepository(
          expectedApplicationId: expectedId,
          reader: () async => throw error,
        ).load();
        expect((result as AppInfoFailure).code, AppInfoFailureCode.readFailed);
      },
    );
  }
}
