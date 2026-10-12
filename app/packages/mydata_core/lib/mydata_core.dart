/// Shared app logic for the myData apps: finding, starting and watching the host, reading this
/// app's token, and the error states every app shows.
library;

export 'package:mydata_client/api.dart';

export 'src/availability.dart';
export 'src/host_controller.dart';
export 'src/platform.dart' show HostEnvironment, HostPlatform, LaunchResult, hostPlatform;
