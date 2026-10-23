import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import 'data_colour.dart';
import 'form_scope.dart';
import 'picker_field.dart' show pickerIsPhone;
import 'pressable.dart';

/// One colour of the calendar palette: its name and its data colour (the same value in both modes).
@immutable
class PaletteColour {
  const PaletteColour(this.name, this.colour);

  /// One word in sentence case: "Blue".
  final String name;
  final Color colour;
}

/// A small row of colour swatches for choosing the colour of a calendar myData owns
/// (design/components/ColourPicker).
///
/// - The label "Colour" above in `label` and `ink`, `space-2` above the swatches; the chosen colour's name
///   under them in `caption` and `ink-muted`, `space-2` below, so the choice never depends on telling colours
///   apart.
/// - **The palette** ([palette]): Red, Orange, Yellow, Green, Blue, Purple, Brown and Grey, the eight
///   `data-*` tokens. They are data colours (DataColour), drawn exactly as given, never a control colour.
/// - **A colour that is not in the palette** ([currentColour], an imported calendar's) is kept exactly: one
///   more swatch, "Current colour", at the end.
/// - **A swatch** is a round target `control-height` wide holding a 20px disc (`icon`). The disc gets
///   DataColour's 1px `line-strong` edge when it has less than 3:1 against what it sits on (`surface`, or
///   `accent-soft` when chosen).
/// - **States:** hover, a 1px `line-strong` edge inside the target over `fast` (none on the chosen swatch);
///   the shared press; **chosen**, MonthGrid's selection on a round target: an `accent-soft` fill and a 2px
///   `ink` ring inside the target's edge, with no check mark; keyboard focus, the 2px `focus` ring 2px
///   outside. There is no disabled or error state; while its form waits for the host ([FormBusy]) the
///   choice does not change.
/// - **Keyboard:** a radio group with one tab stop, on the chosen swatch. The arrow keys move to the next or
///   previous swatch and choose it, wrapping at the ends: Right and Down forward, Left and Up back.
/// - **Screen readers:** a radio group named "Colour"; each swatch a radio button named by its colour.
/// - **Desktop:** one row (wrapping if too narrow), each swatch with its name as a tooltip. **Under 600px:**
///   a grid of four columns, `space-2` apart, so the eight make two rows of four; no tooltips.
class ColourPicker extends StatefulWidget {
  const ColourPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.currentColour,
    this.label = defaultLabel,
    this.compact = false,
  });

  /// The chosen colour: one of the [palette], or [currentColour].
  final Color value;

  /// Called with the newly chosen colour (opaque). In a form it applies on Save.
  final ValueChanged<Color> onChanged;

  /// The calendar's own colour from the host, shown as "Current colour" when it is not one of the palette's.
  /// Pass the saved colour while the form is open, so the user can go back to it before Save.
  final Color? currentColour;
  final String label;

  /// The Compact density on desktop: the target is `control-height-compact`; the disc is unchanged.
  final bool compact;

  static const defaultLabel = 'Colour';
  static const currentColourName = 'Current colour';

  /// Under 600px: four columns.
  static const phoneColumns = 4;

  /// The disc: DataColour's swatch at `icon` size.
  static double discSize(MyDataLook look) => look.density.icon;

  /// The chosen swatch's ring: 2px `ink` inside the target's edge (MonthGrid's selection ring).
  static const ringWidth = 2.0;

  /// The hover edge: 1px `line-strong` inside the target.
  static const hoverWidth = 1.0;

  /// The disc's edge when it has too little contrast: DataColour's 1px `line-strong`.
  static const edgeWidth = 1.0;

  /// The palette in its order, from the `data-*` tokens.
  static List<PaletteColour> palette(MyDataColors c) => [
        PaletteColour('Red', c.dataRed),
        PaletteColour('Orange', c.dataOrange),
        PaletteColour('Yellow', c.dataYellow),
        PaletteColour('Green', c.dataGreen),
        PaletteColour('Blue', c.dataBlue),
        PaletteColour('Purple', c.dataPurple),
        PaletteColour('Brown', c.dataBrown),
        PaletteColour('Grey', c.dataGrey),
      ];

  /// The colour a new calendar starts with: the first in the palette that no owned calendar uses yet
  /// ([used]), or Red when all are used.
  static Color firstUnused(MyDataColors c, Iterable<Color> used) {
    final taken = {for (final u in used) _rgb(u)};
    final p = palette(c);
    return p.firstWhere((e) => !taken.contains(_rgb(e.colour)), orElse: () => p.first).colour;
  }

  /// The hex form the host stores: "#D34730".
  static String toHex(Color colour) =>
      '#${(_rgb(colour)).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// The palette colour equal to [colour] (alpha ignored), or null.
  static PaletteColour? inPalette(MyDataColors c, Color colour) {
    for (final p in palette(c)) {
      if (_rgb(p.colour) == _rgb(colour)) return p;
    }
    return null;
  }

  @override
  State<ColourPicker> createState() => _ColourPickerState();
}

int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;

class _ColourPickerState extends State<ColourPicker> {
  final List<FocusNode> _nodes = [];

  List<PaletteColour> _swatches(MyDataColors c) {
    final p = ColourPicker.palette(c);
    final current = widget.currentColour;
    if (current != null && ColourPicker.inPalette(c, current) == null) {
      p.add(PaletteColour(ColourPicker.currentColourName, current.withValues(alpha: 1)));
    }
    return p;
  }

  void _syncNodes(int n) {
    while (_nodes.length < n) {
      _nodes.add(FocusNode(debugLabel: 'ColourPicker swatch ${_nodes.length}'));
    }
    while (_nodes.length > n) {
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

  KeyEventResult _onKey(List<PaletteColour> swatches, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final focused = _nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (focused < 0) return KeyEventResult.ignored;
    final arrows = event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight;
    // Waiting for the host: the choice does not move.
    if (FormBusy.read(context)) return arrows ? KeyEventResult.handled : KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final n = swatches.length;
    final key = event.logicalKey;
    int? next;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)) {
      next = (focused + 1) % n;
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)) {
      next = (focused - 1 + n) % n;
    }
    if (next == null) return KeyEventResult.ignored;
    _nodes[next].requestFocus();
    _choose(swatches[next]);
    return KeyEventResult.handled;
  }

  void _choose(PaletteColour s) {
    if (FormBusy.read(context)) return;
    if (_rgb(s.colour) != _rgb(widget.value)) widget.onChanged(s.colour.withValues(alpha: 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final phone = pickerIsPhone(context);
    final swatches = _swatches(c);
    _syncNodes(swatches.length);
    final chosen = swatches.indexWhere((s) => _rgb(s.colour) == _rgb(widget.value));
    for (var i = 0; i < _nodes.length; i++) {
      _nodes[i].skipTraversal = chosen >= 0 ? i != chosen : i != 0;
    }
    final target = widget.compact && !phone ? context.density.controlHeightCompact : context.density.controlHeight;
    final name = chosen >= 0 ? swatches[chosen].name : null;

    Widget row = Wrap(
      spacing: context.space(2),
      runSpacing: context.space(2),
      children: [
        for (var i = 0; i < swatches.length; i++)
          Semantics(
            container: true,
            inMutuallyExclusiveGroup: true,
            checked: i == chosen,
            child: Pressable(
              key: ValueKey('colour-swatch-${swatches[i].name}'),
              onPressed: () => _choose(swatches[i]),
              borderRadius: MyDataRadii.pill(context.look),
              focusNode: _nodes[i],
              button: false,
              semanticLabel: swatches[i].name,
              tooltip: phone ? null : swatches[i].name,
              child: _Swatch(colour: swatches[i].colour, chosen: i == chosen, size: target),
            ),
          ),
      ],
    );
    if (phone) {
      row = SizedBox(
        width: ColourPicker.phoneColumns * target + (ColourPicker.phoneColumns - 1) * context.space(2),
        child: row,
      );
    }

    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: widget.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Text(widget.label, style: context.typeScale.label.copyWith(color: c.ink))),
          SizedBox(height: context.space(2)),
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, e) => _onKey(swatches, e),
            child: row,
          ),
          if (name != null) ...[
            SizedBox(height: context.space(2)),
            // The chosen radio button already says it; not read twice.
            ExcludeSemantics(child: Text(name, style: context.typeScale.caption.copyWith(color: c.inkMuted))),
          ],
        ],
      ),
    );
  }
}

/// One swatch: the round target with its marks, and the disc.
class _Swatch extends StatefulWidget {
  const _Swatch({required this.colour, required this.chosen, required this.size});
  final Color colour;
  final bool chosen;
  final double size;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ground = widget.chosen ? c.accentSoft : c.surface;
    final edge = dataColourNeedsEdge(widget.colour, ground);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.chosen ? 1 : 0),
        duration: context.motion.fast,
        curve: context.motion.standard,
        builder: (context, chosen, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: _hovered && !widget.chosen ? 1 : 0),
          duration: context.motion.fast,
          curve: context.motion.standard,
          builder: (context, hover, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _SwatchPainter(
              chosen: chosen,
              hover: hover,
              fill: c.accentSoft,
              ring: c.ink,
              hoverEdge: c.lineStrong,
              disc: widget.colour,
              discEdge: edge ? c.lineStrong : null,
              discSize: ColourPicker.discSize(context.look),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter({
    required this.chosen,
    required this.hover,
    required this.fill,
    required this.ring,
    required this.hoverEdge,
    required this.disc,
    required this.discEdge,
    required this.discSize,
  });

  final double chosen;
  final double hover;
  final Color fill;
  final Color ring;
  final Color hoverEdge;
  final Color disc;
  final Color? discEdge;
  final double discSize;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (chosen > 0) {
      canvas.drawCircle(centre, r, Paint()..color = fill.withValues(alpha: fill.a * chosen));
      canvas.drawCircle(
          centre,
          r - ColourPicker.ringWidth / 2,
          Paint()
            ..color = ring.withValues(alpha: ring.a * chosen)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ColourPicker.ringWidth);
    }
    if (hover > 0) {
      canvas.drawCircle(
          centre,
          r - ColourPicker.hoverWidth / 2,
          Paint()
            ..color = hoverEdge.withValues(alpha: hoverEdge.a * hover)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ColourPicker.hoverWidth);
    }
    final d = discSize / 2;
    canvas.drawCircle(centre, d, Paint()..color = disc);
    if (discEdge != null) {
      canvas.drawCircle(
          centre,
          d - ColourPicker.edgeWidth / 2,
          Paint()
            ..color = discEdge!
            ..style = PaintingStyle.stroke
            ..strokeWidth = ColourPicker.edgeWidth);
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.chosen != chosen ||
      old.hover != hover ||
      old.fill != fill ||
      old.ring != ring ||
      old.hoverEdge != hoverEdge ||
      old.disc != disc ||
      old.discEdge != discEdge ||
      old.discSize != discSize;
}
