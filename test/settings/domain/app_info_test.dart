import 'package:test/test.dart';
import 'package:free_tracker/settings/domain/app_info.dart';

import '../../support/fixtures.dart';

void main() {
  AppInfoResult validate({
    String name = 'free-tracker',
    String id = expectedId,
    String version = '1',
    String build = '1',
  }) => AppInfo.validate(
    appName: name,
    applicationId: id,
    version: version,
    buildNumber: build,
    expectedApplicationId: expectedId,
  );
  test('S001_T05_valid_metadata_is_immutable_and_normalized', () {
    final value = validate(
      name: ' free-tracker ',
      id: ' $expectedId ',
      version: ' opaque-release ',
      build: ' 001 ',
    ) as AppInfoSuccess;
    expect(value.info.appName, 'free-tracker');
    expect(value.info.applicationId, expectedId);
    expect(value.info.version, 'opaque-release');
    expect(value.info.buildNumber, '001');
  });
  for (final blank in ['', '   ']) {
    for (final field in ['name', 'id', 'version', 'build']) {
      test(
        'S001_T06_blank_fields_and_identity_mismatch_are_invalid $field ${blank.length}',
        () {
          final result = validate(
            name: field == 'name' ? blank : 'free-tracker',
            id: field == 'id' ? blank : expectedId,
            version: field == 'version' ? blank : 'v',
            build: field == 'build' ? blank : '1',
          );
          expect(
            (result as AppInfoFailure).code,
            AppInfoFailureCode.invalidMetadata,
          );
        },
      );
    }
  }
  for (final field in ['name', 'id']) {
    test(
      'S001_T06_blank_fields_and_identity_mismatch_are_invalid wrong $field',
      () {
        expect(
          (validate(
            name: field == 'name' ? 'wrong' : 'free-tracker',
            id: field == 'id' ? 'com.example.wrong' : expectedId,
          ) as AppInfoFailure).code,
          AppInfoFailureCode.invalidMetadata,
        );
      },
    );
  }
  for (final build in ['0', '00', '-1', '1.5', 'abc', '1 1', '1\n2', '١']) {
    test('S001_T07_build_number_boundaries invalid $build', () {
      expect(validate(build: build), isA<AppInfoFailure>());
    });
  }
  for (final build in ['1', '001', '9' * 100]) {
    test('S001_T07_build_number_boundaries valid $build', () {
      expect(
        (validate(build: build) as AppInfoSuccess).info.buildNumber,
        build,
      );
    });
  }
}
