import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'mac_chat.dart';

/// What opens a result's items in their own apps: the apps installed on this Mac (looked up once per session
/// and when myAssistant comes back to the front, [InstalledApps]) and how to open a link.
class ResultLinks {
  const ResultLinks({required this.installed, required this.onOpen});

  /// The apps a row may open. A row whose app is missing is not interactive.
  final Set<MyDataAppId> installed;

  /// Opens the link in its app (`mycontacts://contact/<id>`, `mycalendar://day/<date>`).
  final ValueChanged<MyDataLink> onOpen;
}

/// A tool's result as the host sent it: shown the moment the tool returns, before (or instead of) any
/// sentence from the model. The header is written by the host's code.
///
/// The header line sits on the ground in `body-strong`; the items follow as a [GroupedList], each on an
/// [IconTile] that names its kind. Same kind, same tone, and at most three tones in a conversation:
/// calendar `accent`, mail `info`, contacts and photos untinted ([toneFor]). A created event is one row
/// carrying the header. Never a card in a card: the list is the only raised surface.
///
/// **Opening an item.** In real mode ([realMode]), a contact row opens that contact in myContacts and an event
/// row opens its day in myCalendar, when that app is installed ([links]). Such a row is one target, like a
/// [GroupedRow] that opens something: the `surface-hover` hover fill, a chevron at its end, the focus ring,
/// Enter and Space. Otherwise (demo data, the app not installed, an item without an id or a day, mail and
/// photos) the row is not interactive.
///
/// **The Mac frame** ([MacLook]): the header in `body-emphasized`, then the rows in one rounded box with a
/// hairline outline and hairlines between rows (as Mail and System Settings group things), each with its
/// kind's Lucide icon ([macIconFor]; events in the accent, the rest in `secondary-label`) instead of a
/// branded tile. A row that opens its item takes the `hover` fill under the pointer, the system's focus ring
/// and a chevron.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.kind,
    required this.header,
    required this.items,
    this.realMode = false,
    this.links,
  });

  /// events, mail, contacts, photos or event_created.
  final String kind;
  final String header;
  final List<Map<String, Object?>> items;

  /// The items are the user's own data. Sample items (demo mode) never open anything: their ids and days
  /// are not the user's.
  final bool realMode;

  /// The installed apps and how to open them; null opens nothing.
  final ResultLinks? links;

  /// What the screen reader says a row that opens an item does ("Opens in myContacts").
  static String openHint(MyDataAppId app) => 'Opens in ${app.displayName}';

  /// The link that opens [item] of a result of [kind] in its own app: a contact by its id, an event by its
  /// day. Null for other kinds, and for an item without a valid id or day.
  static MyDataLink? linkFor(String kind, Map<String, Object?> item) {
    switch (kind) {
      case 'contacts':
        final id = item['id'];
        return id is String && OpenContact.isValidId(id) ? OpenContact(id) : null;
      case 'events':
        final day = item['date'];
        final date = day is String ? OpenDay.parseDate(day) : null;
        return date == null ? null : OpenDay(date);
    }
    return null;
  }

  /// The link [item]'s row opens here, or null when it is not interactive.
  MyDataLink? _openable(Map<String, Object?> item) {
    final l = links;
    if (!realMode || l == null) return null;
    final link = linkFor(kind, item);
    return link != null && l.installed.contains(link.app) ? link : null;
  }

  /// Between the header line and the list.
  static const headerGap = MyDataSpace.s2;

  /// The icon on each row's tile for [kind].
  static IconData iconFor(String kind) => switch (kind) {
    'events' => Icons.event_outlined,
    'event_created' => Icons.event_available_outlined,
    'mail' => Icons.mail_outline_rounded,
    'contacts' => Icons.person_outline_rounded,
    'photos' => Icons.photo_outlined,
    _ => Icons.list_alt_rounded,
  };

  /// The tile tone for [kind]. Three tones at most across every kind, so a conversation that shows them
  /// all stays within the limit (design/README.md "Colour").
  static MyDataTone toneFor(String kind) => switch (kind) {
    'events' || 'event_created' => MyDataTone.accent,
    'mail' => MyDataTone.info,
    _ => MyDataTone.neutral,
  };

  /// The Mac frame's icon for [kind]'s rows (Lucide, [MacIcons]).
  static IconData macIconFor(String kind) => switch (kind) {
    'events' => MacIcons.calendar,
    'event_created' => MacIcons.calendarCheck,
    'mail' => MacIcons.mail,
    'contacts' => MacIcons.person,
    'photos' => MacIcons.photo,
    _ => MacIcons.list,
  };

  Widget _mac(BuildContext context) {
    final mac = context.mac;
    Widget box(List<_ResultRow> rows) => MacChat.box(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0)
              Padding(
                // Under the text, not the icon, as the system's grouped lists draw it.
                padding: const EdgeInsetsDirectional.only(start: _MacRow.textStart),
                child: Container(height: MyDataMacSize.hairline, color: mac.separator),
              ),
            _MacRow(row: row),
          ],
        ],
      ),
    );
    if (kind == 'event_created') {
      return box([_ResultRow(icon: iconFor(kind), tone: toneFor(kind), kind: kind, lines: [_Line.strong(header)])]);
    }
    final headerLine = Semantics(
      header: true,
      child: Text(header, style: MyDataMacType.bodyEmphasized.copyWith(color: mac.label)),
    );
    if (items.isEmpty) return headerLine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        headerLine,
        const SizedBox(height: headerGap),
        box([for (final item in items) _row(item)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MacLook.of(context)) return _mac(context);
    final c = context.colors;
    if (kind == 'event_created') {
      // The header says what was added; the list's one row carries it.
      return GroupedList(
        rows: [
          _ResultRow(icon: iconFor(kind), tone: toneFor(kind), kind: kind, lines: [_Line.strong(header)]),
        ],
      );
    }
    final headerLine = Semantics(
      header: true,
      child: Text(header, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
    );
    if (items.isEmpty) return headerLine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        headerLine,
        const SizedBox(height: headerGap),
        GroupedList(rows: [for (final item in items) _row(item)]),
      ],
    );
  }

  /// An item's day, written here as every app writes dates (MyDataDates: "Thu 19 Mar 2026") from its ISO
  /// [field] ("date", "taken"); the host's own words ("day") only when that cannot be read.
  static String dayOf(Map<String, Object?> item, {String field = 'date'}) {
    final iso = item[field];
    final d = iso is String && iso.length >= 10 ? DateTime.tryParse(iso.substring(0, 10)) : null;
    if (d != null) return MyDataDates.day(d, weekday: true);
    return item['day'] is String ? item['day'] as String : '';
  }

  /// A time the host gives as "HH:MM", on this device's clock ("7:30 am", or "07:30"); anything else as it is.
  static String timeOf(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
    if (m == null) return hhmm;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return hhmm;
    return MyDataDates.time(DateTime(2000, 1, 1, h, min));
  }

  _ResultRow _row(Map<String, Object?> item) {
    String s(String k) => item[k] is String ? item[k] as String : '';
    String join(Iterable<String> parts, String by) => parts.where((p) => p.isNotEmpty).join(by);
    final icon = iconFor(kind);
    final tone = toneFor(kind);
    final link = _openable(item);
    final opens = link?.app;
    final VoidCallback? onOpen = link == null ? null : () => links!.onOpen(link);
    return switch (kind) {
      'events' => _ResultRow(
        kind: kind,
        icon: icon,
        tone: tone,
        opens: opens,
        onOpen: onOpen,
        lines: [
          _Line.strong(s('title')),
          _Line.caption(
            join([
              join([
                dayOf(item),
                join([timeOf(s('start')), timeOf(s('end'))], ' to '),
              ], ', '),
              s('location'),
            ], ' · '),
          ),
        ],
      ),
      'mail' => _ResultRow(
        kind: kind,
        icon: icon,
        tone: tone,
        end: dayOf(item),
        lines: [_Line.strong(s('from')), _Line.body(s('subject')), _Line.caption(s('snippet'), maxLines: 2)],
      ),
      'contacts' => _ResultRow(
        kind: kind,
        icon: icon,
        tone: tone,
        opens: opens,
        onOpen: onOpen,
        lines: [_Line.strong(s('name')), _Line.mono(s('email')), _Line.mono(s('phone'))],
      ),
      'photos' => _ResultRow(
        kind: kind,
        icon: icon,
        tone: tone,
        lines: [
          _Line.strong(s('place')),
          _Line.caption(
            join([dayOf(item, field: 'taken'), (item['people'] is List ? item['people'] as List : const []).join(', ')], ' · '),
          ),
        ],
      ),
      _ => _ResultRow(kind: kind, icon: icon, tone: tone, lines: [_Line.caption(item.toString())]),
    };
  }
}

enum _LineStyle { strong, body, caption, mono }

/// One line of a result row; empty lines are left out.
class _Line {
  const _Line.strong(this.text) : style = _LineStyle.strong, maxLines = null;
  const _Line.body(this.text) : style = _LineStyle.body, maxLines = null;
  const _Line.caption(this.text, {this.maxLines}) : style = _LineStyle.caption;
  const _Line.mono(this.text) : style = _LineStyle.mono, maxLines = null;

  final String text;
  final _LineStyle style;
  final int? maxLines;

  /// The Mac frame's style: the name in `body-emphasized`, details in `body` / `secondary-label` (addresses
  /// and numbers too: Contacts shows them in the system font), a snippet in `callout`.
  TextStyle macStyleIn(MyDataMacColors mac) => switch (style) {
    _LineStyle.strong => MyDataMacType.bodyEmphasized.copyWith(color: mac.label),
    _LineStyle.body => MyDataMacType.body.copyWith(color: mac.label),
    _LineStyle.caption => MyDataMacType.callout.copyWith(color: mac.secondaryLabel),
    _LineStyle.mono => MyDataMacType.body.copyWith(color: mac.secondaryLabel),
  };

  TextStyle styleIn(MyDataColors c) => switch (style) {
    _LineStyle.strong => MyDataType.bodyStrong.copyWith(color: c.ink),
    _LineStyle.body => MyDataType.body.copyWith(color: c.ink),
    _LineStyle.caption => MyDataType.caption.copyWith(color: c.inkMuted),
    _LineStyle.mono => MyDataType.mono.copyWith(color: c.ink),
  };
}

/// A static [GroupedRow] with more than a title and a subtitle: a result needs a third line (a mail's
/// snippet) and mono lines (a contact's address and phone). It keeps the row's geometry: `row-height` at
/// least, the row padding, the tile, `space-3` between parts, and an optional value at the end.
///
/// A row that opens its item ([onOpen], in the app [opens]) is one target, as a [GroupedRow] with
/// `onPressed`: the hover fill, the press dim, the focus ring, Enter and Space, and a chevron at its end.
class _ResultRow extends GroupedRow {
  _ResultRow({
    required this.kind,
    required IconData icon,
    required super.tone,
    required this.lines,
    this.end,
    this.opens,
    VoidCallback? onOpen,
  }) : super(icon: icon, title: lines.first.text, onPressed: onOpen);

  final List<_Line> lines;

  /// The result's kind, for the Mac frame's icon ([ResultCard.macIconFor]).
  final String kind;

  /// A short value at the end (a mail's day), in `caption` / `ink-muted`.
  final String? end;

  /// The app the row opens its item in; null when it opens nothing.
  final MyDataAppId? opens;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = [
      for (final l in lines)
        if (l.text.isNotEmpty) l,
    ];
    final opensIn = opens;
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MyDataSize.rowHeight),
      child: Padding(
        padding: GroupedRow.padding,
        child: Row(
          children: [
            IconTile(icon: icon!, tone: tone),
            const SizedBox(width: GroupedRow.gap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in shown)
                    Text(
                      l.text,
                      style: l.styleIn(c),
                      maxLines: l.maxLines,
                      overflow: l.maxLines == null ? null : TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (end != null && end!.isNotEmpty) ...[
              const SizedBox(width: GroupedRow.gap),
              Text(end!, style: MyDataType.caption.copyWith(color: c.inkMuted)),
            ],
            if (onPressed != null) ...[
              const SizedBox(width: GroupedRow.gap),
              Icon(Icons.chevron_right_rounded, size: MyDataSize.icon, color: c.inkMuted),
            ],
          ],
        ),
      ),
    );
    if (onPressed != null && opensIn != null) {
      row = Semantics(
        hint: ResultCard.openHint(opensIn),
        child: Pressable(
          onPressed: onPressed,
          borderRadius: GroupedRow.shapeOf(context),
          hoverFill: c.surfaceHover,
          scaleOnPress: false,
          child: row,
        ),
      );
    }
    return MergeSemantics(child: row);
  }
}

/// A result row in the Mac frame: the kind's icon, the lines, an end value, and a chevron when it opens its
/// item. Drawn from the branded row's data, so both looks show the same things.
class _MacRow extends StatelessWidget {
  const _MacRow({required this.row});

  final _ResultRow row;

  /// Where the text starts, for the hairline between rows.
  static const textStart = MyDataSpace.s3 + MyDataMacSize.icon + MyDataSpace.s2;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final shown = [
      for (final l in row.lines)
        if (l.text.isNotEmpty) l,
    ];
    final opensIn = row.opens;
    final end = row.end;
    // The icon sits on the first line.
    final firstLine = MyDataMacType.bodyEmphasized.fontSize! * MyDataMacType.bodyEmphasized.height!;
    Widget content = Padding(
      padding: MacChat.rowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: (firstLine - MyDataMacSize.icon) / 2),
            child: Icon(
              ResultCard.macIconFor(row.kind),
              size: MyDataMacSize.icon,
              color: row.tone == MyDataTone.accent ? mac.accent : mac.secondaryLabel,
            ),
          ),
          const SizedBox(width: MyDataSpace.s2),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in shown)
                  Text(
                    l.text,
                    style: l.macStyleIn(mac),
                    maxLines: l.maxLines,
                    overflow: l.maxLines == null ? null : TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (end != null && end.isNotEmpty) ...[
            const SizedBox(width: MyDataSpace.s3),
            Text(end, style: MyDataMacType.callout.copyWith(color: mac.secondaryLabel)),
          ],
          if (row.onPressed != null) ...[
            const SizedBox(width: MyDataSpace.s2),
            Padding(
              padding: EdgeInsets.only(top: (firstLine - MyDataMacSize.icon) / 2),
              child: Icon(MacIcons.chevronRight, size: MyDataMacSize.icon, color: mac.tertiaryLabel),
            ),
          ],
        ],
      ),
    );
    if (row.onPressed != null && opensIn != null) {
      content = Semantics(
        hint: ResultCard.openHint(opensIn),
        child: Pressable(
          onPressed: row.onPressed,
          borderRadius: BorderRadius.zero,
          hoverFill: mac.hover,
          scaleOnPress: false,
          child: content,
        ),
      );
    }
    return MergeSemantics(child: content);
  }
}
