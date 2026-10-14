//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UndoOut {
  /// Returns a new [UndoOut] instance.
  UndoOut({
    required this.contact,
    this.contactIds = const [],
    required this.undoId,
  });

  /// the contact as it is after the undo (for a merge: the first original, restored)
  ContactDetailOut contact;

  /// every contact the undo changed: for a merge, each original (restored) and the merged contact (moved to Recently deleted)
  List<String> contactIds;

  String undoId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UndoOut &&
          other.contact == contact &&
          _deepEquality.equals(other.contactIds, contactIds) &&
          other.undoId == undoId;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (contact.hashCode) + (contactIds.hashCode) + (undoId.hashCode);

  @override
  String toString() =>
      'UndoOut[contact=$contact, contactIds=$contactIds, undoId=$undoId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'contact'] = this.contact;
    json[r'contact_ids'] = this.contactIds;
    json[r'undo_id'] = this.undoId;
    return json;
  }

  /// Returns a new [UndoOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UndoOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'contact'),
            'Required key "UndoOut[contact]" is missing from JSON.');
        assert(json[r'contact'] != null,
            'Required key "UndoOut[contact]" has a null value in JSON.');
        assert(json.containsKey(r'undo_id'),
            'Required key "UndoOut[undo_id]" is missing from JSON.');
        assert(json[r'undo_id'] != null,
            'Required key "UndoOut[undo_id]" has a null value in JSON.');
        return true;
      }());

      return UndoOut(
        contact: ContactDetailOut.fromJson(json[r'contact'])!,
        contactIds: json[r'contact_ids'] is Iterable
            ? (json[r'contact_ids'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        undoId: mapValueOfType<String>(json, r'undo_id')!,
      );
    }
    return null;
  }

  static List<UndoOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <UndoOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UndoOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UndoOut> mapFromJson(dynamic json) {
    final map = <String, UndoOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UndoOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UndoOut-objects as value to a dart map
  static Map<String, List<UndoOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<UndoOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UndoOut.listFromJson(
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
    'undo_id',
  };
}
