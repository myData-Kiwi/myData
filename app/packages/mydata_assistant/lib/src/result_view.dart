import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// A tool's result as the host sent it: shown the moment the tool returns, before (or instead of) any
/// sentence from the model. The header is written by the host's code.
///
/// The header line sits on the ground in `body-strong`; the items follow as a [GroupedList], each on an
/// [IconTile] that names its kind. Same kind, same tone, and at most three tones in a conversation:
/// calendar `accent`, mail `info`, contacts and photos untinted ([toneFor]). A created event is one row
/// carrying the header. Never a card in a card: the list is the only raised surface.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.kind, required this.header, required this.items});

  /// events, mail, contacts, photos or event_created.
  final String kind;
  final String header;
  final List<Map<String, Object?>> items;

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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (kind == 'event_created') {
      // The header says what was added; the list's one row carries it.
      return GroupedList(rows: [_ResultRow(icon: iconFor(kind), tone: toneFor(kind), lines: [_Line.strong(header)])]);
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

  _ResultRow _row(Map<String, Object?> item) {
    String s(String k) => item[k] is String ? item[k] as String : '';
    String join(Iterable<String> parts, String by) => parts.where((p) => p.isNotEmpty).join(by);
    final icon = iconFor(kind);
    final tone = toneFor(kind);
    return switch (kind) {
      'events' => _ResultRow(
        icon: icon,
        tone: tone,
        lines: [
          _Line.strong(s('title')),
          _Line.caption(
            join([
              join([s('day'), join([s('start'), s('end')], '–')], ', '),
              s('location'),
            ], ' · '),
          ),
        ],
      ),
      'mail' => _ResultRow(
        icon: icon,
        tone: tone,
        end: s('day'),
        lines: [_Line.strong(s('from')), _Line.body(s('subject')), _Line.caption(s('snippet'), maxLines: 2)],
      ),
      'contacts' => _ResultRow(
        icon: icon,
        tone: tone,
        lines: [_Line.strong(s('name')), _Line.mono(s('email')), _Line.mono(s('phone'))],
      ),
      'photos' => _ResultRow(
        icon: icon,
        tone: tone,
        lines: [
          _Line.strong(s('place')),
          _Line.caption(
            join([
              s('day'),
              (item['people'] is List ? item['people'] as List : const []).join(', '),
            ], ' · '),
          ),
        ],
      ),
      _ => _ResultRow(icon: icon, tone: tone, lines: [_Line.caption(item.toString())]),
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
class _ResultRow extends GroupedRow {
  _ResultRow({required IconData icon, required super.tone, required this.lines, this.end})
    : super(icon: icon, title: lines.first.text);

  final List<_Line> lines;

  /// A short value at the end (a mail's day), in `caption` / `ink-muted`.
  final String? end;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = [for (final l in lines) if (l.text.isNotEmpty) l];
    return MergeSemantics(
      child: ConstrainedBox(
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
            ],
          ),
        ),
      ),
    );
  }
}
