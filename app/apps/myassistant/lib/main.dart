import 'package:flutter/widgets.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerMyDataLicenses();
  await MacShell.setUp();
  runApp(MyAssistantApp(host: HostController(app: 'myassistant')));
}
