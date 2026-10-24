import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../accessibility.dart';
import '../theme/motion.dart';
import '../theme/theme.dart';
import 'app_frame.dart' show AppLayout, PhoneType;
import 'button.dart';
import 'contact_list.dart' show ContactList, foldForSearch;
import 'data_colour.dart';
import 'form_scope.dart';
import 'pressable.dart';
import 'sheet.dart';
import 'text_field.dart';
import 'toggle_target.dart';
import 'role_label.dart';
import 'input_box.dart';

/// Whether [query] matches the start of any word in [text], ignoring case and accents ([foldForSearch]): "auck"
/// and "zealand" match "Auckland, New Zealand"; "land" does not. A query of several words matches where
/// they start a word and follow on ("new z"). An empty query matches everything.
bool matchesWordStart(String text, String query) {
  final q = foldForSearch(query.trim());
  if (q.isEmpty) return true;
  final t = foldForSearch(text);
  for (var i = t.indexOf(q); i >= 0; i = t.indexOf(q, i + 1)) {
    if (i == 0 || !_wordChar.hasMatch(t[i - 1])) return true;
  }
  return false;
}

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// One choice in a [MyDataSelect]'s list.
@immutable
class SelectItem<T> {
  const SelectItem({required this.value, required this.title, this.caption, this.startsGroup = false})
    : hasDot = false,
      dot = null;

  /// An item with a calendar's DataColour dot before its name; [dot] null is a calendar with no colour
  /// (`line-strong`).
  const SelectItem.dotted({
    required this.value,
    required this.title,
    required this.dot,
    this.caption,
    this.startsGroup = false,
  }) : hasDot = true;

  final T value;

  /// In sentence case, no full stop ("Every weekday", "Mobile").
  final String title;

  /// A second line in `caption` and `ink-muted` ("New Zealand, GMT+13"); the row is then `row-height`.
  final String? caption;

  /// Whether the item has a leading DataColour dot.
  final bool hasDot;

  /// The dot's colour from the data ([parseDataColour]).
  final Color? dot;

  /// A 1px `line` divider before this item, separating groups of items.
  final bool startsGroup;
}

/// A field that shows one value and opens a list to pick another (design/components/Select): a phone
/// number's label, an event's calendar, a time zone, a repeat rule.
///
/// **Closed** it looks like a TextField, so a form reads as one set of inputs: the [label] above (`label`,
/// `ink`, `space-2`), then a `control-height` field (`surface`, 1px `line-strong`, `radius-md`, `space-4`
/// across) with the value in `body` and `ink` (cut short with an ellipsis), or the [placeholder] in
/// `ink-muted`, and an up-and-down chevron at the end in `ink-muted`, `space-2` from the value; [help] under
/// it. An item with a dot shows its DataColour dot before the name, `space-2` from it.
///
/// **Open**, the list is a popover under the field (above it when there is no room below): `surface-raised`,
/// `shadow-2`, `radius-md`, `space-1` padding, at least the field's width; `control-height` rows (two-line
/// rows `row-height`) with `space-3` padding across, the current value checked in `accent` at the row's end,
/// the highlighted row filled with `surface-hover` in a `radius-sm` shape and, when reached with the keys,
/// the 2px `focus` ring inside it. About eight rows show, then it scrolls; it opens scrolled to the current
/// value. It fades in and grows from the field's edge over `base`; it closes with a `fast` fade (with reduced
/// motion, a `fast` fade only).
///
/// **The long-list variant** ([searchPlaceholder] set, for lists over about 15 items): the list starts with
/// a search pill that takes focus; typing filters on the start of any word in the title or caption,
/// ignoring case and accents ([matchesWordStart]), and highlights the first match. While the search is
/// empty, the [suggested] items show first under "Suggested". With no match, [noMatches] shows in place of
/// the rows. The number of matches is announced politely ([matchCount]) after typing stops.
///
/// **Custom label** ([onCustomLabel] set): the last item, after a divider, is [customItemTitle]. Choosing it
/// turns the field into a text field in place with the current label selected; Return keeps it, Escape
/// returns the previous label.
///
/// **The current value is always in the list:** a [value] that is not among [items] (an imported "iPhone"
/// label, a rule the presets cannot express) is shown above them, named by [titleOf].
///
/// **States:** hover fills the field with `surface-hover` over `fast`; a press dims it to 85% without
/// shrinking; keyboard focus draws the 2px `focus` ring 2px outside it (`ink` while in [error]). Disabled
/// ([onChanged] null): the label and the field at 45%, not focusable, with the [disabledReason] as the help
/// text, not faded. [error]: a 2px `danger` border and the error in place of the help. While its form waits
/// for the host ([FormBusy]) it keeps focus but does not open or change.
///
/// **Keyboard:** closed, Space, Return, Down, Up and Option-Down (Alt-Down) open the list; typing letters
/// picks the next item that starts with them without opening it, and the new value is announced. Open, Up
/// and Down move the highlight and stop at the ends; Home, End, Page Up and Page Down jump; letters move to
/// the next match; Return or Space picks and closes; Escape closes and keeps the old value; Tab closes,
/// keeps the old value and moves focus on. A click outside closes it. After closing, focus is on the field.
///
/// **Screen readers:** "Calendar, Book club, pop-up button"; each item reads its title, caption, whether it
/// is chosen and its position ("3 of 12"). Focus stays in the field while the list is open, so each move of
/// the highlight with the keys is announced ("Work, 3 of 4"). Picking announces the new value.
///
/// **Phone** (under 600px): the value is `body` at 16px. Tapping the field opens a picker [Sheet] titled with
/// the [label] that lists the items as `row-height` rows; tapping one picks it and closes the sheet. "Custom
/// label…" turns the sheet into a text field with Done; typing there is pending input, so the scrim, a drag
/// and Cancel ask before it is lost. The long-list variant opens a pushed full-screen page with the search
/// pill at the top. Type-ahead does not apply.
class MyDataSelect<T> extends StatefulWidget {
  const MyDataSelect({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.showLabel = true,
    this.semanticLabel,
    this.placeholder,
    this.help,
    this.error,
    this.disabledReason,
    this.titleOf,
    this.onCustomLabel,
    this.customItemTitle = 'Custom label…',
    this.searchPlaceholder,
    this.suggested = const [],
    this.suggestedHeading = 'Suggested',
    this.noMatches,
    this.matchCount,
    this.fieldTitle,
    this.fitToItems = false,
    this.focusNode,
    this.autofocus = false,
  }) : assert(onChanged != null || disabledReason != null, 'a Select is never disabled without a reason');

  /// The field's name in sentence case ("Calendar", "Time zone"); shown above it unless [showLabel] is
  /// false, and the sheet's title on a phone.
  final String label;

  final List<SelectItem<T>> items;

  /// The chosen item's value; null shows the [placeholder].
  final T? value;

  /// Called with the picked value. Null disables the field; give the [disabledReason] then.
  final ValueChanged<T>? onChanged;

  /// False in a repeatable form row, where the label picker sits beside its value with no label above.
  final bool showLabel;

  /// The accessible name when it is not [label] ("Label for phone 1").
  final String? semanticLabel;

  /// Names the empty value ("No calendar"), never "Select…".
  final String? placeholder;

  final String? help;

  /// Non-null puts the field in its error state and replaces [help] ("That calendar was deleted. Choose
  /// another.").
  final String? error;

  /// Why the field is disabled, shown as its help, not faded.
  final String? disabledReason;

  /// Names a [value] that is not among [items]; defaults to its `toString()`.
  final String Function(T value)? titleOf;

  /// Allows a custom label: called with the typed label. Null for no "Custom label…" item.
  final ValueChanged<String>? onCustomLabel;

  /// The custom item's title; it ends with an ellipsis because it asks for more.
  final String customItemTitle;

  /// Turns on the long-list variant; names what it searches ("Search time zones").
  final String? searchPlaceholder;

  /// Shown first, under [suggestedHeading], while the search is empty (this device's zone, zones already
  /// used).
  final List<SelectItem<T>> suggested;
  final String suggestedHeading;

  /// The line shown when nothing matches: `(q) => 'No time zones match “$q”'`.
  final String Function(String query)? noMatches;

  /// The polite announcement after typing stops: `(n) => '$n time zones'`.
  final String Function(int count)? matchCount;

  /// How the closed field names the chosen item, when not by its title ("Auckland time").
  final String Function(SelectItem<T> item)? fieldTitle;

  /// Makes the field as wide as its longest preset (a repeatable row's label picker); otherwise it fills
  /// the width it is given. A longer custom label is cut short, and its tooltip shows it in full.
  final bool fitToItems;

  final FocusNode? focusNode;
  final bool autofocus;

  /// Spec: "it shows about eight rows, then scrolls".
  static const visibleRows = 8;

  /// "Discard changes?"'s body when a custom label typed in the phone's sheet would be lost.
  static const customDiscardMessage = 'The label you typed is not saved.';

  /// How long after the last keystroke the number of matches is announced.
  static const announceDelay = Duration(milliseconds: 500);

  /// Spec: the field's "1px `line-strong` border"; 2px `danger` in error.
  static const borderWidth = MyDataTextField.borderWidth;
  static const errorBorderWidth = MyDataTextField.errorBorderWidth;

  /// Spec: the leading dot is 8px, `space-2` from the name.
  static const dotSize = 8.0;

  @override
  State<MyDataSelect<T>> createState() => _MyDataSelectState<T>();
}

sealed class _Entry<T> {
  const _Entry();
}

final class _ItemEntry<T> extends _Entry<T> {
  const _ItemEntry(SelectItem<T> this._item) : customTitle = null;

  /// "Custom label…": it has no value of its own.
  const _ItemEntry.custom(String this.customTitle) : _item = null;

  final SelectItem<T>? _item;
  final String? customTitle;

  bool get custom => _item == null;

  /// The item; only on an entry that is not [custom].
  SelectItem<T> get item => _item!;

  String get title => customTitle ?? _item!.title;
  String? get caption => _item?.caption;
  bool get hasDot => _item?.hasDot ?? false;
  Color? get dot => _item?.dot;
}

final class _DividerEntry<T> extends _Entry<T> {
  const _DividerEntry();
}

final class _HeadingEntry<T> extends _Entry<T> {
  const _HeadingEntry(this.text);
  final String text;
}

final class _NoneEntry<T> extends _Entry<T> {
  const _NoneEntry(this.text);
  final String text;
}

class _MyDataSelectState<T> extends State<MyDataSelect<T>>
    with SingleTickerProviderStateMixin, PendingInputRegistration<MyDataSelect<T>> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'MyDataSelect'));

  final _portal = OverlayPortalController();
  final _fieldKey = GlobalKey();
  final _tapGroup = Object();
  late final AnimationController _motion;
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _searchNode = FocusNode(debugLabel: 'MyDataSelect search');
  final _customText = TextEditingController();
  final _customNode = FocusNode(debugLabel: 'MyDataSelect custom label');

  bool _open = false;
  bool _hovered = false;
  bool _editingCustom = false;

  /// The highlighted entry, an index into [_entries]; -1 for none.
  int _hi = -1;

  /// The highlight was moved with the keys: it also gets the focus ring.
  bool _keyHighlight = false;

  String _typed = '';
  Timer? _typedTimer;

  /// A pointer is down on the field: the list it opens has no keyboard ring on its highlight.
  bool _pointer = false;
  Timer? _announceTimer;

  bool get _enabled => widget.onChanged != null;
  bool get _searchable => widget.searchPlaceholder != null;

  @override
  void initState() {
    super.initState();
    final motion = context.lookNow.motion;
    _motion = AnimationController(vsync: this, duration: motion.base, reverseDuration: motion.fast);
    _node.addListener(_focusChanged);
    _search.addListener(_queryChanged);
    _customNode.addListener(_customFocusChanged);
  }

  @override
  void didUpdateWidget(MyDataSelect<T> old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_focusChanged);
      _node.addListener(_focusChanged);
    }
    if (!_enabled && _open) _close(refocus: false);
  }

  @override
  void dispose() {
    _node.removeListener(_focusChanged);
    _ownNode?.dispose();
    _motion.dispose();
    _scroll.dispose();
    _search.dispose();
    _searchNode.dispose();
    _customText.dispose();
    _customNode.dispose();
    _typedTimer?.cancel();
    _announceTimer?.cancel();
    super.dispose();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  // ----- Pending input: a custom label being typed -----------------------------------------------------

  @override
  bool get hasPendingInput => _editingCustom;

  @override
  bool commitPendingInput() {
    _commitCustom();
    return true;
  }

  @override
  FocusNode get pendingInputFocus => _customNode;

  /// Keeps what was typed as the label, without moving focus.
  void _commitCustom() {
    if (!_editingCustom) return;
    final text = _customText.text.trim();
    setState(() => _editingCustom = false);
    if (text.isNotEmpty && text != _current?.title) widget.onCustomLabel!(text);
  }

  // ----- Items -----------------------------------------------------------------------------------------

  /// The current value as an item: one of [items] or [suggested], or an extra item when it is neither.
  SelectItem<T>? get _current {
    final v = widget.value;
    if (v == null) return null;
    for (final i in widget.items) {
      if (i.value == v) return i;
    }
    for (final i in widget.suggested) {
      if (i.value == v) return i;
    }
    return SelectItem(value: v, title: widget.titleOf?.call(v) ?? '$v');
  }

  bool get _valueIsExtra {
    final v = widget.value;
    return v != null && !widget.items.any((i) => i.value == v) && !widget.suggested.any((i) => i.value == v);
  }

  List<_Entry<T>> get _entries {
    final out = <_Entry<T>>[];
    void items(Iterable<SelectItem<T>> list) {
      for (final i in list) {
        if (i.startsGroup && out.isNotEmpty && out.last is! _DividerEntry<T>) out.add(const _DividerEntry());
        out.add(_ItemEntry(i));
      }
    }

    final q = _search.text;
    if (_searchable && q.trim().isNotEmpty) {
      final matches = [
        for (final i in widget.items)
          if (matchesWordStart(i.title, q) || (i.caption != null && matchesWordStart(i.caption!, q))) i,
      ];
      if (matches.isEmpty) {
        out.add(_NoneEntry(widget.noMatches?.call(q.trim()) ?? 'Nothing matches “${q.trim()}”'));
      } else {
        for (final i in matches) {
          out.add(_ItemEntry(i));
        }
      }
      return out;
    }
    if (_valueIsExtra) {
      out.add(_ItemEntry(_current!));
      out.add(const _DividerEntry());
    }
    if (_searchable && widget.suggested.isNotEmpty) {
      out.add(_HeadingEntry(widget.suggestedHeading));
      for (final i in widget.suggested) {
        out.add(_ItemEntry(i));
      }
      out.add(const _DividerEntry());
    }
    items(widget.items);
    if (widget.onCustomLabel != null) {
      if (out.isNotEmpty) out.add(const _DividerEntry());
      out.add(_ItemEntry<T>.custom(widget.customItemTitle));
    }
    return out;
  }

  static double _extentOf<T>(MyDataLook look, _Entry<T> e) => switch (e) {
    _ItemEntry(:final caption) => caption == null ? look.density.controlHeight : look.density.rowHeight,
    _DividerEntry() => _dividerExtent(look),
    _HeadingEntry() => _headingExtent(look),
    _NoneEntry() => _noneExtent(look),
  };

  static double _dividerExtent(MyDataLook look) => 1 + 2 * look.space(1);
  static double _headingExtent(MyDataLook look) => look.typeScale.label.fontSize! * look.typeScale.label.height! + look.space(2) + look.space(1);
  static double _noneExtent(MyDataLook look) => look.typeScale.body.fontSize! * look.typeScale.body.height! + 2 * look.space(3);

  bool _isItem(List<_Entry<T>> entries, int i) => i >= 0 && i < entries.length && entries[i] is _ItemEntry<T>;

  int _indexOfCurrent(List<_Entry<T>> entries) {
    final v = widget.value;
    if (v == null) return -1;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e is _ItemEntry<T> && !e.custom && e.item.value == v) return i;
    }
    return -1;
  }

  int _firstItem(List<_Entry<T>> entries) => entries.indexWhere((e) => e is _ItemEntry<T>);
  int _lastItem(List<_Entry<T>> entries) => entries.lastIndexWhere((e) => e is _ItemEntry<T>);

  // ----- Opening and closing ---------------------------------------------------------------------------

  void _activate() {
    if (!_enabled || FormBusy.read(context)) return;
    if (_open) {
      _pickHighlighted();
      return;
    }
    if (AppLayout.of(context) == AppLayout.phone) {
      _openOnPhone();
      return;
    }
    _openList(keyboard: !_pointer);
  }

  void _openList({required bool keyboard}) {
    if (_open || !_enabled) return;
    _search.clear();
    final entries = _entries;
    final current = _indexOfCurrent(entries);
    setState(() {
      _open = true;
      _hi = current >= 0 ? current : _firstItem(entries);
      _keyHighlight = keyboard;
    });
    // Keys go to the field while the list is open (to the search pill in the long-list variant).
    if (!_searchable) _node.requestFocus();
    _portal.show();
    _motion.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      _reveal(_hi, centre: true);
      if (_searchable) _searchNode.requestFocus();
    });
  }

  Future<void> _close({bool refocus = true}) async {
    if (!_open) return;
    setState(() => _open = false);
    _announceTimer?.cancel();
    if (refocus && _enabled) _node.requestFocus();
    if (MyDataMotion.reduced(context)) {
      _motion.value = 0;
    } else {
      await _motion.reverse();
    }
    if (!_open && _portal.isShowing) _portal.hide();
  }

  void _pick(_ItemEntry<T> entry) {
    if (entry.custom) {
      _close();
      _startCustom();
      return;
    }
    _close();
    final v = entry.item.value;
    if (v != widget.value) {
      widget.onChanged?.call(v);
      _announce(_titleOf(entry.item));
    }
  }

  void _pickHighlighted() {
    final entries = _entries;
    if (_isItem(entries, _hi)) _pick(entries[_hi] as _ItemEntry<T>);
  }

  void _announce(String message) {
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  }

  String _titleOf(SelectItem<T> item) => widget.fieldTitle?.call(item) ?? item.title;

  // ----- Custom label ----------------------------------------------------------------------------------

  void _startCustom() {
    // The field leaves the tree for the text field: the list goes at once.
    _motion.value = 0;
    if (_portal.isShowing) _portal.hide();
    final cur = _current;
    _customText.text = cur?.title ?? '';
    _customText.selection = TextSelection(baseOffset: 0, extentOffset: _customText.text.length);
    setState(() => _editingCustom = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _customNode.requestFocus();
    });
  }

  void _endCustom({required bool keep}) {
    if (!_editingCustom) return;
    final text = _customText.text.trim();
    setState(() => _editingCustom = false);
    if (keep && text.isNotEmpty && text != _current?.title) {
      widget.onCustomLabel!(text);
      _announce(text);
    }
    _node.requestFocus();
  }

  void _customFocusChanged() {
    // Leaving the text field keeps what was typed: typing is never lost silently.
    if (!_customNode.hasFocus && _editingCustom) _commitCustom();
  }

  KeyEventResult _onCustomKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _endCustom(keep: false);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _endCustom(keep: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ----- Keys ------------------------------------------------------------------------------------------

  void _moveHighlight(int to) {
    final moved = to != _hi;
    setState(() {
      _hi = to;
      _keyHighlight = true;
    });
    _reveal(to);
    // Focus stays in the field (or the search pill), so a screen reader hears where the highlight went.
    if (moved) _announceHighlight();
  }

  void _announceHighlight() {
    final entries = _entries;
    if (!_isItem(entries, _hi)) return;
    final items = entries.whereType<_ItemEntry<T>>().toList();
    final e = entries[_hi] as _ItemEntry<T>;
    final position = items.indexOf(e) + 1;
    _announce('${[e.title, ?e.caption].join(', ')}, $position of ${items.length}');
  }

  int _pageFrom(List<_Entry<T>> entries, int from, int direction) {
    var to = from;
    var travelled = 0.0;
    final page = MyDataSelect.visibleRows * context.density.controlHeight;
    for (var i = from + direction; i >= 0 && i < entries.length; i += direction) {
      travelled += _extentOf(context.look, entries[i]);
      if (travelled > page) break;
      if (entries[i] is _ItemEntry<T>) to = i;
    }
    return to;
  }

  /// Keys while the list is open (from the field, or from the search pill in the long-list variant).
  KeyEventResult _onOpenKey(KeyEvent event, {required bool fromSearch}) {
    final key = event.logicalKey;
    final entries = _entries;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _close(refocus: fromSearch);
      if (fromSearch) {
        // Focus moves on from the field, as if Tab had been pressed there.
        HardwareKeyboard.instance.isShiftPressed ? _node.previousFocus() : _node.nextFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _pickHighlighted();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space && !fromSearch) {
      _pickHighlighted();
      return KeyEventResult.handled;
    }
    int? to;
    if (key == LogicalKeyboardKey.arrowDown) {
      to = _hi < 0 ? _firstItem(entries) : _nextItem(entries, _hi, 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      to = _hi < 0 ? _firstItem(entries) : _nextItem(entries, _hi, -1);
    } else if (key == LogicalKeyboardKey.home && !fromSearch) {
      to = _firstItem(entries);
    } else if (key == LogicalKeyboardKey.end && !fromSearch) {
      to = _lastItem(entries);
    } else if (key == LogicalKeyboardKey.pageDown) {
      to = _pageFrom(entries, _hi, 1);
    } else if (key == LogicalKeyboardKey.pageUp) {
      to = _pageFrom(entries, _hi, -1);
    }
    if (to != null) {
      if (to >= 0) _moveHighlight(to);
      return KeyEventResult.handled;
    }
    if (!fromSearch) {
      final ch = event.character;
      if (_printable(ch)) {
        final i = _typeAhead(entries, ch!, from: _hi);
        if (i != null) _moveHighlight(i);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// The next item from [from] in [direction]; it stops at the ends.
  int _nextItem(List<_Entry<T>> entries, int from, int direction) {
    for (var i = from + direction; i >= 0 && i < entries.length; i += direction) {
      if (entries[i] is _ItemEntry<T>) return i;
    }
    return from;
  }

  static bool _printable(String? ch) => ch != null && ch.isNotEmpty && ch.runes.first > 0x20 && ch.runes.first != 0x7F;

  /// The next item after [from] whose title starts with the letters typed so far, going round.
  int? _typeAhead(List<_Entry<T>> entries, String ch, {required int from}) {
    final again = _typed.isNotEmpty && _typed == ch * _typed.length;
    _typed += ch;
    _typedTimer?.cancel();
    _typedTimer = Timer(ContactList.typeAheadTimeout, () => _typed = '');
    // Pressing the same letter again steps through the items that start with it.
    final prefix = foldForSearch(again ? ch : _typed);
    final start = again || _typed.length == 1 ? from + 1 : math.max(from, 0);
    for (var n = 0; n < entries.length; n++) {
      final i = (start + n) % entries.length;
      final e = entries[i];
      if (e is _ItemEntry<T> && !e.custom && foldForSearch(e.title).startsWith(prefix)) return i;
    }
    return null;
  }

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (!_enabled) return KeyEventResult.ignored;
    if (FormBusy.read(context) && !_open) {
      // Waiting for the host: the keys that would open it or change it do nothing.
      final key = event.logicalKey;
      final opens = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp;
      return opens || _printable(event.character) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (_open) return _onOpenKey(event, fromSearch: false);
    final key = event.logicalKey;
    final k = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      if (k.isMetaPressed || k.isControlPressed) return KeyEventResult.ignored;
      _activate();
      return KeyEventResult.handled;
    }
    if (k.isMetaPressed || k.isControlPressed || k.isAltPressed) return KeyEventResult.ignored;
    final ch = event.character;
    if (_printable(ch) && AppLayout.of(context) != AppLayout.phone) {
      // Type-ahead, closed: the value changes without opening the list.
      final entries = _entries;
      final i = _typeAhead(entries, ch!, from: _indexOfCurrent(entries));
      if (i != null) {
        final item = (entries[i] as _ItemEntry<T>).item;
        if (item.value != widget.value) {
          widget.onChanged!(item.value);
          _announce(_titleOf(item));
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    return _onOpenKey(event, fromSearch: true);
  }

  void _queryChanged() {
    if (!_open) return;
    final entries = _entries;
    setState(() {
      _hi = _firstItem(entries);
      _keyHighlight = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _announceTimer?.cancel();
    if (_search.text.trim().isEmpty || widget.matchCount == null) return;
    _announceTimer = Timer(MyDataSelect.announceDelay, () {
      if (!mounted || !_open) return;
      _announce(widget.matchCount!(_entries.whereType<_ItemEntry<T>>().length));
    });
  }

  /// Scrolls entry [index] into view, or to the middle of the list when [centre].
  void _reveal(int index, {bool centre = false}) {
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final entries = _entries;
      if (index >= entries.length) return;
      var top = 0.0;
      for (var i = 0; i < index; i++) {
        top += _extentOf(context.look, entries[i]);
      }
      final bottom = top + _extentOf(context.look, entries[index]);
      final p = _scroll.position;
      var to = p.pixels;
      if (centre) {
        to = top - (p.viewportDimension - (bottom - top)) / 2;
      } else if (bottom > to + p.viewportDimension) {
        to = bottom - p.viewportDimension;
      } else if (top < to) {
        to = top;
      }
      to = to.clamp(0.0, p.maxScrollExtent);
      if (to != p.pixels) _scroll.jumpTo(to);
    });
  }

  // ----- Phone -----------------------------------------------------------------------------------------

  Future<void> _openOnPhone() async {
    final route = _searchable
        ? MaterialPageRoute<_SheetResult<T>>(
            builder: (_) => _PickerPage<T>(
              title: widget.label,
              items: widget.items,
              suggested: widget.suggested,
              suggestedHeading: widget.suggestedHeading,
              value: widget.value,
              searchPlaceholder: widget.searchPlaceholder!,
              noMatches: widget.noMatches,
            ),
          )
        : null;
    final _SheetResult<T>? result;
    if (route != null) {
      result = await Navigator.of(context).push(route);
    } else {
      final entries = _entries;
      result = await showSheet<_SheetResult<T>>(
        context: context,
        builder: (_) => _PickerSheet<T>(
          title: widget.label,
          entries: entries,
          value: widget.value,
          currentTitle: _current?.title ?? '',
          allowsCustom: widget.onCustomLabel != null,
        ),
      );
    }
    if (!mounted || result == null) return;
    if (result.custom != null) {
      if (result.custom!.isNotEmpty && result.custom != _current?.title) widget.onCustomLabel!(result.custom!);
    } else if (result.value != widget.value) {
      widget.onChanged!(result.value as T);
    }
  }

  // ----- Building --------------------------------------------------------------------------------------

  /// The width of [text] in the closed field's [style], as the Text draws it: merged into the ambient style
  /// (which can add letter spacing).
  double _textWidth(BuildContext context, String text, TextStyle style) {
    final p = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  /// The field's room around its text: the padding, a dot and its gap, the gap and the chevron.
  double _chrome({required bool dot}) =>
      2 * context.space(4) + (dot ? MyDataSelect.dotSize + context.space(2) : 0) + context.space(2) + context.density.icon;

  /// [MyDataSelect.fitToItems]: as wide as the longest preset. A longer custom label is cut short.
  double _fitWidth(BuildContext context, TextStyle style) {
    var widest = 0.0;
    var dots = false;
    for (final i in widget.items) {
      widest = math.max(widest, _textWidth(context, i.title, style));
      dots = dots || i.hasDot;
    }
    return _chrome(dot: dots) + widest.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = widget.error != null;
    final note = widget.error ?? (_enabled ? widget.help : (widget.disabledReason ?? widget.help));
    final current = _current;
    final borderWidth = hasError ? MyDataSelect.errorBorderWidth : MyDataSelect.borderWidth;
    final shown = current == null ? null : _titleOf(current);
    final valueStyle = PhoneType.bodyOf(context);
    final fitWidth = widget.fitToItems ? _fitWidth(context, valueStyle) : null;

    Widget field;
    if (_editingCustom) {
      field = _CustomLabelField(
        controller: _customText,
        focusNode: _customNode,
        onKey: _onCustomKey,
        semanticLabel: widget.semanticLabel ?? widget.label,
      );
    } else {
      final value = Row(
        children: [
          if (current != null && current.hasDot) ...[
            DataDot(colour: current.dot, ground: DataGround.surface, alsoOn: const [DataGround.surfaceHover]),
            SizedBox(width: context.space(2)),
          ],
          Expanded(
            child: Text(
              shown ?? widget.placeholder ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: valueStyle.copyWith(color: shown == null ? c.inkMuted : c.ink),
            ),
          ),
          SizedBox(width: context.space(2)),
          Icon(context.icon(MyDataIcon.upDown), size: context.density.icon, color: c.inkMuted),
        ],
      );
      Widget box = AnimatedContainer(
        key: _fieldKey,
        duration: context.motion.fast,
        curve: context.motion.standard,
        height: context.density.controlHeight,
        padding: EdgeInsets.symmetric(horizontal: math.max(0, InputBox.inset(context.look) - borderWidth)),
        decoration: InputBox.of(context.look,
            edge: hasError ? c.danger : c.lineStrong, width: borderWidth, hovered: _hovered && _enabled),
        child: ExcludeSemantics(child: value),
      );
      // A custom label longer than the presets is cut short; its tooltip shows it in full.
      if (fitWidth != null &&
          shown != null &&
          _textWidth(context, shown, valueStyle) > fitWidth - _chrome(dot: current?.hasDot ?? false)) {
        box = Tooltip(message: shown, excludeFromSemantics: true, child: box);
      }
      field = Semantics(
        label: widget.semanticLabel ?? widget.label,
        value: shown ?? widget.placeholder,
        hint: note,
        expanded: _enabled ? _open : null,
        validationResult: hasError ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            onPointerDown: (_) => _pointer = true,
            onPointerUp: (_) => WidgetsBinding.instance.addPostFrameCallback((_) => _pointer = false),
            onPointerCancel: (_) => _pointer = false,
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _onFieldKey,
              child: Pressable(
                onPressed: _enabled ? _activate : null,
                borderRadius: MyDataRadii.md(context.look),
                scaleOnPress: false,
                focusNode: _node,
                autofocus: widget.autofocus,
                danger: hasError,
                child: box,
              ),
            ),
          ),
        ),
      );
      field = MergeSemantics(child: field);
      field = TapRegion(
        groupId: _tapGroup,
        onTapOutside: (_) {
          if (_open) _close(refocus: false);
        },
        child: OverlayPortal(controller: _portal, overlayChildBuilder: _buildList, child: field),
      );
    }

    if (fitWidth != null) field = SizedBox(width: fitWidth, child: field);

    final children = <Widget>[
      if (widget.showLabel) ...[
        // Disabled, the label fades with the field: it is part of the control. The reason under it does not
        // (design/platforms.md "Disabled controls").
        Opacity(
          opacity: _enabled ? 1 : Pressable.disabledOpacity,
          child: ExcludeSemantics(
            child: RoleLabel(widget.label, color: c.ink),
          ),
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
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.fitToItems ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// The open list's natural width: its widest row (the dot, the title or caption, the check mark) and its
  /// padding. The list is never narrower than the field.
  double _listWidth(BuildContext context, List<_Entry<T>> entries) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;
    double measure(String text, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    var widest = 0.0;
    for (final e in entries) {
      final w = switch (e) {
        _ItemEntry<T>() =>
          (e.hasDot ? MyDataSelect.dotSize + context.space(2) : 0) +
              math.max(
                measure(e.title, context.typeScale.body),
                e.caption == null ? 0.0 : measure(e.caption!, context.typeScale.caption),
              ) +
              context.space(2) +
              context.density.icon,
        _NoneEntry<T>(:final text) => measure(text, context.typeScale.body),
        _HeadingEntry<T>(:final text) => measure(context.typeScale.cased(MyDataTypeRole.label, text), context.typeScale.label),
        _DividerEntry<T>() => 0.0,
      };
      widest = math.max(widest, w);
    }
    final rows = 2 * context.space(3) + widest.ceilToDouble() + 2 * context.space(1);
    // The search pill needs room for its placeholder.
    final search = _searchable
        ? 2 * context.space(4) + context.density.icon + context.space(2) + measure(widget.searchPlaceholder!, context.typeScale.body)
        : 0.0;
    return math.max(rows, search + 2 * context.space(1));
  }

  Widget _buildList(BuildContext context) {
    final c = context.colors;
    final fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (fieldBox == null || overlayBox == null || !fieldBox.attached) return const SizedBox.shrink();
    final anchor = MatrixUtils.transformRect(fieldBox.getTransformTo(overlayBox), Offset.zero & fieldBox.size);
    final entries = _entries;
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    final items = entries.whereType<_ItemEntry<T>>().toList();

    var position = 0;
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      switch (e) {
        case _ItemEntry<T>():
          position++;
          final index = i;
          rows.add(
            _ListRow<T>(
              entry: e,
              chosen: !e.custom && widget.value != null && e.item.value == widget.value,
              highlighted: i == _hi,
              ring: i == _hi && _keyHighlight,
              position: position,
              count: items.length,
              onHover: () {
                if (_hi != index || _keyHighlight) {
                  setState(() {
                    _hi = index;
                    _keyHighlight = false;
                  });
                }
              },
              onTap: () => _pick(e),
            ),
          );
        case _DividerEntry<T>():
          rows.add(
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.space(1)),
              child: Container(height: 1, color: c.line),
            ),
          );
        case _HeadingEntry<T>(:final text):
          rows.add(
            Padding(
              padding: EdgeInsets.fromLTRB(context.space(3), context.space(2), context.space(3), context.space(1)),
              child: Semantics(
                header: true,
                child: RoleLabel(text, color: c.inkMuted),
              ),
            ),
          );
        case _NoneEntry<T>(:final text):
          rows.add(
            SizedBox(
              height: _noneExtent(context.look),
              child: Padding(
                padding: EdgeInsets.all(context.space(3)),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typeScale.body.copyWith(color: c.inkMuted),
                ),
              ),
            ),
          );
      }
    }

    var listHeight = 0.0;
    for (final e in entries) {
      listHeight += _extentOf(context.look, e);
    }
    final width = _listWidth(context, entries);
    final maxRows = MyDataSelect.visibleRows * context.density.controlHeight;

    Widget panel = Container(
      decoration: context.radius.decorate(BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: MyDataRadii.md(context.look),
        boxShadow: context.shadows.shadow2,
      )),
      padding: EdgeInsets.all(context.space(1)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_searchable)
            Padding(
              padding: EdgeInsets.only(bottom: context.space(1)),
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: _onSearchKey,
                child: MyDataSearchField(
                  controller: _search,
                  placeholder: widget.searchPlaceholder!,
                  focusNode: _searchNode,
                ),
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: math.min(listHeight, maxRows)),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: widget.semanticLabel ?? widget.label,
                child: Scrollbar(
                  controller: _scroll,
                  child: ListView(controller: _scroll, padding: EdgeInsets.zero, shrinkWrap: true, children: rows),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final below = overlayBox.size.height - anchor.bottom;
    final panelHeight =
        math.min(listHeight, maxRows) +
        2 * context.space(1) +
        (_searchable ? context.density.controlHeight + context.space(1) : 0);
    final up = below < panelHeight + context.space(1) + context.space(2) && anchor.top > below;

    panel = AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final t = context.motion.standard.transform(_motion.value);
        final grow = reduced || _motion.status == AnimationStatus.reverse ? 1.0 : 0.97 + 0.03 * t;
        return Opacity(
          opacity: reduced ? _motion.value : (_motion.status == AnimationStatus.reverse ? _motion.value : t),
          child: Transform.scale(
            scaleX: 1,
            scaleY: grow,
            alignment: up ? Alignment.bottomCenter : Alignment.topCenter,
            child: child,
          ),
        );
      },
      child: panel,
    );

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _PopoverLayout(anchor: anchor, above: up, width: width, look: context.look),
        child: TapRegion(
          groupId: _tapGroup,
          child: Material(type: MaterialType.transparency, child: panel),
        ),
      ),
    );
  }
}

/// Places the open list `space-1` under the field (or above it), at least as wide as the field and no wider
/// than the window less `space-2` each side.
class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout({required this.anchor, required this.above, required this.width, required this.look});
  final Rect anchor;
  final bool above;
  final MyDataLook look;

  /// The list's own width, from its widest row.
  final double width;

  static double gap(MyDataLook look) => look.space(1);
  static double margin(MyDataLook look) => look.space(2);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxW = math.max(0.0, constraints.maxWidth - 2 * margin(look));
    final room = above ? anchor.top - gap(look) - margin(look) : constraints.maxHeight - anchor.bottom - gap(look) - margin(look);
    final w = width.clamp(math.min(anchor.width, maxW), maxW).toDouble();
    return BoxConstraints(minWidth: w, maxWidth: w, maxHeight: math.max(0.0, room));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = anchor.left.clamp(margin(look), math.max(margin(look), size.width - margin(look) - childSize.width)).toDouble();
    final y = above ? anchor.top - gap(look) - childSize.height : anchor.bottom + gap(look);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor || old.above != above || old.width != width || old.look != look;
}

/// One item row of the open list.
class _ListRow<T> extends StatelessWidget {
  const _ListRow({
    required this.entry,
    required this.chosen,
    required this.highlighted,
    required this.ring,
    required this.position,
    required this.count,
    required this.onHover,
    required this.onTap,
  });
  final _ItemEntry<T> entry;
  final bool chosen;
  final bool highlighted;
  final bool ring;
  final int position;
  final int count;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = entry;
    final title = Text(
      item.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: context.typeScale.body.copyWith(color: c.ink),
    );
    return Semantics(
      selected: chosen,
      button: false,
      label: [item.title, ?item.caption].join(', '),
      hint: '$position of $count',
      onTap: onTap,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (_) => onHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: CustomPaint(
              foregroundPainter: ring
                  ? InsetRingPainter(shape: context.radius, color: FocusRing.colourFor(context), borderRadius: MyDataRadii.sm(context.look))
                  : null,
              child: Container(
                height: item.caption == null ? context.density.controlHeight : context.density.rowHeight,
                padding: EdgeInsets.symmetric(horizontal: context.space(3)),
                decoration: context.radius.decorate(BoxDecoration(color: highlighted ? c.surfaceHover : null, borderRadius: MyDataRadii.sm(context.look))),
                child: Row(
                  children: [
                    if (item.hasDot) ...[
                      DataDot(colour: item.dot, ground: DataGround.surfaceHover),
                      SizedBox(width: context.space(2)),
                    ],
                    Expanded(
                      child: item.caption == null
                          ? title
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                Text(
                                  item.caption!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typeScale.caption.copyWith(color: c.inkMuted),
                                ),
                              ],
                            ),
                    ),
                    if (chosen) ...[
                      SizedBox(width: context.space(2)),
                      Icon(context.icon(MyDataIcon.check), size: context.density.icon, color: c.accent),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The text field a custom label is typed into, in the Select's place: the same box, focused.
class _CustomLabelField extends StatelessWidget {
  const _CustomLabelField({
    required this.controller,
    required this.focusNode,
    required this.onKey,
    required this.semanticLabel,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusOnKeyEventCallback onKey;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = PhoneType.bodyOf(context).copyWith(color: c.ink);
    final vertical = (context.density.controlHeight - style.fontSize! * style.height!) / 2 - MyDataTextField.borderWidth;
    return FocusRing(
      visible: true,
      borderRadius: MyDataRadii.md(context.look),
      clearance: InputBox.focusClearance(context),
      child: Container(
        height: context.density.controlHeight,
        decoration: InputBox.of(context.look, edge: c.lineStrong, width: MyDataTextField.borderWidth),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: onKey,
          child: Semantics(
            label: semanticLabel,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: FormBusy.of(context),
              maxLines: 1,
              style: style,
              cursorColor: c.accent,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.space(4) - MyDataTextField.borderWidth,
                  vertical: vertical,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a phone picker returns: a value, or a typed custom label.
class _SheetResult<T> {
  const _SheetResult.value(this.value) : custom = null;
  const _SheetResult.custom(this.custom) : value = null;
  final T? value;
  final String? custom;
}

/// The picker sheet on a phone (design/components/Sheet, "Picker sheet"): a [Sheet] titled with the field's
/// name, its items as `row-height` rows with the check mark on the chosen one. A tap picks and closes.
/// "Custom label…" turns it into a text field with Done; what is typed there is pending input until Done.
class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.entries,
    required this.value,
    required this.currentTitle,
    required this.allowsCustom,
  });
  final String title;
  final List<_Entry<T>> entries;
  final T? value;
  final String currentTitle;
  final bool allowsCustom;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  bool _custom = false;
  late final _text = TextEditingController(text: widget.currentTitle);
  final _chosenNode = FocusNode(debugLabel: 'Select sheet chosen row');

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _chosenNode.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_SheetResult<T>.custom(_text.text.trim()));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    var hasChosen = false;
    for (final e in widget.entries) {
      switch (e) {
        case _ItemEntry<T>(:final custom):
          final chosen = !custom && widget.value != null && e.item.value == widget.value;
          hasChosen = hasChosen || chosen;
          rows.add(
            SheetPickerRow(
              label: e.title,
              caption: e.caption,
              chosen: chosen,
              focusNode: chosen ? _chosenNode : null,
              leading: e.hasDot ? DataDot(colour: e.dot, ground: DataGround.surfaceHover) : null,
              onPressed: () {
                if (custom) {
                  _text.selection = TextSelection(baseOffset: 0, extentOffset: _text.text.length);
                  setState(() => _custom = true);
                } else {
                  Navigator.of(context).pop(_SheetResult<T>.value(e.item.value));
                }
              },
            ),
          );
        case _DividerEntry<T>():
          rows.add(Container(height: 1, color: c.line));
        case _HeadingEntry<T>() || _NoneEntry<T>():
          break;
      }
    }
    if (_custom) {
      return Sheet(
        kind: SheetKind.picker,
        title: widget.title,
        pending: _text.text.trim() != widget.currentTitle,
        discardMessage: MyDataSelect.customDiscardMessage,
        trailing: Button(label: Sheet.doneLabel, variant: ButtonVariant.plain, onPressed: _done),
        body: MyDataTextField(
          label: widget.title,
          showLabel: false,
          controller: _text,
          autofocus: true,
          onSubmitted: (_) => _done(),
        ),
      );
    }
    return Sheet(
      kind: SheetKind.picker,
      title: widget.title,
      initialFocus: hasChosen ? _chosenNode : null,
      // The rows reach the sheet's edges and scroll under the header when there are many.
      scrollable: false,
      body: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: rows),
    );
  }
}

/// The long-list variant on a phone: a pushed full-screen page with the search pill at the top and the
/// keyboard up.
class _PickerPage<T> extends StatefulWidget {
  const _PickerPage({
    required this.title,
    required this.items,
    required this.suggested,
    required this.suggestedHeading,
    required this.value,
    required this.searchPlaceholder,
    required this.noMatches,
  });
  final String title;
  final List<SelectItem<T>> items;
  final List<SelectItem<T>> suggested;
  final String suggestedHeading;
  final T? value;
  final String searchPlaceholder;
  final String Function(String query)? noMatches;

  @override
  State<_PickerPage<T>> createState() => _PickerPageState<T>();
}

class _PickerPageState<T> extends State<_PickerPage<T>> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _search.text.trim();
    final matches = [
      for (final i in widget.items)
        if (matchesWordStart(i.title, q) || (i.caption != null && matchesWordStart(i.caption!, q))) i,
    ];
    Widget row(SelectItem<T> i) => SheetPickerRow(
      label: i.title,
      caption: i.caption,
      leading: i.hasDot ? DataDot(colour: i.dot, ground: DataGround.surfaceHover) : null,
      chosen: widget.value != null && i.value == widget.value,
      onPressed: () => Navigator.of(context).pop(_SheetResult<T>.value(i.value)),
    );
    return Scaffold(
      backgroundColor: c.surfaceRaised,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: context.density.controlHeight,
              child: NavigationToolbar(
                leading: Button(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  variant: ButtonVariant.plain,
                ),
                middle: Semantics(
                  header: true,
                  child: Text(widget.title, style: context.typeScale.heading.copyWith(color: c.ink)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.space(4)),
              child: MyDataSearchField(controller: _search, placeholder: widget.searchPlaceholder, autofocus: true),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (q.isEmpty && widget.suggested.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.space(4),
                        context.space(2),
                        context.space(4),
                        context.space(1),
                      ),
                      child: Semantics(
                        header: true,
                        child: RoleLabel(widget.suggestedHeading, color: c.inkMuted),
                      ),
                    ),
                    for (final i in widget.suggested) row(i),
                    Container(height: 1, color: c.line),
                  ],
                  if (matches.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(context.space(4)),
                      child: Text(
                        widget.noMatches?.call(q) ?? 'Nothing matches “$q”',
                        style: context.typeScale.body.copyWith(color: c.inkMuted),
                      ),
                    )
                  else
                    for (final i in matches) row(i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
