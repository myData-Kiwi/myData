//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FieldErrorsOut {
  /// Returns a new [FieldErrorsOut] instance.
  FieldErrorsOut({
    required this.detail,
    this.fields = const {},
  });

  String detail;

  /// one message per field that is not valid, by its path in the body (\"emails[1].value\"); never the value itself
  Map<String, String> fields;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldErrorsOut &&
          other.detail == detail &&
          _deepEquality.equals(other.fields, fields);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (detail.hashCode) + (fields.hashCode);

  @override
  String toString() => 'FieldErrorsOut[detail=$detail, fields=$fields]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'detail'] = this.detail;
    json[r'fields'] = this.fields;
    return json;
  }

  /// Returns a new [FieldErrorsOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FieldErrorsOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'detail'),
            'Required key "FieldErrorsOut[detail]" is missing from JSON.');
        assert(json[r'detail'] != null,
            'Required key "FieldErrorsOut[detail]" has a null value in JSON.');
        assert(json.containsKey(r'fields'),
            'Required key "FieldErrorsOut[fields]" is missing from JSON.');
        assert(json[r'fields'] != null,
            'Required key "FieldErrorsOut[fields]" has a null value in JSON.');
        return true;
      }());

      return FieldErrorsOut(
        detail: mapValueOfType<String>(json, r'detail')!,
        fields: mapCastOfType<String, String>(json, r'fields')!,
      );
    }
    return null;
  }

  static List<FieldErrorsOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <FieldErrorsOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FieldErrorsOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FieldErrorsOut> mapFromJson(dynamic json) {
    final map = <String, FieldErrorsOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FieldErrorsOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FieldErrorsOut-objects as value to a dart map
  static Map<String, List<FieldErrorsOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<FieldErrorsOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FieldErrorsOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'detail',
    'fields',
  };
}
