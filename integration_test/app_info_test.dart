import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:free_tracker/main.dart' as entry;

import '../test/support/scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('S001_E01_installed_shell_identity', (tester) async {
    entry.main();
    await tester.pumpAndSettle();
    expect(find.text('free-tracker'), findsNWidgets(2));
    expect(
      find.text('Application ID: com.bindefined.freetracker'),
      findsOneWidget,
    );
    expect(find.text('Version: 1.0.0'), findsOneWidget);
    expect(find.text('Build number: 1'), findsOneWidget);
    expect(find.text('Start tour'), findsNothing);
  });
  controlledScenarios();
}
