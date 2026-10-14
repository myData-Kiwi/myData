//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportItemOut {
  /// Returns a new [ImportItemOut] instance.
  ImportItemOut({
    required this.action,
    this.choices = const [],
    this.convertedFrom,
    required this.displayName,
    this.entry,
    required this.index,
    this.kind,
    this.matches = const [],
    this.reason,
    required this.status,
  });

  /// what the commit does unless chosen otherwise: import, update, link (keep the matching contact of yours and hide the followed copy) or skip
  String action;

  /// the actions this card may be given
  List<String> choices;

  /// 2.1 for a vCard 2.1 stored as 3.0
  String? convertedFrom;

  String displayName;

  /// the zip entry the card came from (a name only)
  String? entry;

  /// the card's position in the input, from 0
  int index;

  /// individual, org or group; null for a card not read
  String? kind;

  List<ImportMatchOut> matches;

  /// conflict: edited, merged or kept_yours; skipped: unreadable, no_end, version, empty, too_large (cards past the first 50000 are counted only, with no item)
  String? reason;

  /// new, duplicate, in_file, unchanged, update, conflict, deleted, skipped
  String status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportItemOut &&
          other.action == action &&
          _deepEquality.equals(other.choices, choices) &&
          other.convertedFrom == convertedFrom &&
          other.displayName == displayName &&
          other.entry == entry &&
          other.index == index &&
          other.kind == kind &&
          _deepEquality.equals(other.matches, matches) &&
          other.reason == reason &&
          other.status == status;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (action.hashCode) +
      (choices.hashCode) +
      (convertedFrom == null ? 0 : convertedFrom!.hashCode) +
      (displayName.hashCode) +
      (entry == null ? 0 : entry!.hashCode) +
      (index.hashCode) +
      (kind == null ? 0 : kind!.hashCode) +
      (matches.hashCode) +
      (reason == null ? 0 : reason!.hashCode) +
      (status.hashCode);

  @override
  String toString() =>
      'ImportItemOut[action=$action, choices=$choices, convertedFrom=$convertedFrom, displayName=$displayName, entry=$entry, index=$index, kind=$kind, matches=$matches, reason=$reason, status=$status]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'action'] = this.action;
    json[r'choices'] = this.choices;
    if (this.convertedFrom != null) {
      json[r'converted_from'] = this.convertedFrom;
    } else {
      json[r'converted_from'] = null;
    }
    json[r'display_name'] = this.displayName;
    if (this.entry != null) {
      json[r'entry'] = this.entry;
    } else {
      json[r'entry'] = null;
    }
    json[r'index'] = this.index;
    if (this.kind != null) {
      json[r'kind'] = this.kind;
    } else {
      json[r'kind'] = null;
    }
    json[r'matches'] = this.matches;
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
    json[r'status'] = this.status;
    return json;
  }

  /// Returns a new [ImportItemOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportItemOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'action'),
            'Required key "ImportItemOut[action]" is missing from JSON.');
        assert(json[r'action'] != null,
            'Required key "ImportItemOut[action]" has a null value in JSON.');
        assert(json.containsKey(r'choices'),
            'Required key "ImportItemOut[choices]" is missing from JSON.');
        assert(json[r'choices'] != null,
            'Required key "ImportItemOut[choices]" has a null value in JSON.');
        assert(json.containsKey(r'display_name'),
            'Required key "ImportItemOut[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null,
            'Required key "ImportItemOut[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'index'),
            'Required key "ImportItemOut[index]" is missing from JSON.');
        assert(json[r'index'] != null,
            'Required key "ImportItemOut[index]" has a null value in JSON.');
        assert(json.containsKey(r'status'),
            'Required key "ImportItemOut[status]" is missing from JSON.');
        assert(json[r'status'] != null,
            'Required key "ImportItemOut[status]" has a null value in JSON.');
        return true;
      }());

      return ImportItemOut(
        action: mapValueOfType<String>(json, r'action')!,
        choices: json[r'choices'] is Iterable
            ? (json[r'choices'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        convertedFrom: mapValueOfType<String>(json, r'converted_from'),
        displayName: mapValueOfType<String>(json, r'display_name')!,
        entry: mapValueOfType<String>(json, r'entry'),
        index: mapValueOfType<int>(json, r'index')!,
        kind: mapValueOfType<String>(json, r'kind'),
        matches: ImportMatchOut.listFromJson(json[r'matches']),
        reason: mapValueOfType<String>(json, r'reason'),
        status: mapValueOfType<String>(json, r'status')!,
      );
    }
    return null;
  }

  static List<ImportItemOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportItemOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportItemOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportItemOut> mapFromJson(dynamic json) {
    final map = <String, ImportItemOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportItemOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportItemOut-objects as value to a dart map
  static Map<String, List<ImportItemOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportItemOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportItemOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'action',
    'choices',
    'display_name',
    'index',
    'status',
  };
}
