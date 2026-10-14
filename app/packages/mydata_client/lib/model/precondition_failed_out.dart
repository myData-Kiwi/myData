//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PreconditionFailedOut {
  /// Returns a new [PreconditionFailedOut] instance.
  PreconditionFailedOut({
    required this.detail,
    required this.etag,
  });

  String detail;

  /// the contact's current etag
  String etag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreconditionFailedOut &&
          other.detail == detail &&
          other.etag == etag;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (detail.hashCode) + (etag.hashCode);

  @override
  String toString() => 'PreconditionFailedOut[detail=$detail, etag=$etag]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'detail'] = this.detail;
    json[r'etag'] = this.etag;
    return json;
  }

  /// Returns a new [PreconditionFailedOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PreconditionFailedOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'detail'),
            'Required key "PreconditionFailedOut[detail]" is missing from JSON.');
        assert(json[r'detail'] != null,
            'Required key "PreconditionFailedOut[detail]" has a null value in JSON.');
        assert(json.containsKey(r'etag'),
            'Required key "PreconditionFailedOut[etag]" is missing from JSON.');
        assert(json[r'etag'] != null,
            'Required key "PreconditionFailedOut[etag]" has a null value in JSON.');
        return true;
      }());

      return PreconditionFailedOut(
        detail: mapValueOfType<String>(json, r'detail')!,
        etag: mapValueOfType<String>(json, r'etag')!,
      );
    }
    return null;
  }

  static List<PreconditionFailedOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <PreconditionFailedOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PreconditionFailedOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PreconditionFailedOut> mapFromJson(dynamic json) {
    final map = <String, PreconditionFailedOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PreconditionFailedOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PreconditionFailedOut-objects as value to a dart map
  static Map<String, List<PreconditionFailedOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<PreconditionFailedOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PreconditionFailedOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'detail',
    'etag',
  };
}
