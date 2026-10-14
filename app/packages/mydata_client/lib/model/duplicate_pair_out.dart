//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class DuplicatePairOut {
  /// Returns a new [DuplicatePairOut] instance.
  DuplicatePairOut({
    this.contacts = const [],
    this.emails = const [],
    this.phones = const [],
    this.signals = const [],
    required this.strength,
  });

  /// the two contacts of yours, in name order
  List<ContactOut> contacts;

  /// the emails they share, as the first contact writes them
  List<String> emails;

  /// the phone numbers they share, as the first contact writes them
  List<String> phones;

  /// what they share: email, phone, name
  List<String> signals;

  /// strong (the same email or phone, under the same name or where one has none) or suggestion (the same name only, or an email or phone shared under another name)
  String strength;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DuplicatePairOut &&
          _deepEquality.equals(other.contacts, contacts) &&
          _deepEquality.equals(other.emails, emails) &&
          _deepEquality.equals(other.phones, phones) &&
          _deepEquality.equals(other.signals, signals) &&
          other.strength == strength;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (contacts.hashCode) +
      (emails.hashCode) +
      (phones.hashCode) +
      (signals.hashCode) +
      (strength.hashCode);

  @override
  String toString() =>
      'DuplicatePairOut[contacts=$contacts, emails=$emails, phones=$phones, signals=$signals, strength=$strength]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'contacts'] = this.contacts;
    json[r'emails'] = this.emails;
    json[r'phones'] = this.phones;
    json[r'signals'] = this.signals;
    json[r'strength'] = this.strength;
    return json;
  }

  /// Returns a new [DuplicatePairOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DuplicatePairOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'contacts'),
            'Required key "DuplicatePairOut[contacts]" is missing from JSON.');
        assert(json[r'contacts'] != null,
            'Required key "DuplicatePairOut[contacts]" has a null value in JSON.');
        assert(json.containsKey(r'signals'),
            'Required key "DuplicatePairOut[signals]" is missing from JSON.');
        assert(json[r'signals'] != null,
            'Required key "DuplicatePairOut[signals]" has a null value in JSON.');
        assert(json.containsKey(r'strength'),
            'Required key "DuplicatePairOut[strength]" is missing from JSON.');
        assert(json[r'strength'] != null,
            'Required key "DuplicatePairOut[strength]" has a null value in JSON.');
        return true;
      }());

      return DuplicatePairOut(
        contacts: ContactOut.listFromJson(json[r'contacts']),
        emails: json[r'emails'] is Iterable
            ? (json[r'emails'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        phones: json[r'phones'] is Iterable
            ? (json[r'phones'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        signals: json[r'signals'] is Iterable
            ? (json[r'signals'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        strength: mapValueOfType<String>(json, r'strength')!,
      );
    }
    return null;
  }

  static List<DuplicatePairOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <DuplicatePairOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DuplicatePairOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DuplicatePairOut> mapFromJson(dynamic json) {
    final map = <String, DuplicatePairOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DuplicatePairOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DuplicatePairOut-objects as value to a dart map
  static Map<String, List<DuplicatePairOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<DuplicatePairOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DuplicatePairOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'contacts',
    'signals',
    'strength',
  };
}
