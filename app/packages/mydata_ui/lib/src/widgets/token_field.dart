import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../accessibility.dart';
import '../theme/theme.dart';
import 'app_frame.dart' show AppLayout, PhoneType;
import 'contact_list.dart' show foldForSearch;
import 'form_scope.dart';
import 'pressable.dart';
import 'select.dart' show matchesWordStart;
import 'text_field.dart';
import 'toggle_target.dart';
import 'role_label.dart';
import 'input_box.dart';

/// A value a [TokenField] can suggest: an existing group, a contact's address.
@immutable
class TokenSuggestion {
  const TokenSuggestion({required this.value, this.label, this.caption});

  /// What the token holds.
  final String value;

  /// What the row and the token show, when not the [value] itself (a contact's name for an address).
  final String? label;

  /// A second line where the value needs telling apart (the address under the name); the row is then
  /// `row-height`.
  final String? caption;

  String get shown => label ?? value;
}

/// A field that holds several values as removable tokens, added by typing or by picking a suggestion
/// (design/components/TokenField): a contact's groups now, a message's recipients later.
///
/// **The field** is a TextField that grows: the [label] above, [help] or the error below; `surface`, 1px
/// `line-strong`, `radius-md`, at least `control-height`, `space-1` padding. Tokens flow in reading order
/// `space-1` apart and wrap; the field grows a line at a time up to [maxLines], then scrolls inside, keeping
/// the typing point in view. After the last token, the typing point (`body`, `space-3` padding at its
/// start) takes the rest of the line, or a new line when less than a third is left. Its [placeholder] shows
/// only while there are no tokens.
///
/// **A token** is a `control-height-compact` pill on `surface-sunken` with the value in `body` and `ink`,
/// cut short with an ellipsis at the field's width (its tooltip shows it in full), and an × at its end in
/// `ink-muted` whose hover shows a `surface` circle `icon-tile` across. The × is not a Tab stop: a token is
/// selected with the arrow keys or Backspace and removed with Backspace or Delete; screen readers get
/// "Remove" as the token's action. Selected: `accent-soft` and the focus ring around the pill. Invalid
/// ([isValid] false): `danger-soft`, `danger` text and ×, an alert icon before the value, the field's border
/// 2px `danger` and [errorText] below; selected, its ring is `ink`. Double-click, or Return on a selected
/// token, turns it back into text at the typing point.
///
/// **Suggestions** open under the field while the user types, in the Select's list: matching the start of
/// any word, ignoring case and accents, leaving out values already in the field, the first match
/// highlighted. With [allowNew], the last row offers a new value ([newValueLabel]: New group “Book club
/// 2”), the only row when nothing matches. Down with nothing typed opens the full list.
///
/// **Adding:** Return or a comma takes the highlighted suggestion, or the typed text when nothing is
/// highlighted. Tab and leaving the field take the typed text **as typed**, never the highlight. Pasted text
/// with commas, semicolons or line breaks makes one token per part. A value already in the field is not
/// added twice: its token is selected briefly and "Book club is already added" is announced.
///
/// **Removing:** the × removes its token. Backspace at the start of an empty typing point selects the last
/// token; Backspace or Delete again removes it. Left and Right move the selection (mirrored in
/// right-to-left text); moving past the last token returns to the typing point. Escape clears the
/// selection, after an open list has closed. ⌘Z (Control+Z) undoes typing first, and only then brings back
/// the last removed token.
///
/// **Disabled** ([onChanged] null): 45%, tokens without their ×, not focusable, with [disabledReason] as
/// the help. While the form waits for the host ([FormBusy]) the field keeps focus but takes no typing, and
/// nothing adds or removes a token. Text typed but not yet a token is committed by the holder before it
/// saves ([PendingInput]), as leaving the field would.
///
/// **Screen readers:** the field is a group read with its label and count ("Groups, 3 groups"); tokens are
/// options ("Book club, selected, 2 of 3"), "invalid" with the error; adding and removing are announced,
/// and the number of suggestions after typing stops.
///
/// **Phone** (under 600px): `body` at 16px; suggestions show as rows directly under the field, inside the
/// page.
class TokenField extends StatefulWidget {
  const TokenField({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.suggestions = const [],
    this.allowNew = true,
    this.newValueLabel,
    this.isValid,
    this.errorText,
    this.help,
    this.placeholder,
    this.disabledReason,
    this.countLabel,
    this.suggestionCount = defaultSuggestionCount,
    this.focusNode,
    this.showLabel = true,
  }) : assert(onChanged != null || disabledReason != null, 'a disabled field says why (platforms.md)');

  /// Sentence case, no full stop ("Groups").
  final String label;

  /// The tokens, in order.
  final List<String> values;

  /// Called with the new list. Null disables the field; give the [disabledReason] then.
  final ValueChanged<List<String>>? onChanged;

  /// Every value that can be suggested; the field filters them as the user types.
  final List<TokenSuggestion> suggestions;

  /// Whether typing can make a value that is not suggested.
  final bool allowNew;

  /// The new-value row: `(t) => 'New group “$t”'`.
  final String Function(String typed)? newValueLabel;

  /// The field's rule; a value it refuses is still added, in the invalid state.
  final bool Function(String value)? isValid;

  /// The error for the invalid values: "ben@example is not a complete address. It looks like
  /// name@example.org.", or "2 addresses are not complete. Fix or remove them."
  final String Function(List<String> invalid)? errorText;

  final String? help;

  /// Starts with a verb ("Add a group"); shown only while the field has no tokens.
  final String? placeholder;

  /// Why the field is disabled, shown as its help.
  final String? disabledReason;

  /// The count read with the label: `(n) => '$n groups'`. Defaults to "n values".
  final String Function(int count)? countLabel;

  /// The polite announcement after typing stops: "2 suggestions".
  final String Function(int count) suggestionCount;

  /// The typing point's focus node.
  final FocusNode? focusNode;

  /// False in a form group that holds only this field (Groups): the group's heading names it, and [label]
  /// stays its accessible name (design/components/FormRow).
  final bool showLabel;

  /// Spec: "the field grows a line at a time, up to four lines, then scrolls inside".
  static const maxLines = 4;

  /// Spec: a new line for the typing point "when less than about a third is left".
  static const typingMinFraction = 1 / 3;

  /// How long a duplicate's token stays selected.
  static const duplicateFlash = Duration(milliseconds: 1200);

  /// How long after the last keystroke the number of suggestions is announced.
  static const announceDelay = Duration(milliseconds: 500);

  /// Spec: the Select's list "shows about eight rows".
  static const visibleRows = 8;

  static String defaultSuggestionCount(int n) => n == 1 ? '1 suggestion' : '$n suggestions';

  /// Characters that end a token when pasted.
  static final separators = RegExp(r'[,;\n\r]');

  @override
  State<TokenField> createState() => _TokenFieldState();
}

/// One suggestion row: an existing value, or the new-value row.
class _Option {
  const _Option(this.suggestion, {this.typed});
  final TokenSuggestion? suggestion;
  final String? typed;
  bool get isNew => typed != null;
}

/// A token as drawn: present in the values, or fading out after a removal.
class _Shown {
  const _Shown(this.value, {this.leaving = false});
  final String value;
  final bool leaving;
}

class _TokenFieldState extends State<TokenField> with PendingInputRegistration<TokenField> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'TokenField'));

  final _text = TextEditingController();
  final _undo = UndoHistoryController();
  final _scroll = ScrollController();
  final _listScroll = ScrollController();
  final _portal = OverlayPortalController();
  final _fieldKey = GlobalKey();
  final _tapGroup = Object();

  String _lastText = '';
  int? _selected;
  int? _flash;
  Timer? _flashTimer;
  Timer? _announceTimer;
  bool _browse = false;
  bool _listOpen = false;
  int _hi = 0;
  bool _keyHighlight = false;

  /// Removed values, newest last, for ⌘Z.
  final _removed = <({int index, String value})>[];

  /// Values that fade in, and removed ones that fade out (with their old place).
  final _entering = <String>{};
  final _timers = <Timer>[];
  final _leaving = <({int index, String value})>[];

  bool get _enabled => widget.onChanged != null;

  /// The form waits for the host: nothing changes the tokens.
  bool get _busy => FormBusy.read(context);

  @override
  bool get hasPendingInput => _enabled && _text.text.trim().isNotEmpty;

  @override
  bool commitPendingInput() {
    // As leaving the field: the typed text, as typed, becomes a token.
    final typed = _text.text;
    _clearText();
    _add(typed);
    _closeList();
    return true;
  }

  @override
  FocusNode get pendingInputFocus => _node;

  @override
  void initState() {
    super.initState();
    _node.addListener(_focusChanged);
    _text.addListener(_textChanged);
  }

  @override
  void didUpdateWidget(TokenField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_focusChanged);
      _node.addListener(_focusChanged);
    }
    if (_selected != null && _selected! >= widget.values.length) _selected = null;
  }

  @override
  void dispose() {
    _node.removeListener(_focusChanged);
    _ownNode?.dispose();
    _text.dispose();
    _undo.dispose();
    _scroll.dispose();
    _listScroll.dispose();
    _flashTimer?.cancel();
    _announceTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  // ----- Values ----------------------------------------------------------------------------------------

  String _shownOf(String value) {
    for (final s in widget.suggestions) {
      if (s.value == value) return s.shown;
    }
    return value;
  }

  bool _invalid(String value) => widget.isValid != null && !widget.isValid!(value);

  int _indexOf(String value) {
    final f = foldForSearch(value.trim());
    return widget.values.indexWhere((v) => foldForSearch(v) == f);
  }

  void _announce(String message) =>
      SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));

  /// Adds [raw] as a token, unless it is empty or already there.
  void _add(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    final existing = _indexOf(value);
    if (existing >= 0) {
      _flashTimer?.cancel();
      setState(() => _flash = existing);
      _flashTimer = Timer(TokenField.duplicateFlash, () {
        if (mounted) setState(() => _flash = null);
      });
      _announce('${_shownOf(widget.values[existing])} is already added');
      return;
    }
    _entering.add(value);
    widget.onChanged!([...widget.values, value]);
    _announce('Added ${_shownOf(value)}');
    _revealEnd();
  }

  void _addAll(Iterable<String> parts) {
    final next = [...widget.values];
    final added = <String>[];
    for (final p in parts) {
      final v = p.trim();
      if (v.isEmpty) continue;
      final f = foldForSearch(v);
      if (next.any((x) => foldForSearch(x) == f)) continue;
      next.add(v);
      added.add(v);
    }
    if (added.isEmpty) return;
    _entering.addAll(added);
    widget.onChanged!(next);
    _announce('Added ${added.map(_shownOf).join(', ')}');
    _revealEnd();
  }

  void _remove(int index) {
    if (_busy) return;
    final value = widget.values[index];
    _removed.add((index: index, value: value));
    setState(() {
      _selected = null;
      _leaving.add((index: index, value: value));
    });
    // It fades out over `fast` (with or without reduced motion), then goes.
    _timers.add(
      Timer(context.motion.fast, () {
        if (mounted) setState(() => _leaving.removeWhere((l) => l.value == value));
      }),
    );
    widget.onChanged!([...widget.values]..removeAt(index));
    _announce('Removed ${_shownOf(value)}');
    if (_enabled) _node.requestFocus();
  }

  /// A click selects the token; a second click within the double-tap time turns it back into text. Counted
  /// here rather than with a double-tap recognizer, which would hold every click on the token (and its ×)
  /// for the double-tap time.
  void _tokenTapped(int index) {
    final now = DateTime.now();
    final last = _lastTap;
    _lastTap = (index: index, at: now);
    if (last != null && last.index == index && now.difference(last.at) < kDoubleTapTimeout) {
      _lastTap = null;
      _edit(index);
      return;
    }
    setState(() => _selected = index);
    _node.requestFocus();
  }

  ({int index, DateTime at})? _lastTap;

  /// Puts the token at [index] back into the typing point, for fixing.
  void _edit(int index) {
    if (_busy) return;
    final value = widget.values[index];
    widget.onChanged!([...widget.values]..removeAt(index));
    _setText(value);
    setState(() => _selected = null);
    _node.requestFocus();
  }

  void _setText(String text) {
    _lastText = text;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _clearText() => _setText('');

  void _revealEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  // ----- Suggestions -----------------------------------------------------------------------------------

  List<_Option> get _options {
    final q = _text.text.trim();
    if (q.isEmpty && !_browse) return const [];
    final taken = {for (final v in widget.values) foldForSearch(v)};
    final matches = <_Option>[
      for (final s in widget.suggestions)
        if (!taken.contains(foldForSearch(s.value)) &&
            (q.isEmpty ||
                matchesWordStart(s.shown, q) ||
                matchesWordStart(s.value, q) ||
                (s.caption != null && matchesWordStart(s.caption!, q))))
          _Option(s),
    ];
    final exact =
        widget.suggestions.any((s) => foldForSearch(s.value) == foldForSearch(q)) || taken.contains(foldForSearch(q));
    if (widget.allowNew && q.isNotEmpty && !exact) matches.add(_Option(null, typed: q));
    return matches;
  }

  bool get _showList => _listOpen && _options.isNotEmpty;

  void _syncList() {
    final open = _node.hasFocus && (_text.text.trim().isNotEmpty || _browse);
    if (open != _listOpen) {
      _listOpen = open;
      _hi = 0;
    }
    final phone = AppLayout.of(context) == AppLayout.phone;
    if (_showList && !phone) {
      _portal.show();
    } else {
      _portal.hide();
    }
  }

  void _take(_Option o) {
    if (_busy) return;
    _browse = false;
    _clearText();
    _add(o.isNew ? o.typed! : o.suggestion!.value);
    setState(() => _listOpen = false);
    _syncList();
    _node.requestFocus();
  }

  void _closeList() {
    setState(() {
      _browse = false;
      _listOpen = false;
    });
    _syncList();
  }

  // ----- Typing ----------------------------------------------------------------------------------------

  void _textChanged() {
    final text = _text.text;
    if (text == _lastText) return;
    final before = _lastText;
    _lastText = text;
    if (TokenField.separators.hasMatch(text)) {
      if (text == '$before,' || text == '$before;') {
        // A comma typed at the end: as Return.
        final options = _options.isEmpty ? null : _currentOptions(before);
        _clearText();
        if (options != null && options.isNotEmpty && _hi < options.length) {
          _take(options[_hi]);
        } else {
          _add(before);
        }
      } else {
        // Pasted: one token per part.
        _clearText();
        _addAll(text.split(TokenField.separators));
      }
      return;
    }
    setState(() {
      _selected = null;
      _hi = 0;
      _keyHighlight = false;
      if (text.isEmpty) _browse = false;
    });
    _syncList();
    _announceTimer?.cancel();
    if (text.trim().isNotEmpty) {
      _announceTimer = Timer(TokenField.announceDelay, () {
        if (mounted && _listOpen) _announce(widget.suggestionCount(_options.length));
      });
    }
  }

  /// The options as they were for [text] (before a comma was typed).
  List<_Option> _currentOptions(String text) {
    final keep = _text.value;
    _text.removeListener(_textChanged);
    _text.value = TextEditingValue(text: text);
    final o = _options;
    _text.value = keep;
    _text.addListener(_textChanged);
    return o;
  }

  void _focusChanged() {
    if (!_node.hasFocus) {
      // Leaving the field turns the typed text, as typed, into a token: typing is never lost silently.
      final typed = _text.text;
      if (typed.trim().isNotEmpty && _enabled) {
        _clearText();
        _add(typed);
      }
      _selected = null;
      _browse = false;
      _listOpen = false;
    }
    _syncList();
    if (mounted) setState(() {});
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (!_enabled) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final k = HardwareKeyboard.instance;
    final values = widget.values;
    if (_busy) {
      // Waiting for the host: the keys that would add or remove a token do nothing.
      final changes = key == LogicalKeyboardKey.backspace ||
          key == LogicalKeyboardKey.delete ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          (key == LogicalKeyboardKey.keyZ && (k.isMetaPressed || k.isControlPressed));
      return changes ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    // ⌘Z: the typing first; then the last removed token.
    if (key == LogicalKeyboardKey.keyZ && (k.isMetaPressed || k.isControlPressed) && !k.isShiftPressed) {
      if (_undo.value.canUndo || _text.text.isNotEmpty || _removed.isEmpty) return KeyEventResult.ignored;
      final last = _removed.removeLast();
      final next = [...values]..insert(math.min(last.index, values.length), last.value);
      widget.onChanged!(next);
      _announce('Added ${_shownOf(last.value)}');
      return KeyEventResult.handled;
    }

    final left = key == LogicalKeyboardKey.arrowLeft;
    final right = key == LogicalKeyboardKey.arrowRight;
    // Toward the start of the line, and toward its end (mirrored in right-to-left text).
    final towardStart = _rtl ? right : left;
    final towardEnd = _rtl ? left : right;

    if (_selected != null) {
      final sel = _selected!;
      if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
        _remove(sel);
        return KeyEventResult.handled;
      }
      if (towardStart) {
        setState(() => _selected = math.max(0, sel - 1));
        return KeyEventResult.handled;
      }
      if (towardEnd) {
        setState(() => _selected = sel + 1 < values.length ? sel + 1 : null);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        _edit(sel);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        setState(() => _selected = null);
        return KeyEventResult.handled;
      }
      // Anything else returns to the typing point.
      setState(() => _selected = null);
      return KeyEventResult.ignored;
    }

    final options = _showList ? _options : const <_Option>[];
    final atStart = _text.text.isEmpty;
    if (key == LogicalKeyboardKey.backspace && atStart && values.isNotEmpty) {
      setState(() => _selected = values.length - 1);
      return KeyEventResult.handled;
    }
    if (towardStart && atStart && values.isNotEmpty) {
      setState(() => _selected = values.length - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (options.isEmpty) {
        if (!atStart || widget.suggestions.isEmpty) return KeyEventResult.ignored;
        setState(() {
          _browse = true;
          _listOpen = true;
          _hi = 0;
          _keyHighlight = true;
        });
        _syncList();
        return KeyEventResult.handled;
      }
      setState(() {
        _hi = math.min(options.length - 1, _hi + 1);
        _keyHighlight = true;
      });
      _revealOption(_hi);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && options.isNotEmpty) {
      setState(() {
        _hi = math.max(0, _hi - 1);
        _keyHighlight = true;
      });
      _revealOption(_hi);
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) &&
        (k.isMetaPressed || k.isControlPressed)) {
      // ⌘Return (Ctrl+Return) is the holder's Save; it commits the typing itself first.
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (options.isNotEmpty) {
        _take(options[_hi.clamp(0, options.length - 1)]);
        return KeyEventResult.handled;
      }
      if (_text.text.trim().isNotEmpty) {
        final typed = _text.text;
        _clearText();
        _add(typed);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape && _listOpen) {
      _closeList();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      // Tab takes the typed text as typed, never the highlight, then moves on.
      final typed = _text.text;
      if (typed.trim().isNotEmpty) {
        _clearText();
        _add(typed);
      }
      _closeList();
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  void _revealOption(int i) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScroll.hasClients) return;
      final options = _options;
      var top = 0.0;
      for (var n = 0; n < i && n < options.length; n++) {
        top += _rowExtent(context.look, options[n]);
      }
      final bottom = top + (i < options.length ? _rowExtent(context.look, options[i]) : 0);
      final p = _listScroll.position;
      var to = p.pixels;
      if (bottom > to + p.viewportDimension) to = bottom - p.viewportDimension;
      if (top < to) to = top;
      _listScroll.jumpTo(to.clamp(0.0, p.maxScrollExtent));
    });
  }

  static double _rowExtent(MyDataLook look, _Option o) =>
      o.suggestion?.caption != null ? look.density.rowHeight : look.density.controlHeight;

  // ----- Building --------------------------------------------------------------------------------------

  List<_Shown> get _shown {
    final out = [for (final v in widget.values) _Shown(v)];
    for (final l in _leaving) {
      if (widget.values.contains(l.value)) continue;
      out.insert(math.min(l.index, out.length), _Shown(l.value, leaving: true));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final values = widget.values;
    final invalid = [
      for (final v in values)
        if (_invalid(v)) v,
    ];
    final error = invalid.isEmpty
        ? null
        : (widget.errorText?.call(invalid) ?? '${invalid.length} values are not valid.');
    final hasError = error != null;
    final note = error ?? (_enabled ? widget.help : (widget.disabledReason ?? widget.help));
    final border = hasError ? MyDataTextField.errorBorderWidth : MyDataTextField.borderWidth;
    final focused = _node.hasFocus;
    final phone = AppLayout.of(context) == AppLayout.phone;
    final bodyStyle = context.typeScale.body.copyWith(color: c.ink);

    final shown = _shown;
    var position = 0;
    final tokens = <Widget>[];
    for (final s in shown) {
      final index = s.leaving ? -1 : position++;
      final isSelected = !s.leaving && (index == _selected || index == _flash);
      Widget token = _Token(
        key: ValueKey('token:${s.value}'),
        shown: _shownOf(s.value),
        full: s.value,
        invalid: _invalid(s.value),
        errorText: error,
        selected: isSelected,
        ring: isSelected && (focused || index == _flash),
        removable: _enabled,
        position: index + 1,
        count: values.length,
        onRemove: s.leaving || !_enabled ? null : () => _remove(index),
        onSelect: s.leaving || !_enabled ? null : () => _tokenTapped(index),
      );
      final entering = _entering.remove(s.value);
      token = TweenAnimationBuilder<double>(
        key: ValueKey('fade:${s.value}:${s.leaving}'),
        tween: Tween(begin: entering || s.leaving ? (s.leaving ? 1 : 0) : 1, end: s.leaving ? 0 : 1),
        duration: context.motion.fast,
        curve: context.motion.standard,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: token,
      );
      tokens.add(token);
    }

    final typing = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Semantics(
        label: widget.label,
        child: TextField(
          controller: _text,
          focusNode: _node,
          undoController: _undo,
          enabled: _enabled,
          readOnly: FormBusy.of(context),
          groupId: _tapGroup,
          maxLines: 1,
          style: PhoneType.body(bodyStyle, phone: phone),
          cursorColor: c.accent,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {},
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: values.isEmpty ? widget.placeholder : null,
            hintStyle: bodyStyle.copyWith(color: c.inkMuted),
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.space(3),
              vertical: (context.density.controlHeightCompact - bodyStyle.fontSize! * bodyStyle.height!) / 2,
            ),
          ),
        ),
      ),
    );

    final line = context.density.controlHeightCompact;
    final inner = TokenField.maxLines * line + (TokenField.maxLines - 1) * context.space(1);
    Widget field = Container(
      key: _fieldKey,
      constraints: BoxConstraints(minHeight: context.density.controlHeight),
      decoration: InputBox.of(context.look, edge: hasError ? c.danger : c.lineStrong, width: border),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: inner + 2 * (context.space(1) - border)),
        child: SingleChildScrollView(
          controller: _scroll,
          child: _TokenFlow(
            padding: EdgeInsets.all(context.space(1) - border),
            reach: context.space(1),
            children: [...tokens, typing],
          ),
        ),
      ),
    );
    field = FocusRing(
      visible: focused && _selected == null && _flash == null,
      borderRadius: MyDataRadii.md(context.look),
      danger: hasError,
      clearance: InputBox.focusClearance(context),
      child: field,
    );
    if (!_enabled) field = Opacity(opacity: Pressable.disabledOpacity, child: field);
    field = TapRegion(
      groupId: _tapGroup,
      onTapOutside: (_) {
        if (_listOpen) _closeList();
      },
      child: OverlayPortal(controller: _portal, overlayChildBuilder: _buildPopover, child: field),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '${widget.label}, ${widget.countLabel?.call(values.length) ?? '${values.length} values'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showLabel) ...[
            ExcludeSemantics(
              child: RoleLabel(widget.label, color: c.ink),
            ),
            SizedBox(height: context.space(2)),
          ],
          field,
          if (note != null) ...[
            SizedBox(height: context.space(2)),
            ExcludeSemantics(
              child: Text(note, style: context.typeScale.caption.copyWith(color: hasError ? c.danger : c.inkMuted)),
            ),
          ],
          if (phone && _showList) ...[SizedBox(height: context.space(2)), _phoneList(context)],
        ],
      ),
    );
  }

  Widget _optionRow(BuildContext context, _Option o, int i, {required bool phone}) {
    final c = context.colors;
    final title = o.isNew ? (widget.newValueLabel?.call(o.typed!) ?? 'New “${o.typed}”') : o.suggestion!.shown;
    final caption = o.suggestion?.caption;
    final highlighted = i == _hi && !phone;
    final style = PhoneType.body(context.typeScale.body, phone: phone).copyWith(color: c.ink);
    return Semantics(
      selected: highlighted,
      label: [title, ?caption].join(', '),
      onTap: () => _take(o),
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (_) {
            if (_hi != i || _keyHighlight) {
              setState(() {
                _hi = i;
                _keyHighlight = false;
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _take(o),
            child: CustomPaint(
              foregroundPainter: highlighted && _keyHighlight
                  ? InsetRingPainter(shape: context.radius, color: FocusRing.colourFor(context), borderRadius: MyDataRadii.sm(context.look))
                  : null,
              child: Container(
                height: phone ? context.density.rowHeight : _rowExtent(context.look, o),
                padding: EdgeInsets.symmetric(horizontal: phone ? context.space(4) : context.space(3)),
                alignment: AlignmentDirectional.centerStart,
                decoration: context.radius.decorate(BoxDecoration(
                  color: highlighted ? c.surfaceHover : null,
                  borderRadius: phone ? null : MyDataRadii.sm(context.look),
                )),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                    if (caption != null)
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typeScale.caption.copyWith(color: c.inkMuted),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneList(BuildContext context) {
    final c = context.colors;
    final options = _options;
    return TapRegion(
      groupId: _tapGroup,
      child: DecoratedBox(
        decoration: context.radius.decorate(BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg(context.look))),
        child: context.radius.clip(
          MyDataRadii.lg(context.look),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) Container(height: 1, color: c.line),
                _optionRow(context, options[i], i, phone: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopover(BuildContext context) {
    final c = context.colors;
    final fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (fieldBox == null || overlayBox == null || !fieldBox.attached) return const SizedBox.shrink();
    final anchor = MatrixUtils.transformRect(fieldBox.getTransformTo(overlayBox), Offset.zero & fieldBox.size);
    final options = _options;
    if (options.isEmpty) return const SizedBox.shrink();
    var height = 0.0;
    for (final o in options) {
      height += _rowExtent(context.look, o);
    }
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    final panel = Container(
      decoration: context.radius.decorate(BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: MyDataRadii.md(context.look),
        boxShadow: context.shadows.shadow2,
      )),
      padding: EdgeInsets.all(context.space(1)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: math.min(height, TokenField.visibleRows * context.density.controlHeight)),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Suggestions',
          child: Scrollbar(
            controller: _listScroll,
            child: ListView(
              controller: _listScroll,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [for (var i = 0; i < options.length; i++) _optionRow(context, options[i], i, phone: false)],
            ),
          ),
        ),
      ),
    );
    return Positioned(
      left: anchor.left,
      top: anchor.bottom + context.space(1),
      width: anchor.width,
      child: TapRegion(
        groupId: _tapGroup,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduced ? context.motion.fast : context.motion.base,
          curve: context.motion.standard,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: reduced
                ? child
                : Transform.scale(scaleY: 0.97 + 0.03 * t, alignment: Alignment.topCenter, child: child),
          ),
          child: Material(type: MaterialType.transparency, child: panel),
        ),
      ),
    );
  }
}

/// One token: the pill, its value and its ×.
class _Token extends StatelessWidget {
  const _Token({
    super.key,
    required this.shown,
    required this.full,
    required this.invalid,
    required this.errorText,
    required this.selected,
    required this.ring,
    required this.removable,
    required this.position,
    required this.count,
    required this.onRemove,
    required this.onSelect,
  });
  final String shown;
  final String full;
  final bool invalid;
  final String? errorText;
  final bool selected;
  final bool ring;
  final bool removable;
  final int position;
  final int count;
  final VoidCallback? onRemove;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = invalid ? c.danger : c.ink;
    final fill = invalid ? c.dangerSoft : (selected ? c.accentSoft : c.surfaceSunken);
    Widget pill = Container(
      height: context.density.controlHeightCompact,
      padding: EdgeInsetsDirectional.only(
        start: invalid ? context.space(2) : context.space(3),
        end: removable ? 0 : context.space(3),
      ),
      decoration: context.radius.decorate(BoxDecoration(color: fill, borderRadius: MyDataRadii.pill(context.look))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (invalid) ...[
            Icon(context.icon(MyDataIcon.error), size: context.density.icon, color: c.danger),
            SizedBox(width: context.space(2)),
          ],
          Flexible(
            child: Text(
              shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: context.typeScale.body.copyWith(color: fg),
            ),
          ),
          if (removable) ...[
            SizedBox(width: context.space(1)),
            _RemoveX(colour: invalid ? c.danger : c.inkMuted, onTap: onRemove),
          ],
        ],
      ),
    );
    pill = FocusRing(visible: ring, borderRadius: MyDataRadii.pill(context.look), danger: invalid, child: pill);
    pill = Tooltip(message: full, excludeFromSemantics: true, child: pill);
    return Semantics(
      selected: selected,
      label: shown == full ? shown : '$shown, $full',
      hint: [if (invalid) 'Invalid. ${errorText ?? ''}'.trim(), '$position of $count'].join('. '),
      customSemanticsActions: onRemove == null ? null : {CustomSemanticsAction(label: 'Remove $shown'): onRemove!},
      onTap: onSelect,
      child: ExcludeSemantics(
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onSelect, child: pill),
      ),
    );
  }
}

/// The token's ×: an icon in a `control-height-compact` circle that shows `surface` on hover and dims on a
/// press. Not a Tab stop.
class _RemoveX extends StatelessWidget {
  const _RemoveX({required this.colour, required this.onTap});
  final Color colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Not a Tab stop: keyboard users select the token and press Backspace.
    return ExcludeFocus(
      child: ToggleTarget(
        onToggle: onTap,
        builder: (context, s) => AnimatedOpacity(
          opacity: s.pressed ? context.motion.pressOpacity : 1,
          duration: s.pressed ? Duration.zero : context.motion.fast,
          child: Container(
            width: context.density.iconTile,
            height: context.density.iconTile,
            decoration: BoxDecoration(color: s.hovered ? c.surface : null, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(context.icon(MyDataIcon.close), size: context.density.icon, color: colour),
          ),
        ),
      ),
    );
  }
}

/// Lays the tokens out in reading order, `space-1` apart, wrapping; the last child (the typing point) takes
/// the rest of its line, or the whole of a new line when less than [TokenField.typingMinFraction] is left.
///
/// A tap within [reach] outside a child, in the gaps and the field's padding, goes to that child at its
/// nearest edge, so the × of a 36px token has a 44px target that overlaps the field's padding, never
/// another token's text.
class _TokenFlow extends MultiChildRenderObjectWidget {
  const _TokenFlow({required super.children, required this.padding, required this.reach});
  final EdgeInsets padding;
  final double reach;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTokenFlow(padding, reach, Directionality.of(context) == TextDirection.rtl, context.look);

  @override
  void updateRenderObject(BuildContext context, _RenderTokenFlow renderObject) {
    renderObject
      ..padding = padding
      ..reach = reach
      ..rtl = Directionality.of(context) == TextDirection.rtl
      ..look = context.look;
  }
}

class _FlowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTokenFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FlowParentData> {
  _RenderTokenFlow(this._padding, this._reach, this._rtl, this._look);

  MyDataLook _look;
  set look(MyDataLook value) {
    if (value == _look) return;
    _look = value;
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets v) {
    if (v == _padding) return;
    _padding = v;
    markNeedsLayout();
  }

  double _reach;
  set reach(double v) => _reach = v;

  bool _rtl;
  set rtl(bool v) {
    if (v == _rtl) return;
    _rtl = v;
    markNeedsLayout();
  }

  double get _gap => _look.space(1);
  double get _line => _look.density.controlHeightCompact;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FlowParentData) child.parentData = _FlowParentData();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
    final inner = math.max(0.0, width - _padding.horizontal);
    var x = 0.0, y = 0.0;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _FlowParentData;
      final last = child == lastChild;
      double w;
      if (last) {
        var room = inner - x;
        if (x > 0 && room < inner * TokenField.typingMinFraction) {
          x = 0;
          y += _line + _gap;
          room = inner;
        }
        child.layout(BoxConstraints.tightFor(width: room, height: _line), parentUsesSize: true);
        w = room;
      } else {
        child.layout(BoxConstraints(maxWidth: inner, maxHeight: _line), parentUsesSize: true);
        w = child.size.width;
        if (x > 0 && x + w > inner) {
          x = 0;
          y += _line + _gap;
        }
      }
      final dy = y + (_line - child.size.height) / 2;
      final dx = _rtl ? inner - x - w : x;
      data.offset = Offset(_padding.left + dx, _padding.top + dy);
      x += w + _gap;
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(width, y + _line + _padding.vertical));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Exactly on a child first; then the nearest child within reach.
    if (defaultHitTestChildren(result, position: position)) return true;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _FlowParentData;
      final rect = data.offset & child.size;
      if (rect.inflate(_reach).contains(position)) {
        final clamped = Offset(
          position.dx.clamp(rect.left, rect.right - 0.01).toDouble(),
          position.dy.clamp(rect.top, rect.bottom - 0.01).toDouble(),
        );
        final hit = result.addWithPaintOffset(
          offset: data.offset,
          position: clamped,
          hitTest: (result, transformed) => child!.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = data.nextSibling;
    }
    return false;
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => _line + _padding.vertical;

  @override
  double computeMaxIntrinsicHeight(double width) => _line + _padding.vertical;
}
