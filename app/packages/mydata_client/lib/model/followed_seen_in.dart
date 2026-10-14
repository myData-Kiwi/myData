//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FollowedSeenIn {
  /// Returns a new [FollowedSeenIn] instance.
  FollowedSeenIn({
    required this.etag,
    required this.id,
  });

  /// its etag as the user saw it
  String etag;

  /// a followed copy's id (FollowedChangeOut.followed.id)
  String id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowedSeenIn && other.etag == etag && other.id == id;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (etag.hashCode) + (id.hashCode);

  @override
  String toString() => 'FollowedSeenIn[etag=$etag, id=$id]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'etag'] = this.etag;
    json[r'id'] = this.id;
    return json;
  }

  /// Returns a new [FollowedSeenIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FollowedSeenIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'etag'),
            'Required key "FollowedSeenIn[etag]" is missing from JSON.');
        assert(json[r'etag'] != null,
            'Required key "FollowedSeenIn[etag]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "FollowedSeenIn[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "FollowedSeenIn[id]" has a null value in JSON.');
        return true;
      }());

      return FollowedSeenIn(
        etag: mapValueOfType<String>(json, r'etag')!,
        id: mapValueOfType<String>(json, r'id')!,
      );
    }
    return null;
  }

  static List<FollowedSeenIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <FollowedSeenIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FollowedSeenIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FollowedSeenIn> mapFromJson(dynamic json) {
    final map = <String, FollowedSeenIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FollowedSeenIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FollowedSeenIn-objects as value to a dart map
  static Map<String, List<FollowedSeenIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<FollowedSeenIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FollowedSeenIn.listFromJson(
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
