import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/composition.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FreeTrackerApp(loader: createAppInfoLoader()));
}
