//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MacContainerOut {
  /// Returns a new [MacContainerOut] instance.
  MacContainerOut({
    required this.id,
    required this.included,
    required this.kind,
    required this.name,
  });

  String id;

  bool included;

  /// cardDAV, exchange, local or unassigned
  String kind;

  String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacContainerOut &&
          other.id == id &&
          other.included == included &&
          other.kind == kind &&
          other.name == name;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (id.hashCode) + (included.hashCode) + (kind.hashCode) + (name.hashCode);

  @override
  String toString() =>
      'MacContainerOut[id=$id, included=$included, kind=$kind, name=$name]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'id'] = this.id;
    json[r'included'] = this.included;
    json[r'kind'] = this.kind;
    json[r'name'] = this.name;
    return json;
  }

  /// Returns a new [MacContainerOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MacContainerOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'),
            'Required key "MacContainerOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "MacContainerOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'included'),
            'Required key "MacContainerOut[included]" is missing from JSON.');
        assert(json[r'included'] != null,
            'Required key "MacContainerOut[included]" has a null value in JSON.');
        assert(json.containsKey(r'kind'),
            'Required key "MacContainerOut[kind]" is missing from JSON.');
        assert(json[r'kind'] != null,
            'Required key "MacContainerOut[kind]" has a null value in JSON.');
        assert(json.containsKey(r'name'),
            'Required key "MacContainerOut[name]" is missing from JSON.');
        assert(json[r'name'] != null,
            'Required key "MacContainerOut[name]" has a null value in JSON.');
        return true;
      }());

      return MacContainerOut(
        id: mapValueOfType<String>(json, r'id')!,
        included: mapValueOfType<bool>(json, r'included')!,
        kind: mapValueOfType<String>(json, r'kind')!,
        name: mapValueOfType<String>(json, r'name')!,
      );
    }
    return null;
  }

  static List<MacContainerOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <MacContainerOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MacContainerOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MacContainerOut> mapFromJson(dynamic json) {
    final map = <String, MacContainerOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MacContainerOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MacContainerOut-objects as value to a dart map
  static Map<String, List<MacContainerOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<MacContainerOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MacContainerOut.listFromJson(
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
    'kind',
    'name',
  };
}
