//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportMissingOut {
  /// Returns a new [ImportMissingOut] instance.
  ImportMissingOut({
    required this.contactId,
    required this.displayName,
  });

  String contactId;

  String displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportMissingOut &&
          other.contactId == contactId &&
          other.displayName == displayName;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (contactId.hashCode) + (displayName.hashCode);

  @override
  String toString() =>
      'ImportMissingOut[contactId=$contactId, displayName=$displayName]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'contact_id'] = this.contactId;
    json[r'display_name'] = this.displayName;
    return json;
  }

  /// Returns a new [ImportMissingOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportMissingOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'contact_id'),
            'Required key "ImportMissingOut[contact_id]" is missing from JSON.');
        assert(json[r'contact_id'] != null,
            'Required key "ImportMissingOut[contact_id]" has a null value in JSON.');
        assert(json.containsKey(r'display_name'),
            'Required key "ImportMissingOut[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null,
            'Required key "ImportMissingOut[display_name]" has a null value in JSON.');
        return true;
      }());

      return ImportMissingOut(
        contactId: mapValueOfType<String>(json, r'contact_id')!,
        displayName: mapValueOfType<String>(json, r'display_name')!,
      );
    }
    return null;
  }

  static List<ImportMissingOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportMissingOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportMissingOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportMissingOut> mapFromJson(dynamic json) {
    final map = <String, ImportMissingOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportMissingOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportMissingOut-objects as value to a dart map
  static Map<String, List<ImportMissingOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportMissingOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportMissingOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'contact_id',
    'display_name',
  };
}
