import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

// Invented values only.
CardValuesOut _values({String note = '', String? birthday = '1990-03-18'}) => CardValuesOut(
      displayName: 'Ava Fictional',
      fullName: 'Ava Fictional',
      kind: 'individual',
      organisation: 'Example Labs, Research',
      jobTitle: 'Head of research',
      phones: [LabeledValue(label: 'Mobile', value: '555-0142')],
      emails: [LabeledValue(label: 'Work', value: 'ava@example.org')],
      addresses: [
        PostalAddress(label: 'Home', street: '1 Example Street', locality: 'Sampleton', postalCode: 'ZZ1 1AA'),
      ],
      birthday: birthday,
      urls: [LabeledValue(label: '', value: 'example.org/ava')],
      note: note,
      fields: [],
    );

void main() {
  test('a contact\'s values by kind, labels in lower case, the birthday written out', () {
    final f = ContactPair.fieldsOfValues(_values());
    expect(f[PairField.name]!.single.value, 'Ava Fictional');
    expect(f[PairField.company]!.single.value, 'Example Labs, Research');
    expect(f[PairField.phone]!.single.spoken, 'mobile 555-0142');
    expect(f[PairField.address]!.single.value, '1 Example Street, Sampleton, ZZ1 1AA');
    expect(f[PairField.birthday]!.single.value, formatBirthday('1990-03-18'));
    expect(f[PairField.links]!.single.spoken, 'example.org/ava');
    expect(f.containsKey(PairField.notes), isFalse);
    expect(f.containsKey(PairField.photo), isFalse);
  });

  test('the merge preview: what is kept and what is left out, by row', () {
    final after = ContactPair.afterOfMerge(
      MergePreviewOut(
        contact: _values(note: 'One.\n\nTwo.'),
        namesFrom: 'c-1',
        newest: 'c-1',
        leftOut: [
          MergeLeftOutValueOut(contactId: 'c-2', kind: 'birthday', property: 'BDAY', value: '--03-18'),
          MergeLeftOutValueOut(contactId: 'c-2', kind: 'job_title', property: 'TITLE', value: 'Researcher'),
          MergeLeftOutValueOut(contactId: 'c-2', kind: 'photo', property: 'PHOTO'),
          MergeLeftOutValueOut(contactId: 'c-2', kind: 'other', property: 'X-ABSHOWAS', value: 'COMPANY'),
        ],
      ),
      caption: 'A new contact.',
      notes: 2,
    );
    expect(after.title, PairAfter.mergingTitle);
    expect(after.leftOut[PairField.birthday], [formatBirthday('--03-18')]);
    expect(after.leftOut[PairField.jobTitle], ['Researcher']);
    expect(after.leftOut[PairField.photo], ['another photo']);
    expect(after.leftOut.length, 3);
    expect(after.valuesOf(PairField.notes).single.value, ContactPair.bothNotes);
  });

  test('what a merge left out, in words', () {
    expect(ContactPair.leftOutWords([MergeLeftOutOut(property: 'BDAY', count: 1)]), '1 birthday');
    expect(
      ContactPair.leftOutWords([
        MergeLeftOutOut(property: 'BDAY', count: 1),
        MergeLeftOutOut(property: 'TITLE', count: 1),
      ]),
      '1 birthday and 1 job title',
    );
    expect(
      ContactPair.leftOutWords([
        MergeLeftOutOut(property: 'PHOTO', count: 2),
        MergeLeftOutOut(property: 'X-ABSHOWAS', count: 1),
        MergeLeftOutOut(property: 'ORG', count: 1),
      ]),
      '2 photos, 1 other detail and 1 company',
    );
  });
}
