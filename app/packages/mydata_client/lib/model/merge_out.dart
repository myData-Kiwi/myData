//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MergeOut {
  /// Returns a new [MergeOut] instance.
  MergeOut({
    required this.contact,
    this.merged = const [],
    required this.undoId,
  });

  /// the merged contact
  ContactDetailOut contact;

  /// the originals' ids, now in Recently deleted
  List<String> merged;

  /// POST /undo/{undo_id} undoes the merge while nothing changed since
  String undoId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeOut &&
          other.contact == contact &&
          _deepEquality.equals(other.merged, merged) &&
          other.undoId == undoId;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (contact.hashCode) + (merged.hashCode) + (undoId.hashCode);

  @override
  String toString() =>
      'MergeOut[contact=$contact, merged=$merged, undoId=$undoId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'contact'] = this.contact;
    json[r'merged'] = this.merged;
    json[r'undo_id'] = this.undoId;
    return json;
  }

  /// Returns a new [MergeOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MergeOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'contact'),
            'Required key "MergeOut[contact]" is missing from JSON.');
        assert(json[r'contact'] != null,
            'Required key "MergeOut[contact]" has a null value in JSON.');
        assert(json.containsKey(r'merged'),
            'Required key "MergeOut[merged]" is missing from JSON.');
        assert(json[r'merged'] != null,
            'Required key "MergeOut[merged]" has a null value in JSON.');
        assert(json.containsKey(r'undo_id'),
            'Required key "MergeOut[undo_id]" is missing from JSON.');
        assert(json[r'undo_id'] != null,
            'Required key "MergeOut[undo_id]" has a null value in JSON.');
        return true;
      }());

      return MergeOut(
        contact: ContactDetailOut.fromJson(json[r'contact'])!,
        merged: json[r'merged'] is Iterable
            ? (json[r'merged'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        undoId: mapValueOfType<String>(json, r'undo_id')!,
      );
    }
    return null;
  }

  static List<MergeOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <MergeOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MergeOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MergeOut> mapFromJson(dynamic json) {
    final map = <String, MergeOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MergeOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MergeOut-objects as value to a dart map
  static Map<String, List<MergeOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<MergeOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MergeOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'contact',
    'merged',
    'undo_id',
  };
}
