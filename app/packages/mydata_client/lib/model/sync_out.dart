//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncOut {
  /// Returns a new [SyncOut] instance.
  SyncOut({
    this.accounts = const [],
    required this.mode,
  });

  List<AccountSyncOut> accounts;

  SyncOutModeEnum mode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOut &&
          _deepEquality.equals(other.accounts, accounts) &&
          other.mode == mode;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accounts.hashCode) + (mode.hashCode);

  @override
  String toString() => 'SyncOut[accounts=$accounts, mode=$mode]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'accounts'] = this.accounts;
    json[r'mode'] = this.mode;
    return json;
  }

  /// Returns a new [SyncOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'accounts'),
            'Required key "SyncOut[accounts]" is missing from JSON.');
        assert(json[r'accounts'] != null,
            'Required key "SyncOut[accounts]" has a null value in JSON.');
        assert(json.containsKey(r'mode'),
            'Required key "SyncOut[mode]" is missing from JSON.');
        assert(json[r'mode'] != null,
            'Required key "SyncOut[mode]" has a null value in JSON.');
        return true;
      }());

      return SyncOut(
        accounts: AccountSyncOut.listFromJson(json[r'accounts']),
        mode: SyncOutModeEnum.fromJson(json[r'mode'])!,
      );
    }
    return null;
  }

  static List<SyncOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <SyncOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncOut> mapFromJson(dynamic json) {
    final map = <String, SyncOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncOut-objects as value to a dart map
  static Map<String, List<SyncOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<SyncOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'accounts',
    'mode',
  };
}

enum SyncOutModeEnum {
  demo._(r'demo'),
  real._(r'real'),
  ;

  /// Instantiate a new enum with the provided value.
  const SyncOutModeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SyncOutModeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SyncOutModeEnum? fromJson(dynamic value) =>
      SyncOutModeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SyncOutModeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SyncOutModeEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <SyncOutModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncOutModeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SyncOutModeEnum] to String,
/// and [decode] dynamic data back to [SyncOutModeEnum].
class SyncOutModeEnumTypeTransformer {
  factory SyncOutModeEnumTypeTransformer() =>
      _instance ??= const SyncOutModeEnumTypeTransformer._();

  const SyncOutModeEnumTypeTransformer._();

  String encode(SyncOutModeEnum data) => data._value;

  /// Returns the instance of [SyncOutModeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SyncOutModeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is SyncOutModeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'demo':
          return SyncOutModeEnum.demo;
        case r'real':
          return SyncOutModeEnum.real;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SyncOutModeEnumTypeTransformer? _instance;
}
