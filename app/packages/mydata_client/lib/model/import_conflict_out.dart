//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportConflictOut {
  /// Returns a new [ImportConflictOut] instance.
  ImportConflictOut({
    this.contactId,
    required this.displayName,
    required this.index,
    this.reason,
  });

  String? contactId;

  String displayName;

  int index;

  String? reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportConflictOut &&
          other.contactId == contactId &&
          other.displayName == displayName &&
          other.index == index &&
          other.reason == reason;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (contactId == null ? 0 : contactId!.hashCode) +
      (displayName.hashCode) +
      (index.hashCode) +
      (reason == null ? 0 : reason!.hashCode);

  @override
  String toString() =>
      'ImportConflictOut[contactId=$contactId, displayName=$displayName, index=$index, reason=$reason]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.contactId != null) {
      json[r'contact_id'] = this.contactId;
    } else {
      json[r'contact_id'] = null;
    }
    json[r'display_name'] = this.displayName;
    json[r'index'] = this.index;
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
    return json;
  }

  /// Returns a new [ImportConflictOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportConflictOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'display_name'),
            'Required key "ImportConflictOut[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null,
            'Required key "ImportConflictOut[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'index'),
            'Required key "ImportConflictOut[index]" is missing from JSON.');
        assert(json[r'index'] != null,
            'Required key "ImportConflictOut[index]" has a null value in JSON.');
        return true;
      }());

      return ImportConflictOut(
        contactId: mapValueOfType<String>(json, r'contact_id'),
        displayName: mapValueOfType<String>(json, r'display_name')!,
        index: mapValueOfType<int>(json, r'index')!,
        reason: mapValueOfType<String>(json, r'reason'),
      );
    }
    return null;
  }

  static List<ImportConflictOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportConflictOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportConflictOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportConflictOut> mapFromJson(dynamic json) {
    final map = <String, ImportConflictOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportConflictOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportConflictOut-objects as value to a dart map
  static Map<String, List<ImportConflictOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportConflictOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportConflictOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'display_name',
    'index',
  };
}
