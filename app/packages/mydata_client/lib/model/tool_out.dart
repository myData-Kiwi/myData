//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ToolOut {
  /// Returns a new [ToolOut] instance.
  ToolOut({
    required this.description,
    this.inputSchema = const {},
    required this.name,
    required this.permission,
  });

  String description;

  Map<String, Object> inputSchema;

  String name;

  ToolOutPermissionEnum permission;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolOut &&
          other.description == description &&
          _deepEquality.equals(other.inputSchema, inputSchema) &&
          other.name == name &&
          other.permission == permission;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (description.hashCode) +
      (inputSchema.hashCode) +
      (name.hashCode) +
      (permission.hashCode);

  @override
  String toString() =>
      'ToolOut[description=$description, inputSchema=$inputSchema, name=$name, permission=$permission]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'description'] = this.description;
    json[r'input_schema'] = this.inputSchema;
    json[r'name'] = this.name;
    json[r'permission'] = this.permission;
    return json;
  }

  /// Returns a new [ToolOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ToolOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'description'),
            'Required key "ToolOut[description]" is missing from JSON.');
        assert(json[r'description'] != null,
            'Required key "ToolOut[description]" has a null value in JSON.');
        assert(json.containsKey(r'input_schema'),
            'Required key "ToolOut[input_schema]" is missing from JSON.');
        assert(json[r'input_schema'] != null,
            'Required key "ToolOut[input_schema]" has a null value in JSON.');
        assert(json.containsKey(r'name'),
            'Required key "ToolOut[name]" is missing from JSON.');
        assert(json[r'name'] != null,
            'Required key "ToolOut[name]" has a null value in JSON.');
        assert(json.containsKey(r'permission'),
            'Required key "ToolOut[permission]" is missing from JSON.');
        assert(json[r'permission'] != null,
            'Required key "ToolOut[permission]" has a null value in JSON.');
        return true;
      }());

      return ToolOut(
        description: mapValueOfType<String>(json, r'description')!,
        inputSchema: mapCastOfType<String, Object>(json, r'input_schema')!,
        name: mapValueOfType<String>(json, r'name')!,
        permission: ToolOutPermissionEnum.fromJson(json[r'permission'])!,
      );
    }
    return null;
  }

  static List<ToolOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ToolOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ToolOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ToolOut> mapFromJson(dynamic json) {
    final map = <String, ToolOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ToolOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ToolOut-objects as value to a dart map
  static Map<String, List<ToolOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ToolOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ToolOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'description',
    'input_schema',
    'name',
    'permission',
  };
}

enum ToolOutPermissionEnum {
  read._(r'read'),
  reversible._(r'reversible'),
  irreversible._(r'irreversible'),
  ;

  /// Instantiate a new enum with the provided value.
  const ToolOutPermissionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ToolOutPermissionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ToolOutPermissionEnum? fromJson(dynamic value) =>
      ToolOutPermissionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ToolOutPermissionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ToolOutPermissionEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ToolOutPermissionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ToolOutPermissionEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ToolOutPermissionEnum] to String,
/// and [decode] dynamic data back to [ToolOutPermissionEnum].
class ToolOutPermissionEnumTypeTransformer {
  factory ToolOutPermissionEnumTypeTransformer() =>
      _instance ??= const ToolOutPermissionEnumTypeTransformer._();

  const ToolOutPermissionEnumTypeTransformer._();

  String encode(ToolOutPermissionEnum data) => data._value;

  /// Returns the instance of [ToolOutPermissionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ToolOutPermissionEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is ToolOutPermissionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'read':
          return ToolOutPermissionEnum.read;
        case r'reversible':
          return ToolOutPermissionEnum.reversible;
        case r'irreversible':
          return ToolOutPermissionEnum.irreversible;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ToolOutPermissionEnumTypeTransformer? _instance;
}
