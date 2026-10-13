//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MacSourceIn {
  /// Returns a new [MacSourceIn] instance.
  MacSourceIn({
    this.calendars = const [],
    this.contactContainers = const [],
    this.enabled,
  });

  /// calendar ids to include; null = all, including calendars added later
  List<String>? calendars;

  /// container ids to include; null = all, including accounts added later
  List<String>? contactContainers;

  /// null keeps it; false deletes everything This Mac mirrored and stops its reader
  bool? enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacSourceIn &&
          _deepEquality.equals(other.calendars, calendars) &&
          _deepEquality.equals(other.contactContainers, contactContainers) &&
          other.enabled == enabled;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (calendars == null ? 0 : calendars!.hashCode) +
      (contactContainers == null ? 0 : contactContainers!.hashCode) +
      (enabled == null ? 0 : enabled!.hashCode);

  @override
  String toString() =>
      'MacSourceIn[calendars=$calendars, contactContainers=$contactContainers, enabled=$enabled]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.calendars != null) {
      json[r'calendars'] = this.calendars;
    } else {
      json[r'calendars'] = null;
    }
    if (this.contactContainers != null) {
      json[r'contact_containers'] = this.contactContainers;
    } else {
      json[r'contact_containers'] = null;
    }
    if (this.enabled != null) {
      json[r'enabled'] = this.enabled;
    } else {
      json[r'enabled'] = null;
    }
    return json;
  }

  /// Returns a new [MacSourceIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MacSourceIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        return true;
      }());

      return MacSourceIn(
        calendars: json[r'calendars'] is Iterable
            ? (json[r'calendars'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        contactContainers: json[r'contact_containers'] is Iterable
            ? (json[r'contact_containers'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        enabled: mapValueOfType<bool>(json, r'enabled'),
      );
    }
    return null;
  }

  static List<MacSourceIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <MacSourceIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MacSourceIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MacSourceIn> mapFromJson(dynamic json) {
    final map = <String, MacSourceIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MacSourceIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MacSourceIn-objects as value to a dart map
  static Map<String, List<MacSourceIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<MacSourceIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MacSourceIn.listFromJson(
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
