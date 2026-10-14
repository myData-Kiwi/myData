import 'package:flutter/painting.dart' show ImageProvider;
import 'package:mydata_client/api.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// A contact's values as a [DuplicatePair] column (design/components/DuplicatePair): the host's contact
/// ([ContactDetailOut]), a card in an import preview ([ImportCardOut], H3) or the contact a merge would make
/// ([CardValuesOut], H6c). Shared by myData's import (Compare) and myContacts (Merge, Changes).
abstract final class ContactPair {
  /// [c] as a column titled [name] (its own name unless given) with [caption].
  static PairVersion ofContact(ContactDetailOut c, {String? name, required String caption, ImageProvider? photo}) =>
      PairVersion(
        name: name ?? c.displayName,
        personName: c.displayName,
        caption: caption,
        givenName: c.givenName,
        familyName: c.familyName,
        photo: photo,
        fields: _fields(
          displayName: c.displayName,
          fullName: c.fullName,
          organisation: c.organisation,
          jobTitle: c.jobTitle,
          phones: c.phones,
          emails: c.emails,
          addresses: c.addresses,
          birthday: c.birthday,
          urls: c.urls,
          note: c.note,
          hasPhoto: c.hasPhoto,
        ),
      );

  /// A card of an import preview as a column titled [name] ("In the file").
  static PairVersion ofCard(ImportCardOut c, {required String name, required String caption}) => PairVersion(
        name: name,
        personName: c.displayName,
        caption: caption,
        givenName: c.givenName,
        familyName: c.familyName,
        fields: _fields(
          displayName: c.displayName,
          fullName: c.fullName,
          organisation: c.organisation,
          jobTitle: c.jobTitle,
          phones: c.phones,
          emails: c.emails,
          addresses: c.addresses,
          birthday: c.birthday,
          urls: c.urls,
          note: c.note,
          hasPhoto: c.hasPhoto,
        ),
      );

  /// The values of [c] by kind, as an after column holds them.
  static Map<PairField, List<PairValue>> fieldsOfValues(CardValuesOut c) => _fields(
        displayName: c.displayName,
        fullName: c.fullName,
        organisation: c.organisation,
        jobTitle: c.jobTitle,
        phones: c.phones,
        emails: c.emails,
        addresses: c.addresses,
        birthday: c.birthday,
        urls: c.urls,
        note: c.note,
        hasPhoto: c.hasPhoto,
      );

  /// The after column of a merge, from the host's preview [p]: its values, and each value it leaves out
  /// under its kind ("Left out: 18 March 1990"). [notes] counts the contacts with a note, so a merge of two
  /// with notes says "Both notes, one after the other." in the Notes row.
  static PairAfter afterOfMerge(MergePreviewOut p, {required String caption, int notes = 0}) {
    final fields = fieldsOfValues(p.contact);
    if (notes > 1 && (fields[PairField.notes]?.isNotEmpty ?? false)) {
      fields[PairField.notes] = [PairValue(notes == 2 ? bothNotes : 'All $notes notes, one after the other.')];
    }
    final leftOut = <PairField, List<String>>{};
    for (final l in p.leftOut) {
      final field = _leftOutField(l.kind);
      if (field == null) continue;
      final value = l.value;
      final shown = field == PairField.photo
          ? 'another photo'
          : field == PairField.birthday && value != null
              ? (formatBirthday(value) ?? value)
              : (value ?? '');
      if (shown.isEmpty) continue;
      (leftOut[field] ??= []).add(shown);
    }
    return PairAfter(title: PairAfter.mergingTitle, caption: caption, fields: fields, leftOut: leftOut);
  }

  static const bothNotes = 'Both notes, one after the other.';
  static const photoValue = 'A photo';

  /// What the host names a left-out value's kind as, in the row it belongs to; "other" has no row.
  static PairField? _leftOutField(String kind) => switch (kind) {
        'birthday' => PairField.birthday,
        'job_title' => PairField.jobTitle,
        'photo' => PairField.photo,
        'company' => PairField.company,
        'nickname' => PairField.name,
        _ => null,
      };

  /// The host's names for what a merge left out (`left_out`, property names), in words: "1 birthday and 1
  /// job title" (design/components/DuplicatePair, "Copy").
  static String leftOutWords(List<MergeLeftOutOut> leftOut) {
    final words = <String>[];
    for (final l in leftOut) {
      final noun = switch (l.property.toUpperCase()) {
        'BDAY' => ('birthday', 'birthdays'),
        'TITLE' => ('job title', 'job titles'),
        'PHOTO' => ('photo', 'photos'),
        'ORG' => ('company', 'companies'),
        'NICKNAME' => ('nickname', 'nicknames'),
        _ => ('other detail', 'other details'),
      };
      words.add('${l.count} ${l.count == 1 ? noun.$1 : noun.$2}');
    }
    if (words.isEmpty) return '';
    if (words.length == 1) return words.single;
    return '${words.sublist(0, words.length - 1).join(', ')} and ${words.last}';
  }

  static Map<PairField, List<PairValue>> _fields({
    required String displayName,
    required String fullName,
    required String organisation,
    required String jobTitle,
    required List<LabeledValue> phones,
    required List<LabeledValue> emails,
    required List<PostalAddress> addresses,
    required String? birthday,
    required List<LabeledValue> urls,
    required String note,
    required bool hasPhoto,
  }) {
    List<PairValue> labelled(List<LabeledValue> l) => [
          for (final v in l)
            if (v.value.trim().isNotEmpty) PairValue(v.value.trim(), label: v.label.trim().toLowerCase()),
        ];
    final name = fullName.trim().isNotEmpty ? fullName.trim() : displayName;
    final born = birthday == null ? null : (formatBirthday(birthday) ?? birthday);
    return {
      PairField.name: [PairValue(name)],
      if (organisation.trim().isNotEmpty) PairField.company: [PairValue(organisation.trim())],
      if (jobTitle.trim().isNotEmpty) PairField.jobTitle: [PairValue(jobTitle.trim())],
      PairField.phone: labelled(phones),
      PairField.email: labelled(emails),
      PairField.address: [
        for (final a in addresses)
          if (_addressLine(a).isNotEmpty) PairValue(_addressLine(a), label: a.label.trim().toLowerCase()),
      ],
      if (born != null && born.isNotEmpty) PairField.birthday: [PairValue(born)],
      PairField.links: labelled(urls),
      if (note.trim().isNotEmpty) PairField.notes: [PairValue(note.trim())],
      if (hasPhoto) PairField.photo: const [PairValue(photoValue)],
    };
  }

  static String _addressLine(PostalAddress a) => [a.street, a.locality, a.region, a.postalCode, a.country]
      .map((p) => p.trim().replaceAll('\n', ', '))
      .where((p) => p.isNotEmpty)
      .join(', ');
}
