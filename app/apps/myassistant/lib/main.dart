import 'package:flutter/widgets.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerMyDataLicenses();
  runApp(MyAssistantApp(host: HostController(app: 'myassistant')));
}
