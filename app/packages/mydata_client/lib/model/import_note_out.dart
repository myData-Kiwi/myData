//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportNoteOut {
  /// Returns a new [ImportNoteOut] instance.
  ImportNoteOut({
    required this.code,
    required this.count,
    this.entries = const [],
    required this.message,
  });

  /// skipped_unreadable, skipped_no_end, skipped_version, skipped_empty, skipped_too_large, skipped_too_many, guessed_charset, outside_text, unreadable_entry, nested_zip, encrypted, unsupported_compression (losses); converted_21, declared_charset, other_files (changes)
  String code;

  int count;

  /// unreadable_entry: the names of the files in the zip not read
  List<String> entries;

  /// for the user; holds no contact data
  String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportNoteOut &&
          other.code == code &&
          other.count == count &&
          _deepEquality.equals(other.entries, entries) &&
          other.message == message;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (code.hashCode) +
      (count.hashCode) +
      (entries.hashCode) +
      (message.hashCode);

  @override
  String toString() =>
      'ImportNoteOut[code=$code, count=$count, entries=$entries, message=$message]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'code'] = this.code;
    json[r'count'] = this.count;
    json[r'entries'] = this.entries;
    json[r'message'] = this.message;
    return json;
  }

  /// Returns a new [ImportNoteOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportNoteOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'code'),
            'Required key "ImportNoteOut[code]" is missing from JSON.');
        assert(json[r'code'] != null,
            'Required key "ImportNoteOut[code]" has a null value in JSON.');
        assert(json.containsKey(r'count'),
            'Required key "ImportNoteOut[count]" is missing from JSON.');
        assert(json[r'count'] != null,
            'Required key "ImportNoteOut[count]" has a null value in JSON.');
        assert(json.containsKey(r'message'),
            'Required key "ImportNoteOut[message]" is missing from JSON.');
        assert(json[r'message'] != null,
            'Required key "ImportNoteOut[message]" has a null value in JSON.');
        return true;
      }());

      return ImportNoteOut(
        code: mapValueOfType<String>(json, r'code')!,
        count: mapValueOfType<int>(json, r'count')!,
        entries: json[r'entries'] is Iterable
            ? (json[r'entries'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        message: mapValueOfType<String>(json, r'message')!,
      );
    }
    return null;
  }

  static List<ImportNoteOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportNoteOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportNoteOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportNoteOut> mapFromJson(dynamic json) {
    final map = <String, ImportNoteOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportNoteOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportNoteOut-objects as value to a dart map
  static Map<String, List<ImportNoteOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportNoteOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportNoteOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'code',
    'count',
    'message',
  };
}
