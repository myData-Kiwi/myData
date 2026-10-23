import 'dart:async';

import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) => myDataTestExecutable(() async {
  // The branded frame unless a test asks for the Mac frame (mac_frame_test.dart), also in the macOS variants.
  MacLook.debugOverride = false;
  await loadMacFonts();
  await testMain();
});
