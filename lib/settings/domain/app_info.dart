/// Installed metadata. Identifiers are opaque strings, not localized numbers.
final class AppInfo {
  const AppInfo._(
    this.appName,
    this.applicationId,
    this.version,
    this.buildNumber,
  );

  final String appName;
  final String applicationId;
  final String version;
  final String buildNumber;

  static AppInfoResult validate({
    required String appName,
    required String applicationId,
    required String version,
    required String buildNumber,
    required String expectedApplicationId,
  }) {
    final name = appName.trim();
    final id = applicationId.trim();
    final release = version.trim();
    final build = buildNumber.trim();
    if (name != 'free-tracker' ||
        id.isEmpty ||
        id != expectedApplicationId ||
        release.isEmpty ||
        !RegExp(r'^[0-9]+$').hasMatch(build) ||
        !RegExp(r'[1-9]').hasMatch(build)) {
      return const AppInfoFailure(AppInfoFailureCode.invalidMetadata);
    }
    return AppInfoSuccess(AppInfo._(name, id, release, build));
  }
}

enum AppInfoFailureCode { invalidMetadata, unsupportedPlatform, readFailed }

sealed class AppInfoResult {
  const AppInfoResult();
}

final class AppInfoSuccess extends AppInfoResult {
  const AppInfoSuccess(this.info);
  final AppInfo info;
}

final class AppInfoFailure extends AppInfoResult {
  const AppInfoFailure(this.code);
  final AppInfoFailureCode code;
}
