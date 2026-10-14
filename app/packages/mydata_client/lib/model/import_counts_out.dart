//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportCountsOut {
  /// Returns a new [ImportCountsOut] instance.
  ImportCountsOut({
    required this.cards,
    required this.conflicts,
    required this.contacts,
    this.created,
    required this.deleted,
    required this.duplicates,
    required this.followedMatches,
    required this.groups,
    this.groupsCreated,
    required this.inFile,
    this.linked,
    required this.missing,
    required this.new_,
    this.notWritten,
    required this.skipped,
    required this.suggestions,
    required this.toImport,
    required this.toLink,
    required this.toUpdate,
    required this.unchanged,
    this.updated,
    required this.updates,
  });

  /// cards in the input, read or not
  int cards;

  /// cards imported before that changed, the owned copy edited (or merged) since: not written
  int conflicts;

  /// cards that are contacts (people and organisations)
  int contacts;

  /// after the commit: contacts created
  int? created;

  /// cards imported before whose owned copy is in Recently deleted
  int deleted;

  /// cards whose email or phone an owned contact of the same name already has
  int duplicates;

  /// cards whose email or phone a followed contact has
  int followedMatches;

  /// group cards: imported as groups, never listed as contacts
  int groups;

  int? groupsCreated;

  /// cards repeated in the input
  int inFile;

  int? linked;

  /// contacts earlier imports from this source brought in that the input no longer has (reported, never deleted)
  int missing;

  int new_;

  int? notWritten;

  /// cards that could not be read (the loss report says why)
  int skipped;

  /// cards with a contact of the same name only (a suggestion)
  int suggestions;

  int toImport;

  int toLink;

  int toUpdate;

  /// cards imported before, unchanged
  int unchanged;

  int? updated;

  /// cards imported before that changed, the owned copy unedited since
  int updates;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportCountsOut &&
          other.cards == cards &&
          other.conflicts == conflicts &&
          other.contacts == contacts &&
          other.created == created &&
          other.deleted == deleted &&
          other.duplicates == duplicates &&
          other.followedMatches == followedMatches &&
          other.groups == groups &&
          other.groupsCreated == groupsCreated &&
          other.inFile == inFile &&
          other.linked == linked &&
          other.missing == missing &&
          other.new_ == new_ &&
          other.notWritten == notWritten &&
          other.skipped == skipped &&
          other.suggestions == suggestions &&
          other.toImport == toImport &&
          other.toLink == toLink &&
          other.toUpdate == toUpdate &&
          other.unchanged == unchanged &&
          other.updated == updated &&
          other.updates == updates;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (cards.hashCode) +
      (conflicts.hashCode) +
      (contacts.hashCode) +
      (created == null ? 0 : created!.hashCode) +
      (deleted.hashCode) +
      (duplicates.hashCode) +
      (followedMatches.hashCode) +
      (groups.hashCode) +
      (groupsCreated == null ? 0 : groupsCreated!.hashCode) +
      (inFile.hashCode) +
      (linked == null ? 0 : linked!.hashCode) +
      (missing.hashCode) +
      (new_.hashCode) +
      (notWritten == null ? 0 : notWritten!.hashCode) +
      (skipped.hashCode) +
      (suggestions.hashCode) +
      (toImport.hashCode) +
      (toLink.hashCode) +
      (toUpdate.hashCode) +
      (unchanged.hashCode) +
      (updated == null ? 0 : updated!.hashCode) +
      (updates.hashCode);

  @override
  String toString() =>
      'ImportCountsOut[cards=$cards, conflicts=$conflicts, contacts=$contacts, created=$created, deleted=$deleted, duplicates=$duplicates, followedMatches=$followedMatches, groups=$groups, groupsCreated=$groupsCreated, inFile=$inFile, linked=$linked, missing=$missing, new_=$new_, notWritten=$notWritten, skipped=$skipped, suggestions=$suggestions, toImport=$toImport, toLink=$toLink, toUpdate=$toUpdate, unchanged=$unchanged, updated=$updated, updates=$updates]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'cards'] = this.cards;
    json[r'conflicts'] = this.conflicts;
    json[r'contacts'] = this.contacts;
    if (this.created != null) {
      json[r'created'] = this.created;
    } else {
      json[r'created'] = null;
    }
    json[r'deleted'] = this.deleted;
    json[r'duplicates'] = this.duplicates;
    json[r'followed_matches'] = this.followedMatches;
    json[r'groups'] = this.groups;
    if (this.groupsCreated != null) {
      json[r'groups_created'] = this.groupsCreated;
    } else {
      json[r'groups_created'] = null;
    }
    json[r'in_file'] = this.inFile;
    if (this.linked != null) {
      json[r'linked'] = this.linked;
    } else {
      json[r'linked'] = null;
    }
    json[r'missing'] = this.missing;
    json[r'new'] = this.new_;
    if (this.notWritten != null) {
      json[r'not_written'] = this.notWritten;
    } else {
      json[r'not_written'] = null;
    }
    json[r'skipped'] = this.skipped;
    json[r'suggestions'] = this.suggestions;
    json[r'to_import'] = this.toImport;
    json[r'to_link'] = this.toLink;
    json[r'to_update'] = this.toUpdate;
    json[r'unchanged'] = this.unchanged;
    if (this.updated != null) {
      json[r'updated'] = this.updated;
    } else {
      json[r'updated'] = null;
    }
    json[r'updates'] = this.updates;
    return json;
  }

  /// Returns a new [ImportCountsOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportCountsOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'cards'),
            'Required key "ImportCountsOut[cards]" is missing from JSON.');
        assert(json[r'cards'] != null,
            'Required key "ImportCountsOut[cards]" has a null value in JSON.');
        assert(json.containsKey(r'conflicts'),
            'Required key "ImportCountsOut[conflicts]" is missing from JSON.');
        assert(json[r'conflicts'] != null,
            'Required key "ImportCountsOut[conflicts]" has a null value in JSON.');
        assert(json.containsKey(r'contacts'),
            'Required key "ImportCountsOut[contacts]" is missing from JSON.');
        assert(json[r'contacts'] != null,
            'Required key "ImportCountsOut[contacts]" has a null value in JSON.');
        assert(json.containsKey(r'deleted'),
            'Required key "ImportCountsOut[deleted]" is missing from JSON.');
        assert(json[r'deleted'] != null,
            'Required key "ImportCountsOut[deleted]" has a null value in JSON.');
        assert(json.containsKey(r'duplicates'),
            'Required key "ImportCountsOut[duplicates]" is missing from JSON.');
        assert(json[r'duplicates'] != null,
            'Required key "ImportCountsOut[duplicates]" has a null value in JSON.');
        assert(json.containsKey(r'followed_matches'),
            'Required key "ImportCountsOut[followed_matches]" is missing from JSON.');
        assert(json[r'followed_matches'] != null,
            'Required key "ImportCountsOut[followed_matches]" has a null value in JSON.');
        assert(json.containsKey(r'groups'),
            'Required key "ImportCountsOut[groups]" is missing from JSON.');
        assert(json[r'groups'] != null,
            'Required key "ImportCountsOut[groups]" has a null value in JSON.');
        assert(json.containsKey(r'in_file'),
            'Required key "ImportCountsOut[in_file]" is missing from JSON.');
        assert(json[r'in_file'] != null,
            'Required key "ImportCountsOut[in_file]" has a null value in JSON.');
        assert(json.containsKey(r'missing'),
            'Required key "ImportCountsOut[missing]" is missing from JSON.');
        assert(json[r'missing'] != null,
            'Required key "ImportCountsOut[missing]" has a null value in JSON.');
        assert(json.containsKey(r'new'),
            'Required key "ImportCountsOut[new]" is missing from JSON.');
        assert(json[r'new'] != null,
            'Required key "ImportCountsOut[new]" has a null value in JSON.');
        assert(json.containsKey(r'skipped'),
            'Required key "ImportCountsOut[skipped]" is missing from JSON.');
        assert(json[r'skipped'] != null,
            'Required key "ImportCountsOut[skipped]" has a null value in JSON.');
        assert(json.containsKey(r'suggestions'),
            'Required key "ImportCountsOut[suggestions]" is missing from JSON.');
        assert(json[r'suggestions'] != null,
            'Required key "ImportCountsOut[suggestions]" has a null value in JSON.');
        assert(json.containsKey(r'to_import'),
            'Required key "ImportCountsOut[to_import]" is missing from JSON.');
        assert(json[r'to_import'] != null,
            'Required key "ImportCountsOut[to_import]" has a null value in JSON.');
        assert(json.containsKey(r'to_link'),
            'Required key "ImportCountsOut[to_link]" is missing from JSON.');
        assert(json[r'to_link'] != null,
            'Required key "ImportCountsOut[to_link]" has a null value in JSON.');
        assert(json.containsKey(r'to_update'),
            'Required key "ImportCountsOut[to_update]" is missing from JSON.');
        assert(json[r'to_update'] != null,
            'Required key "ImportCountsOut[to_update]" has a null value in JSON.');
        assert(json.containsKey(r'unchanged'),
            'Required key "ImportCountsOut[unchanged]" is missing from JSON.');
        assert(json[r'unchanged'] != null,
            'Required key "ImportCountsOut[unchanged]" has a null value in JSON.');
        assert(json.containsKey(r'updates'),
            'Required key "ImportCountsOut[updates]" is missing from JSON.');
        assert(json[r'updates'] != null,
            'Required key "ImportCountsOut[updates]" has a null value in JSON.');
        return true;
      }());

      return ImportCountsOut(
        cards: mapValueOfType<int>(json, r'cards')!,
        conflicts: mapValueOfType<int>(json, r'conflicts')!,
        contacts: mapValueOfType<int>(json, r'contacts')!,
        created: mapValueOfType<int>(json, r'created'),
        deleted: mapValueOfType<int>(json, r'deleted')!,
        duplicates: mapValueOfType<int>(json, r'duplicates')!,
        followedMatches: mapValueOfType<int>(json, r'followed_matches')!,
        groups: mapValueOfType<int>(json, r'groups')!,
        groupsCreated: mapValueOfType<int>(json, r'groups_created'),
        inFile: mapValueOfType<int>(json, r'in_file')!,
        linked: mapValueOfType<int>(json, r'linked'),
        missing: mapValueOfType<int>(json, r'missing')!,
        new_: mapValueOfType<int>(json, r'new')!,
        notWritten: mapValueOfType<int>(json, r'not_written'),
        skipped: mapValueOfType<int>(json, r'skipped')!,
        suggestions: mapValueOfType<int>(json, r'suggestions')!,
        toImport: mapValueOfType<int>(json, r'to_import')!,
        toLink: mapValueOfType<int>(json, r'to_link')!,
        toUpdate: mapValueOfType<int>(json, r'to_update')!,
        unchanged: mapValueOfType<int>(json, r'unchanged')!,
        updated: mapValueOfType<int>(json, r'updated'),
        updates: mapValueOfType<int>(json, r'updates')!,
      );
    }
    return null;
  }

  static List<ImportCountsOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportCountsOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportCountsOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportCountsOut> mapFromJson(dynamic json) {
    final map = <String, ImportCountsOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportCountsOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportCountsOut-objects as value to a dart map
  static Map<String, List<ImportCountsOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportCountsOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportCountsOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'cards',
    'conflicts',
    'contacts',
    'deleted',
    'duplicates',
    'followed_matches',
    'groups',
    'in_file',
    'missing',
    'new',
    'skipped',
    'suggestions',
    'to_import',
    'to_link',
    'to_update',
    'unchanged',
    'updates',
  };
}
