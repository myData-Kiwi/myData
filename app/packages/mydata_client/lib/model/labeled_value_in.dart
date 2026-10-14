//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LabeledValueIn {
  /// Returns a new [LabeledValueIn] instance.
  LabeledValueIn({
    this.label,
    this.value,
  });

  /// mobile, iphone, home, work, main, fax, pager, other, school, homepage, homefax, workfax or otherfax (any case, or as the apps show them: \"Home fax\"), or any text, kept as typed
  String? label;

  /// an empty value is left out
  String? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabeledValueIn && other.label == label && other.value == value;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (label == null ? 0 : label!.hashCode) +
      (value == null ? 0 : value!.hashCode);

  @override
  String toString() => 'LabeledValueIn[label=$label, value=$value]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.label != null) {
      json[r'label'] = this.label;
    } else {
      json[r'label'] = null;
    }
    if (this.value != null) {
      json[r'value'] = this.value;
    } else {
      json[r'value'] = null;
    }
    return json;
  }

  /// Returns a new [LabeledValueIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LabeledValueIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        return true;
      }());

      return LabeledValueIn(
        label: mapValueOfType<String>(json, r'label'),
        value: mapValueOfType<String>(json, r'value'),
      );
    }
    return null;
  }

  static List<LabeledValueIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <LabeledValueIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LabeledValueIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LabeledValueIn> mapFromJson(dynamic json) {
    final map = <String, LabeledValueIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LabeledValueIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LabeledValueIn-objects as value to a dart map
  static Map<String, List<LabeledValueIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<LabeledValueIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LabeledValueIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{};
}
