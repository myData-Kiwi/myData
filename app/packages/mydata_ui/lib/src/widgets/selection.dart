import 'package:flutter/material.dart';

import '../generated/tokens.g.dart' show MyDataColors, MyDataMacColors;
import '../theme/theme.dart';

/// How the current item is marked in a look (`components.selection`, design/themes/ARCHITECTURE.md 3.2): a
/// selected row, the current section in the sidebar, the selected day. [SelectionMark] draws it.
///
/// - `tint`: an `accent-soft` fill. Where that is under 3:1 on `surface` (Kiwi's, Sticker's), a mark is drawn
///   too, so the selection is never told by colour alone (WCAG 1.4.1, ARCHITECTURE.md 2.3): a `selection`
///   bar at the leading edge, or a 2px `selection` outline in a theme that outlines its controls;
/// - `solid`: a `selection` fill with its text in `on-selection`;
/// - `inverse`: an `ink` fill with its text in `bg`;
/// - `bar`: an `accent-soft` fill and a `selection` bar at the leading edge;
/// - `outline`: a 2px `selection` outline, no fill;
/// - `highlighter`: a `selection` swipe behind the item's name ([SelectionHighlight]), its text in
///   `on-selection`, and an `accent` bar at the leading edge, since the swipe alone is under 3:1 on paper.
@immutable
class SelectionPaint {
  const SelectionPaint({
    required this.style,
    this.fill,
    this.foreground,
    this.bar,
    this.outline,
    this.highlight,
    this.onHighlight,
  });

  final SelectionStyle style;

  /// Behind the whole item; null for none.
  final Color? fill;

  /// The item's text and icons, where the fill needs its own ([fill] is `selection` or `ink`); null keeps them.
  final Color? foreground;

  /// The leading bar; null for none.
  final Color? bar;

  /// The outline; null for none.
  final BorderSide? outline;

  /// The swipe behind the item's name ([SelectionHighlight]); null for none.
  final Color? highlight;

  /// The name's colour on [highlight].
  final Color? onHighlight;

  /// The leading bar's width.
  static const barWidth = 3.0;

  /// The outline's width.
  static const outlineWidth = 2.0;

  /// The least contrast a tint needs on `surface` to mark a selection by itself (WCAG 1.4.11).
  static const tintAlone = 3.0;

  /// The fill hovering or pressing adds over a selected item: its text colour at this opacity, the same
  /// step `surface-hover` is from `surface` (GroupedRow.selectedHoverInk).
  static const hoverInk = 0.16;

  /// Whether a theme that marks a tint outlines it rather than barring it: one that outlines its controls.
  static bool _outlines(MyDataLook look) => look.edges.controls;

  static final _tintMarked = Expando<bool>('tint marked');

  /// Whether [c]'s `accent-soft` is under [tintAlone] on `surface`, so a tint needs a mark.
  static bool tintNeedsMark(MyDataColors c) =>
      _tintMarked[c] ??= contrastOf(c.accentSoft, c.surface) < tintAlone;

  /// The WCAG contrast of two opaque colours.
  static double contrastOf(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
  }

  /// The selection in [look]. [macSystem]: System as the Mac shell draws it, whose selection is the
  /// system's own fill, with no mark of ours.
  factory SelectionPaint.of(MyDataLook look, {bool macSystem = false}) {
    final c = look.colors;
    final style = look.variants.selection;
    if (macSystem) return SelectionPaint(style: SelectionStyle.tint, fill: c.accentSoft);
    final marker = BorderSide(color: c.selection, width: outlineWidth);
    return switch (style) {
      SelectionStyle.tint => SelectionPaint(
          style: style,
          fill: c.accentSoft,
          bar: tintNeedsMark(c) && !_outlines(look) ? c.selection : null,
          outline: tintNeedsMark(c) && _outlines(look) ? marker : null),
      SelectionStyle.solid => SelectionPaint(style: style, fill: c.selection, foreground: c.onSelection),
      SelectionStyle.inverse => SelectionPaint(style: style, fill: c.ink, foreground: c.bg),
      SelectionStyle.bar => SelectionPaint(style: style, fill: c.accentSoft, bar: c.selection),
      SelectionStyle.outline => SelectionPaint(style: style, outline: marker),
      SelectionStyle.highlighter =>
        SelectionPaint(style: style, bar: c.accent, highlight: c.selection, onHighlight: c.onSelection),
    };
  }

  /// A solid fill under the item ([SelectionStyle.solid] or [SelectionStyle.inverse]): a focus ring on it is
  /// two-tone.
  bool get filled => foreground != null;

  /// The hover and press fill over a selected item.
  Color hoverOver(MyDataColors c) => (foreground ?? c.ink).withValues(alpha: hoverInk);
}

/// Marks [child] as the current item when [selected], in the look's selection style ([SelectionPaint]):
/// the fill behind it, the bar and the outline over it, both following [borderRadius] in the look's corner
/// style (or [shape]'s). Text inside takes the selection's own colours: `ink` and `ink-muted` are replaced
/// below it by [SelectionPaint.foreground] where the fill needs it, and a [SelectionHighlight] draws the
/// highlighter's swipe.
///
/// The bar sits flush at the leading edge, [SelectionPaint.barWidth] wide and clipped to the item's outline:
/// the start of a row, the curved end of a pill, never a separate stroke beside the icon.
class SelectionMark extends StatelessWidget {
  const SelectionMark({
    super.key,
    required this.selected,
    required this.borderRadius,
    required this.child,
    this.shape,
    this.fill = true,
  });

  final bool selected;
  final BorderRadius borderRadius;
  final Widget child;

  /// The corner style when it is not the look's.
  final MyDataShape? shape;

  /// Draws the selection's fill; false for an item that draws its own fill under other layers (it reads
  /// [SelectionPaint.fill] itself) and wants only the bar, the outline and the colours here.
  final bool fill;

  /// Whether [context] draws System in the Mac shell's colours (the Mac window, or a gallery card of it).
  static bool isMacSystem(BuildContext context) =>
      context.look.frame == LookFrame.system && Theme.of(context).extension<MyDataMacColors>() != null;

  /// Whether [context] is inside a selected [SelectionMark].
  static SelectionPaint? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SelectionScope>()?.paint;

  @override
  Widget build(BuildContext context) {
    if (!selected) return child;
    final look = context.look;
    final paint = SelectionPaint.of(look, macSystem: isMacSystem(context));
    final s = shape ?? look.shape;
    Widget body = child;
    final fg = paint.foreground;
    // The fill needs its own text colour: `ink` and `ink-muted` below are that colour. A row builds its text
    // below this (in a Builder), so its own reads of `context.colors` see it.
    if (fg != null) body = inkAs(context, fg, child: body);
    body = _SelectionScope(paint: paint, child: body);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: _MarkDecoration(paint: paint, shape: s, radius: borderRadius),
      child: fill && paint.fill != null
          ? DecoratedBox(decoration: s.decorate(BoxDecoration(color: paint.fill, borderRadius: borderRadius)), child: body)
          : body,
    );
  }
}

class _SelectionScope extends InheritedWidget {
  const _SelectionScope({required this.paint, required super.child});
  final SelectionPaint paint;

  @override
  bool updateShouldNotify(_SelectionScope old) =>
      old.paint.style != paint.style || old.paint.highlight != paint.highlight || old.paint.foreground != paint.foreground;
}

/// The bar and the outline of a selection, drawn over the item.
class _MarkDecoration extends Decoration {
  const _MarkDecoration({required this.paint, required this.shape, required this.radius});
  final SelectionPaint paint;
  final MyDataShape shape;
  final BorderRadius radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _MarkPainter(this);

  @override
  bool operator ==(Object other) =>
      other is _MarkDecoration &&
      other.paint.bar == paint.bar &&
      other.paint.outline == paint.outline &&
      other.shape.corners == shape.corners &&
      other.shape.cutSize == shape.cutSize &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(paint.bar, paint.outline, shape.corners, shape.cutSize, radius);
}

class _MarkPainter extends BoxPainter {
  _MarkPainter(this.d);
  final _MarkDecoration d;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final outline = d.paint.outline;
    if (outline != null) {
      canvas.drawPath(
          d.shape.ringPath(rect, d.radius, -outline.width / 2),
          Paint()
            ..color = outline.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = outline.width);
    }
    final bar = d.paint.bar;
    if (bar != null) {
      // Flush with the leading edge and clipped to the item's outline, so on a pill or a rounded row it is
      // the coloured start of the shape itself, never a stroke standing loose beside the icon.
      final rtl = configuration.textDirection == TextDirection.rtl;
      final w = SelectionPaint.barWidth;
      final x = rtl ? rect.right - w : rect.left;
      canvas.save();
      canvas.clipPath(d.shape.ringPath(rect, d.radius, 0));
      canvas.drawRect(Rect.fromLTRB(x, rect.top, x + w, rect.bottom), Paint()..color = bar);
      canvas.restore();
    }
  }
}

/// [child] with `ink` and `ink-muted` drawn as [colour] (text on a selection's fill), for everything below
/// that reads `context.colors`: build the text in a Builder under it.
Widget inkAs(BuildContext context, Color colour, {required Widget child}) {
  final theme = Theme.of(context);
  final colors = context.colors.copyWith(ink: colour, inkMuted: colour);
  return Theme(
    data: theme.copyWith(
      extensions: [
        for (final e in theme.extensions.values)
          if (e is MyDataColors) colors else if (e is MyDataLook) e.copyWith(colors: colors) else e,
      ],
      iconTheme: theme.iconTheme.copyWith(color: colour),
    ),
    child: child,
  );
}

/// An item's name, with the highlighter's swipe behind it while its item is selected in a theme whose
/// selection is a highlighter ([SelectionStyle.highlighter]); otherwise [child] as it is.
class SelectionHighlight extends StatelessWidget {
  const SelectionHighlight({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final paint = SelectionMark.of(context);
    final swipe = paint?.highlight;
    if (swipe == null) return child;
    return DecoratedBox(
      decoration: context.radius.decorate(
          BoxDecoration(color: swipe, borderRadius: BorderRadius.all(Radius.circular(context.radius.xs)))),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.space(0.5)),
        child: inkAs(context, paint!.onHighlight!, child: child),
      ),
    );
  }
}

