import 'dart:convert';

import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// A host timestamp (ISO 8601, UTC) in local time: "12 Oct 2026, 2:03 pm", or "12 Oct 2026, 14:03" on a
/// 24-hour clock (the Mac's setting unless [use24HourFormat] says; MyDataDates).
String formatWhen(String iso, {bool? use24HourFormat}) =>
    MyDataDates.hostDayAndTime(iso, use24HourFormat: use24HourFormat);

/// "12 Oct 2026".
String formatDay(DateTime d) => MyDataDates.day(d);

/// A host date ("2026-03-18") as "18 Mar 2026".
String formatDate(String isoDate) => MyDataDates.hostDay(isoDate);

/// "3 d 4 h", "2 h 14 min", "5 min", "40 s".
String formatUptime(num seconds) {
  final d = Duration(seconds: seconds.round());
  if (d.inDays > 0) return '${d.inDays} d ${d.inHours.remainder(24)} h';
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes.remainder(60)} min';
  if (d.inMinutes > 0) return '${d.inMinutes} min';
  return '${d.inSeconds} s';
}

/// Byte counts for people: "9.3 GB", "120 MB". Null (not known) is "Not known".
String formatSize(int? bytes) {
  if (bytes == null) return 'Not known';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

/// The host's own words for a failed request (its JSON `detail`), or the error as text.
String errorText(Object error) {
  if (error is! ApiException) return '$error';
  final body = error.message;
  if (body == null || body.isEmpty) return 'The host answered with status ${error.code}.';
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return body;
  }
  final detail = decoded is Map ? decoded['detail'] : null;
  return detail is String ? detail : body;
}
