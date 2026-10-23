import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'event_row.dart' show formatEventTime;
import 'form_row.dart' show FormGroupHeading;
import 'form_scope.dart';
import 'picker_field.dart';
import 'sheet.dart';

// ---------------------------------------------------------------------------------------------------------------
// Times as the field writes and reads them
// ---------------------------------------------------------------------------------------------------------------

/// Minutes in a day.
const _day = 24 * 60;

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

TimeOfDay _time(int minutes) {
  final m = ((minutes % _day) + _day) % _day;
  return TimeOfDay(hour: m ~/ 60, minute: m % 60);
}

/// A time as the locale writes it, never with seconds: "09:30" on a 24-hour clock, "9:30 am" on a 12-hour
/// one (British English, as [formatEventTime]).
String formatPickerTime(TimeOfDay t, {required bool use24HourFormat}) =>
    formatEventTime(DateTime(2000, 1, 1, t.hour, t.minute), use24HourFormat: use24HourFormat);

/// A length as a short duration: "30 min", "1 hr", "1 hr 45 min".
String formatShortDuration(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return [if (h > 0) '$h hr', if (m > 0) '$m min'].join(' ');
}

/// A length as a screen reader says it: "30 minutes", "1 hour", "1 hour 45 minutes".
String spokenDuration(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return [
    if (h > 0) '$h ${h == 1 ? 'hour' : 'hours'}',
    if (m > 0) '$m ${m == 1 ? 'minute' : 'minutes'}',
  ].join(' ');
}

final _marker = RegExp(r'\s*([ap])\.?\s*(m\.?)?$');
final _split = RegExp(r'^(\d{1,2})(?:[:.](\d{2}))?$');
final _digits = RegExp(r'^(\d{3,4})$');

/// Reads a typed time (design/components/TimePicker, "Typing"):
///
/// - parts split by ":" or "." or not at all; one or two digits are the hour, three or four end with the
///   minutes ("930", "2130");
/// - "am" and "pm" in any case, with or without dots and a space, or "a" and "p", in every locale; after an
///   hour of 0 or over 12 they are an error ("13pm");
/// - with no "am" or "pm": 13 to 23 and 0 on the 24-hour clock everywhere; on a 24-hour locale 1 to 12 as
///   written; on a 12-hour locale 1 to 11 in the morning and 12 at noon, except in an end field ([after]: the
///   start), where it is the first such time after the start ("5" after a 2 pm start is 5 pm).
///
/// Null when the text is not a time.
TimeOfDay? parseTypedTime(String text, {required bool use24HourFormat, TimeOfDay? after}) {
  var t = text.trim().toLowerCase();
  String? marker;
  final mk = _marker.firstMatch(t);
  if (mk != null) {
    marker = mk.group(1);
    t = t.substring(0, mk.start).trim();
  }
  int h, m;
  final a = _split.firstMatch(t);
  final b = _digits.firstMatch(t);
  if (a != null) {
    h = int.parse(a.group(1)!);
    m = a.group(2) == null ? 0 : int.parse(a.group(2)!);
  } else if (b != null) {
    final s = b.group(1)!;
    h = int.parse(s.substring(0, s.length - 2));
    m = int.parse(s.substring(s.length - 2));
  } else {
    return null;
  }
  if (h > 23 || m > 59) return null;
  if (marker != null) {
    if (h < 1 || h > 12) return null;
    return TimeOfDay(hour: h % 12 + (marker == 'p' ? 12 : 0), minute: m);
  }
  if (h >= 13 || h == 0 || use24HourFormat) return TimeOfDay(hour: h, minute: m);
  final am = (h % 12) * 60 + m, pm = am + 12 * 60;
  if (after != null) {
    final start = _minutes(after);
    if (am > start) return _time(am);
    if (pm > start) return _time(pm);
    return _time(am);
  }
  return _time(h == 12 ? pm : am);
}

/// The quarter hour after or before [t] (9:37 goes to 9:45 or 9:30), going round midnight.
TimeOfDay stepQuarterHour(TimeOfDay t, {required bool up}) {
  final m = _minutes(t);
  final step = TimePicker.step;
  final next = up ? (m ~/ step + 1) * step : (m % step == 0 ? m - step : m ~/ step * step);
  return _time(next);
}

// ---------------------------------------------------------------------------------------------------------------
// TimePicker
// ---------------------------------------------------------------------------------------------------------------

/// A field for a time of day in a form: typed as people write times, stepped with the arrow keys, or picked
/// from a list of quarter hours (design/components/TimePicker).
///
/// - **A wall time**, with no zone of its own: the host converts it with the event's zone.
/// - **The field** looks like a TextField, with the time as the locale writes it ("09:30", "9:30 am") and a
///   clock icon at its end, as wide as the longest time ("12:45 pm").
/// - **Typing** ([parseTypedTime]): Return, Tab or leaving the field commits and rewrites the time; Escape
///   puts back the time from before. Text that is not a time is an error: "That is not a time. Type it like
///   9:30 or 21:30." Return commits first: with the list open it closes the list, with an error it stops
///   there, and otherwise it goes on to the form (a Dialog then confirms with the committed time). A holder
///   commits typing before it saves ([PendingInput]). While the form waits for the host ([FormBusy]) the
///   field is read-only and does not step or open.
/// - **Keys:** Up and Down step to the next or previous quarter hour and announce it, going round midnight
///   without changing a date. Option-Down (Alt-Down elsewhere), or a click, opens the list; in it the keys
///   are Select's.
/// - **The list** (Select's): a time every 15 minutes, opened with the field's time (or the nearest step) in
///   the middle, a check mark on the field's time. In an end field ([start] given) it starts 15 minutes after
///   the start and runs for 24 hours, each row adding the length ("10:30  1 hr"); a row past midnight also
///   reports the next day ([onEndDayFromList]).
/// - **Phone** (under 600px): tapping opens a picker [Sheet] with Cancel and Done, the field for typing and the
///   list as `row-height` rows; typed text not yet committed with Done is pending input there.
/// - **Disabled** ([disabledReason]): 45% opacity, not focusable, the reason as the help line, not faded.
///
/// For the event editor's "When" group (All-day, Starts, Ends, Time zone, Repeat) see [EventWhenGroup].
class TimePicker extends StatefulWidget {
  const TimePicker({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.value,
    required this.onChanged,
    this.showLabel = true,
    this.use24HourFormat,
    this.start,
    this.onEndDayFromList,
    this.help,
    this.error,
    this.disabledReason,
    this.compact = false,
    this.focusNode,
    this.onErrorChanged,
  });

  /// The visible label ("Starts"), shown when [showLabel].
  final String label;

  /// The accessible name: "Start time" or "End time".
  final String semanticLabel;

  /// False when the label above a date and a time covers both (the event editor's "Starts").
  final bool showLabel;

  /// The time; null shows an empty field.
  final TimeOfDay? value;

  /// Called with the new time when one is committed (typed, stepped or picked).
  final ValueChanged<TimeOfDay> onChanged;

  /// The clock; null follows `MediaQuery.alwaysUse24HourFormat`.
  final bool? use24HourFormat;

  /// For an end field: the start time the list and a bare hour are measured from.
  final TimeOfDay? start;

  /// In an end field, after a pick from the list: how many days after the start's date the picked row
  /// falls on (0, or 1 past midnight), so the editor moves the end date. Typing never moves a date.
  final ValueChanged<int>? onEndDayFromList;
  final String? help;

  /// An error from the form, such as "Ends before it starts. Change the end date or time."
  final String? error;

  /// Disables the field. A field is never disabled without a reason, a full sentence with a full stop.
  final String? disabledReason;

  /// The Compact density on desktop: the field and the rows are `control-height-compact`.
  final bool compact;
  final FocusNode? focusNode;

  /// Called with the field's own error when it appears (non-null) and when it goes (null).
  final ValueChanged<String?>? onErrorChanged;

  /// The step of the arrow keys and the list (decided 2026-10-14).
  static const step = 15;

  /// Where Up and Down start when the field is empty.
  static const emptyStart = TimeOfDay(hour: 9, minute: 0);

  static const notATimeError = 'That is not a time. Type it like 9:30 or 21:30.';

  /// "Discard changes?"'s body when a time typed in the phone's sheet would be lost.
  static const typedDiscardMessage = 'The time you typed is not set.';
  static const cancelLabel = 'Cancel';
  static const doneLabel = 'Done';

  /// The field's hint.
  static const hint = 'Type a time, or press Up or Down arrow to change it by 15 minutes';

  /// The list's rows: every quarter hour of the day, or, after [start], 15 minutes to 24 hours after it.
  /// Each row is (minutes from midnight of the start's day, its time).
  static List<({int offset, TimeOfDay time})> rows({TimeOfDay? start}) {
    if (start == null) return [for (var m = 0; m < _day; m += step) (offset: m, time: _time(m))];
    final s = _minutes(start);
    return [for (var d = step; d <= _day; d += step) (offset: s + d, time: _time(s + d))];
  }

  @override
  State<TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<TimePicker> with PendingInputRegistration<TimePicker> {
  final _boxKey = GlobalKey();
  late final TextEditingController _text = TextEditingController();
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'TimePicker'));
  final _listNode = FocusNode(debugLabel: 'TimePicker list');

  bool _open = false;
  bool _pointerFocus = false;
  bool _dirty = false;
  String? _ownError;
  bool _initialised = false;

  /// While typing, the time the text reads as.
  TimeOfDay? _preview;

  bool get _use24 => widget.use24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context);
  bool get _disabled => widget.disabledReason != null;

  @override
  bool get hasPendingInput => _dirty;

  @override
  bool commitPendingInput() {
    _commit();
    return !_dirty && _ownError == null;
  }

  @override
  FocusNode get pendingInputFocus => _node;

  String _format(TimeOfDay? t) => t == null ? '' : formatPickerTime(t, use24HourFormat: _use24);

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
    _listNode.addListener(_onFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised || !_dirty) _text.text = _format(widget.value);
    _initialised = true;
  }

  @override
  void didUpdateWidget(TimePicker old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_onFocus);
      _node.addListener(_onFocus);
    }
    if ((old.value != widget.value || old.use24HourFormat != widget.use24HourFormat) && !_dirty) {
      _text.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _ownNode?.dispose();
    _listNode.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    if (!_node.hasFocus && !_listNode.hasFocus) {
      _pointerFocus = false;
      _commit();
      if (_open) setState(() => _open = false);
    }
    setState(() {});
  }

  void _setError(String? error) {
    if (error == _ownError) return;
    setState(() => _ownError = error);
    widget.onErrorChanged?.call(error);
    if (error != null) SemanticsService.sendAnnouncement(View.of(context), error, Directionality.of(context));
  }

  TimeOfDay? _parse(String text) => parseTypedTime(text, use24HourFormat: _use24, after: widget.start);

  void _emit(TimeOfDay t) {
    _text.text = _format(t);
    _dirty = false;
    _preview = null;
    _setError(null);
    if (t != widget.value) widget.onChanged(t);
  }

  void _commit() {
    if (!_dirty) return;
    final t = _parse(_text.text);
    if (t == null) {
      _setError(TimePicker.notATimeError);
      return;
    }
    _emit(t);
  }

  bool _revert() {
    if (!_dirty && _ownError == null) return false;
    setState(() {
      _text.text = _format(widget.value);
      _dirty = false;
      _preview = null;
    });
    _setError(null);
    return true;
  }

  void _step(bool up) {
    final base = (_dirty ? _parse(_text.text) : null) ?? widget.value ?? TimePicker.emptyStart;
    final next = stepQuarterHour(base, up: up);
    _emit(next);
    setState(() {});
    SemanticsService.sendAnnouncement(View.of(context), _format(next), Directionality.of(context));
  }

  void _openList({required bool focusList}) {
    if (_disabled || FormBusy.read(context)) return;
    if (!_open) setState(() => _open = true);
    if (focusList) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) _listNode.requestFocus();
      });
    }
  }

  void _close({bool refocus = true}) {
    if (!_open) return;
    setState(() => _open = false);
    if (refocus) {
      _pointerFocus = false;
      _node.requestFocus();
    }
  }

  void _pickRow(({int offset, TimeOfDay time}) row) {
    _emit(row.time);
    if (widget.start != null) widget.onEndDayFromList?.call(row.offset >= _day ? 1 : 0);
  }

  /// The row the list opens on: the field's time, or the nearest step to it; and whether it is exact.
  (int, bool) _anchor(List<({int offset, TimeOfDay time})> rows) {
    final t = _preview ?? widget.value;
    if (t == null) {
      final i = rows.indexWhere((r) => r.time == TimePicker.emptyStart);
      return (i < 0 ? 0 : i, false);
    }
    if (widget.start == null) {
      final i = ((_minutes(t) / TimePicker.step).round()) % rows.length;
      return (i, _minutes(t) % TimePicker.step == 0);
    }
    var diff = (_minutes(t) - _minutes(widget.start!)) % _day;
    if (diff <= 0) diff += _day;
    final i = ((diff / TimePicker.step).round() - 1).clamp(0, rows.length - 1);
    return (i, diff % TimePicker.step == 0);
  }

  List<PickerListItem> _items(List<({int offset, TimeOfDay time})> rows) {
    final start = widget.start;
    return [
      for (final r in rows)
        start == null
            ? PickerListItem(title: _format(r.time))
            : PickerListItem(
                title: _format(r.time),
                detail: formatShortDuration(r.offset - _minutes(start)),
                semanticLabel: '${_format(r.time)}, ${spokenDuration(r.offset - _minutes(start))}',
              ),
    ];
  }

  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final k = HardwareKeyboard.instance;
    final alt = k.isAltPressed;
    final arrows = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp;
    // Waiting for the host: the field neither steps nor opens.
    if (arrows && FormBusy.read(context)) return KeyEventResult.handled;
    if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) &&
        event is KeyDownEvent &&
        !k.isMetaPressed &&
        !k.isControlPressed &&
        !alt &&
        !k.isShiftPressed) {
      // Return commits first, so a Dialog's Return confirms with the typed time. With the list open it only
      // closes it; with an error it stops here (design/components/Dialog: "unless the field has its own list
      // or popover open … Return then acts on that first").
      _commit();
      if (_open) {
        if (_ownError == null) _close();
        return KeyEventResult.handled;
      }
      return _ownError == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && alt) {
      _pointerFocus = false;
      _openList(focusList: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && !alt) {
      _step(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _step(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      if (_open) {
        _close();
        return KeyEventResult.handled;
      }
      return _revert() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (_pointerFocus) setState(() => _pointerFocus = false);
    return KeyEventResult.ignored;
  }

  Future<void> _openSheet() async {
    if (FormBusy.read(context)) return;
    final rows = TimePicker.rows(start: widget.start);
    await showSheet<void>(
      context: context,
      builder: (sheetContext) => _TimeSheet(
        title: widget.semanticLabel,
        initial: _format(widget.value),
        rows: rows,
        items: _items(rows),
        anchor: _anchor(rows),
        parse: _parse,
        onRow: _pickRow,
        onTyped: _emit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = pickerIsPhone(context);
    final c = context.colors;
    final style = pickerValueStyle(context.look, c, phone: phone);
    final samples = [for (var m = 0; m < _day; m += TimePicker.step) _format(_time(m))];
    final rows = TimePicker.rows(start: widget.start);
    final (anchor, exact) = _anchor(rows);
    final width = pickerFieldWidth(context, samples, style);
    final field = PickerField(
      boxKey: _boxKey,
      controller: _text,
      focusNode: _node,
      icon: Icons.schedule_rounded,
      fieldWidth: width,
      semanticLabel: widget.semanticLabel,
      label: widget.showLabel ? widget.label : null,
      help: widget.help,
      error: _ownError ?? widget.error,
      disabledReason: widget.disabledReason,
      compact: widget.compact,
      phone: phone,
      readOnly: FormBusy.of(context),
      showRing: (_node.hasFocus && !_pointerFocus) || (_open && _listNode.hasFocus),
      semanticsHint: TimePicker.hint,
      keyboardType: TextInputType.datetime,
      onKeyEvent: _onFieldKey,
      onPointerDown: () {
        if (!_node.hasFocus) _pointerFocus = true;
      },
      onTap: phone ? _openSheet : () => _openList(focusList: false),
      onChanged: (text) {
        _dirty = true;
        setState(() => _preview = _parse(text));
      },
      onEditingComplete: () {
        _commit();
        if (_open && _ownError == null) _close();
      },
    );
    if (phone) return field;
    return PickerPopover(
      open: _open,
      anchorKey: _boxKey,
      padding: EdgeInsets.all(context.space(1)),
      onDismiss: () {
        _commit();
        _close(refocus: false);
      },
      popover: (context) => PickerListBox(
        items: _items(rows),
        highlighted: anchor,
        checked: exact ? anchor : null,
        focusNode: _listNode,
        compact: widget.compact,
        width: width - 2 * context.space(1),
        semanticLabel: widget.semanticLabel,
        onPicked: (i) {
          _pickRow(rows[i]);
          _close();
        },
        onDismiss: _close,
      ),
      child: field,
    );
  }
}

/// The phone's picker sheet (a [Sheet]): Cancel, the field's name and Done in its header, the field for
/// typing at the top of its body, and the quarter hours under it as `row-height` rows. Typing not yet
/// committed with Done is pending: the scrim, a drag, back and Cancel ask before it is lost.
class _TimeSheet extends StatefulWidget {
  const _TimeSheet({
    required this.title,
    required this.initial,
    required this.rows,
    required this.items,
    required this.anchor,
    required this.parse,
    required this.onRow,
    required this.onTyped,
  });
  final String title;
  final String initial;
  final List<({int offset, TimeOfDay time})> rows;
  final List<PickerListItem> items;
  final (int, bool) anchor;
  final TimeOfDay? Function(String) parse;
  final ValueChanged<({int offset, TimeOfDay time})> onRow;
  final ValueChanged<TimeOfDay> onTyped;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late final _text = TextEditingController(text: widget.initial);
  final _node = FocusNode(debugLabel: 'TimePicker sheet');
  final _key = GlobalKey();
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _node.dispose();
    super.dispose();
  }

  void _done() {
    final t = widget.parse(_text.text);
    if (t == null) {
      setState(() => _error = TimePicker.notATimeError);
      _node.requestFocus();
      return;
    }
    widget.onTyped(t);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = pickerValueStyle(context.look, c, phone: true);
    return Sheet(
      kind: SheetKind.picker,
      title: widget.title,
      pending: _text.text.trim() != widget.initial.trim(),
      discardMessage: TimePicker.typedDiscardMessage,
      trailing: Button(label: TimePicker.doneLabel, variant: ButtonVariant.plain, onPressed: _done),
      // The field stays at the top, above the keyboard; the rows scroll under it.
      scrollable: false,
      body: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(Sheet.bodyPadding(context.look), 0, Sheet.bodyPadding(context.look), context.space(2)),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: PickerField(
              boxKey: _key,
              controller: _text,
              focusNode: _node,
              icon: Icons.schedule_rounded,
              fieldWidth: pickerFieldWidth(context, [for (final i in widget.items) i.title], style),
              semanticLabel: widget.title,
              error: _error,
              keyboardType: TextInputType.datetime,
              onEditingComplete: _done,
            ),
          ),
        ),
        Flexible(
          // As many rows as fit above the keyboard, up to the list's own eight; then they scroll.
          child: LayoutBuilder(
            builder: (context, constraints) => PickerListBox(
              items: widget.items,
              highlighted: widget.anchor.$1,
              checked: widget.anchor.$2 ? widget.anchor.$1 : null,
              rowHeight: context.density.rowHeight,
              width: constraints.maxWidth,
              visibleRows: constraints.maxHeight.isFinite
                  ? (constraints.maxHeight / context.density.rowHeight).floor().clamp(1, 8)
                  : 8,
              semanticLabel: widget.title,
              onPicked: (i) {
                widget.onRow(widget.rows[i]);
                Navigator.of(context).pop();
              },
              onDismiss: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// The "When" group of the event editor
// ---------------------------------------------------------------------------------------------------------------

/// The event editor's "When" group (design/components/TimePicker, "The \"When\" group"): straight on the
/// Inspector's panel, headed "When" in `label` and `ink-muted`, its rows `space-4` apart:
///
/// 1. [allDaySwitch]: a Switch in a form ("All-day").
/// 2. "Starts": [startDate] and [startTime] on one line, `space-2` apart, under the one label; the time goes
///    under the date, `space-2` below, when the two do not fit side by side (always under 600px).
/// 3. "Ends": [endDate] and [endTime], the same.
/// 4. The time zone, only while the event's zone is not this device's ([zoneDiffers]): [timeZoneField]
///    (Select's long-list variant) and, under the Ends line, [zoneCaption] in `caption` and `ink-muted`
///    ("15:00 to 16:00 London time"). Otherwise a plain "Set time zone" button after Ends ([onSetTimeZone]).
/// 5. [repeat]: a Select.
///
/// With [allDay] on, the two times and the time zone go away (the rows close up over `base` with a fade; a
/// `fast` fade with reduced motion), and the dates stay. Pass the date and time pickers with `showLabel:
/// false` and their own accessible names ("Start date", "Start time").
class EventWhenGroup extends StatelessWidget {
  const EventWhenGroup({
    super.key,
    required this.allDay,
    required this.allDaySwitch,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.zoneDiffers,
    this.timeZoneField,
    this.zoneCaption,
    this.onSetTimeZone,
    this.repeat,
  });

  final bool allDay;
  final Widget allDaySwitch;
  final Widget startDate;
  final Widget startTime;
  final Widget endDate;
  final Widget endTime;

  /// The event's zone is not this device's zone: the time zone field and the caption show.
  final bool zoneDiffers;
  final Widget? timeZoneField;

  /// The same times in this device's zone, worked out by the host ("15:00 to 16:00 London time").
  final String? zoneCaption;

  /// "Set time zone", shown while the zones are the same.
  final VoidCallback? onSetTimeZone;
  final Widget? repeat;

  static const heading = 'When';
  static const startsLabel = 'Starts';
  static const endsLabel = 'Ends';
  static const setTimeZoneLabel = 'Set time zone';

  /// Fields in an Inspector are `space-4` apart (design/components/FormRow).
  static double rowGap(MyDataLook look) => look.space(4);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = MyDataMotion.reduced(context);
    final duration = reduced ? context.motion.fast : context.motion.base;
    final phone = pickerIsPhone(context);

    Widget timed(Widget child) => AnimatedSize(
          duration: reduced ? Duration.zero : duration,
          curve: context.motion.standard,
          alignment: AlignmentDirectional.topStart,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: context.motion.standard,
            switchOutCurve: context.motion.standard,
            child: allDay ? const SizedBox.shrink(key: ValueKey('none')) : child,
          ),
        );

    Widget line(String label, Widget date, Widget time) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Text(label, style: context.typeScale.label.copyWith(color: c.ink))),
            SizedBox(height: context.space(2)),
            // Side by side when both fit, else the time under the date; nothing is cut short.
            Wrap(
              spacing: context.space(2),
              runSpacing: context.space(2),
              direction: phone ? Axis.vertical : Axis.horizontal,
              children: [
                date,
                timed(KeyedSubtree(key: const ValueKey('time'), child: time)),
              ],
            ),
          ],
        );

    final zone = zoneDiffers
        ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (zoneCaption != null)
              Text(zoneCaption!, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
            if (timeZoneField != null) ...[
              if (zoneCaption != null) SizedBox(height: rowGap(context.look)),
              timeZoneField!,
            ],
          ])
        : Button(
            label: setTimeZoneLabel,
            variant: ButtonVariant.plain,
            onPressed: onSetTimeZone,
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: heading,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(child: FormGroupHeading(heading)),
          allDaySwitch,
          SizedBox(height: rowGap(context.look)),
          line(startsLabel, startDate, startTime),
          SizedBox(height: rowGap(context.look)),
          line(endsLabel, endDate, endTime),
          timed(KeyedSubtree(
            key: const ValueKey('zone'),
            child: Padding(
              padding: EdgeInsets.only(top: context.space(2)),
              child: Align(alignment: AlignmentDirectional.centerStart, child: zone),
            ),
          )),
          if (repeat != null) ...[SizedBox(height: rowGap(context.look)), repeat!],
        ],
      ),
    );
  }
}
