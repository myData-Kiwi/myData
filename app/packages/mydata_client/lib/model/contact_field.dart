//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ContactField {
  /// Returns a new [ContactField] instance.
  ContactField({
    this.address,
    this.label = '',
    required this.value,
  });

  /// an address's parts, to lay it out in the locale's order; only for kind address
  PostalAddress? address;

  /// the source's label in sentence case (\"Mobile\", \"Home fax\"), or a label the user typed, exactly as written; empty when none
  String label;

  /// as the source wrote it. Birthday: YYYY-MM-DD, or --MM-DD when the year is not known. Address: plain lines (street, then locality, region and postal code, then country); `address` has the parts
  String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactField &&
          other.address == address &&
          other.label == label &&
          other.value == value;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (address == null ? 0 : address!.hashCode) +
      (label.hashCode) +
      (value.hashCode);

  @override
  String toString() =>
      'ContactField[address=$address, label=$label, value=$value]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.address != null) {
      json[r'address'] = this.address;
    } else {
      json[r'address'] = null;
    }
    json[r'label'] = this.label;
    json[r'value'] = this.value;
    return json;
  }

  /// Returns a new [ContactField] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ContactField? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'value'),
            'Required key "ContactField[value]" is missing from JSON.');
        assert(json[r'value'] != null,
            'Required key "ContactField[value]" has a null value in JSON.');
        return true;
      }());

      return ContactField(
        address: PostalAddress.fromJson(json[r'address']),
        label: mapValueOfType<String>(json, r'label') ?? '',
        value: mapValueOfType<String>(json, r'value')!,
      );
    }
    return null;
  }

  static List<ContactField> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ContactField>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ContactField.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ContactField> mapFromJson(dynamic json) {
    final map = <String, ContactField>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ContactField.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ContactField-objects as value to a dart map
  static Map<String, List<ContactField>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ContactField>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ContactField.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'value',
  };
}
