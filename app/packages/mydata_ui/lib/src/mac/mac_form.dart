import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../theme/motion.dart';
import '../theme/theme.dart';
import '../widgets/pressable.dart';
import 'mac_chrome.dart';
import 'mac_metrics.dart';
import 'mac_theme.dart';

/// The Mac frame's grouped forms, as System Settings and an app's Settings window draw them (plan section 5:
/// "Inset groups only in forms and Settings"; SwiftUI's `Form` with the grouped style on macOS 26):
///
/// - [MacForm]: the page, a centred column at most [MacForm.columnWidth] wide that scrolls;
/// - [MacFormSection]: an optional heading in `body-emphasized`, then a rounded group of rows on a faint
///   fill (`hover` over `content-background`) with a `separator` outline and hairlines between rows, then an
///   optional footer in `caption` and `secondary-label`;
/// - [MacFormRow]: a title in `body`, a line under it in `caption`, and a control at the end;
/// - [MacFormPart]: anything else in a group (a short form, a sentence);
/// - controls: [MacSwitch], [MacSegmented], [MacDisclosure], [MacStatusDot]; text in a [MacEditField].
///
/// Mac density: rows `control-height` plus `space-3` tall at least, controls `push-button-height`. In a drawn
/// theme ([MacLookMetrics]) the theme's type (secondary text italic where it says so), control height and
/// corners, and its card outline round a group where it outlines cards.
class MacForm extends StatelessWidget {
  const MacForm({super.key, required this.children, this.controller, this.maxWidth = MacForm.columnWidth});

  final List<Widget> children;
  final ScrollController? controller;

  /// The column's width: about a Settings window's pane.
  final double maxWidth;

  static const double columnWidth = MyDataMacSize.contentWidth;

  /// Between sections.
  static double gap(MyDataLook look) => look.space(5);

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return DefaultTextStyle.merge(
      style: context.macLook.body.copyWith(color: mac.label),
      child: SingleChildScrollView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(context.space(5), context.space(2), context.space(5), context.space(8)),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, child) in children.indexed) ...[if (i > 0) SizedBox(height: gap(context.look)), child],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One group of a [MacForm]. See [MacForm].
class MacFormSection extends StatelessWidget {
  const MacFormSection({super.key, this.heading, this.footer, required this.rows});

  final String? heading;

  /// A sentence or two under the group, for what the rows do not say.
  final String? footer;
  final List<Widget> rows;

  /// The group's corners: a Settings group's, the nearest token (in a drawn theme, its corner style).
  static BorderRadius radius(MyDataLook look) => BorderRadius.all(Radius.circular(look.shape.sm));

  /// The group's fill: `hover` over `content-background`, a shade off the page in both appearances.
  static Color fill(BuildContext context) => Color.alphaBlend(context.mac.hover, context.mac.contentBackground);

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    // A drawn theme whose lists are ruled (Journal, E-ink) rules its groups too: no box and no fill, a rule
    // above and below and between the rows, in its border colour, as its shared lists are drawn.
    final ruled = !context.isSystemLook && context.variants.list == ListStyle.ruled;
    // One whose lists are plain with no separators (Terminal, Notebook) draws nothing round or between its
    // rows, as its shared lists: the rows stand on the window's ground (Notebook's ruled paper).
    final bare = !context.isSystemLook &&
        context.variants.list == ListStyle.plain &&
        context.look.edges.separators == Separators.none;
    final rule = context.look.edges.side;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading != null)
          Padding(
            padding: EdgeInsets.fromLTRB(context.space(3), 0, context.space(3), context.space(2)),
            child: Semantics(
              header: true,
              child: Text(heading!, style: context.macLook.bodyEmphasized.copyWith(color: mac.label)),
            ),
          ),
        if (rows.isNotEmpty)
          DecoratedBox(
            decoration: bare
                ? const BoxDecoration()
                : ruled
                ? BoxDecoration(border: Border(top: rule, bottom: rule))
                : context.macLook.decorate(BoxDecoration(
              color: fill(context),
              borderRadius: radius(context.look),
              border: Border.fromBorderSide(context.isSystemLook
                  ? BorderSide(color: mac.separator, width: MyDataMacSize.hairline)
                  : (context.look.edges.card ?? BorderSide(color: mac.separator, width: MyDataMacSize.hairline))),
            )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, row) in rows.indexed) ...[
                  if (i > 0 && !bare)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: ruled ? 0 : context.space(3)),
                      child: Container(height: ruled ? rule.width : 1, color: ruled ? rule.color : mac.separator),
                    ),
                  row,
                ],
              ],
            ),
          ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.fromLTRB(context.space(3), context.space(2), context.space(3), 0),
            child: Text(footer!,
                style: context.macLook.secondary(context.macLook.caption).copyWith(color: mac.secondaryLabel)),
          ),
      ],
    );
  }
}

/// One row of a [MacFormSection]: an optional [icon] in `secondary-label`, the [title] over an optional
/// [subtitle] (wrapping), and [trailing] controls at the end, `space-2` apart. Read as one node.
class MacFormRow extends StatelessWidget {
  const MacFormRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing = const [],
    this.subtitleColor,
  });

  final MyDataIcon? icon;
  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  /// The subtitle's colour when it says something is wrong; null: `secondary-label`.
  final Color? subtitleColor;

  static double minHeight(MyDataLook look, {bool system = true}) =>
      MacLookMetrics.forLook(look, system: system).controlHeight + look.space(3);
  static EdgeInsets padding(MyDataLook look) => EdgeInsets.symmetric(horizontal: look.space(3), vertical: look.space(2));

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final m = context.macLook;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight(context.look, system: m.system)),
      child: Padding(
        padding: padding(context.look),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(context.icon(icon!), size: m.icon, color: mac.secondaryLabel),
              SizedBox(width: context.space(2)),
            ],
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: m.body.copyWith(color: mac.label)),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: MyDataMacSize.tight),
                        child: Text(
                          subtitle!,
                          style: m.secondary(m.caption).copyWith(color: subtitleColor ?? mac.secondaryLabel),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final (i, w) in trailing.indexed) ...[
              SizedBox(width: i == 0 ? context.space(3) : context.space(2)),
              w,
            ],
          ],
        ),
      ),
    );
  }
}

/// Anything else in a [MacFormSection] (a short form, a paragraph), with a row's padding.
class MacFormPart extends StatelessWidget {
  const MacFormPart({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.space(3)),
    child: DefaultTextStyle.merge(style: context.macLook.body.copyWith(color: context.mac.label), child: child),
  );
}

/// A value at a row's end, in `body` and `secondary-label` ("Allowed", "128 contacts").
class MacFormValue extends StatelessWidget {
  const MacFormValue(this.text, {super.key, this.dot});

  final String text;

  /// A [MacStatusDot] before the text, in this colour.
  final Color? dot;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (dot != null) ...[MacStatusDot(color: dot!), SizedBox(width: context.space(1) + MyDataMacSize.tight)],
      Text(text, style: context.macLook.secondary(context.macLook.body).copyWith(color: context.mac.secondaryLabel)),
    ],
  );
}

/// A small status dot, as the system's status lights (green running, yellow waiting, red failed).
class MacStatusDot extends StatelessWidget {
  const MacStatusDot({super.key, required this.color});

  final Color color;

  static double size(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size(context.look),
      height: size(context.look),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// The system's switch (NSSwitch at its regular size): the accent track when on, `quaternary-label` when off,
/// a round `on-accent` thumb with a hairline; square, track and thumb, in a drawn theme whose corners are. [onChanged] null disables it (45%). [semanticLabel] names it
/// when the row's title is not right beside it.
class MacSwitch extends StatelessWidget {
  const MacSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  static const height = MyDataMacSize.controlMin + MyDataMacSize.tight;
  static const width = height * 1.75;
  static const inset = MyDataMacSize.tight;
  static const _radius = BorderRadius.all(Radius.circular(MyDataMacRadius.field));

  /// The track's corners: the system's capsule, or none in a drawn theme whose corners are square
  /// (Terminal, Brutalist), whose thumb is then a square too.
  static BorderRadius radius(BuildContext context) => square(context) ? BorderRadius.zero : _radius;

  /// Whether the switch is drawn square ([radius]).
  static bool square(BuildContext context) =>
      !context.isSystemLook && context.look.shape.corners == CornerStyle.square;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    const thumb = height - 2 * inset;
    final target = context.macLook.target;
    final square = MacSwitch.square(context);
    final radius = MacSwitch.radius(context);
    final toggle = onChanged == null ? null : () => onChanged!(!value);
    final Widget control = Pressable(
      onPressed: toggle,
      borderRadius: radius,
      scaleOnPress: false,
      button: false,
      toggled: value,
      semanticLabel: semanticLabel,
      child: AnimatedContainer(
        duration: MyDataMotion.reduced(context) ? Duration.zero : context.motion.fast,
        curve: context.motion.standard,
        width: width,
        height: height,
        padding: const EdgeInsets.all(inset),
        alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        decoration: BoxDecoration(color: value ? mac.accent : mac.quaternaryLabel, borderRadius: radius),
        child: Container(
          width: thumb,
          height: thumb,
          decoration: BoxDecoration(
            color: mac.onAccent,
            shape: square ? BoxShape.rectangle : BoxShape.circle,
            border: Border.all(color: mac.separator, width: MyDataMacSize.hairline),
          ),
        ),
      ),
    );
    if (target <= 0) return control;
    // A theme that promises its control height for every target (Large): the switch, drawn at the Mac's
    // size, takes the press over that much around it, and its accessible node is that box.
    return Semantics(
      container: true,
      toggled: value,
      enabled: onChanged != null,
      label: semanticLabel,
      onTap: toggle,
      child: ExcludeSemantics(child: MacTarget(min: Size.square(target), onTap: toggle, child: control)),
    );
  }
}

/// A segmented control: [segments] as (value, label), one [selected]. In a form ([toolbar] false) a
/// `push-button-height` capsule on `quaternary-label` whose selected segment is raised on `toolbar-item`; in
/// the toolbar band a `toolbar-item-height` capsule on `toolbar-item` (the glass stand-in) whose selected
/// segment has the `sidebar-selection` fill, as a window's tabs. Left and Right move the choice.
class MacSegmented<T> extends StatefulWidget {
  const MacSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
    this.toolbar = false,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final String semanticLabel;
  final bool toolbar;

  @override
  State<MacSegmented<T>> createState() => _MacSegmentedState<T>();
}

class _MacSegmentedState<T> extends State<MacSegmented<T>> {
  bool _focused = false;

  int get _index => widget.segments.indexWhere((s) => s.$1 == widget.selected);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final change = widget.onChanged;
    if (change == null) return KeyEventResult.ignored;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      _ => 0,
    };
    if (step == 0) return KeyEventResult.ignored;
    final to = (_index + step).clamp(0, widget.segments.length - 1);
    if (to != _index) change(widget.segments[to].$1);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final m = context.macLook;
    final toolbar = widget.toolbar;
    final height = toolbar ? m.toolbarItemHeight : m.pushButtonHeight;
    final shape = m.controlRadius;
    final rest = m.itemSide ?? BorderSide(color: mac.separator, width: MyDataMacSize.hairline);
    final enabled = widget.onChanged != null;
    // A drawn theme whose tabs are boxed marks the current segment as its shared tabs do, in `selection`
    // with `on-selection` (High Contrast's inverse), never with a faint tint alone.
    final boxed = !context.isSystemLook && context.variants.tabs == TabsStyle.boxed;
    // A theme that promises its control height for every target (Large): each segment takes the press over
    // that much (the band's height in the toolbar), around the control drawn at its own height.
    final target = toolbar ? m.toolbarTarget : m.target;
    final tall = target > height;
    final capsule = m.decorate(BoxDecoration(
      color: toolbar ? mac.toolbarItem : mac.quaternaryLabel,
      borderRadius: shape,
      border: _focused
          ? Border.all(color: FocusRing.colourFor(context), width: MyDataMacSize.focusRingWidth)
          : (toolbar || m.itemSide != null ? Border.fromBorderSide(rest) : null),
    ));
    Widget segment(T value, Widget face) => tall
        ? ConstrainedBox(
            constraints: BoxConstraints(minWidth: target, minHeight: target, maxHeight: target),
            child: Center(child: SizedBox(height: height - 2 * MyDataMacSize.tight, child: face)),
          )
        : face;
    final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in widget.segments)
            Semantics(
              button: true,
              selected: value == widget.selected,
              enabled: enabled,
              label: label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? () => widget.onChanged!(value) : null,
                child: segment(value, AnimatedContainer(
                  duration: MyDataMotion.reduced(context) ? Duration.zero : context.motion.fast,
                  padding: EdgeInsets.symmetric(horizontal: toolbar ? context.space(4) : context.space(3)),
                  alignment: Alignment.center,
                  decoration: m.decorate(BoxDecoration(
                    color: value == widget.selected
                        ? (boxed ? context.colors.selection : (toolbar ? mac.sidebarSelection : mac.toolbarItem))
                        : null,
                    borderRadius: shape,
                    border: value == widget.selected && !toolbar
                        ? Border.all(color: mac.separator, width: MyDataMacSize.hairline)
                        : null,
                  )),
                  child: Text(
                    label,
                    style: (value == widget.selected && toolbar ? m.bodyEmphasized : m.body)
                        .copyWith(
                            color: !enabled
                                ? mac.tertiaryLabel
                                : (boxed && value == widget.selected ? context.colors.onSelection : mac.label)),
                  ),
                )),
              ),
            ),
        ],
      );
    Widget control = tall
        // The capsule at its own height behind segments as tall as the target.
        ? SizedBox(
            height: target,
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(
                child: Center(child: SizedBox(height: height, width: double.infinity, child: DecoratedBox(decoration: capsule))),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.tight), child: row),
            ]),
          )
        : Container(
            height: height,
            padding: const EdgeInsets.all(MyDataMacSize.tight),
            decoration: capsule,
            child: row,
          );
    control = Semantics(
      container: true,
      label: widget.semanticLabel,
      child: Focus(
        canRequestFocus: enabled,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: control,
      ),
    );
    return toolbar ? MacChrome.of(context).toolbarItem(control) : control;
  }
}

/// A disclosure row, as SwiftUI's DisclosureGroup: a chevron that turns down when [open], the [title] in
/// `body`, and [child] under it while open. The whole row toggles it.
class MacDisclosure extends StatelessWidget {
  const MacDisclosure({
    super.key,
    required this.title,
    required this.open,
    required this.onToggle,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          expanded: open,
          child: Pressable(
            onPressed: onToggle,
            borderRadius: MacFormSection.radius(context.look),
            scaleOnPress: false,
            semanticLabel: title,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: MacFormRow.minHeight(context.look, system: context.macLook.system)),
                child: Padding(
                  padding: MacFormRow.padding(context.look),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: open ? 0.25 : 0,
                        duration: MyDataMotion.reduced(context) ? Duration.zero : context.motion.fast,
                        curve: context.motion.standard,
                        child: Icon(context.icon(MyDataIcon.chevronRight), size: MyDataMacSize.icon - MyDataMacSize.tight, color: mac.secondaryLabel),
                      ),
                      SizedBox(width: context.space(2)),
                      Expanded(child: Text(title, style: context.macLook.body.copyWith(color: mac.label))),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: context.macLook.secondary(context.macLook.body).copyWith(color: mac.secondaryLabel)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (open) child,
      ],
    );
  }
}
