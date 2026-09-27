import 'package:flutter/widgets.dart';

import 'app/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.create();
  runApp(bootstrap.buildApp());
}
