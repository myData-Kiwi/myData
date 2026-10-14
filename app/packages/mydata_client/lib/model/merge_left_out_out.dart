//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MergeLeftOutOut {
  /// Returns a new [MergeLeftOutOut] instance.
  MergeLeftOutOut({
    required this.count,
    required this.property,
  });

  /// how many of the other contacts' values of it the merged contact does not hold
  int count;

  /// a vCard property name, upper case (TITLE, BDAY, PHOTO, X-ABSHOWAS, ...)
  String property;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeLeftOutOut &&
          other.count == count &&
          other.property == property;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (count.hashCode) + (property.hashCode);

  @override
  String toString() => 'MergeLeftOutOut[count=$count, property=$property]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'count'] = this.count;
    json[r'property'] = this.property;
    return json;
  }

  /// Returns a new [MergeLeftOutOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MergeLeftOutOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'count'),
            'Required key "MergeLeftOutOut[count]" is missing from JSON.');
        assert(json[r'count'] != null,
            'Required key "MergeLeftOutOut[count]" has a null value in JSON.');
        assert(json.containsKey(r'property'),
            'Required key "MergeLeftOutOut[property]" is missing from JSON.');
        assert(json[r'property'] != null,
            'Required key "MergeLeftOutOut[property]" has a null value in JSON.');
        return true;
      }());

      return MergeLeftOutOut(
        count: mapValueOfType<int>(json, r'count')!,
        property: mapValueOfType<String>(json, r'property')!,
      );
    }
    return null;
  }

  static List<MergeLeftOutOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <MergeLeftOutOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MergeLeftOutOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MergeLeftOutOut> mapFromJson(dynamic json) {
    final map = <String, MergeLeftOutOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MergeLeftOutOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MergeLeftOutOut-objects as value to a dart map
  static Map<String, List<MergeLeftOutOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<MergeLeftOutOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MergeLeftOutOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'count',
    'property',
  };
}
