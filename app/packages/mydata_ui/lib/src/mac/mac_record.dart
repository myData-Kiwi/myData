import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../widgets/menu.dart';
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
  });

  final Widget avatar;
  final String name;
  final String subtitle;
  final List<Widget> actions;

  /// Between the avatar and the name.
  static const gap = MyDataSpace.s4;

  /// Between the round actions.
  static const actionGap = MyDataSpace.s4;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar,
        const SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: MyDataSpace.s1),
              SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(name, style: MyDataMacType.name.copyWith(color: mac.label))),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: MyDataMacType.body.copyWith(color: mac.secondaryLabel)),
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: MyDataSpace.s3),
                Wrap(spacing: actionGap, runSpacing: MyDataSpace.s2, children: actions),
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

  final IconData icon;

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
    final enabled = widget.onPressed != null;
    final tint = enabled ? mac.accent : mac.tertiaryLabel;
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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _pressed ? mac.tertiaryLabel : mac.quaternaryLabel,
                    border: _focused ? Border.all(color: mac.accent, width: 2) : null,
                  ),
                  child: Icon(widget.icon, size: MyDataMacSize.icon, color: tint),
                ),
                const SizedBox(height: MyDataSpace.s1),
                Text(widget.label, style: MyDataMacType.action.copyWith(color: enabled ? mac.secondaryLabel : tint)),
              ],
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
/// - **Clicking a value copies it** (a web address opens instead, in the accent). For a moment its label
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
  static const gap = MyDataSpace.s3;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, group) in groups.where((g) => g.isNotEmpty).indexed) ...[
        if (i > 0) const SizedBox(height: MyDataSpace.s4),
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
      style: MyDataMacType.callout.copyWith(color: _copied ? mac.accent : mac.secondaryLabel),
    );
    Widget value = Container(
      padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s1, vertical: 1),
      decoration: BoxDecoration(
        color: _hovered ? mac.hover : null,
        borderRadius: const BorderRadius.all(Radius.circular(MyDataMacRadius.selection)),
      ),
      child: Text(f.value, style: MyDataMacType.body.copyWith(color: open != null ? mac.accent : mac.label)),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: MyDataMacSize.labelColumn,
              child: Padding(
                // The label sits on the value's first line.
                padding: const EdgeInsets.only(top: 2),
                child: label,
              ),
            ),
            const SizedBox(width: MacFieldTable.gap - MyDataSpace.s1),
            Flexible(child: value),
          ],
        ),
      ),
    );
  }
}
