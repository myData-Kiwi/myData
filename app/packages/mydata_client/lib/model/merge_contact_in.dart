//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MergeContactIn {
  /// Returns a new [MergeContactIn] instance.
  MergeContactIn({
    required this.etag,
    required this.id,
  });

  /// the contact's etag as the user saw it
  String etag;

  String id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeContactIn && other.etag == etag && other.id == id;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (etag.hashCode) + (id.hashCode);

  @override
  String toString() => 'MergeContactIn[etag=$etag, id=$id]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'etag'] = this.etag;
    json[r'id'] = this.id;
    return json;
  }

  /// Returns a new [MergeContactIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MergeContactIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'etag'),
            'Required key "MergeContactIn[etag]" is missing from JSON.');
        assert(json[r'etag'] != null,
            'Required key "MergeContactIn[etag]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "MergeContactIn[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "MergeContactIn[id]" has a null value in JSON.');
        return true;
      }());

      return MergeContactIn(
        etag: mapValueOfType<String>(json, r'etag')!,
        id: mapValueOfType<String>(json, r'id')!,
      );
    }
    return null;
  }

  static List<MergeContactIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <MergeContactIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MergeContactIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MergeContactIn> mapFromJson(dynamic json) {
    final map = <String, MergeContactIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MergeContactIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MergeContactIn-objects as value to a dart map
  static Map<String, List<MergeContactIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<MergeContactIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MergeContactIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'etag',
    'id',
  };
}
