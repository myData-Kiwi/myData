import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/library.dart';
import '../theme/theme.dart';
import 'pressable.dart';

/// The control for choosing a palette of one theme: the theme gallery's palette row
/// (design/components/ThemePicker, design/themes/ARCHITECTURE.md 4.4).
///
/// - One swatch per palette, in the order of [themes] (the theme's palettes, default first:
///   [ThemeLibrary.paletteSwatches]). Each swatch is a `control-height` pill on `surface` with `shadow-1`,
///   holding a disc of that palette's `accent` for the current brightness and the palette's name in
///   `body-strong`.
/// - The selected swatch has a 2px `ink` ring outside the pill and no shadow (decided 2026-10-12, as the
///   preview), and a check mark in the disc in that theme's `on-accent`. Selection is never colour alone.
///   The ring, shadow and check change over `fast`.
/// - Swatches are `space-2` apart and wrap onto more lines when the row is too narrow.
/// - A radio group: Tab reaches the selected swatch only; the arrow keys move between swatches and choose at
///   once (wrapping), Home and End go to the first and last. Enter and Space choose the focused swatch.
///   There is no Save button.
/// - Semantics: a radio group named [semanticLabel], each swatch a radio named after its theme, checked
///   when selected.
/// - [onChanged] null disables every swatch (45% opacity, no focus).
/// - Mode (light, dark, match system) is a separate SegmentedControl beside it; it is not part of this
///   widget.
class ThemePicker extends StatefulWidget {
  /// [themes] are the palettes the user can pick, in order; [selected] is the current palette id. An id that
  /// is not among them shows the first (the theme's default) as selected.
  const ThemePicker({
    super.key,
    required this.themes,
    required this.selected,
    required this.onChanged,
    this.semanticLabel = 'Theme',
  });

  /// The palettes, in order.
  final List<PaletteSwatch> themes;

  /// The id of the current theme.
  final String? selected;

  /// Called with the id of the newly chosen theme. Not called when the selected theme is chosen again.
  /// Null disables the picker.
  final ValueChanged<String>? onChanged;

  /// What the group chooses, for screen readers.
  final String semanticLabel;

  /// Spec: "a disc of that theme's accent"; the preview's disc is 22px.
  static const discSize = 22.0;

  /// The preview's check mark inside the disc is 12px.
  static const checkSize = 12.0;

  /// Width of the ring around the selected swatch. Spec: "a 2px ink ring".
  static const ringWidth = 2.0;

  /// Space before the disc. The preview's 11px snaps to `space-3`, which also keeps the disc about
  /// concentric with the pill's rounded end.
  static double leadingPadding(MyDataLook look) => look.space(3);

  /// Space after the name. The preview's 18px lies halfway between `space-4` and `space-5`; `space-4` is
  /// used.
  static double trailingPadding(MyDataLook look) => look.space(4);

  /// Space between the disc and the name (the preview's 8px).
  static double discGap(MyDataLook look) => look.space(2);

  /// Space between swatches: the preview's 10px snapped to `space-2`, the chip and button gap (decided
  /// 2026-10-12).
  static double gap(MyDataLook look) => look.space(2);

  @override
  State<ThemePicker> createState() => _ThemePickerState();
}

class _ThemePickerState extends State<ThemePicker> {
  final List<FocusNode> _nodes = [];

  bool get _enabled => widget.onChanged != null;

  int get _selectedIndex {
    final i = widget.themes.indexWhere((t) => t.id == widget.selected);
    return i >= 0 ? i : 0;
  }

  void _syncNodes() {
    while (_nodes.length < widget.themes.length) {
      _nodes.add(FocusNode(debugLabel: 'ThemePicker swatch ${_nodes.length}'));
    }
    while (_nodes.length > widget.themes.length) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _choose(int index) {
    final id = widget.themes[index].id;
    if (index != _selectedIndex || id != widget.selected) widget.onChanged?.call(id);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (!_enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final focused = _nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (focused < 0) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final n = widget.themes.length;
    final key = event.logicalKey;
    int? next;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)) {
      next = (focused + 1) % n;
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)) {
      next = (focused - 1 + n) % n;
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = n - 1;
    }
    if (next == null) return KeyEventResult.ignored;
    _nodes[next].requestFocus();
    _choose(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _syncNodes();
    final selected = _selectedIndex;
    // Only the selected swatch is a Tab stop (a radio group); the arrow keys move within it.
    for (var i = 0; i < _nodes.length; i++) {
      _nodes[i].skipTraversal = selected >= 0 ? i != selected : i != 0;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: widget.semanticLabel,
      enabled: _enabled,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Wrap(
          spacing: ThemePicker.gap(context.look),
          runSpacing: ThemePicker.gap(context.look),
          children: [
            for (var i = 0; i < widget.themes.length; i++)
              Semantics(
                container: true,
                inMutuallyExclusiveGroup: true,
                checked: i == selected,
                child: Pressable(
                  onPressed: _enabled ? () => _choose(i) : null,
                  borderRadius: MyDataRadii.pill(context.look),
                  focusNode: _nodes[i],
                  button: false,
                  child: _Swatch(theme: widget.themes[i], selected: i == selected, dark: dark),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.theme, required this.selected, required this.dark});

  final PaletteSwatch theme;
  final bool selected;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: context.motion.fast,
      curve: context.motion.standard,
      constraints: BoxConstraints(minHeight: context.density.controlHeight),
      padding: EdgeInsetsDirectional.only(
          start: ThemePicker.leadingPadding(context.look), end: ThemePicker.trailingPadding(context.look)),
      decoration: context.radius.decorate(BoxDecoration(
        color: c.surface,
        borderRadius: MyDataRadii.pill(context.look),
        // Selected: the ring replaces the shadow (decided 2026-10-12).
        boxShadow: selected ? const [] : context.shadows.shadow1,
        border: selected
            ? Border.all(color: c.ink, width: ThemePicker.ringWidth, strokeAlign: BorderSide.strokeAlignOutside)
            : Border.all(
                color: c.ink.withValues(alpha: 0),
                width: ThemePicker.ringWidth,
                strokeAlign: BorderSide.strokeAlignOutside),
      )),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ThemePicker.discSize,
            height: ThemePicker.discSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: dark ? theme.accentDark : theme.accentLight, shape: BoxShape.circle),
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: context.motion.fast,
              curve: context.motion.standard,
              child: CustomPaint(
                size: const Size.square(ThemePicker.checkSize),
                painter: _CheckPainter(dark ? theme.onAccentDark : theme.onAccentLight),
              ),
            ),
          ),
          SizedBox(width: ThemePicker.discGap(context.look)),
          Text(theme.name, maxLines: 1, softWrap: false, style: context.typeScale.bodyStrong.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}

/// The preview's check mark: on a 12-unit grid, from (2.5, 6.4) down 2.3 and 2.3, then up to (9.5, 3.5),
/// a 1.8-unit stroke with round ends.
class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / ThemePicker.checkSize;
    final path = Path()
      ..moveTo(2.5 * s, 6.4 * s)
      ..relativeLineTo(2.3 * s, 2.3 * s)
      ..relativeLineTo(4.7 * s, -5.2 * s);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}
