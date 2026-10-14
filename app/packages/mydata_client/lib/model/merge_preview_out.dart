//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MergePreviewOut {
  /// Returns a new [MergePreviewOut] instance.
  MergePreviewOut({
    required this.contact,
    this.leftOut = const [],
    required this.namesFrom,
    required this.newest,
  });

  /// the contact the merge would make (not stored)
  CardValuesOut contact;

  /// each value of the others it would not hold (a different value of a single one, such as a second birthday or job title, or what kind of card it is): it stays with the originals in Recently deleted
  List<MergeLeftOutValueOut> leftOut;

  /// the contact whose name and details it starts from
  String namesFrom;

  /// the contact changed most recently: names_from when none is sent
  String newest;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergePreviewOut &&
          other.contact == contact &&
          _deepEquality.equals(other.leftOut, leftOut) &&
          other.namesFrom == namesFrom &&
          other.newest == newest;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (contact.hashCode) +
      (leftOut.hashCode) +
      (namesFrom.hashCode) +
      (newest.hashCode);

  @override
  String toString() =>
      'MergePreviewOut[contact=$contact, leftOut=$leftOut, namesFrom=$namesFrom, newest=$newest]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'contact'] = this.contact;
    json[r'left_out'] = this.leftOut;
    json[r'names_from'] = this.namesFrom;
    json[r'newest'] = this.newest;
    return json;
  }

  /// Returns a new [MergePreviewOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MergePreviewOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'contact'),
            'Required key "MergePreviewOut[contact]" is missing from JSON.');
        assert(json[r'contact'] != null,
            'Required key "MergePreviewOut[contact]" has a null value in JSON.');
        assert(json.containsKey(r'names_from'),
            'Required key "MergePreviewOut[names_from]" is missing from JSON.');
        assert(json[r'names_from'] != null,
            'Required key "MergePreviewOut[names_from]" has a null value in JSON.');
        assert(json.containsKey(r'newest'),
            'Required key "MergePreviewOut[newest]" is missing from JSON.');
        assert(json[r'newest'] != null,
            'Required key "MergePreviewOut[newest]" has a null value in JSON.');
        return true;
      }());

      return MergePreviewOut(
        contact: CardValuesOut.fromJson(json[r'contact'])!,
        leftOut: MergeLeftOutValueOut.listFromJson(json[r'left_out']),
        namesFrom: mapValueOfType<String>(json, r'names_from')!,
        newest: mapValueOfType<String>(json, r'newest')!,
      );
    }
    return null;
  }

  static List<MergePreviewOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <MergePreviewOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MergePreviewOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MergePreviewOut> mapFromJson(dynamic json) {
    final map = <String, MergePreviewOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MergePreviewOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MergePreviewOut-objects as value to a dart map
  static Map<String, List<MergePreviewOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<MergePreviewOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MergePreviewOut.listFromJson(
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
    'names_from',
    'newest',
  };
}
