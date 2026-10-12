//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ErrorOut {
  /// Returns a new [ErrorOut] instance.
  ErrorOut({
    required this.at,
    required this.logger,
    required this.message,
  });

  String at;

  String logger;

  String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorOut &&
          other.at == at &&
          other.logger == logger &&
          other.message == message;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (at.hashCode) + (logger.hashCode) + (message.hashCode);

  @override
  String toString() => 'ErrorOut[at=$at, logger=$logger, message=$message]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'at'] = this.at;
    json[r'logger'] = this.logger;
    json[r'message'] = this.message;
    return json;
  }

  /// Returns a new [ErrorOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ErrorOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'at'),
            'Required key "ErrorOut[at]" is missing from JSON.');
        assert(json[r'at'] != null,
            'Required key "ErrorOut[at]" has a null value in JSON.');
        assert(json.containsKey(r'logger'),
            'Required key "ErrorOut[logger]" is missing from JSON.');
        assert(json[r'logger'] != null,
            'Required key "ErrorOut[logger]" has a null value in JSON.');
        assert(json.containsKey(r'message'),
            'Required key "ErrorOut[message]" is missing from JSON.');
        assert(json[r'message'] != null,
            'Required key "ErrorOut[message]" has a null value in JSON.');
        return true;
      }());

      return ErrorOut(
        at: mapValueOfType<String>(json, r'at')!,
        logger: mapValueOfType<String>(json, r'logger')!,
        message: mapValueOfType<String>(json, r'message')!,
      );
    }
    return null;
  }

  static List<ErrorOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ErrorOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ErrorOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ErrorOut> mapFromJson(dynamic json) {
    final map = <String, ErrorOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ErrorOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ErrorOut-objects as value to a dart map
  static Map<String, List<ErrorOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ErrorOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ErrorOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'at',
    'logger',
    'message',
  };
}
