import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'contact_actions.dart';
import 'contact_page.dart';
import 'contacts_controller.dart';

/// One contact's page in the Mac frame, laid out as Contacts.app's card (plan section 5, "Person page"):
///
/// - [MacRecordHeader]: the 64pt avatar (ours: photo or initials on the kiwi wash), the name, the job title
///   and company, and the round actions message, call, mail and map (`sms:`, `tel:`, `mailto:`, a Maps link),
///   only those the contact has a number, email or address for (as Contacts.app: an action that cannot work
///   is not shown);
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

  /// The widest the page's content grows (Contacts' card keeps a reading width).
  static const maxWidth = MyDataMacSize.contentWidth;

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
          SizedBox(height: context.space(2)),
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
          SizedBox(height: context.space(4)),
        ],
        if (entry != null || d != null)
          MacRecordHeader(
            avatar: avatar,
            name: name,
            subtitle: subtitle,
            actions: d == null ? const [] : quickActions(d),
            badge: d == null ? null : MacSourceBadge(icon: sourceIcon(d), sentence: ContactPage.sourceLineOf(d)),
          ),
        if (d?.changedInSource != null) ...[
          SizedBox(height: context.space(5)),
          Notice(
            message: ContactPage.changedNotice(d!.changedInSourceLabel),
            actionLabel: actions?.onReview == null ? null : ContactPage.reviewLabel,
            onAction: actions?.onReview == null ? null : () => actions!.onReview!(d.id),
          ),
        ],
        if (below != null) ...[
          SizedBox(height: context.space(6)),
          below,
        ],
      ],
    );
  }

  /// The source badge's glyph: the host's own contact, this Mac's, or an iCloud account's.
  static MyDataIcon sourceIcon(ContactDetailOut d) => switch (d.source_) {
        ContactDetailOutSource_Enum.mydata => MyDataIcon.host,
        ContactDetailOutSource_Enum.mac => MyDataIcon.thisMac,
        _ => MyDataIcon.cloud,
      };

  /// message, call, mail and map for [d]: the first phone number, email address and address; none without.
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
      if (dial != null && dial.isNotEmpty) ...[
        MacQuickAction(
          icon: MyDataIcon.message,
          label: messageLabel,
          tooltip: 'Message $who',
          onPressed: () => onOpenLink(Uri(scheme: 'sms', path: dial)),
        ),
        MacQuickAction(
          icon: MyDataIcon.call,
          label: callLabel,
          tooltip: 'Call $who',
          onPressed: () => onOpenLink(Uri(scheme: 'tel', path: dial)),
        ),
      ],
      if (email != null)
        MacQuickAction(
          icon: MyDataIcon.mail,
          label: mailLabel,
          tooltip: 'Mail $who',
          onPressed: () => onOpenLink(Uri(scheme: 'mailto', path: email)),
        ),
      if (address != null)
        MacQuickAction(
          icon: MyDataIcon.map,
          label: mapLabel,
          tooltip: 'Show $who\'s address in Maps',
          onPressed: () => onOpenLink(Uri.https('maps.apple.com', '/', {'q': address.replaceAll('\n', ', ')})),
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
