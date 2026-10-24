import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'icon_tile.dart';
import 'pressable.dart';
import 'progress_bar.dart';
import 'status.dart';
import 'switch.dart';

/// The control for choosing a theme (design/components/ThemePicker).
///
/// - One swatch per theme, in the order of [themes] (themes.json: Kiwi, Graphite, Dusk, Plum, Rose, Amber).
///   Each swatch is a `control-height` pill on `surface` with `shadow-1`, holding a disc of that theme's
///   `accent` for the current brightness and the theme's name in `body-strong`.
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
///   widget. Show the chosen theme below it with [ThemeSample].
class ThemePicker extends StatefulWidget {
  /// [themes] are the themes the user can pick, in order; [selected] is the current theme id. An id that is
  /// not among them shows the theme MyDataTheme falls back to ([MyDataThemes.fallback]) as selected.
  const ThemePicker({
    super.key,
    this.themes = MyDataThemes.all,
    required this.selected,
    required this.onChanged,
    this.semanticLabel = 'Theme',
  });

  /// The themes from themes.json, in order.
  final List<MyDataThemeSpec> themes;

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
    if (i >= 0) return i;
    return widget.themes.indexWhere((t) => t.id == MyDataThemes.fallback.id);
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

  final MyDataThemeSpec theme;
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

/// The live sample shown below the [ThemePicker] in Settings: one theme in one mode, drawn with the real
/// tokens of that theme (a nested Theme built by [MyDataTheme.data]) and scaled down to fit its parent.
///
/// It is built from the package's own parts ([IconTile], [SwitchTrack], [Button] and [ButtonRow]), so it
/// shows a theme exactly as the apps do. Like the preview, it shows the places the theme's colour appears:
/// the current place (the selected sidebar row in `accent-soft` with `accent` text), an `accent-soft` icon
/// tile, an `accent` link and progress bar, a setting switched on, and a filled and a tonal button. The
/// host's status dot is `brand`, which stays the same in every theme. The preview's segmented control
/// is left out: it uses no theme colour. None of it is interactive or focusable; screen readers hear one
/// description of the sample.
class ThemeSample extends StatelessWidget {
  /// [themeId] is the theme to show; [brightness] the mode, by default the brightness around it (in
  /// Settings, the current mode).
  const ThemeSample({super.key, required this.themeId, this.brightness, this.semanticLabel});

  final String themeId;
  final Brightness? brightness;

  /// Defaults to "Sample of the Dusk theme in light mode", with the theme's name and the mode.
  final String? semanticLabel;

  /// The preview's sidebar: `.side{width:136px}`.
  static const sidebarWidth = 136.0;

  /// The width the sample is laid out at before it is scaled down to its parent: the sidebar plus a main
  /// column wide enough for the cards' text on one line.
  static const naturalWidth = sidebarWidth + 360.0;

  /// The preview's host status dot: `.host i{width:7px;height:7px}`.
  static const hostDotSize = 7.0;

  /// The progress bar is filled to the preview's 62% (`.bar i{width:62%}`).
  static const barValue = 0.62;

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    final spec = MyDataThemes.byId(themeId);
    final label = semanticLabel ?? 'Sample of the ${spec.name} theme in ${b == Brightness.dark ? 'dark' : 'light'} mode';
    return Semantics(
      container: true,
      image: true,
      label: label,
      child: ExcludeSemantics(
        child: ExcludeFocus(
          child: IgnorePointer(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(
                width: naturalWidth,
                child: Theme(
                  data: MyDataTheme.data(spec.id, b),
                  child: const _SampleScreen(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _noop() {}

class _SampleScreen extends StatelessWidget {
  const _SampleScreen();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shadow = context.shadows.shadow1;
    final caption = context.typeScale.caption.copyWith(color: c.inkMuted);
    Decoration card() => context.radius.decorate(BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg(context.look), boxShadow: shadow));

    // Preview: `.main{padding:16px 16px 16px 8px; gap:14px}`; 14px snaps to space-4, as cards are space-4
    // apart.
    final main = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(context.space(2), context.space(4), context.space(4), context.space(4)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Library', style: context.typeScale.title.copyWith(color: c.ink)),
          SizedBox(height: context.space(4)),
          Container(
            decoration: card(),
            padding: EdgeInsets.all(context.space(4)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconTile(icon: MyDataIcon.photo, tone: MyDataTone.accent),
                SizedBox(width: context.space(3)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Backing up 248 photos', style: context.typeScale.bodyStrong.copyWith(color: c.ink)),
                      Text.rich(TextSpan(style: caption, children: [
                        const TextSpan(text: 'To the drive on this Mac. '),
                        TextSpan(
                          text: 'See details',
                          style: context.typeScale.label.copyWith(
                              color: c.link, decoration: TextDecoration.underline, decorationColor: c.link),
                        ),
                      ])),
                      SizedBox(height: context.space(2)),
                      // The ProgressBar's track and fill, without its label and caption.
                      Container(
                        height: MyDataProgressBar.trackHeight,
                        decoration: context.radius.decorate(BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.pill(context.look))),
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          widthFactor: ThemeSample.barValue,
                          heightFactor: 1,
                          child: DecoratedBox(
                              decoration: context.radius.decorate(BoxDecoration(color: c.accent, borderRadius: MyDataRadii.pill(context.look)))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.space(4)),
          Container(
            decoration: card(),
            padding: EdgeInsets.all(context.space(4)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Group photos by face', style: context.typeScale.bodyStrong.copyWith(color: c.ink)),
                      Text('Runs on your host.', style: caption),
                    ],
                  ),
                ),
                SizedBox(width: context.space(3)),
                const SwitchTrack(value: true),
              ],
            ),
          ),
          SizedBox(height: context.space(4)),
          const ButtonRow(children: [
            Button(label: 'Add photos', onPressed: _noop, variant: ButtonVariant.filled),
            Button(label: 'New album', onPressed: _noop),
          ]),
        ],
      ),
    );

    return Container(
      // A window on the ground, edged with a hairline of `line` as in the preview (no shadow, so no card
      // with both a border and a shadow).
      decoration: context.radius.decorate(BoxDecoration(color: c.bg, borderRadius: MyDataRadii.lg(context.look), border: Border.all(color: c.line))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: ThemeSample.sidebarWidth, child: _SampleSidebar()),
            Expanded(child: main),
          ],
        ),
      ),
    );
  }
}

/// The sample's sidebar: the app's name, the places with the current one selected, and the host's status at
/// the foot.
class _SampleSidebar extends StatelessWidget {
  const _SampleSidebar();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Preview: `.nav{padding:8px 12px;border-radius:999px;font-size:14px;line-height:20px}`, 14/20 snapping
    // to `body`; `.nav.sel{background:accent-soft;color:accent;font-weight:600}`.
    Widget place(String name, {bool selected = false}) => Container(
          padding: EdgeInsets.symmetric(horizontal: context.space(3), vertical: context.space(2)),
          decoration: context.radius.decorate(BoxDecoration(color: selected ? c.accentSoft : null, borderRadius: MyDataRadii.pill(context.look))),
          child: Text(name,
              maxLines: 1,
              softWrap: false,
              style: selected
                  ? context.typeScale.bodyStrong.copyWith(color: c.accent)
                  : context.typeScale.body.copyWith(color: c.inkMuted)),
        );

    // Preview: `.side{padding:16px 8px;gap:2px}`; the 2px gap snaps to space-1.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.space(2), vertical: context.space(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview: `.app{font:700 17px/22px display;padding:0 10px 10px}`; 10px snaps to space-3, so the
          // name lines up with the places.
          Padding(
            padding: EdgeInsets.fromLTRB(context.space(3), 0, context.space(3), context.space(3)),
            child: Text('myPhotos', maxLines: 1, softWrap: false, style: context.typeScale.heading.copyWith(color: c.ink)),
          ),
          place('Library', selected: true),
          SizedBox(height: context.space(1)),
          place('Albums'),
          SizedBox(height: context.space(1)),
          place('People'),
          SizedBox(height: context.space(1)),
          place('Places'),
          const Spacer(),
          // Preview: `.host{margin-top:auto;padding:8px 10px;font-size:12px}` with a 7px `brand` dot and a 6px
          // gap; 10px snaps to space-3, 12px text to `caption`, the 6px gap to space-2.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.space(3), vertical: context.space(2)),
            child: Text.rich(
              TextSpan(children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(end: context.space(2)),
                    child: Container(
                      key: const ValueKey('theme-sample-host-dot'),
                      width: ThemeSample.hostDotSize,
                      height: ThemeSample.hostDotSize,
                      decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                    ),
                  ),
                ),
                const TextSpan(text: 'Connected to your host'),
              ]),
              style: context.typeScale.caption.copyWith(color: c.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
