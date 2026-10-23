import 'package:flutter/widgets.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerMyDataLicenses();
  await MacShell.setUp();
  final links = IncomingLinks(app: MyDataAppId.mycalendar)..start();
  runApp(MyCalendarApp(host: HostController(app: MyDataAppId.mycalendar.name), links: links.links));
}
