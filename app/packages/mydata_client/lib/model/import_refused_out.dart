//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportRefusedOut {
  /// Returns a new [ImportRefusedOut] instance.
  ImportRefusedOut({
    required this.code,
    required this.detail,
  });

  /// a whole file refused (400, 413): too_big (over 50 MB), zip_too_big (the zip expands to over 200 MB), zip_entry_too_big (a file in the zip expands far more than a vCard does), zip_too_many (over 10,000 files in the zip), zip_unreadable, zip_no_vcard (no .vcf in the zip), no_vcard (no vCard in the file), utf16_unreadable. A commit refused (400): losses_not_accepted, choice_refused (a choice a card cannot take now: read the preview again)
  String code;

  /// for logs and the command line; the apps write their own sentence from code
  String detail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportRefusedOut && other.code == code && other.detail == detail;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (code.hashCode) + (detail.hashCode);

  @override
  String toString() => 'ImportRefusedOut[code=$code, detail=$detail]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'code'] = this.code;
    json[r'detail'] = this.detail;
    return json;
  }

  /// Returns a new [ImportRefusedOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportRefusedOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'code'),
            'Required key "ImportRefusedOut[code]" is missing from JSON.');
        assert(json[r'code'] != null,
            'Required key "ImportRefusedOut[code]" has a null value in JSON.');
        assert(json.containsKey(r'detail'),
            'Required key "ImportRefusedOut[detail]" is missing from JSON.');
        assert(json[r'detail'] != null,
            'Required key "ImportRefusedOut[detail]" has a null value in JSON.');
        return true;
      }());

      return ImportRefusedOut(
        code: mapValueOfType<String>(json, r'code')!,
        detail: mapValueOfType<String>(json, r'detail')!,
      );
    }
    return null;
  }

  static List<ImportRefusedOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportRefusedOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportRefusedOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportRefusedOut> mapFromJson(dynamic json) {
    final map = <String, ImportRefusedOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportRefusedOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportRefusedOut-objects as value to a dart map
  static Map<String, List<ImportRefusedOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportRefusedOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportRefusedOut.listFromJson(
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
    'detail',
  };
}
