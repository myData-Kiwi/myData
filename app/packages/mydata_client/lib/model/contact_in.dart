//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ContactIn {
  /// Returns a new [ContactIn] instance.
  ContactIn({
    this.addresses = const [],
    this.birthday,
    this.company,
    this.department,
    this.emails = const [],
    this.familyName,
    this.givenName,
    this.jobTitle,
    this.middleName,
    this.namePrefix,
    this.nameSuffix,
    this.nickname,
    this.note,
    this.phones = const [],
    this.urls = const [],
  });

  List<PostalAddressIn>? addresses;

  /// YYYY-MM-DD, or --MM-DD when the year is not known
  String? birthday;

  String? company;

  String? department;

  List<LabeledValueIn>? emails;

  String? familyName;

  String? givenName;

  String? jobTitle;

  String? middleName;

  String? namePrefix;

  String? nameSuffix;

  String? nickname;

  /// may hold line breaks
  String? note;

  List<LabeledValueIn>? phones;

  List<LabeledValueIn>? urls;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactIn &&
          _deepEquality.equals(other.addresses, addresses) &&
          other.birthday == birthday &&
          other.company == company &&
          other.department == department &&
          _deepEquality.equals(other.emails, emails) &&
          other.familyName == familyName &&
          other.givenName == givenName &&
          other.jobTitle == jobTitle &&
          other.middleName == middleName &&
          other.namePrefix == namePrefix &&
          other.nameSuffix == nameSuffix &&
          other.nickname == nickname &&
          other.note == note &&
          _deepEquality.equals(other.phones, phones) &&
          _deepEquality.equals(other.urls, urls);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (addresses == null ? 0 : addresses!.hashCode) +
      (birthday == null ? 0 : birthday!.hashCode) +
      (company == null ? 0 : company!.hashCode) +
      (department == null ? 0 : department!.hashCode) +
      (emails == null ? 0 : emails!.hashCode) +
      (familyName == null ? 0 : familyName!.hashCode) +
      (givenName == null ? 0 : givenName!.hashCode) +
      (jobTitle == null ? 0 : jobTitle!.hashCode) +
      (middleName == null ? 0 : middleName!.hashCode) +
      (namePrefix == null ? 0 : namePrefix!.hashCode) +
      (nameSuffix == null ? 0 : nameSuffix!.hashCode) +
      (nickname == null ? 0 : nickname!.hashCode) +
      (note == null ? 0 : note!.hashCode) +
      (phones == null ? 0 : phones!.hashCode) +
      (urls == null ? 0 : urls!.hashCode);

  @override
  String toString() =>
      'ContactIn[addresses=$addresses, birthday=$birthday, company=$company, department=$department, emails=$emails, familyName=$familyName, givenName=$givenName, jobTitle=$jobTitle, middleName=$middleName, namePrefix=$namePrefix, nameSuffix=$nameSuffix, nickname=$nickname, note=$note, phones=$phones, urls=$urls]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.addresses != null) {
      json[r'addresses'] = this.addresses;
    } else {
      json[r'addresses'] = null;
    }
    if (this.birthday != null) {
      json[r'birthday'] = this.birthday;
    } else {
      json[r'birthday'] = null;
    }
    if (this.company != null) {
      json[r'company'] = this.company;
    } else {
      json[r'company'] = null;
    }
    if (this.department != null) {
      json[r'department'] = this.department;
    } else {
      json[r'department'] = null;
    }
    if (this.emails != null) {
      json[r'emails'] = this.emails;
    } else {
      json[r'emails'] = null;
    }
    if (this.familyName != null) {
      json[r'family_name'] = this.familyName;
    } else {
      json[r'family_name'] = null;
    }
    if (this.givenName != null) {
      json[r'given_name'] = this.givenName;
    } else {
      json[r'given_name'] = null;
    }
    if (this.jobTitle != null) {
      json[r'job_title'] = this.jobTitle;
    } else {
      json[r'job_title'] = null;
    }
    if (this.middleName != null) {
      json[r'middle_name'] = this.middleName;
    } else {
      json[r'middle_name'] = null;
    }
    if (this.namePrefix != null) {
      json[r'name_prefix'] = this.namePrefix;
    } else {
      json[r'name_prefix'] = null;
    }
    if (this.nameSuffix != null) {
      json[r'name_suffix'] = this.nameSuffix;
    } else {
      json[r'name_suffix'] = null;
    }
    if (this.nickname != null) {
      json[r'nickname'] = this.nickname;
    } else {
      json[r'nickname'] = null;
    }
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    if (this.phones != null) {
      json[r'phones'] = this.phones;
    } else {
      json[r'phones'] = null;
    }
    if (this.urls != null) {
      json[r'urls'] = this.urls;
    } else {
      json[r'urls'] = null;
    }
    return json;
  }

  /// Returns a new [ContactIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ContactIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        return true;
      }());

      return ContactIn(
        addresses: PostalAddressIn.listFromJson(json[r'addresses']),
        birthday: mapValueOfType<String>(json, r'birthday'),
        company: mapValueOfType<String>(json, r'company'),
        department: mapValueOfType<String>(json, r'department'),
        emails: LabeledValueIn.listFromJson(json[r'emails']),
        familyName: mapValueOfType<String>(json, r'family_name'),
        givenName: mapValueOfType<String>(json, r'given_name'),
        jobTitle: mapValueOfType<String>(json, r'job_title'),
        middleName: mapValueOfType<String>(json, r'middle_name'),
        namePrefix: mapValueOfType<String>(json, r'name_prefix'),
        nameSuffix: mapValueOfType<String>(json, r'name_suffix'),
        nickname: mapValueOfType<String>(json, r'nickname'),
        note: mapValueOfType<String>(json, r'note'),
        phones: LabeledValueIn.listFromJson(json[r'phones']),
        urls: LabeledValueIn.listFromJson(json[r'urls']),
      );
    }
    return null;
  }

  static List<ContactIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ContactIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ContactIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ContactIn> mapFromJson(dynamic json) {
    final map = <String, ContactIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ContactIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ContactIn-objects as value to a dart map
  static Map<String, List<ContactIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ContactIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ContactIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{};
}
