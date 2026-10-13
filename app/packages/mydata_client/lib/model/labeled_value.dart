//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LabeledValue {
  /// Returns a new [LabeledValue] instance.
  LabeledValue({
    this.label = '',
    required this.value,
  });

  String label;

  String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabeledValue && other.label == label && other.value == value;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (label.hashCode) + (value.hashCode);

  @override
  String toString() => 'LabeledValue[label=$label, value=$value]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'label'] = this.label;
    json[r'value'] = this.value;
    return json;
  }

  /// Returns a new [LabeledValue] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LabeledValue? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'value'),
            'Required key "LabeledValue[value]" is missing from JSON.');
        assert(json[r'value'] != null,
            'Required key "LabeledValue[value]" has a null value in JSON.');
        return true;
      }());

      return LabeledValue(
        label: mapValueOfType<String>(json, r'label') ?? '',
        value: mapValueOfType<String>(json, r'value')!,
      );
    }
    return null;
  }

  static List<LabeledValue> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <LabeledValue>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LabeledValue.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LabeledValue> mapFromJson(dynamic json) {
    final map = <String, LabeledValue>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LabeledValue.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LabeledValue-objects as value to a dart map
  static Map<String, List<LabeledValue>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<LabeledValue>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LabeledValue.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'value',
  };
}
