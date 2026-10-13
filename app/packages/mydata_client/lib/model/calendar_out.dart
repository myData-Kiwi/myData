//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CalendarOut {
  /// Returns a new [CalendarOut] instance.
  CalendarOut({
    required this.accountId,
    this.color,
    required this.id,
    required this.name,
  });

  String accountId;

  String? color;

  String id;

  String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarOut &&
          other.accountId == accountId &&
          other.color == color &&
          other.id == id &&
          other.name == name;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId.hashCode) +
      (color == null ? 0 : color!.hashCode) +
      (id.hashCode) +
      (name.hashCode);

  @override
  String toString() =>
      'CalendarOut[accountId=$accountId, color=$color, id=$id, name=$name]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'account_id'] = this.accountId;
    if (this.color != null) {
      json[r'color'] = this.color;
    } else {
      json[r'color'] = null;
    }
    json[r'id'] = this.id;
    json[r'name'] = this.name;
    return json;
  }

  /// Returns a new [CalendarOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CalendarOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'account_id'),
            'Required key "CalendarOut[account_id]" is missing from JSON.');
        assert(json[r'account_id'] != null,
            'Required key "CalendarOut[account_id]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "CalendarOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "CalendarOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'name'),
            'Required key "CalendarOut[name]" is missing from JSON.');
        assert(json[r'name'] != null,
            'Required key "CalendarOut[name]" has a null value in JSON.');
        return true;
      }());

      return CalendarOut(
        accountId: mapValueOfType<String>(json, r'account_id')!,
        color: mapValueOfType<String>(json, r'color'),
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
      );
    }
    return null;
  }

  static List<CalendarOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <CalendarOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CalendarOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CalendarOut> mapFromJson(dynamic json) {
    final map = <String, CalendarOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CalendarOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CalendarOut-objects as value to a dart map
  static Map<String, List<CalendarOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<CalendarOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CalendarOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'account_id',
    'id',
    'name',
  };
}
