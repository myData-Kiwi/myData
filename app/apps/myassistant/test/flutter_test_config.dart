import 'dart:async';

import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) {
  // No test asks LaunchServices about, or opens, a real app: the shared links answer "not installed".
  appLinks = AppLinks(macOS: false);
  return myDataTestExecutable(testMain);
}
