//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class DecisionIn {
  /// Returns a new [DecisionIn] instance.
  DecisionIn({
    required this.decision,
  });

  DecisionInDecisionEnum decision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecisionIn && other.decision == decision;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (decision.hashCode);

  @override
  String toString() => 'DecisionIn[decision=$decision]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'decision'] = this.decision;
    return json;
  }

  /// Returns a new [DecisionIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DecisionIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'decision'),
            'Required key "DecisionIn[decision]" is missing from JSON.');
        assert(json[r'decision'] != null,
            'Required key "DecisionIn[decision]" has a null value in JSON.');
        return true;
      }());

      return DecisionIn(
        decision: DecisionInDecisionEnum.fromJson(json[r'decision'])!,
      );
    }
    return null;
  }

  static List<DecisionIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <DecisionIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DecisionIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DecisionIn> mapFromJson(dynamic json) {
    final map = <String, DecisionIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DecisionIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DecisionIn-objects as value to a dart map
  static Map<String, List<DecisionIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<DecisionIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DecisionIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'decision',
  };
}

enum DecisionInDecisionEnum {
  approve._(r'approve'),
  reject._(r'reject'),
  ;

  /// Instantiate a new enum with the provided value.
  const DecisionInDecisionEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DecisionInDecisionEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DecisionInDecisionEnum? fromJson(dynamic value) =>
      DecisionInDecisionEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DecisionInDecisionEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DecisionInDecisionEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <DecisionInDecisionEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DecisionInDecisionEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DecisionInDecisionEnum] to String,
/// and [decode] dynamic data back to [DecisionInDecisionEnum].
class DecisionInDecisionEnumTypeTransformer {
  factory DecisionInDecisionEnumTypeTransformer() =>
      _instance ??= const DecisionInDecisionEnumTypeTransformer._();

  const DecisionInDecisionEnumTypeTransformer._();

  String encode(DecisionInDecisionEnum data) => data._value;

  /// Returns the instance of [DecisionInDecisionEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DecisionInDecisionEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is DecisionInDecisionEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'approve':
          return DecisionInDecisionEnum.approve;
        case r'reject':
          return DecisionInDecisionEnum.reject;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DecisionInDecisionEnumTypeTransformer? _instance;
}
