//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportPreviewOut {
  /// Returns a new [ImportPreviewOut] instance.
  ImportPreviewOut({
    this.accountId,
    this.changes = const [],
    required this.counts,
    required this.expiresAt,
    required this.id,
    this.items = const [],
    required this.label,
    this.losses = const [],
    this.missing = const [],
    required this.needsAcceptance,
    required this.source_,
    this.stopFollowing,
  });

  String? accountId;

  /// what is stored differently without being lost
  List<ImportNoteOut> changes;

  ImportCountsOut counts;

  String expiresAt;

  /// the preview's id, held by the host until expires_at (not across a restart)
  String id;

  List<ImportItemOut> items;

  /// the file's name, or the source as a heading
  String label;

  /// what in the input will not reach the host; when not empty, commit needs accept_losses
  List<ImportNoteOut> losses;

  List<ImportMissingOut> missing;

  bool needsAcceptance;

  /// file, or icloud for a copy of a followed iCloud account
  String source_;

  /// for a copy of a followed account: the app may offer to stop following it
  StopFollowingOut? stopFollowing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportPreviewOut &&
          other.accountId == accountId &&
          _deepEquality.equals(other.changes, changes) &&
          other.counts == counts &&
          other.expiresAt == expiresAt &&
          other.id == id &&
          _deepEquality.equals(other.items, items) &&
          other.label == label &&
          _deepEquality.equals(other.losses, losses) &&
          _deepEquality.equals(other.missing, missing) &&
          other.needsAcceptance == needsAcceptance &&
          other.source_ == source_ &&
          other.stopFollowing == stopFollowing;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId == null ? 0 : accountId!.hashCode) +
      (changes.hashCode) +
      (counts.hashCode) +
      (expiresAt.hashCode) +
      (id.hashCode) +
      (items.hashCode) +
      (label.hashCode) +
      (losses.hashCode) +
      (missing.hashCode) +
      (needsAcceptance.hashCode) +
      (source_.hashCode) +
      (stopFollowing == null ? 0 : stopFollowing!.hashCode);

  @override
  String toString() =>
      'ImportPreviewOut[accountId=$accountId, changes=$changes, counts=$counts, expiresAt=$expiresAt, id=$id, items=$items, label=$label, losses=$losses, missing=$missing, needsAcceptance=$needsAcceptance, source_=$source_, stopFollowing=$stopFollowing]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.accountId != null) {
      json[r'account_id'] = this.accountId;
    } else {
      json[r'account_id'] = null;
    }
    json[r'changes'] = this.changes;
    json[r'counts'] = this.counts;
    json[r'expires_at'] = this.expiresAt;
    json[r'id'] = this.id;
    json[r'items'] = this.items;
    json[r'label'] = this.label;
    json[r'losses'] = this.losses;
    json[r'missing'] = this.missing;
    json[r'needs_acceptance'] = this.needsAcceptance;
    json[r'source'] = this.source_;
    if (this.stopFollowing != null) {
      json[r'stop_following'] = this.stopFollowing;
    } else {
      json[r'stop_following'] = null;
    }
    return json;
  }

  /// Returns a new [ImportPreviewOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportPreviewOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'changes'),
            'Required key "ImportPreviewOut[changes]" is missing from JSON.');
        assert(json[r'changes'] != null,
            'Required key "ImportPreviewOut[changes]" has a null value in JSON.');
        assert(json.containsKey(r'counts'),
            'Required key "ImportPreviewOut[counts]" is missing from JSON.');
        assert(json[r'counts'] != null,
            'Required key "ImportPreviewOut[counts]" has a null value in JSON.');
        assert(json.containsKey(r'expires_at'),
            'Required key "ImportPreviewOut[expires_at]" is missing from JSON.');
        assert(json[r'expires_at'] != null,
            'Required key "ImportPreviewOut[expires_at]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "ImportPreviewOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "ImportPreviewOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'items'),
            'Required key "ImportPreviewOut[items]" is missing from JSON.');
        assert(json[r'items'] != null,
            'Required key "ImportPreviewOut[items]" has a null value in JSON.');
        assert(json.containsKey(r'label'),
            'Required key "ImportPreviewOut[label]" is missing from JSON.');
        assert(json[r'label'] != null,
            'Required key "ImportPreviewOut[label]" has a null value in JSON.');
        assert(json.containsKey(r'losses'),
            'Required key "ImportPreviewOut[losses]" is missing from JSON.');
        assert(json[r'losses'] != null,
            'Required key "ImportPreviewOut[losses]" has a null value in JSON.');
        assert(json.containsKey(r'missing'),
            'Required key "ImportPreviewOut[missing]" is missing from JSON.');
        assert(json[r'missing'] != null,
            'Required key "ImportPreviewOut[missing]" has a null value in JSON.');
        assert(json.containsKey(r'needs_acceptance'),
            'Required key "ImportPreviewOut[needs_acceptance]" is missing from JSON.');
        assert(json[r'needs_acceptance'] != null,
            'Required key "ImportPreviewOut[needs_acceptance]" has a null value in JSON.');
        assert(json.containsKey(r'source'),
            'Required key "ImportPreviewOut[source]" is missing from JSON.');
        assert(json[r'source'] != null,
            'Required key "ImportPreviewOut[source]" has a null value in JSON.');
        return true;
      }());

      return ImportPreviewOut(
        accountId: mapValueOfType<String>(json, r'account_id'),
        changes: ImportNoteOut.listFromJson(json[r'changes']),
        counts: ImportCountsOut.fromJson(json[r'counts'])!,
        expiresAt: mapValueOfType<String>(json, r'expires_at')!,
        id: mapValueOfType<String>(json, r'id')!,
        items: ImportItemOut.listFromJson(json[r'items']),
        label: mapValueOfType<String>(json, r'label')!,
        losses: ImportNoteOut.listFromJson(json[r'losses']),
        missing: ImportMissingOut.listFromJson(json[r'missing']),
        needsAcceptance: mapValueOfType<bool>(json, r'needs_acceptance')!,
        source_: mapValueOfType<String>(json, r'source')!,
        stopFollowing: StopFollowingOut.fromJson(json[r'stop_following']),
      );
    }
    return null;
  }

  static List<ImportPreviewOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportPreviewOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportPreviewOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportPreviewOut> mapFromJson(dynamic json) {
    final map = <String, ImportPreviewOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportPreviewOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportPreviewOut-objects as value to a dart map
  static Map<String, List<ImportPreviewOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportPreviewOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportPreviewOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'changes',
    'counts',
    'expires_at',
    'id',
    'items',
    'label',
    'losses',
    'missing',
    'needs_acceptance',
    'source',
  };
}
