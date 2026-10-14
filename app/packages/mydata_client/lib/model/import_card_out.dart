//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportCardOut {
  /// Returns a new [ImportCardOut] instance.
  ImportCardOut({
    this.addresses = const [],
    this.birthday,
    this.company = '',
    this.convertedFrom,
    this.department = '',
    required this.displayName,
    this.emails = const [],
    this.entry,
    this.familyName = '',
    this.fields = const [],
    this.fullName = '',
    this.givenName = '',
    this.hasPhoto = false,
    required this.index,
    this.jobTitle = '',
    required this.kind,
    this.middleName = '',
    this.namePrefix = '',
    this.nameSuffix = '',
    this.nickname = '',
    this.note = '',
    this.organisation = '',
    this.phones = const [],
    this.urls = const [],
  });

  List<PostalAddress> addresses;

  /// YYYY-MM-DD, or --MM-DD when the year is not known
  String? birthday;

  String company;

  /// 2.1 for a vCard 2.1, shown as it would be stored (3.0)
  String? convertedFrom;

  String department;

  /// never empty (organisation, email or phone when the card has no name)
  String displayName;

  List<LabeledValue> emails;

  /// the zip entry it came from (a name only)
  String? entry;

  String familyName;

  /// the values grouped as a contact's page shows them: phone, email, address, birthday, url, note
  List<ContactFieldGroup> fields;

  String fullName;

  String givenName;

  bool hasPhoto;

  /// the card's position in the input, from 0
  int index;

  String jobTitle;

  /// individual, org or group
  String kind;

  String middleName;

  String namePrefix;

  String nameSuffix;

  String nickname;

  String note;

  /// the company and, after a comma, the department
  String organisation;

  List<LabeledValue> phones;

  List<LabeledValue> urls;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportCardOut &&
          _deepEquality.equals(other.addresses, addresses) &&
          other.birthday == birthday &&
          other.company == company &&
          other.convertedFrom == convertedFrom &&
          other.department == department &&
          other.displayName == displayName &&
          _deepEquality.equals(other.emails, emails) &&
          other.entry == entry &&
          other.familyName == familyName &&
          _deepEquality.equals(other.fields, fields) &&
          other.fullName == fullName &&
          other.givenName == givenName &&
          other.hasPhoto == hasPhoto &&
          other.index == index &&
          other.jobTitle == jobTitle &&
          other.kind == kind &&
          other.middleName == middleName &&
          other.namePrefix == namePrefix &&
          other.nameSuffix == nameSuffix &&
          other.nickname == nickname &&
          other.note == note &&
          other.organisation == organisation &&
          _deepEquality.equals(other.phones, phones) &&
          _deepEquality.equals(other.urls, urls);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (addresses.hashCode) +
      (birthday == null ? 0 : birthday!.hashCode) +
      (company.hashCode) +
      (convertedFrom == null ? 0 : convertedFrom!.hashCode) +
      (department.hashCode) +
      (displayName.hashCode) +
      (emails.hashCode) +
      (entry == null ? 0 : entry!.hashCode) +
      (familyName.hashCode) +
      (fields.hashCode) +
      (fullName.hashCode) +
      (givenName.hashCode) +
      (hasPhoto.hashCode) +
      (index.hashCode) +
      (jobTitle.hashCode) +
      (kind.hashCode) +
      (middleName.hashCode) +
      (namePrefix.hashCode) +
      (nameSuffix.hashCode) +
      (nickname.hashCode) +
      (note.hashCode) +
      (organisation.hashCode) +
      (phones.hashCode) +
      (urls.hashCode);

  @override
  String toString() =>
      'ImportCardOut[addresses=$addresses, birthday=$birthday, company=$company, convertedFrom=$convertedFrom, department=$department, displayName=$displayName, emails=$emails, entry=$entry, familyName=$familyName, fields=$fields, fullName=$fullName, givenName=$givenName, hasPhoto=$hasPhoto, index=$index, jobTitle=$jobTitle, kind=$kind, middleName=$middleName, namePrefix=$namePrefix, nameSuffix=$nameSuffix, nickname=$nickname, note=$note, organisation=$organisation, phones=$phones, urls=$urls]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'addresses'] = this.addresses;
    if (this.birthday != null) {
      json[r'birthday'] = this.birthday;
    } else {
      json[r'birthday'] = null;
    }
    json[r'company'] = this.company;
    if (this.convertedFrom != null) {
      json[r'converted_from'] = this.convertedFrom;
    } else {
      json[r'converted_from'] = null;
    }
    json[r'department'] = this.department;
    json[r'display_name'] = this.displayName;
    json[r'emails'] = this.emails;
    if (this.entry != null) {
      json[r'entry'] = this.entry;
    } else {
      json[r'entry'] = null;
    }
    json[r'family_name'] = this.familyName;
    json[r'fields'] = this.fields;
    json[r'full_name'] = this.fullName;
    json[r'given_name'] = this.givenName;
    json[r'has_photo'] = this.hasPhoto;
    json[r'index'] = this.index;
    json[r'job_title'] = this.jobTitle;
    json[r'kind'] = this.kind;
    json[r'middle_name'] = this.middleName;
    json[r'name_prefix'] = this.namePrefix;
    json[r'name_suffix'] = this.nameSuffix;
    json[r'nickname'] = this.nickname;
    json[r'note'] = this.note;
    json[r'organisation'] = this.organisation;
    json[r'phones'] = this.phones;
    json[r'urls'] = this.urls;
    return json;
  }

  /// Returns a new [ImportCardOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportCardOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'display_name'),
            'Required key "ImportCardOut[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null,
            'Required key "ImportCardOut[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'fields'),
            'Required key "ImportCardOut[fields]" is missing from JSON.');
        assert(json[r'fields'] != null,
            'Required key "ImportCardOut[fields]" has a null value in JSON.');
        assert(json.containsKey(r'index'),
            'Required key "ImportCardOut[index]" is missing from JSON.');
        assert(json[r'index'] != null,
            'Required key "ImportCardOut[index]" has a null value in JSON.');
        assert(json.containsKey(r'kind'),
            'Required key "ImportCardOut[kind]" is missing from JSON.');
        assert(json[r'kind'] != null,
            'Required key "ImportCardOut[kind]" has a null value in JSON.');
        return true;
      }());

      return ImportCardOut(
        addresses: PostalAddress.listFromJson(json[r'addresses']),
        birthday: mapValueOfType<String>(json, r'birthday'),
        company: mapValueOfType<String>(json, r'company') ?? '',
        convertedFrom: mapValueOfType<String>(json, r'converted_from'),
        department: mapValueOfType<String>(json, r'department') ?? '',
        displayName: mapValueOfType<String>(json, r'display_name')!,
        emails: LabeledValue.listFromJson(json[r'emails']),
        entry: mapValueOfType<String>(json, r'entry'),
        familyName: mapValueOfType<String>(json, r'family_name') ?? '',
        fields: ContactFieldGroup.listFromJson(json[r'fields']),
        fullName: mapValueOfType<String>(json, r'full_name') ?? '',
        givenName: mapValueOfType<String>(json, r'given_name') ?? '',
        hasPhoto: mapValueOfType<bool>(json, r'has_photo') ?? false,
        index: mapValueOfType<int>(json, r'index')!,
        jobTitle: mapValueOfType<String>(json, r'job_title') ?? '',
        kind: mapValueOfType<String>(json, r'kind')!,
        middleName: mapValueOfType<String>(json, r'middle_name') ?? '',
        namePrefix: mapValueOfType<String>(json, r'name_prefix') ?? '',
        nameSuffix: mapValueOfType<String>(json, r'name_suffix') ?? '',
        nickname: mapValueOfType<String>(json, r'nickname') ?? '',
        note: mapValueOfType<String>(json, r'note') ?? '',
        organisation: mapValueOfType<String>(json, r'organisation') ?? '',
        phones: LabeledValue.listFromJson(json[r'phones']),
        urls: LabeledValue.listFromJson(json[r'urls']),
      );
    }
    return null;
  }

  static List<ImportCardOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportCardOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportCardOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportCardOut> mapFromJson(dynamic json) {
    final map = <String, ImportCardOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportCardOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportCardOut-objects as value to a dart map
  static Map<String, List<ImportCardOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportCardOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportCardOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'display_name',
    'fields',
    'index',
    'kind',
  };
}
