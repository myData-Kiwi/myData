import 'dart:ui' show PlatformDispatcher;

/// The one way every app writes dates and times (CLAUDE.md: British English, "Wed 14 Oct 2026"), so a
/// contact's "Added", Recently deleted, myData's status and myCalendar's times read alike:
///
/// - **Short** ([day]): "14 Oct 2026", or "Wed 14 Oct 2026" with the weekday. Lines, captions, history.
/// - **Long** ([longDay]): "Wednesday 14 October 2026", the year left out when [longDay]'s `year` is false.
///   Headings.
/// - **Times** ([time]): "07:58" or "7:58 am", as the device's clock is set (System Settings, "24-hour
///   time": `MediaQuery.alwaysUse24HourFormat`, which this reads when not told).
/// - **Both** ([dayAndTime]): "14 Oct 2026, 7:58 am".
/// - Host values ([parseHost]): an ISO 8601 time in UTC is read into local time; a date ("2026-10-14") stays
///   that day.
abstract final class MyDataDates {
  static const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const months = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// Whether this device shows a 24-hour clock.
  static bool get deviceUses24Hour => PlatformDispatcher.instance.alwaysUse24HourFormat;

  /// "14 Oct 2026"; with [weekday] "Wed 14 Oct 2026"; without [year] "14 Oct".
  static String day(DateTime d, {bool weekday = false, bool year = true}) => [
        if (weekday) shortWeekdays[d.weekday - 1],
        '${d.day}',
        shortMonths[d.month - 1],
        if (year) '${d.year}',
      ].join(' ');

  /// "Wednesday 14 October 2026"; without [weekday] "14 October 2026"; without [year] "Wednesday 14 October".
  static String longDay(DateTime d, {bool weekday = true, bool year = true}) => [
        if (weekday) weekdays[d.weekday - 1],
        '${d.day}',
        months[d.month - 1],
        if (year) '${d.year}',
      ].join(' ');

  /// "October 2026".
  static String month(DateTime d) => '${months[d.month - 1]} ${d.year}';

  /// "07:58" on a 24-hour clock, else "7:58 am".
  static String time(DateTime t, {bool? use24HourFormat}) {
    final m = t.minute.toString().padLeft(2, '0');
    if (use24HourFormat ?? deviceUses24Hour) return '${t.hour.toString().padLeft(2, '0')}:$m';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:$m ${t.hour < 12 ? 'am' : 'pm'}';
  }

  /// "14 Oct 2026, 7:58 am".
  static String dayAndTime(DateTime t, {bool? use24HourFormat}) =>
      '${day(t)}, ${time(t, use24HourFormat: use24HourFormat)}';

  /// A host time (ISO 8601, UTC) in local time, or a host date ("2026-10-14") as that day; null when it
  /// cannot be read.
  static DateTime? parseHost(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return null;
    return iso.length == 10 ? t : t.toLocal();
  }

  /// [iso] (see [parseHost]) as [day], or [iso] itself when it cannot be read.
  static String hostDay(String iso) => switch (parseHost(iso)) { final d? => day(d), null => iso };

  /// [iso] (see [parseHost]) as [dayAndTime], or [iso] itself when it cannot be read.
  static String hostDayAndTime(String iso, {bool? use24HourFormat}) =>
      switch (parseHost(iso)) { final t? => dayAndTime(t, use24HourFormat: use24HourFormat), null => iso };
}
