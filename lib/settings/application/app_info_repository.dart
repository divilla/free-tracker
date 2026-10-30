import '../domain/app_info.dart';

abstract interface class AppInfoRepository {
  Future<AppInfoResult> load();
}
