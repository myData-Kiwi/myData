import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'contact_actions.dart';
import 'contacts_controller.dart';

/// Opens a web address from a contact's Links in the default browser, never inside the app.
typedef WebOpener = void Function(Uri url);

/// The default [WebOpener]: the system's `open` on macOS; nothing elsewhere.
void openInBrowser(Uri url) => macSystem.open(url.toString());

/// One contact's page: [ContactHeader], then the contact's fields grouped Phone, Email, Address, Birthday,
/// Links and Notes ([FieldGroups]), `space-6` below it.
///
/// - **A contact the host owns** (made in myContacts): its source line is "On myData only, not on your phone
///   yet.", and Edit (Tonal) and "More actions" sit beside the header from 600px ([showActions]; a phone's
///   pushed page has them in its top row).
/// - **A followed contact** (This Mac, an iCloud account) is read-only: no Edit or Delete, and the source
///   line says where to change it.
///
/// Until the page is read from the host, the header shows what the list already knows (the name, the
/// organisation and the photo) and no fields. A contact the host no longer has, or a page that cannot be
/// read, is one plain line in place of the fields.
class ContactPage extends StatelessWidget {
  const ContactPage({
    super.key,
    required this.controller,
    required this.id,
    required this.onOpenLink,
    this.actions,
    this.showActions = true,
  });

  final ContactsController controller;
  final String id;
  final WebOpener onOpenLink;

  /// Edit and Delete; null shows the page read-only.
  final ContactActions? actions;

  /// Edit and "More actions" beside the header (from 600px); false where the screen shows them elsewhere.
  final bool showActions;

  /// The source line of a contact the host owns.
  static const ownedLine = 'On myData only, not on your phone yet.';

  /// The source line for [d]: where it comes from, and where to change it unless it is the host's own.
  static String sourceLineOf(ContactDetailOut d) => d.source_ == ContactDetailOutSource_Enum.mydata
      ? ownedLine
      : ContactHeader.sourceLineFor(d.sourceLabel, thisMac: d.source_ == ContactDetailOutSource_Enum.mac);

  /// The fields' widest (preview: `.g{max-width:560px}`).
  static const fieldsMaxWidth = 560.0;

  static const missingText =
      'This contact is no longer on your host. It may have been deleted, or its source '
      'turned off in myData.';
  static const failedText = 'myContacts could not read this contact from your host.';
  static const reviewLabel = 'Review';

  /// The Notice on a contact whose followed copy changed since the import (H7).
  static String changedNotice(String? label) =>
      'This contact changed in ${label ?? 'a source myData follows'} after you imported it.';
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
        sourceLine: sourceLineOf(d),
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
      DetailMissing() => Text(missingText, style: context.typeScale.body.copyWith(color: c.inkMuted)),
      DetailFailed() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(failedText, style: context.typeScale.body.copyWith(color: c.inkMuted)),
          SizedBox(height: context.space(3)),
          Button(label: retryLabel, onPressed: () => controller.retryDetail(id)),
        ],
      ),
    };

    final actions = this.actions;
    final editable = detail is DetailReady && detail.contact.editable;
    final error = controller.paneErrorId == id ? controller.paneError : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(error, style: context.typeScale.body.copyWith(color: c.danger)),
          ),
          SizedBox(height: context.space(4)),
        ],
        if (actions != null && editable && showActions)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: header),
              SizedBox(width: context.space(4)),
              ContactPageActions(actions: actions, contact: detail.contact),
            ],
          )
        else
          header,
        if (detail is DetailReady && detail.contact.changedInSource != null) ...[
          SizedBox(height: ContactHeader.fieldsGap(context.look)),
          // Between the header and the fields (design/components/DuplicatePair, "The contact page flag").
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: fieldsMaxWidth),
              child: Notice(
                message: changedNotice(detail.contact.changedInSourceLabel),
                actionLabel: actions?.onReview == null ? null : reviewLabel,
                onAction: actions?.onReview == null ? null : () => actions!.onReview!(detail.contact.id),
              ),
            ),
          ),
        ],
        if (below != null) ...[
          SizedBox(height: ContactHeader.fieldsGap(context.look)),
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

/// Edit (Tonal) and "More actions" for a contact the host owns, `space-2` apart: beside the header from
/// 600px, at the end of a phone page's top row.
class ContactPageActions extends StatelessWidget {
  const ContactPageActions({super.key, required this.actions, required this.contact});

  final ContactActions actions;
  final ContactDetailOut contact;

  static const moreLabel = 'More actions';

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Button(label: ContactActions.editButton, onPressed: () => actions.edit(contact.id)),
          SizedBox(width: context.space(2)),
          MoreActionsButton(entries: () => actions.menuFor(contact.id)),
        ],
      );
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
