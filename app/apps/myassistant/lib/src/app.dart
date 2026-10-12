import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'home.dart';

/// The myAssistant app. It connects to the host (starting it if needed) and never stops it: the host's
/// lifetime belongs to the myData app.
class MyAssistantApp extends StatelessWidget {
  const MyAssistantApp({super.key, required this.host});

  /// This app's view of the host, made with `app: 'myassistant'`. The app connects and disposes it.
  final HostController host;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'myAssistant',
    theme: myDataTheme(),
    debugShowCheckedModeBanner: false,
    home: AssistantHome(host: host),
  );
}
