//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FollowedKeepIn {
  /// Returns a new [FollowedKeepIn] instance.
  FollowedKeepIn({
    this.followed = const [],
  });

  /// the changed copies the user reviewed: their mark is cleared
  List<FollowedSeenIn> followed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowedKeepIn && _deepEquality.equals(other.followed, followed);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (followed.hashCode);

  @override
  String toString() => 'FollowedKeepIn[followed=$followed]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'followed'] = this.followed;
    return json;
  }

  /// Returns a new [FollowedKeepIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FollowedKeepIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'followed'),
            'Required key "FollowedKeepIn[followed]" is missing from JSON.');
        assert(json[r'followed'] != null,
            'Required key "FollowedKeepIn[followed]" has a null value in JSON.');
        return true;
      }());

      return FollowedKeepIn(
        followed: FollowedSeenIn.listFromJson(json[r'followed']),
      );
    }
    return null;
  }

  static List<FollowedKeepIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <FollowedKeepIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FollowedKeepIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FollowedKeepIn> mapFromJson(dynamic json) {
    final map = <String, FollowedKeepIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FollowedKeepIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FollowedKeepIn-objects as value to a dart map
  static Map<String, List<FollowedKeepIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<FollowedKeepIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FollowedKeepIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'followed',
  };
}
