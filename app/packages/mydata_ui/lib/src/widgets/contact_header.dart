import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_frame.dart' show AppLayout;
import 'avatar.dart';

/// The top of a contact's page: the avatar, the name, what the person does, and where the card comes from
/// (design/components/ContactHeader).
///
/// - No card: it sits on `bg` at the top of the contact pane. Put the contact's fields (FieldGroups)
///   [fieldsGap] (`space-6`) below it.
/// - **From 600px** (the window is not a phone, [AppLayout]): the 96px [avatar] with the text beside it,
///   [sideGap] (`space-5`) away and centred on it. **Under 600px:** the avatar above the text, [stackGap]
///   (`space-4`) apart, and everything centred. The header is also stacked in a wider window when it is
///   itself narrower than [sideMinWidth], as in a narrow contact pane beside the list pane: beside the
///   avatar, the name would get too little room and break in the middle of its words.
/// - The [name], as the host gives it to show, in `display-lg` and `ink`. It is the screen's title (a
///   heading for screen readers), so no other title sits above it. A long name wraps and is never cut short;
///   a word longer than the line breaks anywhere.
/// - Under it, in `body` and `ink-muted`, the [roleLine]: the job title and the organisation joined by a
///   comma ("Head of research, Example Labs"), the organisation alone without a job title, the job title
///   alone without an organisation. Left out when the card has neither, or when the name shown already is the
///   organisation.
/// - A `caption` line in `ink-muted`, [captionGap] (`space-1`) lower: [sourceLine], where the card comes from
///   and where to change it, because the apps only read contacts. Build it with [sourceLineFor].
/// - All the text can be selected with the pointer, across its lines. It is not a Tab stop: there are no
///   buttons and nothing to focus.
class ContactHeader extends StatefulWidget {
  ContactHeader({
    super.key,
    required this.name,
    this.jobTitle = '',
    this.organisation = '',
    required this.sourceLine,
    required this.avatar,
  }) : assert(avatar.size == AvatarSize.large, 'the header shows the 96px avatar (AvatarSize.large)');

  /// The name to show, as the host gives it (`display_name`): never empty.
  final String name;

  /// The card's job title, or empty.
  final String jobTitle;

  /// The card's organisation, or empty.
  final String organisation;

  /// Where the card comes from and where to change it ([sourceLineFor]). Empty: no line.
  final String sourceLine;

  /// The contact's [Avatar] at [AvatarSize.large], decorative (its default): the name beside it says who it is.
  final Avatar avatar;

  /// Between the avatar and the text from 600px (preview: `.ch{gap:20px}`).
  static double sideGap(MyDataLook look) => look.space(5);

  /// The least room the text needs beside the avatar, at the normal text size: about ten letters of the name
  /// in `display-lg`, so a name breaks between its words, not inside them. It grows with the system text size.
  static const sideTextMin = 240.0;

  /// The narrowest header that puts the text beside the avatar: the avatar, [sideGap] and [sideTextMin]
  /// (scaled by [textScaler]). A narrower header is stacked, whatever the window's width.
  static double sideMinWidth(MyDataLook look, TextScaler textScaler) =>
      AvatarSize.large.diameter(look) + sideGap(look) + textScaler.scale(sideTextMin);

  /// Between the avatar and the text under 600px (preview: `.ch.ph{gap:16px}`).
  static double stackGap(MyDataLook look) => look.space(4);

  /// Above the source line (preview: `.ch .cap{margin:4px 0 0}`).
  static double captionGap(MyDataLook look) => look.space(1);

  /// Between the header and the contact's fields below it. The page that holds both puts it there.
  static double fieldsGap(MyDataLook look) => look.space(6);

  /// The line under the name: "Job title, Organisation", either one alone, or null for no line. Null also
  /// when [name] is the organisation (ignoring case and spaces at the ends), because the line would repeat
  /// the title. Spaces at the ends of each part are dropped.
  static String? roleLine({required String name, String jobTitle = '', String organisation = ''}) {
    final job = jobTitle.trim();
    final org = organisation.trim();
    if (org.isNotEmpty && org.toLowerCase() == name.trim().toLowerCase()) return null;
    if (job.isEmpty && org.isEmpty) return null;
    if (job.isEmpty) return org;
    if (org.isEmpty) return job;
    return '$job, $org';
  }

  /// The source line for a card from [source], the source as the host names it inside a sentence
  /// (`source_label`: "this Mac", "the iCloud account you@example.com"):
  ///
  /// - [thisMac]: "From this Mac. Change it in Contacts."
  /// - otherwise, a followed iCloud account: "From the iCloud account you@example.com. Change it in your
  ///   iCloud account."
  static String sourceLineFor(String source, {required bool thisMac}) =>
      'From ${source.trim()}. ${thisMac ? 'Change it in Contacts.' : 'Change it in your iCloud account.'}';

  @override
  State<ContactHeader> createState() => _ContactHeaderState();
}

class _ContactHeaderState extends State<ContactHeader> {
  // The selection takes focus when the pointer selects, but is never reached by Tab: there is nothing to do.
  final _selectionFocus = FocusNode(debugLabel: 'ContactHeader selection', skipTraversal: true);

  @override
  void dispose() {
    _selectionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A phone window always stacks; a wider one stacks too when the pane gives the header too little room.
    final phone = AppLayout.of(context) == AppLayout.phone;
    final minSide = ContactHeader.sideMinWidth(context.look, MediaQuery.textScalerOf(context));
    return LayoutBuilder(
      builder: (context, constraints) => _build(context, stacked: phone || constraints.maxWidth < minSide),
    );
  }

  Widget _build(BuildContext context, {required bool stacked}) {
    final c = context.colors;
    final align = stacked ? TextAlign.center : TextAlign.start;
    final role = ContactHeader.roleLine(
      name: widget.name,
      jobTitle: widget.jobTitle,
      organisation: widget.organisation,
    );
    final source = widget.sourceLine.trim();

    final text = SelectionArea(
      focusNode: _selectionFocus,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: stacked ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(widget.name, textAlign: align, style: context.typeScale.displayLg.copyWith(color: c.ink)),
          ),
          if (role != null)
            Text(role,
                textAlign: align,
                style: context.typeScale.secondary(context.typeScale.body).copyWith(color: c.inkMuted)),
          if (source.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: ContactHeader.captionGap(context.look)),
              child: Text(source, textAlign: align, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
            ),
        ],
      ),
    );

    if (stacked) {
      // As wide as the pane, so the centred avatar and text sit in its middle.
      return Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [widget.avatar, SizedBox(height: ContactHeader.stackGap(context.look)), text],
        ),
      );
    }
    return Row(
      children: [
        widget.avatar,
        SizedBox(width: ContactHeader.sideGap(context.look)),
        Expanded(child: text),
      ],
    );
  }
}
