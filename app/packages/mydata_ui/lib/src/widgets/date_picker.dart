import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'field_row.dart' show formatBirthday;
import 'form_scope.dart';
import 'icon_button.dart';
import 'month_grid.dart';
import 'picker_field.dart';
import 'pressable.dart';
import 'sheet.dart';
import 'input_box.dart';

// ---------------------------------------------------------------------------------------------------------------
// Dates as the field writes and reads them
// ---------------------------------------------------------------------------------------------------------------

/// The order of a date's numeric parts in a locale ("14/10/2026" in the UK, "10/14/2026" in the US).
enum DateFieldOrder {
  dayMonthYear,
  monthDayYear,
  yearMonthDay;

  /// Regions that write the month first (CLDR's short date pattern `M/d/y`): the United States and its
  /// territories.
  static const _monthFirst = {'US', 'PR', 'UM', 'VI', 'AS', 'GU', 'MP', 'FM', 'MH', 'PW'};

  /// Regions that write the year first (CLDR's `y/M/d`).
  static const _yearFirst = {'CN', 'JP', 'KR', 'KP', 'TW', 'HU', 'LT', 'MN', 'IR', 'BT'};

  /// The order in [locale]'s region; day, month, year when there is no region.
  static DateFieldOrder of(Locale locale) {
    final region = locale.countryCode?.toUpperCase();
    if (_monthFirst.contains(region)) return monthDayYear;
    if (_yearFirst.contains(region)) return yearMonthDay;
    return dayMonthYear;
  }
}

/// A birthday, which may have no year (design/components/FieldRow, DatePicker "Birthday (year optional)").
@immutable
class Birthday {
  const Birthday({this.year, required this.month, required this.day});

  /// Reads the host's form: `YYYY-MM-DD`, or `--MM-DD` (also `--MMDD`) when the year is not known. Null for
  /// anything else, or a day the month does not have.
  static Birthday? parse(String value) {
    final v = value.trim();
    final full = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
    final noYear = RegExp(r'^--(\d{2})-?(\d{2})$').firstMatch(v);
    final Birthday b;
    if (full != null) {
      b = Birthday(year: int.parse(full.group(1)!), month: int.parse(full.group(2)!), day: int.parse(full.group(3)!));
    } else if (noYear != null) {
      b = Birthday(month: int.parse(noYear.group(1)!), day: int.parse(noYear.group(2)!));
    } else {
      return null;
    }
    return _validDay(b.year, b.month, b.day) ? b : null;
  }

  final int? year;
  final int month;
  final int day;

  /// The host's form: "1990-05-12", or "--05-12" with no year.
  String toHostString() {
    String two(int n) => n.toString().padLeft(2, '0');
    return year == null ? '--${two(month)}-${two(day)}' : '${year.toString().padLeft(4, '0')}-${two(month)}-${two(day)}';
  }

  /// As FieldRow writes a birthday: "12 May 1990", or "12 May".
  String format() => formatBirthday(toHostString()) ?? '';

  @override
  bool operator ==(Object other) => other is Birthday && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'Birthday(${toHostString()})';
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

bool _isLeap(int y) => y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);

int _daysIn(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// A real day; with no year, 29 February counts (a leap year decides).
bool _validDay(int? year, int month, int day) =>
    month >= 1 && month <= 12 && day >= 1 && day <= _daysIn(year ?? 2000, month);

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// The field's medium form, with a short weekday and always the year: "Wed 14 Oct 2026". The apps are in
/// English, written British (as [formatBirthday]); a locale-aware form comes with localisation.
String formatPickerDate(DateTime d) =>
    '${_weekdayNames[d.weekday - 1].substring(0, 3)} ${d.day} ${_monthNames[d.month - 1].substring(0, 3)} ${d.year}';

/// The medium form without the weekday, as errors name a date: "14 Oct 2026".
String formatPickerDateNoWeekday(DateTime d) => '${d.day} ${_monthNames[d.month - 1].substring(0, 3)} ${d.year}';

/// The full date a screen reader reads: "Wednesday 14 October 2026"; with [noYear], "12 May".
String spokenPickerDate(DateTime d, {bool noYear = false}) => noYear
    ? '${d.day} ${_monthNames[d.month - 1]}'
    : '${_weekdayNames[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1]} ${d.year}';

/// [d] in the locale's numeric order, for the error's example: "14/10/2026", "10/14/2026", "2026/10/14".
String numericPickerDate(DateTime d, DateFieldOrder order) => switch (order) {
      DateFieldOrder.dayMonthYear => '${d.day}/${d.month}/${d.year}',
      DateFieldOrder.monthDayYear => '${d.month}/${d.day}/${d.year}',
      DateFieldOrder.yearMonthDay => '${d.year}/${d.month}/${d.day}',
    };

/// A month or weekday word: its full name or a short form of at least three letters ("oct", "sept").
int? _monthFromWord(String w) {
  if (w.length < 3) return null;
  for (var i = 0; i < 12; i++) {
    final name = _monthNames[i].toLowerCase();
    if (name.startsWith(w)) return i + 1;
  }
  return null;
}

bool _isWeekdayWord(String w) {
  if (w.length < 2) return false;
  const extra = {'tues', 'weds', 'thur', 'thurs'};
  if (extra.contains(w)) return true;
  return _weekdayNames.any((n) => w.length >= 3 && n.toLowerCase().startsWith(w));
}

/// A two-digit year in the century nearest to [today] ("26" is 2026).
int _fullYear(int twoDigits, DateTime today) {
  final base = today.year - today.year % 100;
  final candidates = [base - 100 + twoDigits, base + twoDigits, base + 100 + twoDigits];
  candidates.sort((a, b) => (a - today.year).abs().compareTo((b - today.year).abs()));
  return candidates.first;
}

/// Reads a typed date (design/components/DatePicker, "Typing"):
///
/// - the locale's numeric [order], with "/", ".", "-" or spaces between the parts ("14/10/2026",
///   "14.10.26");
/// - a month as a word or its short form ("14 Oct 2026", "14 october", "Oct 14"); a weekday is ignored;
///   an ordinal ending is allowed ("14th");
/// - a two-digit year in the century nearest to [today]; four digits as written;
/// - no year: [yearOptional] keeps none (a birthday), otherwise the year is [defaultYear] (the year of the
///   date in the field before), or [today]'s.
///
/// Null when the text is not a real date.
({int? year, int month, int day})? parseTypedDate(
  String text, {
  required DateFieldOrder order,
  required DateTime today,
  int? defaultYear,
  bool yearOptional = false,
}) {
  final parts = text
      .toLowerCase()
      .split(RegExp(r'[\s/.,\-]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => p.replaceFirstMapped(RegExp(r'^(\d+)(st|nd|rd|th)$'), (m) => m.group(1)!))
      .where((p) => !_isWeekdayWord(p))
      .toList();
  if (parts.isEmpty) return null;
  int? month;
  final numbers = <String>[];
  for (final p in parts) {
    if (RegExp(r'^\d+$').hasMatch(p)) {
      numbers.add(p);
    } else {
      final m = _monthFromWord(p);
      if (m == null || month != null) return null;
      month = m;
    }
  }
  int? yearOf(String s) => switch (s.length) {
        2 => _fullYear(int.parse(s), today),
        4 => int.parse(s),
        _ => null,
      };
  int? day;
  int? year;
  bool yearGiven = false;
  if (month != null) {
    // "14 Oct 2026", "Oct 14 2026", "2026 Oct 14": the year is the four-digit part, or the second one.
    if (numbers.isEmpty || numbers.length > 2) return null;
    if (numbers.length == 1) {
      if (numbers.single.length > 2) return null;
      day = int.parse(numbers.single);
    } else {
      final yearIndex = numbers[0].length == 4 ? 0 : 1;
      if (numbers[1 - yearIndex].length > 2) return null;
      day = int.parse(numbers[1 - yearIndex]);
      year = yearOf(numbers[yearIndex]);
      if (year == null) return null;
      yearGiven = true;
    }
  } else {
    if (numbers.length < 2 || numbers.length > 3) return null;
    final String d, m;
    String? y;
    switch (order) {
      case DateFieldOrder.dayMonthYear:
        d = numbers[0];
        m = numbers[1];
        y = numbers.length == 3 ? numbers[2] : null;
      case DateFieldOrder.monthDayYear:
        m = numbers[0];
        d = numbers[1];
        y = numbers.length == 3 ? numbers[2] : null;
      case DateFieldOrder.yearMonthDay:
        if (numbers.length == 3) {
          y = numbers[0];
          m = numbers[1];
          d = numbers[2];
        } else {
          m = numbers[0];
          d = numbers[1];
        }
    }
    if (d.length > 2 || m.length > 2) return null;
    day = int.parse(d);
    month = int.parse(m);
    if (y != null) {
      year = yearOf(y);
      if (year == null) return null;
      yearGiven = true;
    }
  }
  if (!yearGiven) year = yearOptional ? null : (defaultYear ?? today.year);
  if (!_validDay(year, month, day)) return null;
  return (year: year, month: month, day: day);
}

// ---------------------------------------------------------------------------------------------------------------
// DatePicker
// ---------------------------------------------------------------------------------------------------------------

/// A field for one date in a form: typed, stepped with the arrow keys, or picked from a small month calendar
/// that opens under it (design/components/DatePicker).
///
/// - **The field** looks like a TextField ([label] above, [help] below), with the date in the medium form
///   ("Wed 14 Oct 2026") and a calendar icon at its end. It is as wide as the longest date, not the form.
/// - **Typing** reads the locale's numeric order and month words ([parseTypedDate]). Return, Tab or leaving
///   the field commits the date and rewrites it in the medium form; Escape puts back the date from before.
///   Text that is not a date, or a date before [earliest], puts the field in error (a 2px `danger` border,
///   the error in place of the help); the form keeps its last good date and [onErrorChanged] says so.
///   Return commits first: with the calendar open it closes it, with an error it stops there, and otherwise
///   it goes on to the form (a Dialog then confirms with the committed date). A holder commits typing before
///   it saves ([PendingInput]). While the form waits for the host ([FormBusy]) the field is read-only and
///   does not step or open.
/// - **Keys:** Up and Down step the date by a day and announce it; Option-Down (Alt-Down elsewhere) opens
///   the calendar and moves focus into it. In the calendar the arrow keys move by a day or a week, Page Up and
///   Page Down by a month (with Shift, a year), Home and End to the week's ends. Focus does not pick: Return
///   or Space picks the focused day, closes the popover and returns focus to the field. Escape closes it with
///   no change. Tab stays inside the popover until it closes.
/// - **The popover** (`surface-raised`, `shadow-2`, `radius-md`, `space-3` padding) holds the month in
///   `heading`, "Previous month" and "Next month", the short weekday names and six weeks of round days drawn
///   by MonthGrid's own day cell ([MonthGridDay]): today's `accent` disc, the selection's `accent-soft`
///   fill and `ink` ring, the hover edge, the focus ring and, before [earliest], unavailable days.
/// - **Birthday** ([DatePicker.birthday]): the year may be left out. The field then shows "12 May", and the
///   popover's title becomes two lists, "Month" and "Year" (starting with "No year").
/// - **Phone** (under 600px): not typed; tapping the field opens the same calendar in a picker [Sheet], and
///   tapping a day picks it and closes the sheet.
/// - **Disabled** ([disabledReason]): 45% opacity, not focusable, the reason as the help line, not faded.
class DatePicker extends StatefulWidget {
  const DatePicker({
    super.key,
    required this.label,
    required this.value,
    required ValueChanged<DateTime> this.onChanged,
    required this.today,
    this.semanticLabel,
    this.showLabel = true,
    this.earliest,
    this.earliestReason = defaultEarliestReason,
    this.firstDayOfWeek,
    this.order,
    this.help,
    this.error,
    this.disabledReason,
    this.compact = false,
    this.focusNode,
    this.onErrorChanged,
  })  : birthday = null,
        onBirthdayChanged = null,
        yearOptional = false;

  /// The birthday variant (year optional), for myContacts' "Birthday": no weekday in the field, no earliest
  /// date, and "Month" and "Year" lists in the popover.
  const DatePicker.birthday({
    super.key,
    this.label = birthdayLabel,
    required Birthday? value,
    required ValueChanged<Birthday> onChanged,
    required this.today,
    this.semanticLabel,
    this.showLabel = true,
    this.firstDayOfWeek,
    this.order,
    this.help,
    this.error,
    this.disabledReason,
    this.compact = false,
    this.focusNode,
    this.onErrorChanged,
  })  : birthday = value,
        onBirthdayChanged = onChanged,
        value = null,
        onChanged = null,
        earliest = null,
        earliestReason = defaultEarliestReason,
        yearOptional = true;

  /// The visible label above the field, a noun in sentence case ("Starts", "Ends on", "Birthday").
  final String label;

  /// The accessible name when it differs from [label]: a date and a time sharing "Starts" are "Start date"
  /// and "Start time".
  final String? semanticLabel;

  /// False when a label above a row of fields already shows [label] (the event editor's "Starts").
  final bool showLabel;

  /// The date; only the date is used. Null shows an empty field. Null in the birthday variant.
  final DateTime? value;

  /// Called with the new date when one is committed (typed, stepped or picked). Null in the birthday
  /// variant.
  final ValueChanged<DateTime>? onChanged;

  /// The birthday variant's value (its `value`), which may have no year; null shows an empty field.
  final Birthday? birthday;

  /// The birthday variant's `onChanged`.
  final ValueChanged<Birthday>? onBirthdayChanged;

  /// Whether the year may be left out ([DatePicker.birthday]).
  final bool yearOptional;

  /// Today, in this device's time zone. Only the date is used.
  final DateTime today;

  /// Days before it cannot be picked, and typing one is an error (Ends has Starts as its earliest date).
  final DateTime? earliest;

  /// The first sentence of the error for a date before [earliest]; "Choose 14 Oct 2026 or later." follows.
  final String earliestReason;

  /// A [DateTime] weekday; null takes the locale's ([MonthGrid.firstDayOfWeekFor]).
  final int? firstDayOfWeek;

  /// The numeric order typing reads; null takes the locale's ([DateFieldOrder.of]).
  final DateFieldOrder? order;
  final String? help;

  /// An error from the form (shown when the field's own typing is fine).
  final String? error;

  /// Disables the field. A field is never disabled without a reason, a full sentence with a full stop.
  final String? disabledReason;

  /// The Compact density on desktop: the field and the cells are `control-height-compact`.
  final bool compact;
  final FocusNode? focusNode;

  /// Called with the field's own error when it appears (non-null) and when it goes (null).
  final ValueChanged<String?>? onErrorChanged;

  static const birthdayLabel = 'Birthday';
  static const defaultEarliestReason = 'Ends before it starts.';
  static const previousMonthLabel = 'Previous month';
  static const nextMonthLabel = 'Next month';
  static const monthLabel = 'Month';
  static const yearLabel = 'Year';
  static const noYearLabel = 'No year';
  static const cancelLabel = 'Cancel';

  /// How far back the birthday's Year list goes.
  static const birthdayYears = 120;

  /// The error for text that is not a date, with an example in the locale's order.
  static String notADateError(DateTime example, DateFieldOrder order) =>
      'That is not a date. Type it like ${numericPickerDate(example, order)}.';

  /// The error for a date before [earliest].
  static String earliestError(String reason, DateTime earliest) =>
      '$reason Choose ${formatPickerDateNoWeekday(earliest)} or later.';

  /// The field's hint, naming Option on Apple platforms and Alt elsewhere.
  static String hint({required bool apple}) =>
      'Type a date, press Up or Down arrow to change it by a day, or ${apple ? 'Option' : 'Alt'} Down arrow '
      'to choose from a calendar';

  /// The popover's name: "Start date, choose a date".
  static String popoverLabel(String name) => '$name, choose a date';

  /// The height of the weekday names' row: the preview's 28px, the today disc's size.
  static const weekdayRowHeight = MonthGrid.todayDiameter;

  @override
  State<DatePicker> createState() => _DatePickerState();
}

typedef _Ymd = ({int? year, int month, int day});

bool _apple() => defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;

class _DatePickerState extends State<DatePicker> with PendingInputRegistration<DatePicker> {
  final _boxKey = GlobalKey();
  late final TextEditingController _text = TextEditingController(text: _format(_committed));
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'DatePicker'));
  final _calendarNode = FocusNode(debugLabel: 'DatePicker calendar');
  final _popoverScope = FocusScopeNode(debugLabel: 'DatePicker popover');

  bool _open = false;
  bool _pointerFocus = false;
  bool _dirty = false;
  String? _ownError;

  /// The month shown in the calendar: its year (null: "No year") and month.
  int? _shownYear;
  int _shownMonth = 1;

  /// The day the calendar's keyboard focus is on.
  DateTime _focusDay = DateTime(2000);

  /// While typing, the date the text reads as.
  _Ymd? _preview;

  _Ymd? get _committed {
    if (widget.yearOptional) {
      final b = widget.birthday;
      return b == null ? null : (year: b.year, month: b.month, day: b.day);
    }
    final v = widget.value;
    return v == null ? null : (year: v.year, month: v.month, day: v.day);
  }

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

  String _format(_Ymd? d) {
    if (d == null) return '';
    if (widget.yearOptional) return Birthday(year: d.year, month: d.month, day: d.day).format();
    return formatPickerDate(DateTime(d.year!, d.month, d.day));
  }

  String _spoken(_Ymd d) {
    if (widget.yearOptional) return Birthday(year: d.year, month: d.month, day: d.day).format();
    return spokenPickerDate(DateTime(d.year!, d.month, d.day));
  }

  DateFieldOrder get _order => widget.order ?? DateFieldOrder.of(View.of(context).platformDispatcher.locale);

  int get _firstDay =>
      widget.firstDayOfWeek ?? MonthGrid.firstDayOfWeekFor(View.of(context).platformDispatcher.locale);

  /// The year a "No year" birthday is laid out in: the next leap year, so that 29 February can be chosen.
  int get _leapYear {
    var y = widget.today.year;
    while (!_isLeap(y)) {
      y++;
    }
    return y;
  }

  DateTime _asDate(_Ymd d) => DateTime(d.year ?? _leapYear, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
    _calendarNode.addListener(_onFocus);
    _popoverScope.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(DatePicker old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_onFocus);
      _node.addListener(_onFocus);
    }
    final before = old.yearOptional ? old.birthday?.toHostString() : old.value?.toString();
    final now = widget.yearOptional ? widget.birthday?.toHostString() : widget.value?.toString();
    if (before != now && !_dirty) {
      _text.text = _format(_committed);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _ownNode?.dispose();
    _calendarNode.dispose();
    _popoverScope.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    if (!_node.hasFocus && !_popoverScope.hasFocus) {
      // Focus left the field and the popover: commit what was typed and close.
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
    if (error != null) {
      SemanticsService.sendAnnouncement(View.of(context), error, Directionality.of(context));
    }
  }

  /// Checks [d] against [DatePicker.earliest]; returns the error or null.
  String? _check(_Ymd d) {
    final earliest = widget.earliest;
    if (earliest == null || d.year == null) return null;
    if (_key(_asDate(d)) < _key(earliest)) return DatePicker.earliestError(widget.earliestReason, _date(earliest));
    return null;
  }

  _Ymd? _parse(String text) => parseTypedDate(text,
      order: _order, today: widget.today, defaultYear: _committed?.year, yearOptional: widget.yearOptional);

  void _emit(_Ymd d) {
    final same = _committed == d;
    _text.text = _format(d);
    _dirty = false;
    _preview = null;
    _setError(null);
    if (same) return;
    if (widget.yearOptional) {
      widget.onBirthdayChanged!(Birthday(year: d.year, month: d.month, day: d.day));
    } else {
      widget.onChanged!(DateTime(d.year!, d.month, d.day));
    }
  }

  /// Return, Tab, leaving the field or a click outside: the typed text becomes the date, or an error.
  void _commit() {
    if (!_dirty) return;
    final parsed = _parse(_text.text);
    if (parsed == null) {
      final example = _committed == null ? _date(widget.today) : _asDate(_committed!);
      _setError(DatePicker.notADateError(example, _order));
      return;
    }
    final tooEarly = _check(parsed);
    if (tooEarly != null) {
      _setError(tooEarly);
      return;
    }
    _emit(parsed);
  }

  /// Escape in the field: the date from before the typing.
  bool _revert() {
    if (!_dirty && _ownError == null) return false;
    setState(() {
      _text.text = _format(_committed);
      _dirty = false;
      _preview = null;
    });
    _setError(null);
    return true;
  }

  void _step(int days) {
    final base = (_dirty ? _parse(_text.text) : null) ?? _committed;
    final DateTime from = base == null ? _date(widget.today) : _asDate(base);
    var next = DateTime(from.year, from.month, from.day + days);
    _Ymd d;
    if (base != null && base.year == null) {
      // A birthday with no year stays in its leap year, going round the year's ends.
      next = DateTime(_leapYear, next.month, next.day);
      d = (year: null, month: next.month, day: next.day);
    } else {
      d = (year: next.year, month: next.month, day: next.day);
    }
    if (widget.earliest != null && _check(d) != null) return;
    _emit(d);
    if (_open) _show(_asDate(d), noYear: d.year == null && widget.yearOptional);
    SemanticsService.sendAnnouncement(View.of(context), _spoken(d), Directionality.of(context));
  }

  void _show(DateTime day, {bool noYear = false, bool announce = false}) {
    final changed = _shownMonth != day.month || _shownYear != (noYear ? null : day.year);
    setState(() {
      _shownYear = noYear ? null : day.year;
      _shownMonth = day.month;
      _focusDay = _date(day);
    });
    if (announce && changed) {
      SemanticsService.sendAnnouncement(View.of(context), _monthTitle(), Directionality.of(context));
    }
  }

  String _monthTitle() =>
      _shownYear == null ? _monthNames[_shownMonth - 1] : '${_monthNames[_shownMonth - 1]} $_shownYear';

  void _openPopover({required bool focusCalendar}) {
    if (FormBusy.read(context)) return;
    if (_disabled || _open) {
      if (focusCalendar) _calendarNode.requestFocus();
      return;
    }
    final d = (_dirty ? _parse(_text.text) : null) ?? _committed;
    final day = d == null ? _date(widget.today) : _asDate(d);
    _show(day, noYear: d != null && d.year == null && widget.yearOptional);
    setState(() => _open = true);
    if (focusCalendar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) _calendarNode.requestFocus();
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

  /// A day picked in the calendar (Return, Space or a press).
  void _pick(DateTime day) {
    if (widget.earliest != null && _key(day) < _key(widget.earliest!)) return;
    final noYear = widget.yearOptional && _shownYear == null;
    _emit((year: noYear ? null : day.year, month: day.month, day: day.day));
    _close();
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
      // Return commits first, so a Dialog's Return confirms with the typed date. With the calendar open it
      // only closes it; with an error it stops here (design/components/Dialog: "unless the field has its own
      // list or popover open … Return then acts on that first").
      _commit();
      if (_open) {
        if (_ownError == null) _close();
        return KeyEventResult.handled;
      }
      return _ownError == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && alt) {
      _pointerFocus = false;
      _openPopover(focusCalendar: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && !alt) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      // design/platforms.md "Which handler gets a key first": close what is open, then revert.
      if (_open) {
        _close();
        return KeyEventResult.handled;
      }
      return _revert() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (_pointerFocus) setState(() => _pointerFocus = false);
    return KeyEventResult.ignored;
  }

  void _moveFocusDay(DateTime to) {
    var day = _date(to);
    final noYear = widget.yearOptional && _shownYear == null;
    if (noYear) day = DateTime(_leapYear, day.month, day.day);
    _show(day, noYear: noYear, announce: true);
  }

  DateTime _addMonths(DateTime d, int months) {
    final first = DateTime(d.year, d.month + months);
    return DateTime(first.year, first.month, math.min(d.day, _daysIn(first.year, first.month)));
  }

  KeyEventResult _onCalendarKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final refresh = _sheetRefresh;
    if (refresh != null) {
      // In the phone's sheet the calendar is drawn by the sheet's route: redraw it there too.
      var result = KeyEventResult.ignored;
      refresh(() => result = _onCalendarKeyIn(event));
      return result;
    }
    return _onCalendarKeyIn(event);
  }

  KeyEventResult _onCalendarKeyIn(KeyEvent event) {
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final f = _focusDay;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveFocusDay(DateTime(f.year, f.month, f.day + (rtl ? 1 : -1)));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveFocusDay(DateTime(f.year, f.month, f.day + (rtl ? -1 : 1)));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocusDay(DateTime(f.year, f.month, f.day - 7));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocusDay(DateTime(f.year, f.month, f.day + 7));
    } else if (key == LogicalKeyboardKey.pageUp) {
      _moveFocusDay(_addMonths(f, shift ? -12 : -1));
    } else if (key == LogicalKeyboardKey.pageDown) {
      _moveFocusDay(_addMonths(f, shift ? 12 : 1));
    } else if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) {
      final fromStart = (f.weekday - _firstDay + 7) % 7;
      _moveFocusDay(DateTime(f.year, f.month, f.day + (key == LogicalKeyboardKey.end ? 6 - fromStart : -fromStart)));
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space)) {
      (_sheetPick ?? _pick)(f);
    } else if (event is KeyDownEvent && key == LogicalKeyboardKey.escape && _open) {
      _close();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// The previous and next buttons: the month before or after, the focused day kept in it.
  void _stepMonth(int months) {
    final noYear = widget.yearOptional && _shownYear == null;
    final layoutYear = _shownYear ?? _leapYear;
    var target = _addMonths(DateTime(layoutYear, _shownMonth, math.min(_focusDay.day, 28)), months);
    target = DateTime(target.year, target.month, math.min(_focusDay.day, _daysIn(target.year, target.month)));
    if (noYear) target = DateTime(_leapYear, target.month, target.day);
    _show(target, noYear: noYear, announce: true);
  }

  void _onTyped(String text) {
    _dirty = true;
    final parsed = _parse(text);
    if (parsed != null && _open) {
      _preview = parsed;
      _show(_asDate(parsed), noYear: parsed.year == null && widget.yearOptional);
    } else {
      setState(() => _preview = parsed);
    }
  }

  Future<void> _openSheet() async {
    if (FormBusy.read(context)) return;
    final d = _committed;
    _show(d == null ? _date(widget.today) : _asDate(d), noYear: d != null && d.year == null && widget.yearOptional);
    await showSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheet) {
        void refresh(VoidCallback f) {
          f();
          setSheet(() {});
        }

        void pick(DateTime day) {
          if (widget.earliest != null && _key(day) < _key(widget.earliest!)) return;
          final noYear = widget.yearOptional && _shownYear == null;
          _emit((year: noYear ? null : day.year, month: day.month, day: day.day));
          Navigator.of(sheetContext).pop();
        }

        _sheetPick = pick;
        _sheetRefresh = refresh;
        return Sheet(
          kind: SheetKind.picker,
          title: widget.semanticLabel ?? widget.label,
          // Focus starts on the chosen day, as a picker sheet's does.
          initialFocus: _calendarNode,
          body: Center(child: _calendar(phone: true, onPick: pick, refresh: refresh)),
        );
      }),
    );
    _sheetPick = null;
    _sheetRefresh = null;
  }

  /// While the phone's sheet is open: picking from the keys closes it, and key moves redraw it.
  ValueChanged<DateTime>? _sheetPick;
  void Function(VoidCallback)? _sheetRefresh;

  /// The calendar part of the popover and of the phone sheet.
  Widget _calendar({required bool phone, required ValueChanged<DateTime> onPick, void Function(VoidCallback)? refresh}) {
    void update(VoidCallback f) => refresh == null ? f() : refresh(f);
    final selected = _preview ?? _committed;
    final noYear = widget.yearOptional && _shownYear == null;
    return _Calendar(
      year: _shownYear ?? _leapYear,
      month: _shownMonth,
      noYear: noYear,
      firstDay: _firstDay,
      today: noYear ? null : _date(widget.today),
      selected: selected == null || (selected.year == null) != noYear ? null : _asDate(selected),
      focusDay: _focusDay,
      earliest: widget.earliest == null ? null : _date(widget.earliest!),
      cellSize: widget.compact && !phone ? context.density.controlHeightCompact : context.density.controlHeight,
      calendarNode: _calendarNode,
      showFocus: !phone && _calendarNode.hasFocus,
      onKey: _onCalendarKey,
      onPick: onPick,
      onPrevious: () => update(() => _stepMonth(-1)),
      onNext: () => update(() => _stepMonth(1)),
      birthday: widget.yearOptional,
      thisYear: widget.today.year,
      onMonth: (m) => update(() {
        final y = _shownYear ?? _leapYear;
        _show(DateTime(y, m, math.min(_focusDay.day, _daysIn(y, m))), noYear: noYear, announce: true);
      }),
      onYear: (y) => update(() {
        final layout = y ?? _leapYear;
        _show(DateTime(layout, _shownMonth, math.min(_focusDay.day, _daysIn(layout, _shownMonth))),
            noYear: y == null, announce: true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = pickerIsPhone(context);
    final c = context.colors;
    final style = pickerValueStyle(context.look, c, phone: phone);
    final year = widget.today.year;
    final samples = widget.yearOptional
        ? [for (final m in _monthNames) '28 $m $year']
        : [
            for (final w in _weekdayNames)
              for (final m in _monthNames) '${w.substring(0, 3)} 28 ${m.substring(0, 3)} $year',
          ];
    final committed = _committed;
    final name = widget.semanticLabel ?? widget.label;
    final field = PickerField(
      boxKey: _boxKey,
      controller: _text,
      focusNode: _node,
      icon: MyDataIcon.calendar,
      fieldWidth: pickerFieldWidth(context, samples, style),
      semanticLabel: name,
      label: widget.showLabel ? widget.label : null,
      help: widget.help,
      error: _ownError ?? widget.error,
      disabledReason: widget.disabledReason,
      compact: widget.compact,
      phone: phone,
      readOnly: FormBusy.of(context),
      showRing: (_node.hasFocus && !_pointerFocus) || (_open && _popoverScope.hasFocus),
      semanticsValue: _dirty || committed == null ? null : _spoken(committed),
      semanticsHint: DatePicker.hint(apple: _apple()),
      onKeyEvent: _onFieldKey,
      onPointerDown: () {
        if (!_node.hasFocus) _pointerFocus = true;
      },
      onTap: phone ? _openSheet : () => _openPopover(focusCalendar: false),
      onChanged: _onTyped,
      onEditingComplete: () {
        _commit();
        if (_open && _ownError == null) _close();
      },
    );
    if (phone) return field;
    return PickerPopover(
      open: _open,
      anchorKey: _boxKey,
      padding: EdgeInsets.all(context.space(3)),
      semanticLabel: DatePicker.popoverLabel(name),
      onDismiss: () {
        _commit();
        _close(refocus: false);
      },
      popover: (context) => FocusScope(
        node: _popoverScope,
        child: _calendar(phone: false, onPick: _pick),
      ),
      child: field,
    );
  }
}

/// The popover's (and the sheet's) header, weekday names and six weeks of days.
class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.year,
    required this.month,
    required this.noYear,
    required this.firstDay,
    required this.today,
    required this.selected,
    required this.focusDay,
    required this.earliest,
    required this.cellSize,
    required this.calendarNode,
    required this.showFocus,
    required this.onKey,
    required this.onPick,
    required this.onPrevious,
    required this.onNext,
    required this.birthday,
    required this.thisYear,
    required this.onMonth,
    required this.onYear,
  });

  /// The year the month is laid out in (for "No year", the next leap year).
  final int year;
  final int month;
  final bool noYear;
  final int firstDay;
  final DateTime? today;
  final DateTime? selected;
  final DateTime focusDay;
  final DateTime? earliest;
  final double cellSize;
  final FocusNode calendarNode;
  final bool showFocus;
  final FocusOnKeyEventCallback onKey;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool birthday;
  final int thisYear;
  final ValueChanged<int> onMonth;
  final ValueChanged<int?> onYear;

  String _dayLabel(DateTime d) {
    final parts = [spokenPickerDate(d, noYear: noYear)];
    if (today != null && _key(d) == _key(today!)) parts.add('today');
    if (selected != null && _key(d) == _key(selected!)) parts.add('selected');
    if (earliest != null && _key(d) < _key(earliest!)) parts.add('unavailable');
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final days = MonthGrid.visibleDays(DateTime(year, month), firstDay);
    final title = noYear ? _monthNames[month - 1] : '${_monthNames[month - 1]} $year';

    final Widget start = birthday
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            _MiniSelect(
              label: DatePicker.monthLabel,
              items: _monthNames,
              selected: month - 1,
              onSelected: (i) => onMonth(i + 1),
            ),
            SizedBox(width: context.space(2)),
            _MiniSelect(
              label: DatePicker.yearLabel,
              items: [DatePicker.noYearLabel, for (var y = thisYear; y > thisYear - DatePicker.birthdayYears; y--) '$y'],
              selected: noYear ? 0 : (thisYear - year + 1).clamp(0, DatePicker.birthdayYears),
              onSelected: (i) => onYear(i == 0 ? null : thisYear - i + 1),
            ),
          ])
        : Padding(
            padding: EdgeInsetsDirectional.only(start: context.space(1)),
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Text(title, maxLines: 1, style: context.typeScale.heading.copyWith(color: c.ink)),
            ),
          );

    final header = Padding(
      padding: EdgeInsets.only(bottom: context.space(1)),
      child: Row(children: [
        if (birthday) start else Expanded(child: start),
        if (birthday) const Spacer(),
        SizedBox(width: context.space(1)),
        _MonthButton(
            icon: rtl ? MyDataIcon.chevronRight : MyDataIcon.chevronLeft,
            label: DatePicker.previousMonthLabel,
            onPressed: onPrevious),
        SizedBox(width: context.space(1)),
        _MonthButton(
            icon: rtl ? MyDataIcon.chevronLeft : MyDataIcon.chevronRight,
            label: DatePicker.nextMonthLabel,
            onPressed: onNext),
      ]),
    );

    final weekdays = ExcludeSemantics(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 7; i++)
          SizedBox(
            width: cellSize,
            height: DatePicker.weekdayRowHeight,
            child: Center(
              child: Text(MonthGrid.weekdayShortName((firstDay - 1 + i) % 7 + 1),
                  maxLines: 1, softWrap: false, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
            ),
          ),
      ]),
    );

    final weeks = Column(
      key: ValueKey(year * 100 + month + (noYear ? 1000000 : 0)),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var w = 0; w < MonthGrid.weeks; w++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var d = 0; d < 7; d++) _day(days[w * 7 + d]),
          ]),
      ],
    );

    final grid = Focus(
      focusNode: calendarNode,
      onKeyEvent: onKey,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: title,
        child: AnimatedSwitcher(
          duration: context.motion.fast,
          switchInCurve: context.motion.standard,
          switchOutCurve: context.motion.standard,
          layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
          child: weeks,
        ),
      ),
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [header, weekdays, grid],
    );
    // Seven cells wide. The birthday's two lists and the month buttons can need a little more ("September",
    // "No year"): the popover then widens rather than cutting a value short, and the days stay centred.
    if (!birthday) return SizedBox(width: 7 * cellSize, child: column);
    return IntrinsicWidth(stepWidth: 1, child: ConstrainedBox(constraints: BoxConstraints(minWidth: 7 * cellSize), child: column));
  }

  Widget _day(DateTime day) {
    final isToday = today != null && _key(day) == _key(today!);
    final isSelected = selected != null && _key(day) == _key(selected!);
    final isFocused = _key(day) == _key(focusDay);
    final unavailable = earliest != null && _key(day) < _key(earliest!);
    return Semantics(
      container: true,
      selected: isSelected,
      enabled: !unavailable,
      focusable: isFocused ? true : null,
      focused: isFocused ? calendarNode.hasFocus : null,
      label: _dayLabel(day),
      onTap: unavailable ? null : () => onPick(day),
      child: ExcludeSemantics(
        child: MonthGridDay(
          key: ValueKey('date-picker-day-${_key(day)}'),
          day: day,
          size: cellSize,
          inMonth: day.month == month,
          today: isToday,
          selected: isSelected,
          focused: isFocused && showFocus,
          unavailable: unavailable,
          onPressed: onPick,
        ),
      ),
    );
  }
}

/// "Previous month" and "Next month": [MyDataIconButton]s in the normal tone.
class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.label, required this.onPressed});
  final MyDataIcon icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MyDataIconButton(icon: icon, label: label, onPressed: onPressed);
}

/// The birthday popover's "Month" and "Year": a small Select field (`surface`, 1px `line-strong`,
/// `radius-md`, `control-height`, an up-and-down chevron in `ink-muted`) opening Select's list under it.
class _MiniSelect extends StatefulWidget {
  const _MiniSelect({required this.label, required this.items, required this.selected, required this.onSelected});
  final String label;
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<_MiniSelect> createState() => _MiniSelectState();
}

class _MiniSelectState extends State<_MiniSelect> {
  final _key = GlobalKey();
  final _listNode = FocusNode(debugLabel: 'DatePicker list');
  final _fieldNode = FocusNode(debugLabel: 'DatePicker select');
  bool _open = false;

  @override
  void dispose() {
    _listNode.dispose();
    _fieldNode.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    setState(() => _open = open);
    if (open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _open) _listNode.requestFocus();
      });
    } else {
      _fieldNode.requestFocus();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _open) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      _setOpen(true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = Container(
      key: _key,
      height: context.density.controlHeight,
      padding: EdgeInsetsDirectional.only(start: context.space(3), end: context.space(2)),
      decoration: InputBox.of(context.look, edge: c.lineStrong, width: InputBox.borderWidth),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.items[widget.selected], maxLines: 1, style: context.typeScale.body.copyWith(color: c.ink)),
        SizedBox(width: context.space(1)),
        Icon(context.icon(MyDataIcon.upDown), size: context.density.icon, color: c.inkMuted),
      ]),
    );
    return PickerPopover(
      open: _open,
      anchorKey: _key,
      padding: EdgeInsets.all(context.space(1)),
      onDismiss: () => setState(() => _open = false),
      popover: (context) => PickerListBox(
        items: [for (final i in widget.items) PickerListItem(title: i)],
        highlighted: widget.selected,
        checked: widget.selected,
        focusNode: _listNode,
        semanticLabel: widget.label,
        onPicked: (i) {
          widget.onSelected(i);
          _setOpen(false);
        },
        onDismiss: () => _setOpen(false),
      ),
      child: Focus(
        onKeyEvent: _onKey,
        skipTraversal: true,
        canRequestFocus: false,
        child: Semantics(
          value: widget.items[widget.selected],
          child: Pressable(
            onPressed: () => _setOpen(!_open),
            focusNode: _fieldNode,
            borderRadius: MyDataRadii.md(context.look),
            scaleOnPress: false,
            hoverFill: c.surfaceHover,
            semanticLabel: widget.label,
            child: box,
          ),
        ),
      ),
    );
  }
}
