//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportChoiceIn {
  /// Returns a new [ImportChoiceIn] instance.
  ImportChoiceIn({
    required this.action,
    required this.index,
  });

  ImportChoiceInActionEnum action;

  /// Minimum value: 0
  int index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportChoiceIn && other.action == action && other.index == index;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (action.hashCode) + (index.hashCode);

  @override
  String toString() => 'ImportChoiceIn[action=$action, index=$index]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'action'] = this.action;
    json[r'index'] = this.index;
    return json;
  }

  /// Returns a new [ImportChoiceIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportChoiceIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'action'),
            'Required key "ImportChoiceIn[action]" is missing from JSON.');
        assert(json[r'action'] != null,
            'Required key "ImportChoiceIn[action]" has a null value in JSON.');
        assert(json.containsKey(r'index'),
            'Required key "ImportChoiceIn[index]" is missing from JSON.');
        assert(json[r'index'] != null,
            'Required key "ImportChoiceIn[index]" has a null value in JSON.');
        return true;
      }());

      return ImportChoiceIn(
        action: ImportChoiceInActionEnum.fromJson(json[r'action'])!,
        index: mapValueOfType<int>(json, r'index')!,
      );
    }
    return null;
  }

  static List<ImportChoiceIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportChoiceIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportChoiceIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportChoiceIn> mapFromJson(dynamic json) {
    final map = <String, ImportChoiceIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportChoiceIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportChoiceIn-objects as value to a dart map
  static Map<String, List<ImportChoiceIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportChoiceIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportChoiceIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'index',
  };
}

enum ImportChoiceInActionEnum {
  import_._(r'import'),
  update._(r'update'),
  link._(r'link'),
  skip._(r'skip'),
  ;

  /// Instantiate a new enum with the provided value.
  const ImportChoiceInActionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ImportChoiceInActionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ImportChoiceInActionEnum? fromJson(dynamic value) =>
      ImportChoiceInActionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ImportChoiceInActionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ImportChoiceInActionEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportChoiceInActionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportChoiceInActionEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ImportChoiceInActionEnum] to String,
/// and [decode] dynamic data back to [ImportChoiceInActionEnum].
class ImportChoiceInActionEnumTypeTransformer {
  factory ImportChoiceInActionEnumTypeTransformer() =>
      _instance ??= const ImportChoiceInActionEnumTypeTransformer._();

  const ImportChoiceInActionEnumTypeTransformer._();

  String encode(ImportChoiceInActionEnum data) => data._value;

  /// Returns the instance of [ImportChoiceInActionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ImportChoiceInActionEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is ImportChoiceInActionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'import':
          return ImportChoiceInActionEnum.import_;
        case r'update':
          return ImportChoiceInActionEnum.update;
        case r'link':
          return ImportChoiceInActionEnum.link;
        case r'skip':
          return ImportChoiceInActionEnum.skip;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ImportChoiceInActionEnumTypeTransformer? _instance;
}
