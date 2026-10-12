import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';
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
///   `:focus-visible` in the preview, however it was focused).
/// - Disabled: 45% opacity, not focusable.
///
/// The field fills the width it is given; put it in an [Expanded] or a sized box inside a [Row].
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
  });

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
    final style = (widget.mono ? MyDataType.mono : MyDataType.body).copyWith(color: c.ink);

    Widget field = _Field(
      controller: widget.controller,
      focusNode: _node,
      style: style,
      placeholder: widget.placeholder,
      enabled: widget.enabled,
      obscure: widget.obscure,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      // The 2px error border grows inward; the text stays where it was.
      horizontalInset: MyDataSpace.s4 - borderWidth,
      verticalInset: borderWidth,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: MyDataRadii.md,
        border: Border.all(color: hasError ? c.danger : c.lineStrong, width: borderWidth),
      ),
      borderRadius: MyDataRadii.md,
    );

    field = Semantics(
      label: widget.label,
      hint: note,
      validationResult: hasError ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
      child: field,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Read out through the field's own semantics.
        ExcludeSemantics(child: Text(widget.label, style: MyDataType.label.copyWith(color: c.ink))),
        const SizedBox(height: MyDataSpace.s2),
        field,
        if (note != null) ...[
          const SizedBox(height: MyDataSpace.s2),
          ExcludeSemantics(
            child: Text(note, style: MyDataType.caption.copyWith(color: hasError ? c.danger : c.inkMuted)),
          ),
        ],
      ],
    );
    return widget.enabled ? body : Opacity(opacity: Pressable.disabledOpacity, child: body);
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
        style: MyDataType.body.copyWith(color: c.ink),
        placeholder: widget.placeholder,
        enabled: true,
        obscure: false,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        horizontalInset: MyDataSpace.s4,
        verticalInset: 0,
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.pill),
        borderRadius: MyDataRadii.pill,
        // The outer label is the name; reading the placeholder too would say it twice.
        readPlaceholder: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: MyDataSpace.s4),
          child: Icon(Icons.search_rounded, size: MyDataSize.icon, color: c.inkMuted),
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String? placeholder;
  final bool enabled;
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lineHeight = style.fontSize! * style.height!;
    final vertical = (MyDataSize.controlHeight - lineHeight) / 2 - verticalInset;
    final hintStyle = style.copyWith(color: c.inkMuted);
    final text = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscure,
      autocorrect: !obscure,
      enableSuggestions: !obscure,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: 1,
      style: style,
      cursorColor: c.accent,
      textAlignVertical: TextAlignVertical.center,
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
        hintMaxLines: 1,
        contentPadding: EdgeInsets.fromLTRB(
            leading == null ? horizontalInset : MyDataSpace.s2, vertical, horizontalInset, vertical),
      ),
    );
    return FocusRing(
      visible: enabled && focusNode.hasFocus,
      borderRadius: borderRadius,
      child: Container(
        height: MyDataSize.controlHeight,
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
