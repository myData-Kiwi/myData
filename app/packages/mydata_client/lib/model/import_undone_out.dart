//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportUndoneOut {
  /// Returns a new [ImportUndoneOut] instance.
  ImportUndoneOut({
    required this.gone,
    this.groupsRemoved = 0,
    this.kept = const [],
    required this.removed,
    required this.reverted,
    required this.summary,
    this.unhidden = 0,
    required this.unlinked,
  });

  /// contacts already in Recently deleted or deleted for good
  int gone;

  /// group cards it created, now in Recently deleted with them
  int groupsRemoved;

  /// contacts changed since the import: left as they are
  List<ImportMissingOut> kept;

  /// contacts it created, now in Recently deleted
  int removed;

  /// contacts it updated, back to their earlier text
  int reverted;

  /// the import as it is now (status undone)
  ImportOut summary;

  /// followed contacts the import hid, shown again
  int unhidden;

  int unlinked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportUndoneOut &&
          other.gone == gone &&
          other.groupsRemoved == groupsRemoved &&
          _deepEquality.equals(other.kept, kept) &&
          other.removed == removed &&
          other.reverted == reverted &&
          other.summary == summary &&
          other.unhidden == unhidden &&
          other.unlinked == unlinked;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (gone.hashCode) +
      (groupsRemoved.hashCode) +
      (kept.hashCode) +
      (removed.hashCode) +
      (reverted.hashCode) +
      (summary.hashCode) +
      (unhidden.hashCode) +
      (unlinked.hashCode);

  @override
  String toString() =>
      'ImportUndoneOut[gone=$gone, groupsRemoved=$groupsRemoved, kept=$kept, removed=$removed, reverted=$reverted, summary=$summary, unhidden=$unhidden, unlinked=$unlinked]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'gone'] = this.gone;
    json[r'groups_removed'] = this.groupsRemoved;
    json[r'kept'] = this.kept;
    json[r'removed'] = this.removed;
    json[r'reverted'] = this.reverted;
    json[r'summary'] = this.summary;
    json[r'unhidden'] = this.unhidden;
    json[r'unlinked'] = this.unlinked;
    return json;
  }

  /// Returns a new [ImportUndoneOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportUndoneOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'gone'),
            'Required key "ImportUndoneOut[gone]" is missing from JSON.');
        assert(json[r'gone'] != null,
            'Required key "ImportUndoneOut[gone]" has a null value in JSON.');
        assert(json.containsKey(r'kept'),
            'Required key "ImportUndoneOut[kept]" is missing from JSON.');
        assert(json[r'kept'] != null,
            'Required key "ImportUndoneOut[kept]" has a null value in JSON.');
        assert(json.containsKey(r'removed'),
            'Required key "ImportUndoneOut[removed]" is missing from JSON.');
        assert(json[r'removed'] != null,
            'Required key "ImportUndoneOut[removed]" has a null value in JSON.');
        assert(json.containsKey(r'reverted'),
            'Required key "ImportUndoneOut[reverted]" is missing from JSON.');
        assert(json[r'reverted'] != null,
            'Required key "ImportUndoneOut[reverted]" has a null value in JSON.');
        assert(json.containsKey(r'summary'),
            'Required key "ImportUndoneOut[summary]" is missing from JSON.');
        assert(json[r'summary'] != null,
            'Required key "ImportUndoneOut[summary]" has a null value in JSON.');
        assert(json.containsKey(r'unlinked'),
            'Required key "ImportUndoneOut[unlinked]" is missing from JSON.');
        assert(json[r'unlinked'] != null,
            'Required key "ImportUndoneOut[unlinked]" has a null value in JSON.');
        return true;
      }());

      return ImportUndoneOut(
        gone: mapValueOfType<int>(json, r'gone')!,
        groupsRemoved: mapValueOfType<int>(json, r'groups_removed') ?? 0,
        kept: ImportMissingOut.listFromJson(json[r'kept']),
        removed: mapValueOfType<int>(json, r'removed')!,
        reverted: mapValueOfType<int>(json, r'reverted')!,
        summary: ImportOut.fromJson(json[r'summary'])!,
        unhidden: mapValueOfType<int>(json, r'unhidden') ?? 0,
        unlinked: mapValueOfType<int>(json, r'unlinked')!,
      );
    }
    return null;
  }

  static List<ImportUndoneOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportUndoneOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportUndoneOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportUndoneOut> mapFromJson(dynamic json) {
    final map = <String, ImportUndoneOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportUndoneOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportUndoneOut-objects as value to a dart map
  static Map<String, List<ImportUndoneOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportUndoneOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportUndoneOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'gone',
    'kept',
    'removed',
    'reverted',
    'summary',
    'unlinked',
  };
}
