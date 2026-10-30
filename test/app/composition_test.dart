import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:free_tracker/app/composition.dart';
import 'package:free_tracker/main.dart' as entry;
import 'package:free_tracker/settings/application/app_info_loader.dart';

import '../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'S001_T03_composition_selects_injected_or_real_repository injected',
    () async {
      final repo = Repository(() async => success(version: 'distinct'));
      final loader = createAppInfoLoader(repository: repo);
      await loader.load();
      expect(loader.state.info!.version, 'distinct');
      expect(repo.calls, 1);
      await loader.close();
    },
  );
  testWidgets(
    'S001_T03_composition_selects_injected_or_real_repository production startup',
    (tester) async {
      var reads = 0;
      const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            reads++;
            expect(call.method, 'getAll');
            return {
              'appName': 'free-tracker',
              'packageName': applicationId,
              'version': 'platform-fixture',
              'buildNumber': '1',
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      entry.main();
      await tester.pumpAndSettle();
      expect(find.text('Version: platform-fixture'), findsOneWidget);
      expect(reads, 1);
      // This channel mock proves wiring only; Android P01 uses no channel mock.
    },
  );
  test(
    'S001_T03_composition_selects_injected_or_real_repository ready',
    () async {
      final loader = createAppInfoLoader(
        repository: Repository(() async => success()),
      );
      await loader.load();
      expect(loader.state.phase, AppInfoPhase.ready);
      await loader.close();
    },
  );
}
