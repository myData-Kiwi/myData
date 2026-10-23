import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import '../widgets/kiwi.dart';
import '../widgets/progress_bar.dart';
import 'mac_icons.dart';
import 'mac_theme.dart';

/// What a [MacEmptyState] leads with.
enum MacEmptySymbol {
  /// Nothing here yet, or a first launch: the kiwi mark, bare (no tile, no shadow).
  kiwi,

  /// Something is under way: the loading kiwi.
  working,

  /// A plain message: Lucide's info glyph in `secondary-label`.
  info,

  /// Something failed: Lucide's alert glyph in `secondary-label` (the words carry the failure, not a colour).
  error,
}

/// The one empty, waiting and error state of the Mac frame, as macOS draws ContentUnavailableView
/// (docs/2026-10-23-plan.md 5.5: "One line of secondary text per state"): a symbol, a [title] in `title`, one
/// [line] in `body` and `secondary-label`, and at most one [action]. Centred in the pane, at most
/// `alert-width` plus a margin wide.
///
/// - [detail] (an error's text, a log's path) follows in `caption` and `tertiary-label`, selectable so it can
///   be copied: never a dark code block.
/// - [progress] (0 to 1) replaces the symbol with a progress bar labelled [progressLabel].
/// - EmptyState and StatusPanel draw this in the Mac frame, so every app's empty, waiting and error states
///   look the same there.
class MacEmptyState extends StatelessWidget {
  const MacEmptyState({
    super.key,
    this.symbol = MacEmptySymbol.kiwi,
    required this.title,
    this.line,
    this.detail,
    this.action,
    this.progress,
    this.progressLabel,
  }) : assert(progress == null || progressLabel != null, 'A progress bar needs a label.');

  final MacEmptySymbol symbol;
  final String title;
  final String? line;
  final String? detail;

  /// At most one button: a Button, filled (the default button).
  final Widget? action;

  final double? progress;
  final String? progressLabel;

  /// The symbol's size: the kiwi mark's height, and a glyph's.
  static double symbolSize(MyDataLook look) => look.space(12);

  /// The column's width at most.
  static double maxWidth(MyDataLook look) => MyDataMacSize.alertWidth + 2 * look.space(12);

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final Widget? lead = progress != null
        ? null
        : switch (symbol) {
            MacEmptySymbol.kiwi => MacKiwi(height: symbolSize(context.look)),
            MacEmptySymbol.working => KiwiLoader(size: symbolSize(context.look)),
            MacEmptySymbol.info => Icon(MacIcons.info, size: symbolSize(context.look), color: mac.secondaryLabel),
            MacEmptySymbol.error => Icon(MacIcons.warning, size: symbolSize(context.look), color: mac.secondaryLabel),
          };
    final column = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth(context.look)),
      child: Semantics(
        container: true,
        liveRegion: symbol != MacEmptySymbol.kiwi && symbol != MacEmptySymbol.info,
        explicitChildNodes: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (lead != null) ...[ExcludeSemantics(child: lead), SizedBox(height: context.space(4))],
            Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, style: MyDataMacType.title.copyWith(color: mac.label)),
            ),
            if (progress != null) ...[
              SizedBox(height: context.space(4)),
              MyDataProgressBar(label: progressLabel!, value: progress!, caption: line ?? ''),
            ] else if (line != null && line!.isNotEmpty) ...[
              SizedBox(height: context.space(1)),
              Text(line!, textAlign: TextAlign.center, style: MyDataMacType.body.copyWith(color: mac.secondaryLabel)),
            ],
            if (detail != null && detail!.isNotEmpty) ...[
              SizedBox(height: context.space(3)),
              SelectableText(detail!,
                  textAlign: TextAlign.center, style: MyDataMacType.caption.copyWith(color: mac.tertiaryLabel)),
            ],
            if (action != null) ...[SizedBox(height: context.space(5)), action!],
          ],
        ),
      ),
    );
    return LayoutBuilder(builder: (context, constraints) {
      final pad = EdgeInsets.all(context.space(6));
      if (!constraints.hasBoundedHeight) return Padding(padding: pad, child: Center(heightFactor: 1, child: column));
      return SingleChildScrollView(
        padding: pad,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: (constraints.maxHeight - pad.vertical).clamp(0, double.infinity)),
          child: Center(child: column),
        ),
      );
    });
  }
}

/// The kiwi mark in the Mac frame (empty states, first launch): bare, with no tile or shadow, on a light
/// window; on a flat `paper` disc on a dark one, as the mark's ink is a fixed dark colour
/// (design/assets/Logos/README.md). [height] is the light mark's; the disc is that tall and a half.
class MacKiwi extends StatelessWidget {
  const MacKiwi({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) {
      return ExcludeSemantics(child: KiwiMark(height: height, semanticLabel: null));
    }
    return ExcludeSemantics(
      child: Container(
        width: height * 1.5,
        height: height * 1.5,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: context.colors.paper, shape: BoxShape.circle),
        child: KiwiMark(height: height * 0.75, semanticLabel: null),
      ),
    );
  }
}
