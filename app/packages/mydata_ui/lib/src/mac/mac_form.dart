import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../motion.dart';
import '../widgets/pressable.dart';
import 'mac_chrome.dart';
import 'mac_icons.dart';
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
/// Mac density: rows `control-height` plus `space-3` tall at least, controls `push-button-height`.
class MacForm extends StatelessWidget {
  const MacForm({super.key, required this.children, this.controller, this.maxWidth = MacForm.columnWidth});

  final List<Widget> children;
  final ScrollController? controller;

  /// The column's width: about a Settings window's pane.
  final double maxWidth;

  static const double columnWidth = MyDataMacSize.contentWidth;

  /// Between sections.
  static const gap = MyDataSpace.s5;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return DefaultTextStyle.merge(
      style: MyDataMacType.body.copyWith(color: mac.label),
      child: SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(MyDataSpace.s5, MyDataSpace.s2, MyDataSpace.s5, MyDataSpace.s8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(height: gap), child],
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

  /// The group's corners: a Settings group's, the nearest token.
  static const radius = BorderRadius.all(Radius.circular(MyDataRadius.sm));

  /// The group's fill: `hover` over `content-background`, a shade off the page in both appearances.
  static Color fill(BuildContext context) => Color.alphaBlend(context.mac.hover, context.mac.contentBackground);

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(MyDataSpace.s3, 0, MyDataSpace.s3, MyDataSpace.s2),
            child: Semantics(
              header: true,
              child: Text(heading!, style: MyDataMacType.bodyEmphasized.copyWith(color: mac.label)),
            ),
          ),
        if (rows.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: fill(context),
              borderRadius: radius,
              border: Border.all(color: mac.separator, width: MyDataMacSize.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, row) in rows.indexed) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s3),
                      child: Container(height: 1, color: mac.separator),
                    ),
                  row,
                ],
              ],
            ),
          ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(MyDataSpace.s3, MyDataSpace.s2, MyDataSpace.s3, 0),
            child: Text(footer!, style: MyDataMacType.caption.copyWith(color: mac.secondaryLabel)),
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

  final IconData? icon;
  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  /// The subtitle's colour when it says something is wrong; null: `secondary-label`.
  final Color? subtitleColor;

  static const minHeight = MyDataMacSize.controlHeight + MyDataSpace.s3;
  static const padding = EdgeInsets.symmetric(horizontal: MyDataSpace.s3, vertical: MyDataSpace.s2);

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: MyDataMacSize.icon, color: mac.secondaryLabel),
              const SizedBox(width: MyDataSpace.s2),
            ],
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: MyDataMacType.body.copyWith(color: mac.label)),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: MyDataMacSize.tight),
                        child: Text(
                          subtitle!,
                          style: MyDataMacType.caption.copyWith(color: subtitleColor ?? mac.secondaryLabel),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final (i, w) in trailing.indexed) ...[
              SizedBox(width: i == 0 ? MyDataSpace.s3 : MyDataSpace.s2),
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
    padding: const EdgeInsets.all(MyDataSpace.s3),
    child: DefaultTextStyle.merge(style: MyDataMacType.body.copyWith(color: context.mac.label), child: child),
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
      if (dot != null) ...[MacStatusDot(color: dot!), const SizedBox(width: MyDataSpace.s1 + MyDataMacSize.tight)],
      Text(text, style: MyDataMacType.body.copyWith(color: context.mac.secondaryLabel)),
    ],
  );
}

/// A small status dot, as the system's status lights (green running, yellow waiting, red failed).
class MacStatusDot extends StatelessWidget {
  const MacStatusDot({super.key, required this.color});

  final Color color;

  static const size = MyDataSpace.s2;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// The system's switch (NSSwitch at its regular size): the accent track when on, `quaternary-label` when off,
/// a round `on-accent` thumb with a hairline. [onChanged] null disables it (45%). [semanticLabel] names it
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

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    const thumb = height - 2 * inset;
    return Pressable(
      onPressed: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: _radius,
      scaleOnPress: false,
      button: false,
      toggled: value,
      semanticLabel: semanticLabel,
      child: AnimatedContainer(
        duration: MyDataMotion.reduced(context) ? Duration.zero : MyDataMotion.fast,
        curve: MyDataMotion.standard,
        width: width,
        height: height,
        padding: const EdgeInsets.all(inset),
        alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        decoration: BoxDecoration(color: value ? mac.accent : mac.quaternaryLabel, borderRadius: _radius),
        child: Container(
          width: thumb,
          height: thumb,
          decoration: BoxDecoration(
            color: mac.onAccent,
            shape: BoxShape.circle,
            border: Border.all(color: mac.separator, width: MyDataMacSize.hairline),
          ),
        ),
      ),
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
    final toolbar = widget.toolbar;
    final height = toolbar ? MyDataMacSize.toolbarItemHeight : MyDataMacSize.pushButtonHeight;
    const shape = BorderRadius.all(Radius.circular(MyDataMacRadius.field));
    final enabled = widget.onChanged != null;
    Widget control = Container(
      height: height,
      padding: const EdgeInsets.all(MyDataMacSize.tight),
      decoration: BoxDecoration(
        color: toolbar ? mac.toolbarItem : mac.quaternaryLabel,
        borderRadius: shape,
        border: _focused
            ? Border.all(color: FocusRing.colourFor(context), width: MyDataMacSize.focusRingWidth)
            : (toolbar ? Border.all(color: mac.separator, width: MyDataMacSize.hairline) : null),
      ),
      child: Row(
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
                child: AnimatedContainer(
                  duration: MyDataMotion.reduced(context) ? Duration.zero : MyDataMotion.fast,
                  padding: EdgeInsets.symmetric(horizontal: toolbar ? MyDataSpace.s4 : MyDataSpace.s3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == widget.selected ? (toolbar ? mac.sidebarSelection : mac.toolbarItem) : null,
                    borderRadius: shape,
                    border: value == widget.selected && !toolbar
                        ? Border.all(color: mac.separator, width: MyDataMacSize.hairline)
                        : null,
                  ),
                  child: Text(
                    label,
                    style: (value == widget.selected && toolbar ? MyDataMacType.bodyEmphasized : MyDataMacType.body)
                        .copyWith(color: enabled ? mac.label : mac.tertiaryLabel),
                  ),
                ),
              ),
            ),
        ],
      ),
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
            borderRadius: MacFormSection.radius,
            scaleOnPress: false,
            semanticLabel: title,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: MacFormRow.minHeight),
                child: Padding(
                  padding: MacFormRow.padding,
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: open ? 0.25 : 0,
                        duration: MyDataMotion.reduced(context) ? Duration.zero : MyDataMotion.fast,
                        curve: MyDataMotion.standard,
                        child: Icon(MacIcons.chevronRight, size: MyDataMacSize.icon - MyDataMacSize.tight, color: mac.secondaryLabel),
                      ),
                      const SizedBox(width: MyDataSpace.s2),
                      Expanded(child: Text(title, style: MyDataMacType.body.copyWith(color: mac.label))),
                      if (subtitle != null)
                        Text(subtitle!, style: MyDataMacType.body.copyWith(color: mac.secondaryLabel)),
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
