//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportCommittedOut {
  /// Returns a new [ImportCommittedOut] instance.
  ImportCommittedOut({
    this.addressBookId,
    this.conflicts = const [],
    this.counts = const {},
    this.finishedAt,
    required this.id,
    required this.label,
    this.missing = const [],
    required this.source_,
    this.sourceAccount,
    required this.startedAt,
    required this.status,
    this.stopFollowing,
    this.undoneAt,
  });

  String? addressBookId;

  List<ImportConflictOut> conflicts;

  /// as ImportCountsOut, plus undo (removed, reverted, unlinked, kept, gone) once undone
  Map<String, Object> counts;

  String? finishedAt;

  String id;

  String label;

  List<ImportMissingOut> missing;

  String source_;

  String? sourceAccount;

  String startedAt;

  /// committed or undone
  String status;

  StopFollowingOut? stopFollowing;

  String? undoneAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportCommittedOut &&
          other.addressBookId == addressBookId &&
          _deepEquality.equals(other.conflicts, conflicts) &&
          _deepEquality.equals(other.counts, counts) &&
          other.finishedAt == finishedAt &&
          other.id == id &&
          other.label == label &&
          _deepEquality.equals(other.missing, missing) &&
          other.source_ == source_ &&
          other.sourceAccount == sourceAccount &&
          other.startedAt == startedAt &&
          other.status == status &&
          other.stopFollowing == stopFollowing &&
          other.undoneAt == undoneAt;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (addressBookId == null ? 0 : addressBookId!.hashCode) +
      (conflicts.hashCode) +
      (counts.hashCode) +
      (finishedAt == null ? 0 : finishedAt!.hashCode) +
      (id.hashCode) +
      (label.hashCode) +
      (missing.hashCode) +
      (source_.hashCode) +
      (sourceAccount == null ? 0 : sourceAccount!.hashCode) +
      (startedAt.hashCode) +
      (status.hashCode) +
      (stopFollowing == null ? 0 : stopFollowing!.hashCode) +
      (undoneAt == null ? 0 : undoneAt!.hashCode);

  @override
  String toString() =>
      'ImportCommittedOut[addressBookId=$addressBookId, conflicts=$conflicts, counts=$counts, finishedAt=$finishedAt, id=$id, label=$label, missing=$missing, source_=$source_, sourceAccount=$sourceAccount, startedAt=$startedAt, status=$status, stopFollowing=$stopFollowing, undoneAt=$undoneAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.addressBookId != null) {
      json[r'address_book_id'] = this.addressBookId;
    } else {
      json[r'address_book_id'] = null;
    }
    json[r'conflicts'] = this.conflicts;
    json[r'counts'] = this.counts;
    if (this.finishedAt != null) {
      json[r'finished_at'] = this.finishedAt;
    } else {
      json[r'finished_at'] = null;
    }
    json[r'id'] = this.id;
    json[r'label'] = this.label;
    json[r'missing'] = this.missing;
    json[r'source'] = this.source_;
    if (this.sourceAccount != null) {
      json[r'source_account'] = this.sourceAccount;
    } else {
      json[r'source_account'] = null;
    }
    json[r'started_at'] = this.startedAt;
    json[r'status'] = this.status;
    if (this.stopFollowing != null) {
      json[r'stop_following'] = this.stopFollowing;
    } else {
      json[r'stop_following'] = null;
    }
    if (this.undoneAt != null) {
      json[r'undone_at'] = this.undoneAt;
    } else {
      json[r'undone_at'] = null;
    }
    return json;
  }

  /// Returns a new [ImportCommittedOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportCommittedOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'counts'),
            'Required key "ImportCommittedOut[counts]" is missing from JSON.');
        assert(json[r'counts'] != null,
            'Required key "ImportCommittedOut[counts]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "ImportCommittedOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "ImportCommittedOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'label'),
            'Required key "ImportCommittedOut[label]" is missing from JSON.');
        assert(json[r'label'] != null,
            'Required key "ImportCommittedOut[label]" has a null value in JSON.');
        assert(json.containsKey(r'source'),
            'Required key "ImportCommittedOut[source]" is missing from JSON.');
        assert(json[r'source'] != null,
            'Required key "ImportCommittedOut[source]" has a null value in JSON.');
        assert(json.containsKey(r'started_at'),
            'Required key "ImportCommittedOut[started_at]" is missing from JSON.');
        assert(json[r'started_at'] != null,
            'Required key "ImportCommittedOut[started_at]" has a null value in JSON.');
        assert(json.containsKey(r'status'),
            'Required key "ImportCommittedOut[status]" is missing from JSON.');
        assert(json[r'status'] != null,
            'Required key "ImportCommittedOut[status]" has a null value in JSON.');
        return true;
      }());

      return ImportCommittedOut(
        addressBookId: mapValueOfType<String>(json, r'address_book_id'),
        conflicts: ImportConflictOut.listFromJson(json[r'conflicts']),
        counts: mapCastOfType<String, Object>(json, r'counts')!,
        finishedAt: mapValueOfType<String>(json, r'finished_at'),
        id: mapValueOfType<String>(json, r'id')!,
        label: mapValueOfType<String>(json, r'label')!,
        missing: ImportMissingOut.listFromJson(json[r'missing']),
        source_: mapValueOfType<String>(json, r'source')!,
        sourceAccount: mapValueOfType<String>(json, r'source_account'),
        startedAt: mapValueOfType<String>(json, r'started_at')!,
        status: mapValueOfType<String>(json, r'status')!,
        stopFollowing: StopFollowingOut.fromJson(json[r'stop_following']),
        undoneAt: mapValueOfType<String>(json, r'undone_at'),
      );
    }
    return null;
  }

  static List<ImportCommittedOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportCommittedOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportCommittedOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportCommittedOut> mapFromJson(dynamic json) {
    final map = <String, ImportCommittedOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportCommittedOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportCommittedOut-objects as value to a dart map
  static Map<String, List<ImportCommittedOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportCommittedOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportCommittedOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'counts',
    'id',
    'label',
    'source',
    'started_at',
    'status',
  };
}
