import 'dart:async';
import 'dart:io';

import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// Set to a folder outside the checkout to write the stack gate's screenshots there (stack_gate_test.dart),
/// in the Mac's own system font; unset, the Mac frame's committed screenshots use the bundled Figtree.
final gateOut = Platform.environment['MYDATA_GATE_OUT'];

Future<void> testExecutable(FutureOr<void> Function() testMain) => myDataTestExecutable(() async {
  // The branded frame unless a test asks for the Mac frame (mac_frame_test.dart), also in the macOS variants.
  MacLook.debugOverride = false;
  await loadMacFonts(systemFont: gateOut != null && gateOut!.isNotEmpty);
  await testMain();
});
