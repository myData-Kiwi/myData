import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'contact_actions.dart';
import 'contact_page.dart';
import 'contacts_controller.dart';

/// One contact's page in the Mac frame, laid out as Contacts.app's card (plan section 5, "Person page"):
///
/// - [MacRecordHeader]: the 64pt avatar (ours: photo or initials on the kiwi wash), the name, the job title
///   and company, and the round actions Message, Call, Mail and Map (`sms:`, `tel:`, `mailto:`, a Maps link),
///   each disabled with its reason when the contact has no number, address or email;
/// - the values in two columns ([MacFieldTable]): the label right-aligned (built-in labels in lower case, as
///   Contacts writes them), the value beside it; clicking a value copies it, a web address opens;
/// - at the bottom, where the contact comes from in `caption` ("On myData only, not on your phone yet.").
///
/// Edit lives in the toolbar; Delete in the menu bar and the row's Menu. Until the page is read, the header
/// shows what the list knows; a contact the host no longer has is one plain line.
class MacContactPage extends StatelessWidget {
  const MacContactPage({
    super.key,
    required this.controller,
    required this.id,
    required this.onOpenLink,
    this.actions,
  });

  final ContactsController controller;
  final String id;

  /// Opens a web address, and the actions' `sms:`, `tel:`, `mailto:` and Maps links, outside the app.
  final WebOpener onOpenLink;
  final ContactActions? actions;

  static const messageLabel = 'message';
  static const callLabel = 'call';
  static const mailLabel = 'mail';
  static const mapLabel = 'map';
  static const noPhone = 'This contact has no phone number.';
  static const noEmail = 'This contact has no email address.';
  static const noAddress = 'This contact has no address.';

  /// The widest the page's content grows (Contacts' card keeps a reading width).
  static const maxWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final detail = controller.detailOf(id);
    final entry = controller.entryFor(id);
    final error = controller.paneErrorId == id ? controller.paneError : null;

    final ContactDetailOut? d = detail is DetailReady ? detail.contact : null;
    final name = d?.displayName ?? entry?.name ?? '';
    final avatar = Avatar(
      name: name,
      givenName: d?.givenName ?? entry?.givenName ?? '',
      familyName: d?.familyName ?? entry?.familyName ?? '',
      size: AvatarSize.mac,
      photo: d != null ? controller.photoFor(d) : entry?.photo,
    );
    final subtitle = d == null
        ? (entry?.organisation ?? '')
        : [d.jobTitle.trim(), d.organisation.trim()].where((s) => s.isNotEmpty).join(' · ');

    final Widget? below = switch (detail) {
      DetailReady(:final contact) => MacFieldTable(groups: fieldsFor(contact, onOpenLink: onOpenLink)),
      DetailLoading() => null,
      DetailMissing() => Text(ContactPage.missingText, style: MyDataMacType.body.copyWith(color: mac.secondaryLabel)),
      DetailFailed() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ContactPage.failedText, style: MyDataMacType.body.copyWith(color: mac.secondaryLabel)),
          const SizedBox(height: MyDataSpace.s2),
          MacToolbarButton.text(
            text: ContactPage.retryLabel,
            label: ContactPage.retryLabel,
            onPressed: () => controller.retryDetail(id),
          ),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Semantics(liveRegion: true, child: Text(error, style: MyDataMacType.body.copyWith(color: context.colors.danger))),
          const SizedBox(height: MyDataSpace.s4),
        ],
        if (entry != null || d != null)
          MacRecordHeader(
            avatar: avatar,
            name: name,
            subtitle: subtitle,
            actions: d == null ? const [] : quickActions(d),
          ),
        if (d?.changedInSource != null) ...[
          const SizedBox(height: MyDataSpace.s5),
          Notice(
            message: ContactPage.changedNotice(d!.changedInSourceLabel),
            actionLabel: actions?.onReview == null ? null : ContactPage.reviewLabel,
            onAction: actions?.onReview == null ? null : () => actions!.onReview!(d.id),
          ),
        ],
        if (below != null) ...[
          const SizedBox(height: MyDataSpace.s6),
          below,
        ],
        if (d != null) ...[
          const SizedBox(height: MyDataSpace.s6),
          Text(ContactPage.sourceLineOf(d), style: MyDataMacType.caption.copyWith(color: mac.secondaryLabel)),
        ],
      ],
    );
  }

  /// Message, Call, Mail and Map for [d]: the first phone number, email address and address.
  List<Widget> quickActions(ContactDetailOut d) {
    final phone = d.phones.where((p) => p.value.trim().isNotEmpty).firstOrNull?.value.trim();
    final email = d.emails.where((e) => e.value.trim().isNotEmpty).firstOrNull?.value.trim();
    final address = [
      for (final g in d.fields)
        if (g.kind == ContactFieldGroupKindEnum.address)
          for (final i in g.items)
            if (i.value.trim().isNotEmpty) i.value.trim(),
    ].firstOrNull;
    final who = d.displayName;
    final dial = phone?.replaceAll(RegExp(r'[^0-9+*#,;]'), '');
    return [
      MacQuickAction(
        icon: MacIcons.message,
        label: messageLabel,
        tooltip: 'Message $who',
        disabledReason: noPhone,
        onPressed: dial == null || dial.isEmpty ? null : () => onOpenLink(Uri(scheme: 'sms', path: dial)),
      ),
      MacQuickAction(
        icon: MacIcons.call,
        label: callLabel,
        tooltip: 'Call $who',
        disabledReason: noPhone,
        onPressed: dial == null || dial.isEmpty ? null : () => onOpenLink(Uri(scheme: 'tel', path: dial)),
      ),
      MacQuickAction(
        icon: MacIcons.mail,
        label: mailLabel,
        tooltip: 'Mail $who',
        disabledReason: noEmail,
        onPressed: email == null ? null : () => onOpenLink(Uri(scheme: 'mailto', path: email)),
      ),
      MacQuickAction(
        icon: MacIcons.map,
        label: mapLabel,
        tooltip: 'Show $who\'s address in Maps',
        disabledReason: noAddress,
        onPressed: address == null
            ? null
            : () => onOpenLink(Uri.https('maps.apple.com', '/', {'q': address.replaceAll('\n', ', ')})),
      ),
    ];
  }
}

/// The page's values for [c], one group per kind in the host's order: phones, emails, addresses, birthday,
/// links and the note. A birthday that is not a real date, and empty values, are left out.
List<List<MacField>> fieldsFor(ContactDetailOut c, {required WebOpener onOpenLink}) => [
  for (final group in c.fields)
    if (_kinds[group.kind] case final kind?)
      [
        for (final item in group.items)
          if (_valueOf(kind, item.value) case final value?)
            _field(kind, item.label.trim(), value, onOpenLink),
      ],
];

MacField _field(FieldKind kind, String label, String value, WebOpener onOpenLink) {
  final shown = label.isEmpty ? _bareLabels[kind]! : (FieldRow.builtInLabels.contains(label) ? label.toLowerCase() : label);
  final link = kind == FieldKind.link ? safeWebLink(value) : null;
  return MacField(
    label: shown,
    value: value,
    copyName: FieldRow.copyNameFor(kind, label.isEmpty ? null : label),
    onOpen: link == null ? null : () => onOpenLink(link),
    openName: link == null ? null : 'Open $shown',
  );
}

String? _valueOf(FieldKind kind, String value) {
  if (kind == FieldKind.birthday) return formatBirthday(value);
  return value.trim().isEmpty ? null : value;
}

const _bareLabels = {
  FieldKind.phone: 'phone',
  FieldKind.email: 'email',
  FieldKind.address: 'address',
  FieldKind.birthday: 'birthday',
  FieldKind.link: 'homepage',
  FieldKind.note: 'note',
};

const _kinds = {
  ContactFieldGroupKindEnum.phone: FieldKind.phone,
  ContactFieldGroupKindEnum.email: FieldKind.email,
  ContactFieldGroupKindEnum.address: FieldKind.address,
  ContactFieldGroupKindEnum.birthday: FieldKind.birthday,
  ContactFieldGroupKindEnum.url: FieldKind.link,
  ContactFieldGroupKindEnum.note: FieldKind.note,
};
