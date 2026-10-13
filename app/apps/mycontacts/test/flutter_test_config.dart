import 'dart:async';

import 'package:mydata_testing/mydata_testing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) => myDataTestExecutable(testMain);
