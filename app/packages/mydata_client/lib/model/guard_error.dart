//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GuardError {
  /// Returns a new [GuardError] instance.
  GuardError({
    required this.detail,
  });

  String detail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GuardError && other.detail == detail;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (detail.hashCode);

  @override
  String toString() => 'GuardError[detail=$detail]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'detail'] = this.detail;
    return json;
  }

  /// Returns a new [GuardError] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static GuardError? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'detail'),
            'Required key "GuardError[detail]" is missing from JSON.');
        assert(json[r'detail'] != null,
            'Required key "GuardError[detail]" has a null value in JSON.');
        return true;
      }());

      return GuardError(
        detail: mapValueOfType<String>(json, r'detail')!,
      );
    }
    return null;
  }

  static List<GuardError> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <GuardError>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = GuardError.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, GuardError> mapFromJson(dynamic json) {
    final map = <String, GuardError>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = GuardError.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of GuardError-objects as value to a dart map
  static Map<String, List<GuardError>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<GuardError>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = GuardError.listFromJson(
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
  };
}
