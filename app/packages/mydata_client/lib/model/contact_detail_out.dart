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
    this.caption,
    required this.createdAt,
    this.deletedAt,
    required this.displayName,
    this.emails = const [],
    this.familyName = '',
    this.fields = const [],
    this.fullName = '',
    this.givenName = '',
    this.hasPhoto = false,
    required this.id,
    this.jobTitle = '',
    required this.modifiedAt,
    this.nickname = '',
    this.note = '',
    this.notesIncluded = true,
    this.organisation = '',
    this.phones = const [],
    this.rawVcard,
    required this.sortLetter,
    required this.source_,
    required this.sourceLabel,
    this.urls = const [],
  });

  String accountId;

  String addressBookId;

  List<PostalAddress> addresses;

  String? birthday;

  /// the line under the name in the contact list: the organisation, else the first email or phone that is not already the name; none when there is nothing else to say
  String? caption;

  String createdAt;

  String? deletedAt;

  /// the name to show: never empty (organisation, email or phone when the card has no name)
  String displayName;

  List<LabeledValue> emails;

  String familyName;

  /// the contact's values for its page, grouped by kind in this order: phone, email, address, birthday, url, note. A kind with no values is left out; note only when the source reads notes and the note is not empty (never for This Mac)
  List<ContactFieldGroup> fields;

  String fullName;

  String givenName;

  bool hasPhoto;

  String id;

  String jobTitle;

  String modifiedAt;

  String nickname;

  String note;

  /// false when the source never reads notes (This Mac): show no Notes field
  bool notesIncluded;

  String organisation;

  List<LabeledValue> phones;

  /// the card as the server sent it; only with ?raw=1
  String? rawVcard;

  /// the contact list's letter group: the first letter of display_name without accents, upper case; \"#\" when it does not start with a letter (digits, symbols, Chinese, Japanese kanji or Korean characters)
  String sortLetter;

  /// where the contact comes from
  ContactDetailOutSource_Enum source_;

  /// the source inside a sentence: \"this Mac\" or \"the iCloud account <email>\" (\"From this Mac. Change it in Contacts.\")
  String sourceLabel;

  /// web addresses as the source wrote them; never trusted to say what they open
  List<LabeledValue> urls;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactDetailOut &&
          other.accountId == accountId &&
          other.addressBookId == addressBookId &&
          _deepEquality.equals(other.addresses, addresses) &&
          other.birthday == birthday &&
          other.caption == caption &&
          other.createdAt == createdAt &&
          other.deletedAt == deletedAt &&
          other.displayName == displayName &&
          _deepEquality.equals(other.emails, emails) &&
          other.familyName == familyName &&
          _deepEquality.equals(other.fields, fields) &&
          other.fullName == fullName &&
          other.givenName == givenName &&
          other.hasPhoto == hasPhoto &&
          other.id == id &&
          other.jobTitle == jobTitle &&
          other.modifiedAt == modifiedAt &&
          other.nickname == nickname &&
          other.note == note &&
          other.notesIncluded == notesIncluded &&
          other.organisation == organisation &&
          _deepEquality.equals(other.phones, phones) &&
          other.rawVcard == rawVcard &&
          other.sortLetter == sortLetter &&
          other.source_ == source_ &&
          other.sourceLabel == sourceLabel &&
          _deepEquality.equals(other.urls, urls);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId.hashCode) +
      (addressBookId.hashCode) +
      (addresses.hashCode) +
      (birthday == null ? 0 : birthday!.hashCode) +
      (caption == null ? 0 : caption!.hashCode) +
      (createdAt.hashCode) +
      (deletedAt == null ? 0 : deletedAt!.hashCode) +
      (displayName.hashCode) +
      (emails.hashCode) +
      (familyName.hashCode) +
      (fields.hashCode) +
      (fullName.hashCode) +
      (givenName.hashCode) +
      (hasPhoto.hashCode) +
      (id.hashCode) +
      (jobTitle.hashCode) +
      (modifiedAt.hashCode) +
      (nickname.hashCode) +
      (note.hashCode) +
      (notesIncluded.hashCode) +
      (organisation.hashCode) +
      (phones.hashCode) +
      (rawVcard == null ? 0 : rawVcard!.hashCode) +
      (sortLetter.hashCode) +
      (source_.hashCode) +
      (sourceLabel.hashCode) +
      (urls.hashCode);

  @override
  String toString() =>
      'ContactDetailOut[accountId=$accountId, addressBookId=$addressBookId, addresses=$addresses, birthday=$birthday, caption=$caption, createdAt=$createdAt, deletedAt=$deletedAt, displayName=$displayName, emails=$emails, familyName=$familyName, fields=$fields, fullName=$fullName, givenName=$givenName, hasPhoto=$hasPhoto, id=$id, jobTitle=$jobTitle, modifiedAt=$modifiedAt, nickname=$nickname, note=$note, notesIncluded=$notesIncluded, organisation=$organisation, phones=$phones, rawVcard=$rawVcard, sortLetter=$sortLetter, source_=$source_, sourceLabel=$sourceLabel, urls=$urls]';

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
    if (this.caption != null) {
      json[r'caption'] = this.caption;
    } else {
      json[r'caption'] = null;
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
    json[r'fields'] = this.fields;
    json[r'full_name'] = this.fullName;
    json[r'given_name'] = this.givenName;
    json[r'has_photo'] = this.hasPhoto;
    json[r'id'] = this.id;
    json[r'job_title'] = this.jobTitle;
    json[r'modified_at'] = this.modifiedAt;
    json[r'nickname'] = this.nickname;
    json[r'note'] = this.note;
    json[r'notes_included'] = this.notesIncluded;
    json[r'organisation'] = this.organisation;
    json[r'phones'] = this.phones;
    if (this.rawVcard != null) {
      json[r'raw_vcard'] = this.rawVcard;
    } else {
      json[r'raw_vcard'] = null;
    }
    json[r'sort_letter'] = this.sortLetter;
    json[r'source'] = this.source_;
    json[r'source_label'] = this.sourceLabel;
    json[r'urls'] = this.urls;
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
        assert(json.containsKey(r'fields'),
            'Required key "ContactDetailOut[fields]" is missing from JSON.');
        assert(json[r'fields'] != null,
            'Required key "ContactDetailOut[fields]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "ContactDetailOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "ContactDetailOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'modified_at'),
            'Required key "ContactDetailOut[modified_at]" is missing from JSON.');
        assert(json[r'modified_at'] != null,
            'Required key "ContactDetailOut[modified_at]" has a null value in JSON.');
        assert(json.containsKey(r'sort_letter'),
            'Required key "ContactDetailOut[sort_letter]" is missing from JSON.');
        assert(json[r'sort_letter'] != null,
            'Required key "ContactDetailOut[sort_letter]" has a null value in JSON.');
        assert(json.containsKey(r'source'),
            'Required key "ContactDetailOut[source]" is missing from JSON.');
        assert(json[r'source'] != null,
            'Required key "ContactDetailOut[source]" has a null value in JSON.');
        assert(json.containsKey(r'source_label'),
            'Required key "ContactDetailOut[source_label]" is missing from JSON.');
        assert(json[r'source_label'] != null,
            'Required key "ContactDetailOut[source_label]" has a null value in JSON.');
        return true;
      }());

      return ContactDetailOut(
        accountId: mapValueOfType<String>(json, r'account_id')!,
        addressBookId: mapValueOfType<String>(json, r'address_book_id')!,
        addresses: PostalAddress.listFromJson(json[r'addresses']),
        birthday: mapValueOfType<String>(json, r'birthday'),
        caption: mapValueOfType<String>(json, r'caption'),
        createdAt: mapValueOfType<String>(json, r'created_at')!,
        deletedAt: mapValueOfType<String>(json, r'deleted_at'),
        displayName: mapValueOfType<String>(json, r'display_name')!,
        emails: LabeledValue.listFromJson(json[r'emails']),
        familyName: mapValueOfType<String>(json, r'family_name') ?? '',
        fields: ContactFieldGroup.listFromJson(json[r'fields']),
        fullName: mapValueOfType<String>(json, r'full_name') ?? '',
        givenName: mapValueOfType<String>(json, r'given_name') ?? '',
        hasPhoto: mapValueOfType<bool>(json, r'has_photo') ?? false,
        id: mapValueOfType<String>(json, r'id')!,
        jobTitle: mapValueOfType<String>(json, r'job_title') ?? '',
        modifiedAt: mapValueOfType<String>(json, r'modified_at')!,
        nickname: mapValueOfType<String>(json, r'nickname') ?? '',
        note: mapValueOfType<String>(json, r'note') ?? '',
        notesIncluded: mapValueOfType<bool>(json, r'notes_included') ?? true,
        organisation: mapValueOfType<String>(json, r'organisation') ?? '',
        phones: LabeledValue.listFromJson(json[r'phones']),
        rawVcard: mapValueOfType<String>(json, r'raw_vcard'),
        sortLetter: mapValueOfType<String>(json, r'sort_letter')!,
        source_: ContactDetailOutSource_Enum.fromJson(json[r'source'])!,
        sourceLabel: mapValueOfType<String>(json, r'source_label')!,
        urls: LabeledValue.listFromJson(json[r'urls']),
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
    'fields',
    'id',
    'modified_at',
    'sort_letter',
    'source',
    'source_label',
  };
}

/// where the contact comes from
enum ContactDetailOutSource_Enum {
  mac._(r'mac'),
  icloud._(r'icloud'),
  ;

  /// Instantiate a new enum with the provided value.
  const ContactDetailOutSource_Enum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ContactDetailOutSource_Enum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ContactDetailOutSource_Enum? fromJson(dynamic value) =>
      ContactDetailOutSource_EnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ContactDetailOutSource_Enum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ContactDetailOutSource_Enum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ContactDetailOutSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ContactDetailOutSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ContactDetailOutSource_Enum] to String,
/// and [decode] dynamic data back to [ContactDetailOutSource_Enum].
class ContactDetailOutSource_EnumTypeTransformer {
  factory ContactDetailOutSource_EnumTypeTransformer() =>
      _instance ??= const ContactDetailOutSource_EnumTypeTransformer._();

  const ContactDetailOutSource_EnumTypeTransformer._();

  String encode(ContactDetailOutSource_Enum data) => data._value;

  /// Returns the instance of [ContactDetailOutSource_Enum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ContactDetailOutSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data is ContactDetailOutSource_Enum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'mac':
          return ContactDetailOutSource_Enum.mac;
        case r'icloud':
          return ContactDetailOutSource_Enum.icloud;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ContactDetailOutSource_EnumTypeTransformer? _instance;
}
