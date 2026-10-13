//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MacCalendarOut {
  /// Returns a new [MacCalendarOut] instance.
  MacCalendarOut({
    this.color,
    required this.id,
    required this.included,
    required this.name,
    this.sourceName = '',
  });

  String? color;

  String id;

  bool included;

  String name;

  String sourceName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacCalendarOut &&
          other.color == color &&
          other.id == id &&
          other.included == included &&
          other.name == name &&
          other.sourceName == sourceName;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (color == null ? 0 : color!.hashCode) +
      (id.hashCode) +
      (included.hashCode) +
      (name.hashCode) +
      (sourceName.hashCode);

  @override
  String toString() =>
      'MacCalendarOut[color=$color, id=$id, included=$included, name=$name, sourceName=$sourceName]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.color != null) {
      json[r'color'] = this.color;
    } else {
      json[r'color'] = null;
    }
    json[r'id'] = this.id;
    json[r'included'] = this.included;
    json[r'name'] = this.name;
    json[r'source_name'] = this.sourceName;
    return json;
  }

  /// Returns a new [MacCalendarOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MacCalendarOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'),
            'Required key "MacCalendarOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "MacCalendarOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'included'),
            'Required key "MacCalendarOut[included]" is missing from JSON.');
        assert(json[r'included'] != null,
            'Required key "MacCalendarOut[included]" has a null value in JSON.');
        assert(json.containsKey(r'name'),
            'Required key "MacCalendarOut[name]" is missing from JSON.');
        assert(json[r'name'] != null,
            'Required key "MacCalendarOut[name]" has a null value in JSON.');
        return true;
      }());

      return MacCalendarOut(
        color: mapValueOfType<String>(json, r'color'),
        id: mapValueOfType<String>(json, r'id')!,
        included: mapValueOfType<bool>(json, r'included')!,
        name: mapValueOfType<String>(json, r'name')!,
        sourceName: mapValueOfType<String>(json, r'source_name') ?? '',
      );
    }
    return null;
  }

  static List<MacCalendarOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <MacCalendarOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MacCalendarOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MacCalendarOut> mapFromJson(dynamic json) {
    final map = <String, MacCalendarOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MacCalendarOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MacCalendarOut-objects as value to a dart map
  static Map<String, List<MacCalendarOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<MacCalendarOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MacCalendarOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'included',
    'name',
  };
}
