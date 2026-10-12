import 'dart:convert';

import 'package:mydata_client/api.dart';

/// The `detail` text of a host error body (`{"detail": "..."}`), or null if there is none.
String? hostDetail(String body) {
  try {
    final json = jsonDecode(body);
    if (json is! Map) return null;
    final detail = json['detail'];
    if (detail == null) return null;
    return detail is String ? detail : jsonEncode(detail);
  } on FormatException {
    return body.trim().isEmpty ? null : body.trim();
  }
}

/// Words for a failed host call: the host's own detail where it gave one.
String describeHostError(Object error) {
  if (error is ApiException) {
    final detail = error.message == null ? null : hostDetail(error.message!);
    final inner = error.innerException;
    if (inner != null) return '${detail ?? 'The myData host could not be reached'}: $inner';
    return detail ?? 'The myData host answered ${error.code}.';
  }
  if (error is StateError) return error.message;
  return '$error';
}
