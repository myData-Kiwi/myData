//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class StopFollowingOut {
  /// Returns a new [StopFollowingOut] instance.
  StopFollowingOut({
    required this.accountId,
    required this.calendarsFollowed,
    required this.contactsFollowed,
    required this.label,
    required this.message,
  });

  String accountId;

  /// stopping following the account stops following these too; they are not imported yet
  int calendarsFollowed;

  int contactsFollowed;

  /// the source as a heading
  String label;

  String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StopFollowingOut &&
          other.accountId == accountId &&
          other.calendarsFollowed == calendarsFollowed &&
          other.contactsFollowed == contactsFollowed &&
          other.label == label &&
          other.message == message;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId.hashCode) +
      (calendarsFollowed.hashCode) +
      (contactsFollowed.hashCode) +
      (label.hashCode) +
      (message.hashCode);

  @override
  String toString() =>
      'StopFollowingOut[accountId=$accountId, calendarsFollowed=$calendarsFollowed, contactsFollowed=$contactsFollowed, label=$label, message=$message]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'account_id'] = this.accountId;
    json[r'calendars_followed'] = this.calendarsFollowed;
    json[r'contacts_followed'] = this.contactsFollowed;
    json[r'label'] = this.label;
    json[r'message'] = this.message;
    return json;
  }

  /// Returns a new [StopFollowingOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static StopFollowingOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'account_id'),
            'Required key "StopFollowingOut[account_id]" is missing from JSON.');
        assert(json[r'account_id'] != null,
            'Required key "StopFollowingOut[account_id]" has a null value in JSON.');
        assert(json.containsKey(r'calendars_followed'),
            'Required key "StopFollowingOut[calendars_followed]" is missing from JSON.');
        assert(json[r'calendars_followed'] != null,
            'Required key "StopFollowingOut[calendars_followed]" has a null value in JSON.');
        assert(json.containsKey(r'contacts_followed'),
            'Required key "StopFollowingOut[contacts_followed]" is missing from JSON.');
        assert(json[r'contacts_followed'] != null,
            'Required key "StopFollowingOut[contacts_followed]" has a null value in JSON.');
        assert(json.containsKey(r'label'),
            'Required key "StopFollowingOut[label]" is missing from JSON.');
        assert(json[r'label'] != null,
            'Required key "StopFollowingOut[label]" has a null value in JSON.');
        assert(json.containsKey(r'message'),
            'Required key "StopFollowingOut[message]" is missing from JSON.');
        assert(json[r'message'] != null,
            'Required key "StopFollowingOut[message]" has a null value in JSON.');
        return true;
      }());

      return StopFollowingOut(
        accountId: mapValueOfType<String>(json, r'account_id')!,
        calendarsFollowed: mapValueOfType<int>(json, r'calendars_followed')!,
        contactsFollowed: mapValueOfType<int>(json, r'contacts_followed')!,
        label: mapValueOfType<String>(json, r'label')!,
        message: mapValueOfType<String>(json, r'message')!,
      );
    }
    return null;
  }

  static List<StopFollowingOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <StopFollowingOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = StopFollowingOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, StopFollowingOut> mapFromJson(dynamic json) {
    final map = <String, StopFollowingOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = StopFollowingOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of StopFollowingOut-objects as value to a dart map
  static Map<String, List<StopFollowingOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<StopFollowingOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = StopFollowingOut.listFromJson(
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
    'calendars_followed',
    'contacts_followed',
    'label',
    'message',
  };
}
