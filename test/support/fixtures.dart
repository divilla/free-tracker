import 'package:free_tracker/settings/application/app_info_repository.dart';
import 'package:free_tracker/settings/domain/app_info.dart';

const expectedId = 'com.bindefined.freetracker';
AppInfoSuccess success({
  String version = 'fixture-release',
  String build = '001',
}) => AppInfo.validate(
  appName: 'free-tracker',
  applicationId: expectedId,
  version: version,
  buildNumber: build,
  expectedApplicationId: expectedId,
) as AppInfoSuccess;

class Repository implements AppInfoRepository {
  Repository(this.read);
  final Future<AppInfoResult> Function() read;
  int calls = 0;
  @override
  Future<AppInfoResult> load() {
    calls++;
    return read();
  }
}
