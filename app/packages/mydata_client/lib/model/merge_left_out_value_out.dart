//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MergeLeftOutValueOut {
  /// Returns a new [MergeLeftOutValueOut] instance.
  MergeLeftOutValueOut({
    required this.contactId,
    required this.kind,
    required this.property,
    this.value,
  });

  /// the contact that holds it
  String contactId;

  /// what the app names it: birthday, job_title, photo, company, nickname, or other
  String kind;

  /// a vCard property name, upper case (TITLE, BDAY, PHOTO, ...)
  String property;

  /// the value as the contact holds it (a birthday as YYYY-MM-DD or --MM-DD); null for a photo
  String? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeLeftOutValueOut &&
          other.contactId == contactId &&
          other.kind == kind &&
          other.property == property &&
          other.value == value;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (contactId.hashCode) +
      (kind.hashCode) +
      (property.hashCode) +
      (value == null ? 0 : value!.hashCode);

  @override
  String toString() =>
      'MergeLeftOutValueOut[contactId=$contactId, kind=$kind, property=$property, value=$value]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'contact_id'] = this.contactId;
    json[r'kind'] = this.kind;
    json[r'property'] = this.property;
    if (this.value != null) {
      json[r'value'] = this.value;
    } else {
      json[r'value'] = null;
    }
    return json;
  }

  /// Returns a new [MergeLeftOutValueOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MergeLeftOutValueOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'contact_id'),
            'Required key "MergeLeftOutValueOut[contact_id]" is missing from JSON.');
        assert(json[r'contact_id'] != null,
            'Required key "MergeLeftOutValueOut[contact_id]" has a null value in JSON.');
        assert(json.containsKey(r'kind'),
            'Required key "MergeLeftOutValueOut[kind]" is missing from JSON.');
        assert(json[r'kind'] != null,
            'Required key "MergeLeftOutValueOut[kind]" has a null value in JSON.');
        assert(json.containsKey(r'property'),
            'Required key "MergeLeftOutValueOut[property]" is missing from JSON.');
        assert(json[r'property'] != null,
            'Required key "MergeLeftOutValueOut[property]" has a null value in JSON.');
        return true;
      }());

      return MergeLeftOutValueOut(
        contactId: mapValueOfType<String>(json, r'contact_id')!,
        kind: mapValueOfType<String>(json, r'kind')!,
        property: mapValueOfType<String>(json, r'property')!,
        value: mapValueOfType<String>(json, r'value'),
      );
    }
    return null;
  }

  static List<MergeLeftOutValueOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <MergeLeftOutValueOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MergeLeftOutValueOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MergeLeftOutValueOut> mapFromJson(dynamic json) {
    final map = <String, MergeLeftOutValueOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MergeLeftOutValueOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MergeLeftOutValueOut-objects as value to a dart map
  static Map<String, List<MergeLeftOutValueOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<MergeLeftOutValueOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MergeLeftOutValueOut.listFromJson(
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
    'kind',
    'property',
  };
}
