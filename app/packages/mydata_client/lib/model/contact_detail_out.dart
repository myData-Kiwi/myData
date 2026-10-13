//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ContactDetailOut {
  /// Returns a new [ContactDetailOut] instance.
  ContactDetailOut({
    required this.accountId,
    required this.addressBookId,
    this.addresses = const [],
    this.birthday,
    required this.createdAt,
    this.deletedAt,
    required this.displayName,
    this.emails = const [],
    this.familyName = '',
    this.fullName = '',
    this.givenName = '',
    this.hasPhoto = false,
    required this.id,
    required this.modifiedAt,
    this.nickname = '',
    this.note = '',
    this.organisation = '',
    this.phones = const [],
    this.rawVcard,
  });

  String accountId;

  String addressBookId;

  List<PostalAddress> addresses;

  String? birthday;

  String createdAt;

  String? deletedAt;

  /// the name to show: never empty (organisation, email or phone when the card has no name)
  String displayName;

  List<LabeledValue> emails;

  String familyName;

  String fullName;

  String givenName;

  bool hasPhoto;

  String id;

  String modifiedAt;

  String nickname;

  String note;

  String organisation;

  List<LabeledValue> phones;

  /// the card as the server sent it; only with ?raw=1
  String? rawVcard;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactDetailOut &&
          other.accountId == accountId &&
          other.addressBookId == addressBookId &&
          _deepEquality.equals(other.addresses, addresses) &&
          other.birthday == birthday &&
          other.createdAt == createdAt &&
          other.deletedAt == deletedAt &&
          other.displayName == displayName &&
          _deepEquality.equals(other.emails, emails) &&
          other.familyName == familyName &&
          other.fullName == fullName &&
          other.givenName == givenName &&
          other.hasPhoto == hasPhoto &&
          other.id == id &&
          other.modifiedAt == modifiedAt &&
          other.nickname == nickname &&
          other.note == note &&
          other.organisation == organisation &&
          _deepEquality.equals(other.phones, phones) &&
          other.rawVcard == rawVcard;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId.hashCode) +
      (addressBookId.hashCode) +
      (addresses.hashCode) +
      (birthday == null ? 0 : birthday!.hashCode) +
      (createdAt.hashCode) +
      (deletedAt == null ? 0 : deletedAt!.hashCode) +
      (displayName.hashCode) +
      (emails.hashCode) +
      (familyName.hashCode) +
      (fullName.hashCode) +
      (givenName.hashCode) +
      (hasPhoto.hashCode) +
      (id.hashCode) +
      (modifiedAt.hashCode) +
      (nickname.hashCode) +
      (note.hashCode) +
      (organisation.hashCode) +
      (phones.hashCode) +
      (rawVcard == null ? 0 : rawVcard!.hashCode);

  @override
  String toString() =>
      'ContactDetailOut[accountId=$accountId, addressBookId=$addressBookId, addresses=$addresses, birthday=$birthday, createdAt=$createdAt, deletedAt=$deletedAt, displayName=$displayName, emails=$emails, familyName=$familyName, fullName=$fullName, givenName=$givenName, hasPhoto=$hasPhoto, id=$id, modifiedAt=$modifiedAt, nickname=$nickname, note=$note, organisation=$organisation, phones=$phones, rawVcard=$rawVcard]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'account_id'] = this.accountId;
    json[r'address_book_id'] = this.addressBookId;
    json[r'addresses'] = this.addresses;
    if (this.birthday != null) {
      json[r'birthday'] = this.birthday;
    } else {
      json[r'birthday'] = null;
    }
    json[r'created_at'] = this.createdAt;
    if (this.deletedAt != null) {
      json[r'deleted_at'] = this.deletedAt;
    } else {
      json[r'deleted_at'] = null;
    }
    json[r'display_name'] = this.displayName;
    json[r'emails'] = this.emails;
    json[r'family_name'] = this.familyName;
    json[r'full_name'] = this.fullName;
    json[r'given_name'] = this.givenName;
    json[r'has_photo'] = this.hasPhoto;
    json[r'id'] = this.id;
    json[r'modified_at'] = this.modifiedAt;
    json[r'nickname'] = this.nickname;
    json[r'note'] = this.note;
    json[r'organisation'] = this.organisation;
    json[r'phones'] = this.phones;
    if (this.rawVcard != null) {
      json[r'raw_vcard'] = this.rawVcard;
    } else {
      json[r'raw_vcard'] = null;
    }
    return json;
  }

  /// Returns a new [ContactDetailOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ContactDetailOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'account_id'),
            'Required key "ContactDetailOut[account_id]" is missing from JSON.');
        assert(json[r'account_id'] != null,
            'Required key "ContactDetailOut[account_id]" has a null value in JSON.');
        assert(json.containsKey(r'address_book_id'),
            'Required key "ContactDetailOut[address_book_id]" is missing from JSON.');
        assert(json[r'address_book_id'] != null,
            'Required key "ContactDetailOut[address_book_id]" has a null value in JSON.');
        assert(json.containsKey(r'created_at'),
            'Required key "ContactDetailOut[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null,
            'Required key "ContactDetailOut[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'display_name'),
            'Required key "ContactDetailOut[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null,
            'Required key "ContactDetailOut[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "ContactDetailOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "ContactDetailOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'modified_at'),
            'Required key "ContactDetailOut[modified_at]" is missing from JSON.');
        assert(json[r'modified_at'] != null,
            'Required key "ContactDetailOut[modified_at]" has a null value in JSON.');
        return true;
      }());

      return ContactDetailOut(
        accountId: mapValueOfType<String>(json, r'account_id')!,
        addressBookId: mapValueOfType<String>(json, r'address_book_id')!,
        addresses: PostalAddress.listFromJson(json[r'addresses']),
        birthday: mapValueOfType<String>(json, r'birthday'),
        createdAt: mapValueOfType<String>(json, r'created_at')!,
        deletedAt: mapValueOfType<String>(json, r'deleted_at'),
        displayName: mapValueOfType<String>(json, r'display_name')!,
        emails: LabeledValue.listFromJson(json[r'emails']),
        familyName: mapValueOfType<String>(json, r'family_name') ?? '',
        fullName: mapValueOfType<String>(json, r'full_name') ?? '',
        givenName: mapValueOfType<String>(json, r'given_name') ?? '',
        hasPhoto: mapValueOfType<bool>(json, r'has_photo') ?? false,
        id: mapValueOfType<String>(json, r'id')!,
        modifiedAt: mapValueOfType<String>(json, r'modified_at')!,
        nickname: mapValueOfType<String>(json, r'nickname') ?? '',
        note: mapValueOfType<String>(json, r'note') ?? '',
        organisation: mapValueOfType<String>(json, r'organisation') ?? '',
        phones: LabeledValue.listFromJson(json[r'phones']),
        rawVcard: mapValueOfType<String>(json, r'raw_vcard'),
      );
    }
    return null;
  }

  static List<ContactDetailOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ContactDetailOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ContactDetailOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ContactDetailOut> mapFromJson(dynamic json) {
    final map = <String, ContactDetailOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ContactDetailOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ContactDetailOut-objects as value to a dart map
  static Map<String, List<ContactDetailOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ContactDetailOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ContactDetailOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'account_id',
    'address_book_id',
    'created_at',
    'display_name',
    'id',
    'modified_at',
  };
}
