import 'package:flutter/widgets.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'src/app.dart';
import 'src/mac_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerMyDataLicenses();
  if (MacLook.forThisPlatform) await MacWindow.setUp();
  runApp(MyContactsApp(host: HostController(app: 'mycontacts')));
}
