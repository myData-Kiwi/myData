import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'button.dart';
import 'pressable.dart' show MyDataRadii;
import 'role_label.dart';

/// A well for a value the user reads exactly or copies: a token, an address, a path, an error from the host
/// (design/components/MonoWell).
///
/// - `surface-sunken` with `radius-md` and no border, `space-3` padding across and `space-2` down. It sits
///   on `surface` or `bg`, never on `surface-sunken`. The well fills the width it is given.
/// - The [value] is in the `mono` style in `ink` and selectable. It wraps at any character when a word is
///   longer than the line (Flutter breaks such a word wherever it must), so a long token stays inside the
///   well; text with spaces or slashes wraps there first.
/// - With [copyLabel] ("Copy token"), a tonal button sits beside the well, `space-2` away. Pressing it puts
///   the value on the clipboard; the button then reads [copiedLabel] until the value changes, and screen
///   readers hear [copiedLabel]. The button keeps one width for both words, so the well does not shift.
/// - [label] ("Token", "MCP URL") sits above in the `label` style and `ink`, `space-2` above the well, when
///   the well is one of several values.
/// - Not for sentences: an explanation goes in `body` or `caption` next to the well.
class MonoWell extends StatefulWidget {
  const MonoWell({super.key, required this.value, this.label, this.copyLabel});

  /// The exact value.
  final String value;

  /// The value's name, in sentence case. Null for none.
  final String? label;

  /// The copy button's label, a verb and the thing: "Copy token". Null for no button.
  final String? copyLabel;

  /// What the button reads, and what screen readers hear, after copying.
  static const copiedLabel = 'Copied';

  /// Spec: "`space-3` padding across and `space-2` down".
  static EdgeInsets padding(MyDataLook look) => EdgeInsets.symmetric(horizontal: look.space(3), vertical: look.space(2));

  /// Between the well and its copy button, and between the label and the well.
  static double gap(MyDataLook look) => look.space(2);

  @override
  State<MonoWell> createState() => _MonoWellState();
}

class _MonoWellState extends State<MonoWell> {
  bool _copied = false;

  @override
  void didUpdateWidget(MonoWell old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _copied = false;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    await SemanticsService.sendAnnouncement(View.of(context), MonoWell.copiedLabel, Directionality.of(context));
  }

  /// The width of a [Button] for the wider of [copyLabel] and [MonoWell.copiedLabel].
  double _buttonWidth(BuildContext context, String copyLabel) {
    // Measured as the button's Text lays its label out: the label style over the inherited text style.
    final style = DefaultTextStyle.of(context).style.merge(context.typeScale.bodyStrong);
    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final text = math.max(textWidth(copyLabel), textWidth(MonoWell.copiedLabel));
    return math.max(context.density.controlHeight, (text + 2 * Button.horizontalPadding(context.look)).ceilToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget well = DecoratedBox(
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.md(context.look)),
      child: Padding(padding: MonoWell.padding(context.look), child: _WellText(value: widget.value)),
    );
    final copyLabel = widget.copyLabel;
    if (copyLabel != null) {
      well = Row(
        children: [
          Expanded(child: well),
          SizedBox(width: MonoWell.gap(context.look)),
          // As wide as the wider of its two words, so it does not change width when it says "Copied".
          SizedBox(
            width: _buttonWidth(context, copyLabel),
            child: Button(label: _copied ? MonoWell.copiedLabel : copyLabel, onPressed: _copy),
          ),
        ],
      );
    }
    final label = widget.label;
    if (label == null) return well;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoleLabel(label, color: c.ink),
        SizedBox(height: MonoWell.gap(context.look)),
        well,
      ],
    );
  }
}

/// The value, selectable. A word longer than the line (a token, a URL) breaks at any character, so it
/// never runs out of the well.
class _WellText extends StatefulWidget {
  const _WellText({required this.value});
  final String value;

  @override
  State<_WellText> createState() => _WellTextState();
}

class _WellTextState extends State<_WellText> {
  // Reached by pointer, not by Tab: it has no focus ring of its own, and the copy button is the keyboard's
  // way to copy.
  final _focusNode = FocusNode(debugLabel: 'MonoWell', skipTraversal: true);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SelectableText(widget.value, focusNode: _focusNode, style: context.typeScale.mono.copyWith(color: context.colors.ink));
}
