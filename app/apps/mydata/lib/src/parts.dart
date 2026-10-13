import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';

// TEMPORARY. SettingsSection and SectionRow stand in for two parts mydata_ui does not have yet: a GroupedList
// part that holds arbitrary content (a picker, a form) and a GroupedTrailing that holds buttons. They copy
// GroupedList's look and its tile-tone check, built from its public constants, so the two cannot drift
// apart silently; replace them with GroupedList once mydata_ui offers those parts (requested from mydata_ui).

/// A settings section that holds more than GroupedList rows (a picker, a form, rows with a button): the
/// GroupedList's heading above a `surface` group with `radius-lg` and `shadow-1`, no border, its parts
/// separated by full-width `line` dividers, as in a grouped list. Never put a card inside it.
///
/// Like GroupedList, it asserts in debug builds that its [SectionRow]s use at most
/// [GroupedList.maxTileTones] tile tones.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.heading, required this.children});

  /// In sentence case: "Appearance".
  final String heading;

  /// The parts, top to bottom, each padded by its builder.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    assert(
      children.whereType<SectionRow>().where((r) => r.icon != null).map((r) => r.tone).toSet().length <=
          GroupedList.maxTileTones,
      'use at most ${GroupedList.maxTileTones} different tile tones on one screen (design/README.md "Colour")',
    );
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: GroupedList.headingPadding,
          child: Semantics(
            header: true,
            child: Text(heading, style: MyDataType.label.copyWith(color: c.inkMuted)),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg, boxShadow: context.shadows.shadow1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Container(height: GroupedList.dividerWidth, color: c.line),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A part of a [SettingsSection] laid out like a GroupedList row: at least `row-height` tall, padded
/// `space-4` across and `space-2` down, with an optional tile, a title over a caption, and [trailing]
/// widgets (a chip, a button) at the end, `space-3` apart.
class SectionRow extends StatelessWidget {
  const SectionRow({
    super.key,
    this.icon,
    this.tone = MyDataTone.neutral,
    required this.title,
    this.subtitle,
    this.trailing = const [],
  });

  final IconData? icon;
  final MyDataTone tone;
  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MyDataSize.rowHeight),
      child: Padding(
        padding: GroupedRow.padding,
        child: Row(
          children: [
            if (icon != null) ...[IconTile(icon: icon!, tone: tone), const SizedBox(width: GroupedRow.gap)],
            Expanded(
              child: MergeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
                    if (subtitle != null) Text(subtitle!, style: MyDataType.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
            ),
            for (final t in trailing) ...[const SizedBox(width: GroupedRow.gap), t],
          ],
        ),
      ),
    );
  }
}

/// A copied or technical value (a token, an address, an error) in `mono` on a `surface-sunken` well,
/// selectable so it can be copied by hand.
class MonoWell extends StatelessWidget {
  const MonoWell({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s3, vertical: MyDataSpace.s2),
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.md),
      child: SelectableText(text, style: MyDataType.mono.copyWith(color: c.ink)),
    );
  }
}
