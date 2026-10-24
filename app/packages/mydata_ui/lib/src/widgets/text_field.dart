import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_frame.dart' show AppLayout, PhoneType;
import 'form_scope.dart';
import 'pressable.dart';

/// A single-line input with a label above and optional help below (design/components/TextField).
///
/// - The label is `label` style in `ink`, sentence case, `space-2` above the field.
/// - The field is `surface` with a 1px `line-strong` border, `radius-md`, `control-height`; text is `body` in
///   `ink`, or `mono` for paths and addresses ([mono]); the placeholder is `ink-muted`.
/// - [help] sits `space-2` below in `caption`, `ink-muted`.
/// - **Error:** with [error] set, the border is 2px `danger` and [error] replaces [help], in `danger`. Say what
///   is wrong and what a correct value looks like: "That address is incomplete. It looks like 192.168.1.20."
/// - Focus draws the 2px `focus` ring whenever the field holds focus (a text input always matches
///   `:focus-visible` in the preview, however it was focused). In error the ring is `ink`, so it cannot merge
///   with the red border (design/README.md "Focus and danger").
/// - Disabled: the label and the box at 45% opacity, not focusable; the [help] (the reason) is not faded.
/// - While its Dialog or Inspector waits for the host ([FormBusy]) it is read-only: focus stays, typing does
///   nothing.
/// - Under 600px the text is `body` at 16px ([PhoneType]); `mono` keeps its size.
///
/// The field fills the width it is given; put it in an [Expanded] or a sized box inside a [Row].
///
/// [MyDataTextField.multiline] is the text area, for text people write in sentences.
class MyDataTextField extends StatefulWidget {
  const MyDataTextField({
    super.key,
    required this.label,
    required this.controller,
    this.help,
    this.error,
    this.placeholder,
    this.mono = false,
    this.obscure = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.showLabel = true,
  }) : multiline = false;

  /// A TextField that takes several lines, for text people write in sentences: a contact's notes, an
  /// event's description (design/components/TextField, "Multi-line").
  ///
  /// - As the single-line field (label above, help or error below, `surface`, 1px `line-strong`,
  ///   `radius-md`), with `space-4` padding across and `space-3` down; the text wraps.
  /// - It starts [minLines] tall and grows a line at a time, at once and without animation, up to
  ///   [maxLines]; past that it scrolls inside with the platform's scroll bar, keeping the typing point in
  ///   view. It never shrinks below [minLines].
  /// - Return inserts a new line; Tab moves focus on (it never inserts a tab); ⌘Return (Control+Return
  ///   elsewhere) is not handled here, so the Inspector or Dialog holding the form saves with it.
  /// - No counter: none of today's uses has a limit.
  /// - Not for a single value, an address, or a mail body.
  const MyDataTextField.multiline({
    super.key,
    required this.label,
    required this.controller,
    this.help,
    this.error,
    this.placeholder,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.showLabel = true,
  })  : multiline = true,
        mono = false,
        obscure = false,
        onSubmitted = null,
        keyboardType = TextInputType.multiline,
        textInputAction = TextInputAction.newline;

  /// Sentence case: "Folder for your data".
  final String label;

  /// Holds the value.
  final TextEditingController controller;

  /// Shown below the field when there is no [error].
  final String? help;

  /// Non-null puts the field in its error state and replaces [help].
  final String? error;

  /// Shown in the empty field.
  final String? placeholder;

  /// Paths, addresses and copied values use the mono font (decision 2026-10-12).
  final bool mono;

  /// Hides the characters (passwords, tokens).
  final bool obscure;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Whether this is the text area ([MyDataTextField.multiline]).
  final bool multiline;

  /// False in a form group that holds only this field (Notes): the group's heading names it, and [label]
  /// stays its accessible name (design/components/FormRow).
  final bool showLabel;

  /// The text area's height: spec "it starts three lines tall".
  static const minLines = 3;

  /// Spec: "grows a line at a time as the text grows, up to twelve lines; past that it scrolls inside".
  static const maxLines = 12;

  /// Spec: "Multi-line: `space-4` padding across and `space-3` down".
  static double multilineVerticalPadding(MyDataLook look) => look.space(3);

  /// Spec: "`surface` fill, 1px `line-strong` border".
  static const borderWidth = 1.0;

  /// Spec: "Error: a 2px `danger` border".
  static const errorBorderWidth = 2.0;

  @override
  State<MyDataTextField> createState() => _MyDataTextFieldState();
}

class _MyDataTextFieldState extends State<MyDataTextField> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'MyDataTextField'));

  @override
  void initState() {
    super.initState();
    _node.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(MyDataTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_focusChanged);
      _node.addListener(_focusChanged);
    }
  }

  void _focusChanged() => setState(() {});

  @override
  void dispose() {
    _node.removeListener(_focusChanged);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = widget.error != null;
    final note = widget.error ?? widget.help;
    final borderWidth = hasError ? MyDataTextField.errorBorderWidth : MyDataTextField.borderWidth;
    final phone = AppLayout.isPhone(context);
    final style =
        (widget.mono ? context.typeScale.mono : PhoneType.body(context.typeScale.body, phone: phone)).copyWith(color: c.ink);

    Widget field = _Field(
      controller: widget.controller,
      focusNode: _node,
      style: style,
      placeholder: widget.placeholder,
      enabled: widget.enabled,
      readOnly: FormBusy.of(context),
      obscure: widget.obscure,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      // The 2px error border grows inward; the text stays where it was.
      horizontalInset: context.space(4) - borderWidth,
      verticalInset: borderWidth,
      multiline: widget.multiline,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: MyDataRadii.md(context.look),
        border: Border.all(color: hasError ? c.danger : c.lineStrong, width: borderWidth),
      ),
      borderRadius: MyDataRadii.md(context.look),
      danger: hasError,
    );

    field = Semantics(
      label: widget.label,
      hint: note,
      validationResult: hasError ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: field,
    );

    // Disabled, only the control fades (its label and box); the help, which gives the reason, keeps full
    // `ink-muted` (design/platforms.md "Disabled controls").
    Widget faded(Widget w) => widget.enabled ? w : Opacity(opacity: Pressable.disabledOpacity, child: w);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel) ...[
          // Read out through the field's own semantics.
          faded(ExcludeSemantics(child: Text(widget.label, style: context.typeScale.label.copyWith(color: c.ink)))),
          SizedBox(height: context.space(2)),
        ],
        faded(field),
        if (note != null) ...[
          SizedBox(height: context.space(2)),
          ExcludeSemantics(
            child: Text(note, style: context.typeScale.caption.copyWith(color: hasError ? c.danger : c.inkMuted)),
          ),
        ],
      ],
    );
  }
}

/// A search field: a borderless pill on `surface-sunken`, `control-height`, with a search icon and a
/// placeholder in `ink-muted` (spec; decision 2026-10-12). It has no visible label, so the placeholder is
/// also its accessible name. Focus draws the `focus` ring around the pill.
class MyDataSearchField extends StatefulWidget {
  const MyDataSearchField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;

  /// What can be searched, sentence case: "Search contacts".
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<MyDataSearchField> createState() => _MyDataSearchFieldState();
}

class _MyDataSearchFieldState extends State<MyDataSearchField> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'MyDataSearchField'));

  @override
  void initState() {
    super.initState();
    _node.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(MyDataSearchField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_focusChanged);
      _node.addListener(_focusChanged);
    }
  }

  void _focusChanged() => setState(() {});

  @override
  void dispose() {
    _node.removeListener(_focusChanged);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: widget.placeholder,
      child: _Field(
        controller: widget.controller,
        focusNode: _node,
        style: context.typeScale.body.copyWith(color: c.ink),
        placeholder: widget.placeholder,
        enabled: true,
        readOnly: false,
        obscure: false,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        horizontalInset: context.space(4),
        verticalInset: 0,
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.pill(context.look)),
        borderRadius: MyDataRadii.pill(context.look),
        // The outer label is the name; reading the placeholder too would say it twice.
        readPlaceholder: false,
        leading: Padding(
          padding: EdgeInsets.only(left: context.space(4)),
          child: Icon(Icons.search_rounded, size: context.density.icon, color: c.inkMuted),
        ),
      ),
    );
  }
}

/// The shared box: [decoration] at `control-height`, the text vertically centred, the ring when focused.
/// The text field's own padding fills the box, so a click anywhere in it focuses the field.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.placeholder,
    required this.enabled,
    required this.readOnly,
    required this.obscure,
    required this.autofocus,
    required this.onChanged,
    required this.onSubmitted,
    required this.keyboardType,
    required this.textInputAction,
    required this.horizontalInset,
    required this.verticalInset,
    required this.decoration,
    required this.borderRadius,
    this.readPlaceholder = true,
    this.leading,
    this.danger = false,
    this.multiline = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String? placeholder;
  final bool enabled;

  /// Its form waits for the host ([FormBusy]): focus stays, typing does nothing.
  final bool readOnly;
  final bool obscure;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Left and right padding of the text inside the border.
  final double horizontalInset;

  /// The border's width, which the text's vertical padding gives back.
  final double verticalInset;
  final BoxDecoration decoration;
  final BorderRadius borderRadius;

  /// Whether the placeholder joins the field's semantic label. The search field turns this off: its
  /// placeholder is already its name, given by an outer [Semantics] that stays after the user types (the
  /// hint fades out of the semantics tree once the field holds text).
  final bool readPlaceholder;
  final Widget? leading;

  /// In error, with its 2px `danger` border: the focus ring is `ink` (design/README.md "Focus and danger").
  final bool danger;

  /// The text area: [MyDataTextField.minLines] to [MyDataTextField.maxLines] lines, `space-3` padding down.
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lineHeight = style.fontSize! * style.height!;
    final vertical = multiline
        ? MyDataTextField.multilineVerticalPadding(context.look) - verticalInset
        : (context.density.controlHeight - lineHeight) / 2 - verticalInset;
    final hintStyle = context.typeScale.secondary(style).copyWith(color: c.inkMuted);
    final text = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscure,
      autocorrect: !obscure,
      enableSuggestions: !obscure,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: multiline ? MyDataTextField.minLines : null,
      maxLines: multiline ? MyDataTextField.maxLines : 1,
      style: style,
      cursorColor: c.accent,
      textAlignVertical: multiline ? TextAlignVertical.top : TextAlignVertical.center,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        filled: false,
        hintText: readPlaceholder ? placeholder : null,
        // Drawn as InputDecorator draws hintText, but silent.
        hint: readPlaceholder || placeholder == null
            ? null
            : ExcludeSemantics(
                child: Text(placeholder!, style: hintStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
        hintStyle: hintStyle,
        hintMaxLines: multiline ? MyDataTextField.minLines : 1,
        contentPadding: EdgeInsets.fromLTRB(
            leading == null ? horizontalInset : context.space(2), vertical, horizontalInset, vertical),
      ),
    );
    return FocusRing(
      visible: enabled && focusNode.hasFocus,
      borderRadius: borderRadius,
      danger: danger,
      child: Container(
        height: multiline ? null : context.density.controlHeight,
        decoration: decoration,
        child: leading == null
            ? text
            : Row(children: [
                // A click on the icon focuses the field too. Pointer only: the field itself is the one
                // semantic target, so the icon adds no unnamed tap node and the outer label merges into
                // the text field's node.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: focusNode.requestFocus,
                  child: ExcludeSemantics(child: leading!),
                ),
                Expanded(child: text),
              ]),
      ),
    );
  }
}
