//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportOut {
  /// Returns a new [ImportOut] instance.
  ImportOut({
    this.addressBookId,
    this.counts = const {},
    this.finishedAt,
    required this.id,
    required this.label,
    required this.source_,
    this.sourceAccount,
    required this.startedAt,
    required this.status,
    this.undoneAt,
  });

  String? addressBookId;

  /// as ImportCountsOut, plus undo (removed, reverted, unlinked, kept, gone) once undone
  Map<String, Object> counts;

  String? finishedAt;

  String id;

  String label;

  String source_;

  String? sourceAccount;

  String startedAt;

  /// committed or undone
  String status;

  String? undoneAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportOut &&
          other.addressBookId == addressBookId &&
          _deepEquality.equals(other.counts, counts) &&
          other.finishedAt == finishedAt &&
          other.id == id &&
          other.label == label &&
          other.source_ == source_ &&
          other.sourceAccount == sourceAccount &&
          other.startedAt == startedAt &&
          other.status == status &&
          other.undoneAt == undoneAt;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (addressBookId == null ? 0 : addressBookId!.hashCode) +
      (counts.hashCode) +
      (finishedAt == null ? 0 : finishedAt!.hashCode) +
      (id.hashCode) +
      (label.hashCode) +
      (source_.hashCode) +
      (sourceAccount == null ? 0 : sourceAccount!.hashCode) +
      (startedAt.hashCode) +
      (status.hashCode) +
      (undoneAt == null ? 0 : undoneAt!.hashCode);

  @override
  String toString() =>
      'ImportOut[addressBookId=$addressBookId, counts=$counts, finishedAt=$finishedAt, id=$id, label=$label, source_=$source_, sourceAccount=$sourceAccount, startedAt=$startedAt, status=$status, undoneAt=$undoneAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.addressBookId != null) {
      json[r'address_book_id'] = this.addressBookId;
    } else {
      json[r'address_book_id'] = null;
    }
    json[r'counts'] = this.counts;
    if (this.finishedAt != null) {
      json[r'finished_at'] = this.finishedAt;
    } else {
      json[r'finished_at'] = null;
    }
    json[r'id'] = this.id;
    json[r'label'] = this.label;
    json[r'source'] = this.source_;
    if (this.sourceAccount != null) {
      json[r'source_account'] = this.sourceAccount;
    } else {
      json[r'source_account'] = null;
    }
    json[r'started_at'] = this.startedAt;
    json[r'status'] = this.status;
    if (this.undoneAt != null) {
      json[r'undone_at'] = this.undoneAt;
    } else {
      json[r'undone_at'] = null;
    }
    return json;
  }

  /// Returns a new [ImportOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'counts'),
            'Required key "ImportOut[counts]" is missing from JSON.');
        assert(json[r'counts'] != null,
            'Required key "ImportOut[counts]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "ImportOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "ImportOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'label'),
            'Required key "ImportOut[label]" is missing from JSON.');
        assert(json[r'label'] != null,
            'Required key "ImportOut[label]" has a null value in JSON.');
        assert(json.containsKey(r'source'),
            'Required key "ImportOut[source]" is missing from JSON.');
        assert(json[r'source'] != null,
            'Required key "ImportOut[source]" has a null value in JSON.');
        assert(json.containsKey(r'started_at'),
            'Required key "ImportOut[started_at]" is missing from JSON.');
        assert(json[r'started_at'] != null,
            'Required key "ImportOut[started_at]" has a null value in JSON.');
        assert(json.containsKey(r'status'),
            'Required key "ImportOut[status]" is missing from JSON.');
        assert(json[r'status'] != null,
            'Required key "ImportOut[status]" has a null value in JSON.');
        return true;
      }());

      return ImportOut(
        addressBookId: mapValueOfType<String>(json, r'address_book_id'),
        counts: mapCastOfType<String, Object>(json, r'counts')!,
        finishedAt: mapValueOfType<String>(json, r'finished_at'),
        id: mapValueOfType<String>(json, r'id')!,
        label: mapValueOfType<String>(json, r'label')!,
        source_: mapValueOfType<String>(json, r'source')!,
        sourceAccount: mapValueOfType<String>(json, r'source_account'),
        startedAt: mapValueOfType<String>(json, r'started_at')!,
        status: mapValueOfType<String>(json, r'status')!,
        undoneAt: mapValueOfType<String>(json, r'undone_at'),
      );
    }
    return null;
  }

  static List<ImportOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportOut> mapFromJson(dynamic json) {
    final map = <String, ImportOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportOut-objects as value to a dart map
  static Map<String, List<ImportOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportOut.listFromJson(
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
