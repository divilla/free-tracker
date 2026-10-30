import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:free_tracker/app/app.dart';
import 'package:free_tracker/app/composition.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('S001_P01_real_android_metadata', (tester) async {
    final loader = createAppInfoLoader();
    await tester.pumpWidget(FreeTrackerApp(loader: loader));
    await tester.pumpAndSettle();
    final info = loader.state.info;
    expect(info, isNotNull);
    expect(info!.appName, 'free-tracker');
    expect(info.applicationId, applicationId);
    expect(info.version, '1.0.0');
    expect(info.buildNumber, '1');
    expect(find.text('Version: 1.0.0'), findsOneWidget);
  });
}
