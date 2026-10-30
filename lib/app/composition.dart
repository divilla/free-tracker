import '../settings/application/app_info_loader.dart';
import '../settings/application/app_info_repository.dart';
import '../settings/data/platform_app_info_repository.dart';

const applicationId = 'com.bindefined.freetracker';

AppInfoLoader createAppInfoLoader({AppInfoRepository? repository}) =>
    AppInfoLoader(
      repository ??
          PlatformAppInfoRepository(expectedApplicationId: applicationId),
    );
