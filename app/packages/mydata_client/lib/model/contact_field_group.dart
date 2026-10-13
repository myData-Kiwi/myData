//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ContactFieldGroup {
  /// Returns a new [ContactFieldGroup] instance.
  ContactFieldGroup({
    this.items = const [],
    required this.kind,
    required this.title,
  });

  List<ContactField> items;

  ContactFieldGroupKindEnum kind;

  /// the group's heading: Phone, Email, Address, Birthday, Links or Notes
  String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactFieldGroup &&
          _deepEquality.equals(other.items, items) &&
          other.kind == kind &&
          other.title == title;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (items.hashCode) + (kind.hashCode) + (title.hashCode);

  @override
  String toString() =>
      'ContactFieldGroup[items=$items, kind=$kind, title=$title]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'items'] = this.items;
    json[r'kind'] = this.kind;
    json[r'title'] = this.title;
    return json;
  }

  /// Returns a new [ContactFieldGroup] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ContactFieldGroup? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'items'),
            'Required key "ContactFieldGroup[items]" is missing from JSON.');
        assert(json[r'items'] != null,
            'Required key "ContactFieldGroup[items]" has a null value in JSON.');
        assert(json.containsKey(r'kind'),
            'Required key "ContactFieldGroup[kind]" is missing from JSON.');
        assert(json[r'kind'] != null,
            'Required key "ContactFieldGroup[kind]" has a null value in JSON.');
        assert(json.containsKey(r'title'),
            'Required key "ContactFieldGroup[title]" is missing from JSON.');
        assert(json[r'title'] != null,
            'Required key "ContactFieldGroup[title]" has a null value in JSON.');
        return true;
      }());

      return ContactFieldGroup(
        items: ContactField.listFromJson(json[r'items']),
        kind: ContactFieldGroupKindEnum.fromJson(json[r'kind'])!,
        title: mapValueOfType<String>(json, r'title')!,
      );
    }
    return null;
  }

  static List<ContactFieldGroup> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ContactFieldGroup>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ContactFieldGroup.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ContactFieldGroup> mapFromJson(dynamic json) {
    final map = <String, ContactFieldGroup>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ContactFieldGroup.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ContactFieldGroup-objects as value to a dart map
  static Map<String, List<ContactFieldGroup>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ContactFieldGroup>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ContactFieldGroup.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
    'kind',
    'title',
  };
}

enum ContactFieldGroupKindEnum {
  phone._(r'phone'),
  email._(r'email'),
  address._(r'address'),
  birthday._(r'birthday'),
  url._(r'url'),
  note._(r'note'),
  ;

  /// Instantiate a new enum with the provided value.
  const ContactFieldGroupKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ContactFieldGroupKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ContactFieldGroupKindEnum? fromJson(dynamic value) =>
      ContactFieldGroupKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ContactFieldGroupKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ContactFieldGroupKindEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ContactFieldGroupKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ContactFieldGroupKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ContactFieldGroupKindEnum] to String,
/// and [decode] dynamic data back to [ContactFieldGroupKindEnum].
class ContactFieldGroupKindEnumTypeTransformer {
  factory ContactFieldGroupKindEnumTypeTransformer() =>
      _instance ??= const ContactFieldGroupKindEnumTypeTransformer._();

  const ContactFieldGroupKindEnumTypeTransformer._();

  String encode(ContactFieldGroupKindEnum data) => data._value;

  /// Returns the instance of [ContactFieldGroupKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ContactFieldGroupKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is ContactFieldGroupKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'phone':
          return ContactFieldGroupKindEnum.phone;
        case r'email':
          return ContactFieldGroupKindEnum.email;
        case r'address':
          return ContactFieldGroupKindEnum.address;
        case r'birthday':
          return ContactFieldGroupKindEnum.birthday;
        case r'url':
          return ContactFieldGroupKindEnum.url;
        case r'note':
          return ContactFieldGroupKindEnum.note;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ContactFieldGroupKindEnumTypeTransformer? _instance;
}
