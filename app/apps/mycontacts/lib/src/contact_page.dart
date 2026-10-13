import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'contacts_controller.dart';

/// Opens a web address from a contact's Links in the default browser, never inside the app.
typedef WebOpener = void Function(Uri url);

/// The default [WebOpener]: the system's `open` on macOS; nothing elsewhere.
void openInBrowser(Uri url) => macSystem.open(url.toString());

/// One contact's page: [ContactHeader], then the contact's fields grouped Phone, Email, Address, Birthday,
/// Links and Notes ([FieldGroups]), `space-6` below it. Read-only: the header says where to change the card.
///
/// Until the page is read from the host, the header shows what the list already knows (the name, the
/// organisation and the photo) and no fields. A contact the host no longer has, or a page that cannot be
/// read, is one plain line in place of the fields.
class ContactPage extends StatelessWidget {
  const ContactPage({super.key, required this.controller, required this.id, required this.onOpenLink});

  final ContactsController controller;
  final String id;
  final WebOpener onOpenLink;

  /// The fields' widest (preview: `.g{max-width:560px}`).
  static const fieldsMaxWidth = 560.0;

  static const missingText =
      'This contact is no longer on your host. It may have been deleted, or its source '
      'turned off in myData.';
  static const failedText = 'myContacts could not read this contact from your host.';
  static const retryLabel = 'Try again';

  @override
  Widget build(BuildContext context) {
    final detail = controller.detailOf(id);
    final entry = controller.entryFor(id);
    final c = context.colors;

    final Widget header;
    if (detail is DetailReady) {
      final d = detail.contact;
      header = ContactHeader(
        name: d.displayName,
        jobTitle: d.jobTitle,
        organisation: d.organisation,
        sourceLine: ContactHeader.sourceLineFor(d.sourceLabel, thisMac: d.source_ == ContactDetailOutSource_Enum.mac),
        avatar: Avatar(
          name: d.displayName,
          givenName: d.givenName,
          familyName: d.familyName,
          size: AvatarSize.large,
          photo: controller.photoFor(d),
        ),
      );
    } else if (entry != null) {
      header = ContactHeader(
        name: entry.name,
        organisation: entry.organisation,
        sourceLine: '',
        avatar: Avatar(
          name: entry.name,
          givenName: entry.givenName,
          familyName: entry.familyName,
          size: AvatarSize.large,
          photo: entry.photo,
        ),
      );
    } else {
      header = const SizedBox.shrink();
    }

    final Widget? below = switch (detail) {
      DetailReady(:final contact) => FieldGroups(fields: fieldRowsFor(contact, onOpenLink: onOpenLink)),
      DetailLoading() => null,
      DetailMissing() => Text(missingText, style: MyDataType.body.copyWith(color: c.inkMuted)),
      DetailFailed() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(failedText, style: MyDataType.body.copyWith(color: c.inkMuted)),
          const SizedBox(height: MyDataSpace.s3),
          Button(label: retryLabel, onPressed: () => controller.retryDetail(id)),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (below != null) ...[
          const SizedBox(height: ContactHeader.fieldsGap),
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: fieldsMaxWidth),
              child: below,
            ),
          ),
        ],
      ],
    );
  }
}

/// The [FieldRow]s of contact [c], from the host's groups (`fields`), in the host's order. A birthday is
/// written in the long form ("12 May 1990", "12 May"); one that is not a real date is left out.
List<FieldRow> fieldRowsFor(ContactDetailOut c, {required WebOpener onOpenLink}) => [
  for (final group in c.fields)
    if (_kinds[group.kind] case final kind?)
      for (final item in group.items)
        if (_valueOf(kind, item.value) case final value?)
          FieldRow(
            kind: kind,
            label: item.label.trim().isEmpty ? null : item.label,
            value: value,
            onOpenLink: kind == FieldKind.link ? onOpenLink : null,
          ),
];

String? _valueOf(FieldKind kind, String value) {
  if (kind == FieldKind.birthday) return formatBirthday(value);
  return value.trim().isEmpty ? null : value;
}

const _kinds = {
  ContactFieldGroupKindEnum.phone: FieldKind.phone,
  ContactFieldGroupKindEnum.email: FieldKind.email,
  ContactFieldGroupKindEnum.address: FieldKind.address,
  ContactFieldGroupKindEnum.birthday: FieldKind.birthday,
  ContactFieldGroupKindEnum.url: FieldKind.link,
  ContactFieldGroupKindEnum.note: FieldKind.note,
};
