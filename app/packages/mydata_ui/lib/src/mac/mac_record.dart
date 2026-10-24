import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart' show Avatar;
import '../widgets/menu.dart';
import 'mac_metrics.dart';
import 'mac_overlays.dart' show MacMenuLook;
import 'mac_theme.dart';

/// The top of a record's page in the Mac frame (plan section 5, "Person page"): the avatar at
/// `avatar` (64pt), the name in `name` beside it, one line under it in `body` and `secondary-label` (job
/// title and company), and the round [actions] under that. Name and line can be selected.
class MacRecordHeader extends StatelessWidget {
  const MacRecordHeader({
    super.key,
    required this.avatar,
    required this.name,
    this.subtitle = '',
    this.actions = const [],
    this.badge,
  });

  final Widget avatar;
  final String name;
  final String subtitle;
  final List<Widget> actions;

  /// A small glyph after the name: where the record comes from ([MacSourceBadge]).
  final Widget? badge;

  /// Between the avatar and the name.
  static double gap(MyDataLook look) => look.space(4);

  /// Between the round actions.
  static double actionGap(MyDataLook look) => look.space(4);

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A drawn theme without avatars leaves out its place too.
        if (Avatar.shown(context)) ...[avatar, SizedBox(width: gap(context.look))],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: context.space(1)),
              SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Semantics(
                          header: true,
                          // In a drawn theme its `title`, in the display face where it sets titles in one.
                          child: Text(name, style: context.macLook.name.copyWith(color: mac.label)),
                        ),
                      ),
                      if (badge != null) ...[SizedBox(width: context.space(2)), badge!],
                    ]),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: context.macLook.secondary(context.macLook.body).copyWith(color: mac.secondaryLabel)),
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                SizedBox(height: context.space(3)),
                Wrap(spacing: actionGap(context.look), runSpacing: context.space(2), children: actions),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A round quick action under a record's name (message, call, video, mail, map): an `action-button` circle
/// on `quaternary-label` with the icon in the accent, its word under it in `action` and `secondary-label`. Disabled
/// (no number, no address): both in `tertiary-label`, the [disabledReason] in its tooltip and hint.
class MacQuickAction extends StatefulWidget {
  const MacQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.disabledReason,
  });

  final MyDataIcon icon;

  /// The word under the circle, in lower case as the system's apps write it ("message").
  final String label;

  /// The tooltip and accessible name ("Message Ava"); null: [label].
  final String? tooltip;
  final VoidCallback? onPressed;
  final String? disabledReason;

  @override
  State<MacQuickAction> createState() => _MacQuickActionState();
}

class _MacQuickActionState extends State<MacQuickAction> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final m = context.macLook;
    final enabled = widget.onPressed != null;
    final tint = enabled ? mac.accent : mac.tertiaryLabel;
    // A circle in System and where the theme's controls are capsules; the theme's control corners else.
    final round = m.system || context.look.variants.buttonShape == ButtonShapeStyle.pill;
    final name = widget.tooltip ?? widget.label;
    return Semantics(
      button: true,
      enabled: enabled,
      label: name,
      hint: enabled ? null : widget.disabledReason,
      excludeSemantics: true,
      child: Tooltip(
        message: enabled || widget.disabledReason == null ? name : '$name\n${widget.disabledReason}',
        waitDuration: const Duration(milliseconds: 700),
        child: MacTarget(
          min: Size.square(m.target),
          onTap: widget.onPressed,
          child: FocusableActionDetector(
            enabled: enabled,
            onShowFocusHighlight: (f) => setState(() => _focused = f),
            actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call())},
            child: GestureDetector(
              onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
              onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onPressed,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: MyDataMacSize.actionButton,
                    height: MyDataMacSize.actionButton,
                    decoration: round
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            color: _pressed ? mac.tertiaryLabel : mac.quaternaryLabel,
                            border: _focused ? Border.all(color: mac.focusRing, width: MyDataMacSize.focusRingWidth) : null,
                          )
                        : m.decorate(BoxDecoration(
                            borderRadius: m.controlRadius,
                            color: _pressed ? mac.tertiaryLabel : mac.quaternaryLabel,
                            border: _focused
                                ? Border.all(color: mac.focusRing, width: MyDataMacSize.focusRingWidth)
                                : (m.itemSide == null ? null : Border.fromBorderSide(m.itemSide!)),
                          )),
                    child: Icon(context.icon(widget.icon), size: m.icon, color: tint),
                  ),
                  SizedBox(height: context.space(1)),
                  Text(widget.label, style: m.action.copyWith(color: enabled ? mac.secondaryLabel : tint)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One labelled value on a record's page.
@immutable
class MacField {
  const MacField({required this.label, required this.value, this.onOpen, this.copyName, this.openName});

  /// The label as the page shows it ("mobile", "home", "birthday").
  final String label;

  /// The value, exactly as the source wrote it; line breaks are kept (an address, a note).
  final String value;

  /// Clicking the value opens it (a web address); null: clicking copies it.
  final VoidCallback? onOpen;

  /// The copy action's name for screen readers and the menu ("Copy mobile number"); null: "Copy".
  final String? copyName;

  /// The open action's name ("Open website").
  final String? openName;
}

/// A record's values as Contacts.app lays them out (plan section 5, "label and value in two columns; click
/// to copy"): each [MacField] on a line, its label right-aligned in a `label-column` in `callout` and
/// `secondary-label`, the value beside it in `body` and `label`. [groups] are `space-4` apart (phones,
/// emails, addresses...). There are no cards and no copy buttons:
///
/// - **Clicking a value copies it** (a web address opens instead, in the accent; in a drawn theme in `link`
///   and underlined). For a moment its label
///   reads [copiedLabel] in the accent; screen readers hear it.
/// - **Right-click** offers Copy (and Open for a web address).
/// - Under the pointer a value gets the `hover` fill.
class MacFieldTable extends StatelessWidget {
  const MacFieldTable({super.key, required this.groups});

  final List<List<MacField>> groups;

  static const copiedLabel = 'copied';
  static const copyMenuLabel = 'Copy';
  static const openMenuLabel = 'Open';

  /// Between the label column and the values.
  static double gap(MyDataLook look) => look.space(3);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, group) in groups.where((g) => g.isNotEmpty).indexed) ...[
        if (i > 0) SizedBox(height: context.space(4)),
        for (final field in group) _FieldLine(field: field),
      ],
    ],
  );
}

class _FieldLine extends StatefulWidget {
  const _FieldLine({required this.field});

  final MacField field;

  @override
  State<_FieldLine> createState() => _FieldLineState();
}

class _FieldLineState extends State<_FieldLine> {
  /// A value's style. A web address is in the accent, as Contacts.app draws it, in System; in a drawn theme
  /// it is in `link` and underlined, as every link is (design/README.md "Links"), so it is never told from
  /// the text around it by colour alone (WCAG 1.4.1): Hairline's link is almost its ink.
  static TextStyle _valueStyle(BuildContext context, {required bool link}) {
    final mac = context.mac;
    if (context.isSystemLook) return MyDataMacType.body.copyWith(color: link ? mac.accent : mac.label);
    final c = context.colors;
    return context.macLook.body.copyWith(
      color: link ? c.link : mac.label,
      decoration: link ? TextDecoration.underline : null,
      decorationColor: link ? c.link : null,
    );
  }

  bool _hovered = false;
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.field.value));
    if (!mounted) return;
    SemanticsService.sendAnnouncement(View.of(context), MacFieldTable.copiedLabel, Directionality.of(context));
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final f = widget.field;
    final open = f.onOpen;
    final copyName = f.copyName ?? MacFieldTable.copyMenuLabel;
    final label = Text(
      _copied ? MacFieldTable.copiedLabel : f.label,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.macLook.secondary(context.macLook.callout).copyWith(color: _copied ? mac.accent : mac.secondaryLabel),
    );
    Widget value = Container(
      padding: EdgeInsets.symmetric(horizontal: context.space(1), vertical: 2 * MyDataMacSize.hairline),
      decoration: context.macLook.decorate(BoxDecoration(
        color: _hovered ? mac.hover : null,
        borderRadius: context.macLook.selectionRadius,
      )),
      child: Text(f.value, style: _valueStyle(context, link: open != null)),
    );
    value = MouseRegion(
      cursor: open != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(onTap: open ?? _copy, child: value),
    );
    value = ContextMenuRegion(
      compact: true,
      entries: () => [
        if (open != null) MenuItem(label: f.openName ?? MacFieldTable.openMenuLabel, onSelected: open),
        MenuItem(label: copyName, onSelected: () => unawaited(_copy())),
      ],
      child: value,
    );
    return Semantics(
      button: true,
      label: '${f.label}, ${f.value}',
      hint: open != null ? f.openName : copyName,
      onTap: open ?? () => unawaited(_copy()),
      customSemanticsActions: open == null ? null : {CustomSemanticsAction(label: copyName): () => unawaited(_copy())},
      excludeSemantics: true,
      // In a theme that promises its control height for every target (Large) the whole line takes the
      // press, at least that tall.
      child: MacTarget(
        min: Size(0, context.macLook.target),
        onTap: open ?? () => unawaited(_copy()),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MyDataMacSize.tight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: MyDataMacSize.labelColumn,
                child: Padding(
                  // The label sits on the value's first line.
                  padding: const EdgeInsets.only(top: MyDataMacSize.tight),
                  child: label,
                ),
              ),
              SizedBox(width: MacFieldTable.gap(context.look) - context.space(1)),
              Flexible(child: value),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a record comes from, as a small glyph with the full sentence as its help tag and accessible name
/// (plan 5.5: "Ownership and source as small glyph badges. Explanations behind ⓘ."): [MyDataIcon.cloud] for an
/// iCloud account, [MyDataIcon.thisMac] for this Mac, [MyDataIcon.host] for what the host owns. In
/// `secondary-label`, at `icon` size.
class MacSourceBadge extends StatelessWidget {
  const MacSourceBadge({super.key, required this.icon, required this.sentence});

  final MyDataIcon icon;

  /// "From the iCloud account you@example.com. Change it in your iCloud account."
  final String sentence;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return Semantics(
      label: sentence,
      excludeSemantics: true,
      child: MacMenuLook.helpTag(
        context,
        message: sentence,
        child: Icon(context.icon(icon), size: context.macLook.icon, color: mac.secondaryLabel),
      ),
    );
  }
}
