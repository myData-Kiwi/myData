//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AccessIn {
  /// Returns a new [AccessIn] instance.
  AccessIn({
    required this.what,
  });

  AccessInWhatEnum what;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AccessIn && other.what == what;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (what.hashCode);

  @override
  String toString() => 'AccessIn[what=$what]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'what'] = this.what;
    return json;
  }

  /// Returns a new [AccessIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AccessIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'what'),
            'Required key "AccessIn[what]" is missing from JSON.');
        assert(json[r'what'] != null,
            'Required key "AccessIn[what]" has a null value in JSON.');
        return true;
      }());

      return AccessIn(
        what: AccessInWhatEnum.fromJson(json[r'what'])!,
      );
    }
    return null;
  }

  static List<AccessIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AccessIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AccessIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AccessIn> mapFromJson(dynamic json) {
    final map = <String, AccessIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AccessIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AccessIn-objects as value to a dart map
  static Map<String, List<AccessIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AccessIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AccessIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'what',
  };
}

enum AccessInWhatEnum {
  contacts._(r'contacts'),
  calendars._(r'calendars'),
  ;

  /// Instantiate a new enum with the provided value.
  const AccessInWhatEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [AccessInWhatEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static AccessInWhatEnum? fromJson(dynamic value) =>
      AccessInWhatEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [AccessInWhatEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<AccessInWhatEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AccessInWhatEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AccessInWhatEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AccessInWhatEnum] to String,
/// and [decode] dynamic data back to [AccessInWhatEnum].
class AccessInWhatEnumTypeTransformer {
  factory AccessInWhatEnumTypeTransformer() =>
      _instance ??= const AccessInWhatEnumTypeTransformer._();

  const AccessInWhatEnumTypeTransformer._();

  String encode(AccessInWhatEnum data) => data._value;

  /// Returns the instance of [AccessInWhatEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AccessInWhatEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is AccessInWhatEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'contacts':
          return AccessInWhatEnum.contacts;
        case r'calendars':
          return AccessInWhatEnum.calendars;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static AccessInWhatEnumTypeTransformer? _instance;
}
