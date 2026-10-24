import 'package:flutter/material.dart';

import '../mac/mac_empty_state.dart';
import '../mac/mac_theme.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'icon_tile.dart';
import 'kiwi.dart';
import 'mono_well.dart';
import 'progress_bar.dart';
import 'status.dart';

/// What a [StatusPanel] is saying.
enum StatusPanelKind {
  /// Something is under way: the loading kiwi, or a progress bar when the amount is known.
  working,

  /// A plain message: an `accent-soft` tile.
  info,

  /// Something failed: a `danger-soft` tile, and the technical detail in a well.
  error,
}

/// A whole-screen message instead of a blank screen: what is happening or what went wrong, and what to do
/// next (design/README.md "Voice", design/platforms.md "Offline and errors").
///
/// - Centred, at most [maxWidth] wide, with the parts centred under each other.
/// - Scrolls when it is taller than the space it has (a long [detail], a short window), and keeps clear of
///   MediaQuery's padding, so on a phone it never runs under the floating tab bar. Given an unbounded height
///   (in a scrolling column) it takes its own height instead.
/// - **Working:** the loading kiwi ([KiwiLoader]); with a [progress], a [MyDataProgressBar] instead, labelled
///   [progressLabel] with the [message] as its caption.
/// - **Info:** an `accent-soft` [IconTile]. **Error:** a `danger-soft` tile with an error icon.
/// - The [title] is in the `title` style; the [message], in `body` / `ink-muted`, says what went wrong and
///   the next step, never a code alone.
/// - [detail] (an error text, a path) sits in a [MonoWell]: `mono` on `surface-sunken`, selectable so it can
///   be copied.
/// - [actions] are buttons in a [ButtonRow]: at most one filled, the rest tonal or plain.
class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.detail,
    this.progress,
    this.progressLabel,
    this.actions = const [],
  }) : assert(progress == null || kind == StatusPanelKind.working, 'Only a working panel shows progress.'),
       assert(progress == null || progressLabel != null, 'A progress bar needs a label: what is in progress.');

  final StatusPanelKind kind;

  /// What is happening or what failed, in sentence case: "Starting your host", "The host did not start".
  final String title;

  /// The next step, or what the user can do meanwhile.
  final String message;

  /// Technical detail, shown in mono in a well. Null or empty for none.
  final String? detail;

  /// From 0 to 1, for work of known length. Null shows the loading kiwi.
  final double? progress;

  /// What is in progress ("Downloading qwen3:14b"): the progress bar's label. Required with [progress].
  final String? progressLabel;

  final List<Widget> actions;

  /// No token: about 65 characters of `body`, a comfortable line for a
  /// message. `content-max` (880px) is for whole reading columns.
  static const maxWidth = 520.0;

  /// The loading kiwi's size: larger than the inline loader, as the one thing on the screen.
  static double loaderSize(MyDataLook look) => look.space(12);

  /// Around the panel.
  static double padding(MyDataLook look) => look.space(6);

  /// Between the leading tile or loader and the title.
  static double leadGap(MyDataLook look) => look.space(4);

  /// Between the title and the message.
  static double titleGap(MyDataLook look) => look.space(2);

  /// Between the message, the progress bar, the detail and the actions.
  static double sectionGap(MyDataLook look) => look.space(5);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasDetail = detail != null && detail!.isNotEmpty;
    // The Mac frame: one symbol, the title, one line, the detail as selectable small text, the actions.
    if (context.isSystemLook) {
      return MacEmptyState(
        symbol: switch (kind) {
          StatusPanelKind.working => MacEmptySymbol.working,
          StatusPanelKind.info => MacEmptySymbol.info,
          StatusPanelKind.error => MacEmptySymbol.error,
        },
        title: title,
        line: message,
        detail: detail,
        progress: progress,
        progressLabel: progressLabel,
        action: actions.isEmpty
            ? null
            : actions.length == 1
            ? actions.single
            : ButtonRow(alignment: WrapAlignment.center, children: actions),
      );
    }
    final showBar = kind == StatusPanelKind.working && progress != null;
    final Widget? lead = switch (kind) {
      StatusPanelKind.working => showBar ? null : KiwiLoader(size: loaderSize(context.look)),
      StatusPanelKind.info => const IconTile(icon: MyDataIcon.info, tone: MyDataTone.accent),
      StatusPanelKind.error => const IconTile(icon: MyDataIcon.error, tone: MyDataTone.danger),
    };
    final panel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Semantics(
        container: true,
        liveRegion: kind != StatusPanelKind.info,
        explicitChildNodes: true,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (lead != null) ...[Center(child: lead), SizedBox(height: leadGap(context.look))],
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: context.type(MyDataTypeRole.title).copyWith(color: c.ink)),
          ),
          if (showBar) ...[
            SizedBox(height: sectionGap(context.look)),
            MyDataProgressBar(label: progressLabel!, value: progress!, caption: message),
          ] else ...[
            SizedBox(height: titleGap(context.look)),
            Text(message, textAlign: TextAlign.center, style: context.type(MyDataTypeRole.body).copyWith(color: c.inkMuted)),
          ],
          if (hasDetail) ...[
            SizedBox(height: sectionGap(context.look)),
            MonoWell(value: detail!),
          ],
          if (actions.isNotEmpty) ...[
            SizedBox(height: sectionGap(context.look)),
            ButtonRow(alignment: WrapAlignment.center, children: actions),
          ],
        ]),
      ),
    );
    final insets = MediaQuery.paddingOf(context);
    final pad = padding(context.look);
    final outer = EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, pad + insets.right, pad + insets.bottom);
    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.hasBoundedHeight) {
        return Padding(padding: outer, child: Center(heightFactor: 1, child: panel));
      }
      return SingleChildScrollView(
        padding: outer,
        child: ConstrainedBox(
          // At least the visible height, so a short panel stays centred.
          constraints: BoxConstraints(minHeight: (constraints.maxHeight - outer.vertical).clamp(0, double.infinity)),
          child: Center(child: panel),
        ),
      );
    });
  }
}
