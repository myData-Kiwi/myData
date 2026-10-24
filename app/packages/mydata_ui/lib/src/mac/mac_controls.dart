import 'dart:async';
import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/cupertino.dart' show cupertinoDesktopTextSelectionControls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import '../widgets/form_row.dart' show FormRemoveButton;
import '../widgets/form_scope.dart';
import '../widgets/menu.dart';
import '../widgets/pressable.dart';
import 'mac_metrics.dart';
import 'mac_theme.dart';

/// The Mac frame's form controls (docs/2026-10-23-plan.md section 5, "Mac density"): what a form in the Mac
/// frame is made of where the branded controls (`control-height` 44, `radius-md`, Figtree) would look like
/// another platform's. They keep the branded controls' rules (a reason for every disabled control, read-only
/// while the form waits for the host, errors said in words under the field) at the Mac's sizes, in the system
/// font and colours. Added for myContacts' contact editor (M1a look pass); any app's Mac form can use them.
///
/// - [MacEditField]: the one text field of the Mac frame: a `push-button-height` rounded field (or the text
///   area, or a password field), its accessible name given, its label drawn by the form (a label column, as
///   Contacts' editor has, or a Settings row), its error under it.
/// - [MacPopUpButton]: a pop-up button, bezeled (Merge's "Keep the name and details of") or borderless (a
///   value's label in the editor, "mobile ⌄"), opening a [Menu] with a check mark on the current item.
abstract final class MacControl {
  /// A field's and a pop-up button's height: the Mac's regular control size (`push-button-height`).
  static const height = MyDataMacSize.pushButtonHeight;

  /// A field's corners.
  static const radius = BorderRadius.all(Radius.circular(MyDataMacRadius.selection));

  /// Text inside a field, from its edge.
  static double inset(MyDataLook look) => look.space(2);

  /// Between a field and the line under it (its error).
  static double noteGap(MyDataLook look) => look.space(1);

  /// The field's bezel: `content-background` with a hairline in `tertiary-label` (a stronger hairline than
  /// `separator`, as an NSTextField's bezel), `danger` in error.
  static BoxDecoration bezel(BuildContext context, {bool error = false}) {
    final mac = context.mac;
    return BoxDecoration(
      color: mac.contentBackground,
      borderRadius: radius,
      border: Border.all(color: error ? context.colors.danger : mac.tertiaryLabel),
    );
  }
}

/// A text field in the Mac frame: [MacControl.height] tall (the text area grows from three lines), the value
/// in `body` and `label`, the placeholder in `tertiary-label`, the system's focus ring around it.
///
/// - [label] is its accessible name; the form shows it where it belongs (a label column, a placeholder).
/// - **Error:** the bezel in `danger`, and [error] under it in `caption` and `danger`, read with the field.
/// - Read-only while its form waits for the host ([FormBusy]); disabled at 45%.
/// - [MacEditField.multiline]: Return inserts a line; ⌘Return is left to the form (Save).
/// - [obscure]: a password field (secure text, never shown).
class MacEditField extends StatefulWidget {
  const MacEditField({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.placeholder,
    this.error,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
  }) : multiline = false;

  const MacEditField.multiline({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.placeholder,
    this.error,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
  })  : multiline = true,
        onSubmitted = null,
        obscure = false,
        textInputAction = TextInputAction.newline,
        keyboardType = TextInputType.multiline;

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final String? error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final bool multiline;

  /// The text area's height in lines: three to start, twelve before it scrolls (as MyDataTextField's).
  static const minLines = 3;
  static const maxLines = 12;

  @override
  State<MacEditField> createState() => _MacEditFieldState();
}

class _MacEditFieldState extends State<MacEditField> {
  FocusNode? _own;
  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'MacEditField'));

  @override
  void initState() {
    super.initState();
    _node.addListener(_changed);
  }

  @override
  void didUpdateWidget(MacEditField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _own)?.removeListener(_changed);
      _node.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _node.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final c = context.colors;
    final error = widget.error;
    final style = context.macLook.body.copyWith(color: mac.label);
    final line = style.fontSize! * style.height!;
    final vertical = widget.multiline ? context.space(1) : (MacControl.height - line) / 2 - MyDataMacSize.hairline * 2;
    final field = TextField(
      controller: widget.controller,
      focusNode: _node,
      enabled: widget.enabled,
      readOnly: FormBusy.of(context),
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.obscure,
      minLines: widget.multiline ? MacEditField.minLines : null,
      maxLines: widget.multiline ? MacEditField.maxLines : 1,
      style: style,
      cursorColor: mac.accent,
      cursorHeight: style.fontSize! + MyDataMacSize.tight,
      // The Mac's own selection: no touch handles, the system's menu.
      selectionControls: cupertinoDesktopTextSelectionControls,
      textAlignVertical: widget.multiline ? TextAlignVertical.top : TextAlignVertical.center,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        filled: false,
        hintText: widget.placeholder,
        hintStyle: style.copyWith(color: mac.tertiaryLabel),
        hintMaxLines: 1,
        contentPadding: EdgeInsets.symmetric(horizontal: MacControl.inset(context.look) - MyDataMacSize.hairline * 2, vertical: vertical),
      ),
    );
    Widget box = FocusRing(
      visible: widget.enabled && _node.hasFocus,
      borderRadius: MacControl.radius,
      child: Container(
        height: widget.multiline ? null : MacControl.height,
        decoration: MacControl.bezel(context, error: error != null),
        child: field,
      ),
    );
    if (!widget.enabled) box = Opacity(opacity: Pressable.disabledOpacity, child: box);
    return Semantics(
      label: widget.label,
      hint: error,
      validationResult: error != null ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          box,
          if (error != null) ...[
            SizedBox(height: MacControl.noteGap(context.look)),
            ExcludeSemantics(child: Text(error, style: context.macLook.caption.copyWith(color: c.danger))),
          ],
        ],
      ),
    );
  }
}

/// One choice of a [MacPopUpButton].
@immutable
class MacPopUpItem<T> {
  const MacPopUpItem({required this.value, required this.title});
  final T value;
  final String title;
}

/// A pop-up button in the Mac frame: it shows the current choice and opens a [Menu] of [items] with a check
/// mark on it (as NSPopUpButton).
///
/// - **Bezeled** (the default): [MacControl.height] tall on `content-background` with a hairline, the
///   choice in `body`, up and down chevrons at the end in the accent.
/// - **Borderless** ([bordered] false): the choice in `callout` and `secondary-label` with a small chevron,
///   a `hover` fill under the pointer: a value's label in an editing form ("mobile ⌄"), right-aligned in its
///   label column as Contacts' editor draws it.
/// - [onCustom] adds "Custom label…" after a separator; the holder asks for the label (a Dialog with a
///   field).
/// - Opened from the keyboard (Space, Return, Down) focus goes to the menu's first item; the menu lines up
///   with the button's start edge, under it.
/// - [label] is its accessible name and the menu's; the choice is read as its value. Read-only while its form
///   waits for the host ([FormBusy]); with [onChanged] null it is disabled, with [disabledReason] as its
///   tooltip and hint.
class MacPopUpButton<T> extends StatefulWidget {
  const MacPopUpButton({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.shown,
    this.onCustom,
    this.customLabel = defaultCustomLabel,
    this.bordered = true,
    this.focusNode,
    this.autofocus = false,
    this.disabledReason,
  });

  final String label;
  final List<MacPopUpItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;

  /// What the button shows when [value] is none of [items] (a custom label); null shows [value]'s item.
  final String? shown;

  final VoidCallback? onCustom;
  final String customLabel;
  final bool bordered;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? disabledReason;

  static const defaultCustomLabel = 'Custom label…';

  @override
  State<MacPopUpButton<T>> createState() => _MacPopUpButtonState<T>();
}

class _MacPopUpButtonState<T> extends State<MacPopUpButton<T>> {
  final _key = GlobalKey();
  bool _hovered = false;

  String get _shown =>
      widget.shown ?? widget.items.where((i) => i.value == widget.value).firstOrNull?.title ?? '';

  Future<void> _open({bool fromKeyboard = false}) async {
    final onChanged = widget.onChanged;
    if (onChanged == null || FormBusy.read(context)) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    await Menu.showAt(
      context,
      position: rect.bottomLeft + Offset(0, Menu.anchorGap(context.look)),
      fromKeyboard: fromKeyboard,
      compact: true,
      entries: [
        for (final i in widget.items)
          MenuItem(label: i.title, checked: i.value == widget.value, onSelected: () => onChanged(i.value)),
        if (widget.onCustom != null) ...[
          const MenuSeparator(),
          MenuItem(label: widget.customLabel, onSelected: widget.onCustom!),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final enabled = widget.onChanged != null;
    final Widget face;
    if (widget.bordered) {
      face = Container(
        height: MacControl.height,
        padding: EdgeInsetsDirectional.only(start: MacControl.inset(context.look), end: context.space(1)),
        decoration: MacControl.bezel(context),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text(_shown,
                maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false,
                style: context.macLook.body.copyWith(color: mac.label)),
          ),
          SizedBox(width: context.space(2)),
          Icon(context.icon(MyDataIcon.upDown), size: MyDataMacSize.icon - context.space(1), color: mac.accent),
        ]),
      );
    } else {
      face = Container(
        height: MacControl.height,
        padding: EdgeInsets.symmetric(horizontal: context.space(1)),
        decoration: BoxDecoration(color: _hovered && enabled ? mac.hover : null, borderRadius: MacControl.radius),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text(_shown,
                maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, textAlign: TextAlign.end,
                style: context.macLook.secondary(context.macLook.callout).copyWith(color: mac.secondaryLabel)),
          ),
          SizedBox(width: context.space(1)),
          Icon(context.icon(MyDataIcon.chevronDown), size: MyDataMacSize.icon - context.space(1), color: mac.secondaryLabel),
        ]),
      );
    }
    return MergeSemantics(
      child: Semantics(
        value: _shown,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, e) {
              if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowDown) {
                unawaited(_open(fromKeyboard: true));
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Pressable(
              key: _key,
              onPressed: enabled ? () => unawaited(_open(fromKeyboard: _keyboardActivation())) : null,
              borderRadius: MacControl.radius,
              scaleOnPress: false,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              semanticLabel: widget.label,
              disabledReason: enabled ? null : widget.disabledReason,
              tooltip: enabled ? null : widget.disabledReason,
              child: face,
            ),
          ),
        ),
      ),
    );
  }

  /// A press from the keyboard (Space, Return) opens the menu with focus on its first item.
  static bool _keyboardActivation() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.space) ||
        keys.contains(LogicalKeyboardKey.enter) ||
        keys.contains(LogicalKeyboardKey.numpadEnter);
  }
}

/// A row of a form in the Mac frame: a right-aligned label column (`label-column` plus [extra], as a record's
/// page and Contacts' editor), then the control. [label] is drawn in `callout` and `secondary-label` on the
/// control's first line, or is a control itself (a [MacPopUpButton]); [leading] sits before it at the
/// column's start (a remove button).
class MacEditorRow extends StatelessWidget {
  const MacEditorRow({super.key, this.label, this.leading, required this.child, this.extra = 0});

  final Widget? label;
  final Widget? leading;
  final Widget child;

  /// Added to the label column's width (an editor's labels are pop-up buttons with a chevron).
  final double extra;

  /// Between the label column and the control.
  static double gap(MyDataLook look) => look.space(3);

  /// A label in the column: [text] in `callout` and `secondary-label`, right-aligned, on the control's line.
  static Widget text(BuildContext context, String text) => SizedBox(
        height: MacControl.height,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          widthFactor: 1,
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
              style: context.macLook.secondary(context.macLook.callout).copyWith(color: context.mac.secondaryLabel)),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MyDataMacSize.labelColumn + extra,
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                ?leading,
                if (label != null) Flexible(child: label!),
              ]),
            ),
          ),
          SizedBox(width: gap(context.look)),
          Expanded(child: child),
        ],
      );
}

/// The remove button before a value in a Mac editing form: the minus-in-a-circle in `danger`, as Contacts'
/// editor has it, [MacControl.height] square, its [label] as its name and tooltip ("Remove mobile number").
class MacRemoveButton extends StatelessWidget {
  const MacRemoveButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
        // While the form waits for the host it stays as it is and does nothing (FormBusy).
        onPressed: onPressed == null
            ? null
            : () {
                if (!FormBusy.read(context)) onPressed!();
              },
        borderRadius: MacControl.radius,
        scaleOnPress: false,
        semanticLabel: label,
        tooltip: label,
        hoverFill: context.mac.hover,
        disabledReason: onPressed == null ? FormRemoveButton.defaultDisabledReason : null,
        child: SizedBox.square(
          dimension: MacControl.height,
          child: Icon(context.icon(MyDataIcon.remove), size: MyDataMacSize.icon, color: context.colors.danger),
        ),
      );
}

/// "Add phone", "Add email": the add button of a Mac editing form, as Contacts' edit mode draws it: a small
/// round button in the system's green with a white plus, then the [label] in `body` and `label`, borderless
/// (the `hover` fill under the pointer). [MacControl.height] tall, so the form's rows keep one pitch.
class MacAddButton extends StatelessWidget {
  const MacAddButton({super.key, required this.label, required this.onPressed, this.focusNode});

  final String label;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  /// The round button: the size of a remove button's glyph.
  static const size = MyDataMacSize.icon;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return Pressable(
      onPressed: onPressed == null
          ? null
          : () {
              if (!FormBusy.read(context)) onPressed!();
            },
      focusNode: focusNode,
      borderRadius: MacControl.radius,
      scaleOnPress: false,
      semanticLabel: label,
      hoverFill: mac.hover,
      child: Container(
        height: MacControl.height,
        padding: EdgeInsetsDirectional.only(start: context.space(1), end: context.space(2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: mac.green, shape: BoxShape.circle),
            child: Icon(context.icon(MyDataIcon.add), size: size - 2 * MyDataMacSize.tight, color: MyDataMacColors.light.onAccent),
          ),
          SizedBox(width: context.space(2)),
          Text(label, style: context.macLook.body.copyWith(color: mac.label)),
        ]),
      ),
    );
  }
}
