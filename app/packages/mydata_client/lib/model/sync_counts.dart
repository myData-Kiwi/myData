//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncCounts {
  /// Returns a new [SyncCounts] instance.
  SyncCounts({
    this.addressBooks = 0,
    this.calendars = 0,
    this.contacts = 0,
    this.events = 0,
  });

  int addressBooks;

  int calendars;

  int contacts;

  int events;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncCounts &&
          other.addressBooks == addressBooks &&
          other.calendars == calendars &&
          other.contacts == contacts &&
          other.events == events;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (addressBooks.hashCode) +
      (calendars.hashCode) +
      (contacts.hashCode) +
      (events.hashCode);

  @override
  String toString() =>
      'SyncCounts[addressBooks=$addressBooks, calendars=$calendars, contacts=$contacts, events=$events]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'address_books'] = this.addressBooks;
    json[r'calendars'] = this.calendars;
    json[r'contacts'] = this.contacts;
    json[r'events'] = this.events;
    return json;
  }

  /// Returns a new [SyncCounts] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncCounts? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        return true;
      }());

      return SyncCounts(
        addressBooks: mapValueOfType<int>(json, r'address_books') ?? 0,
        calendars: mapValueOfType<int>(json, r'calendars') ?? 0,
        contacts: mapValueOfType<int>(json, r'contacts') ?? 0,
        events: mapValueOfType<int>(json, r'events') ?? 0,
      );
    }
    return null;
  }

  static List<SyncCounts> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <SyncCounts>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncCounts.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncCounts> mapFromJson(dynamic json) {
    final map = <String, SyncCounts>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncCounts.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncCounts-objects as value to a dart map
  static Map<String, List<SyncCounts>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<SyncCounts>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncCounts.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{};
}
