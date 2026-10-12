// The host lives on this machine and is reached through files and processes, which the web build
// cannot use. The io implementation does the real work; the web one reports "not supported".
export 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';
