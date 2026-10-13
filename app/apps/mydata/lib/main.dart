import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'src/app.dart';
import 'src/desktop_lifetime.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerMyDataLicenses();
  final controller = HostController(app: 'mydata');
  if (DesktopLifetime.supported) {
    try {
      await DesktopLifetime.start(controller);
    } on Object catch (e) {
      // A plain window that quits on close beats no window at all.
      debugPrint('myData: no menu-bar icon: $e');
    }
  }
  // mydata://settings/sources, from myContacts and myCalendar: the runner forwards it (LinksAppDelegate.swift).
  final links = IncomingLinks(app: MyDataAppId.mydata)..start();
  runApp(MyDataApp(controller: controller, openSetup: args.contains('--setup'), links: links.links));
  unawaited(controller.connect());
}
