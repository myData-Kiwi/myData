import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';

import 'format.dart';

/// Runs one request against the host, then refreshes its status so every screen shows the result.
/// A failure is shown to the person as `[failure]: the host's reason`. Returns whether it worked.
Future<bool> runHostAction(
  BuildContext context,
  HostController controller, {
  required String failure,
  required Future<void> Function(HostConnection connection) action,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final connection = controller.connection;
  if (connection == null) {
    messenger.showSnackBar(SnackBar(content: Text('$failure: the host is not connected.')));
    return false;
  }
  try {
    await action(connection);
  } on Object catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$failure: ${errorText(e)}')));
    return false;
  }
  await controller.refresh();
  return true;
}
