//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ContactOut {
  /// Returns a new [ContactOut] instance.
  ContactOut({
    required this.accountId,
    required this.addressBookId,
    this.addresses = const [],
    this.birthday,
    this.caption,
    this.changedInSource,
    required this.createdAt,
    this.deletedAt,
    required this.displayName,
    required this.editable,
    this.emails = const [],
    required this.etag,
    this.familyName = '',
    this.fullName = '',
    this.givenName = '',
    this.hasPhoto = false,
    required this.id,
    this.mergedInto,
    required this.modifiedAt,
    this.nickname = '',
    this.note = '',
    this.notesIncluded = true,
    this.onPhone,
    this.organisation = '',
    this.phones = const [],
    this.purgeAfter,
    required this.sortLetter,
    required this.source_,
  });

  String accountId;

  String addressBookId;

  List<PostalAddress> addresses;

  String? birthday;

  /// the line under the name in the contact list: the organisation, else the first email or phone that is not already the name; none when there is nothing else to say
  String? caption;

  /// for a contact the host owns that was imported from a followed account: that account's id (GET /sources) when its copy changed since the import (\"changed in <source> since import\", to review); null otherwise
  String? changedInSource;

  String createdAt;

  String? deletedAt;

  /// the name to show: never empty (organisation, email or phone when the card has no name)
  String displayName;

  /// true for a contact the host owns, which the apps may change and delete; false for one followed from a source (change it there)
  bool editable;

  List<LabeledValue> emails;

  /// the contact's current version, to send back as If-Match when changing it; it changes with every change, a delete or restore included
  String etag;

  String familyName;

  String fullName;

  String givenName;

  bool hasPhoto;

  String id;

  /// for a contact in Recently deleted because it was merged: the contact it went into, which a link to it can open instead; null otherwise
  String? mergedInto;

  String modifiedAt;

  String nickname;

  String note;

  /// false when the source never reads notes (This Mac): show no Notes field
  bool notesIncluded;

  /// false for a contact the host owns: it is on myData only, not on any phone yet. Null for a followed one (the source decides where it is)
  bool? onPhone;

  String organisation;

  List<LabeledValue> phones;

  /// for a contact in Recently deleted: when it is deleted for good (UTC)
  String? purgeAfter;

  /// the contact list's letter group: the first letter of display_name without accents, upper case; \"#\" when it does not start with a letter (digits, symbols, Chinese, Japanese kanji or Korean characters)
  String sortLetter;

  /// where the contact comes from: mydata for a contact the host owns (made in an app; the only copy is on this host)
  ContactOutSource_Enum source_;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactOut &&
          other.accountId == accountId &&
          other.addressBookId == addressBookId &&
          _deepEquality.equals(other.addresses, addresses) &&
          other.birthday == birthday &&
          other.caption == caption &&
          other.changedInSource == changedInSource &&
          other.createdAt == createdAt &&
          other.deletedAt == deletedAt &&
          other.displayName == displayName &&
          other.editable == editable &&
          _deepEquality.equals(other.emails, emails) &&
          other.etag == etag &&
          other.familyName == familyName &&
          other.fullName == fullName &&
          other.givenName == givenName &&
          other.hasPhoto == hasPhoto &&
          other.id == id &&
          other.mergedInto == mergedInto &&
          other.modifiedAt == modifiedAt &&
          other.nickname == nickname &&
          other.note == note &&
          other.notesIncluded == notesIncluded &&
          other.onPhone == onPhone &&
          other.organisation == organisation &&
          _deepEquality.equals(other.phones, phones) &&
          other.purgeAfter == purgeAfter &&
          other.sortLetter == sortLetter &&
          other.source_ == source_;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId.hashCode) +
      (addressBookId.hashCode) +
      (addresses.hashCode) +
      (birthday == null ? 0 : birthday!.hashCode) +
      (caption == null ? 0 : caption!.hashCode) +
      (changedInSource == null ? 0 : changedInSource!.hashCode) +
      (createdAt.hashCode) +
      (deletedAt == null ? 0 : deletedAt!.hashCode) +
      (displayName.hashCode) +
      (editable.hashCode) +
      (emails.hashCode) +
      (etag.hashCode) +
      (familyName.hashCode) +
      (fullName.hashCode) +
      (givenName.hashCode) +
      (hasPhoto.hashCode) +
      (id.hashCode) +
      (mergedInto == null ? 0 : mergedInto!.hashCode) +
      (modifiedAt.hashCode) +
      (nickname.hashCode) +
      (note.hashCode) +
      (notesIncluded.hashCode) +
      (onPhone == null ? 0 : onPhone!.hashCode) +
      (organisation.hashCode) +
      (phones.hashCode) +
      (purgeAfter == null ? 0 : purgeAfter!.hashCode) +
      (sortLetter.hashCode) +
      (source_.hashCode);

  @override
  String toString() =>
      'ContactOut[accountId=$accountId, addressBookId=$addressBookId, addresses=$addresses, birthday=$birthday, caption=$caption, changedInSource=$changedInSource, createdAt=$createdAt, deletedAt=$deletedAt, displayName=$displayName, editable=$editable, emails=$emails, etag=$etag, familyName=$familyName, fullName=$fullName, givenName=$givenName, hasPhoto=$hasPhoto, id=$id, mergedInto=$mergedInto, modifiedAt=$modifiedAt, nickname=$nickname, note=$note, notesIncluded=$notesIncluded, onPhone=$onPhone, organisation=$organisation, phones=$phones, purgeAfter=$purgeAfter, sortLetter=$sortLetter, source_=$source_]';

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
    if (this.changedInSource != null) {
      json[r'changed_in_source'] = this.changedInSource;
    } else {
      json[r'changed_in_source'] = null;
    }
    json[r'created_at'] = this.createdAt;
    if (this.deletedAt != null) {
      json[r'deleted_at'] = this.deletedAt;
    } else {
      json[r'deleted_at'] = null;
    }
    json[r'display_name'] = this.displayName;
    json[r'editable'] = this.editable;
    json[r'emails'] = this.emails;
    json[r'etag'] = this.etag;
    json[r'family_name'] = this.familyName;
    json[r'full_name'] = this.fullName;
    json[r'given_name'] = this.givenName;
    json[r'has_photo'] = this.hasPhoto;
    json[r'id'] = this.id;
    if (this.mergedInto != null) {
      json[r'merged_into'] = this.mergedInto;
    } else {
      json[r'merged_into'] = null;
    }
    json[r'modified_at'] = this.modifiedAt;
    json[r'nickname'] = this.nickname;
    json[r'note'] = this.note;
    json[r'notes_included'] = this.notesIncluded;
    if (this.onPhone != null) {
      json[r'on_phone'] = this.onPhone;
    } else {
      json[r'on_phone'] = null;
    }
    json[r'organisation'] = this.organisation;
    json[r'phones'] = this.phones;
    if (this.purgeAfter != null) {
      json[r'purge_after'] = this.purgeAfter;
    } else {
      json[r'purge_after'] = null;
    }
    json[r'sort_letter'] = this.sortLetter;
    json[r'source'] = this.source_;
    return json;
  }

  /// Returns a new [ContactOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ContactOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'account_id'),
            'Required key "ContactOut[account_id]" is missing from JSON.');
        assert(json[r'account_id'] != null,
            'Required key "ContactOut[account_id]" has a null value in JSON.');
        assert(json.containsKey(r'address_book_id'),
            'Required key "ContactOut[address_book_id]" is missing from JSON.');
        assert(json[r'address_book_id'] != null,
            'Required key "ContactOut[address_book_id]" has a null value in JSON.');
        assert(json.containsKey(r'created_at'),
            'Required key "ContactOut[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null,
            'Required key "ContactOut[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'display_name'),
            'Required key "ContactOut[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null,
            'Required key "ContactOut[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'editable'),
            'Required key "ContactOut[editable]" is missing from JSON.');
        assert(json[r'editable'] != null,
            'Required key "ContactOut[editable]" has a null value in JSON.');
        assert(json.containsKey(r'etag'),
            'Required key "ContactOut[etag]" is missing from JSON.');
        assert(json[r'etag'] != null,
            'Required key "ContactOut[etag]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "ContactOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "ContactOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'modified_at'),
            'Required key "ContactOut[modified_at]" is missing from JSON.');
        assert(json[r'modified_at'] != null,
            'Required key "ContactOut[modified_at]" has a null value in JSON.');
        assert(json.containsKey(r'sort_letter'),
            'Required key "ContactOut[sort_letter]" is missing from JSON.');
        assert(json[r'sort_letter'] != null,
            'Required key "ContactOut[sort_letter]" has a null value in JSON.');
        assert(json.containsKey(r'source'),
            'Required key "ContactOut[source]" is missing from JSON.');
        assert(json[r'source'] != null,
            'Required key "ContactOut[source]" has a null value in JSON.');
        return true;
      }());

      return ContactOut(
        accountId: mapValueOfType<String>(json, r'account_id')!,
        addressBookId: mapValueOfType<String>(json, r'address_book_id')!,
        addresses: PostalAddress.listFromJson(json[r'addresses']),
        birthday: mapValueOfType<String>(json, r'birthday'),
        caption: mapValueOfType<String>(json, r'caption'),
        changedInSource: mapValueOfType<String>(json, r'changed_in_source'),
        createdAt: mapValueOfType<String>(json, r'created_at')!,
        deletedAt: mapValueOfType<String>(json, r'deleted_at'),
        displayName: mapValueOfType<String>(json, r'display_name')!,
        editable: mapValueOfType<bool>(json, r'editable')!,
        emails: LabeledValue.listFromJson(json[r'emails']),
        etag: mapValueOfType<String>(json, r'etag')!,
        familyName: mapValueOfType<String>(json, r'family_name') ?? '',
        fullName: mapValueOfType<String>(json, r'full_name') ?? '',
        givenName: mapValueOfType<String>(json, r'given_name') ?? '',
        hasPhoto: mapValueOfType<bool>(json, r'has_photo') ?? false,
        id: mapValueOfType<String>(json, r'id')!,
        mergedInto: mapValueOfType<String>(json, r'merged_into'),
        modifiedAt: mapValueOfType<String>(json, r'modified_at')!,
        nickname: mapValueOfType<String>(json, r'nickname') ?? '',
        note: mapValueOfType<String>(json, r'note') ?? '',
        notesIncluded: mapValueOfType<bool>(json, r'notes_included') ?? true,
        onPhone: mapValueOfType<bool>(json, r'on_phone'),
        organisation: mapValueOfType<String>(json, r'organisation') ?? '',
        phones: LabeledValue.listFromJson(json[r'phones']),
        purgeAfter: mapValueOfType<String>(json, r'purge_after'),
        sortLetter: mapValueOfType<String>(json, r'sort_letter')!,
        source_: ContactOutSource_Enum.fromJson(json[r'source'])!,
      );
    }
    return null;
  }

  static List<ContactOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ContactOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ContactOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ContactOut> mapFromJson(dynamic json) {
    final map = <String, ContactOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ContactOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ContactOut-objects as value to a dart map
  static Map<String, List<ContactOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ContactOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ContactOut.listFromJson(
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
    'editable',
    'etag',
    'id',
    'modified_at',
    'sort_letter',
    'source',
  };
}

/// where the contact comes from: mydata for a contact the host owns (made in an app; the only copy is on this host)
enum ContactOutSource_Enum {
  mac._(r'mac'),
  icloud._(r'icloud'),
  mydata._(r'mydata'),
  ;

  /// Instantiate a new enum with the provided value.
  const ContactOutSource_Enum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ContactOutSource_Enum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ContactOutSource_Enum? fromJson(dynamic value) =>
      ContactOutSource_EnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ContactOutSource_Enum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ContactOutSource_Enum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ContactOutSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ContactOutSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ContactOutSource_Enum] to String,
/// and [decode] dynamic data back to [ContactOutSource_Enum].
class ContactOutSource_EnumTypeTransformer {
  factory ContactOutSource_EnumTypeTransformer() =>
      _instance ??= const ContactOutSource_EnumTypeTransformer._();

  const ContactOutSource_EnumTypeTransformer._();

  String encode(ContactOutSource_Enum data) => data._value;

  /// Returns the instance of [ContactOutSource_Enum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ContactOutSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data is ContactOutSource_Enum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'mac':
          return ContactOutSource_Enum.mac;
        case r'icloud':
          return ContactOutSource_Enum.icloud;
        case r'mydata':
          return ContactOutSource_Enum.mydata;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ContactOutSource_EnumTypeTransformer? _instance;
}
