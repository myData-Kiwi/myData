import 'dart:async';

import 'platform.dart';

/// The myData apps that can be opened from another one. Each is a separate app with the bundle id
/// `kiwi.mydata.<name>`; those that accept links register [scheme] in their Info.plist (CFBundleURLTypes).
enum MyDataAppId {
  mydata('myData', 'mydata'),
  myassistant('myAssistant', null),
  mycontacts('myContacts', 'mycontacts'),
  mycalendar('myCalendar', 'mycalendar');

  const MyDataAppId(this.displayName, this.scheme);

  /// The app's name, for people ("Open in myCalendar").
  final String displayName;

  /// The URL scheme the app accepts, or null if it accepts no links.
  final String? scheme;

  /// The macOS bundle id, e.g. `kiwi.mydata.mycontacts`.
  String get bundleId => 'kiwi.mydata.$name';
}

/// A link from one myData app to another. The only links there are:
///
/// - `mycontacts://contact/<id>`: a contact, by its id on the host ([OpenContact]);
/// - `mycalendar://day/<YYYY-MM-DD>`: a day ([OpenDay]);
/// - `mycontacts://contacts`: myContacts at its list of contacts ([OpenContactList]);
/// - `mydata://settings/sources`: the myData app at Settings, Sources ([OpenMyDataSources]);
/// - `mydata://import/contacts`: the myData app at Import, choosing a contacts file ([OpenMyDataImport]).
///
/// Anything else, including these with a query, a fragment, a port, a trailing slash or a percent escape,
/// is not a link: [parse] returns null.
sealed class MyDataLink {
  const MyDataLink();

  /// The app this link opens.
  MyDataAppId get app;

  /// The link, in its one canonical spelling.
  Uri get uri;

  /// The link [link] (a [String] or a [Uri]) stands for, or null if it is not a valid myData link.
  static MyDataLink? parse(Object? link) {
    final s = switch (link) {
      final String s => s,
      final Uri u => u.toString(),
      _ => null,
    };
    if (s == null || s.length > 128) return null;
    final contact = _contactLink.firstMatch(s);
    if (contact != null) return OpenContact(contact.group(1)!);
    final day = _dayLink.firstMatch(s);
    if (day != null) {
      final date = OpenDay.parseDate('${day.group(1)}-${day.group(2)}-${day.group(3)}');
      return date == null ? null : OpenDay(date);
    }
    if (_sourcesLink.hasMatch(s)) return const OpenMyDataSources();
    if (_importLink.hasMatch(s)) return const OpenMyDataImport();
    if (_listLink.hasMatch(s)) return const OpenContactList();
    return null;
  }

  @override
  String toString() => uri.toString();
}

// Whole-string matches: the scheme and the first part are case-insensitive, as in any URL; the rest is exact.
final _contactLink = RegExp(r'^mycontacts://contact/([A-Za-z0-9-]{1,64})$', caseSensitive: false);
final _dayLink = RegExp(r'^mycalendar://day/([0-9]{4})-([0-9]{2})-([0-9]{2})$', caseSensitive: false);
final _sourcesLink = RegExp(r'^mydata://settings/sources$', caseSensitive: false);
final _importLink = RegExp(r'^mydata://import/contacts$', caseSensitive: false);
final _listLink = RegExp(r'^mycontacts://contacts$', caseSensitive: false);
final _contactId = RegExp(r'^[A-Za-z0-9-]{1,64}$');

/// Show one contact in myContacts.
final class OpenContact extends MyDataLink {
  /// Throws [ArgumentError] if [id] is not a valid contact id ([isValidId]).
  OpenContact(this.id) {
    if (!isValidId(id)) throw ArgumentError.value(id, 'id', 'not a contact id');
  }

  /// The contact's id on the host.
  final String id;

  /// Letters, digits and hyphens, 1 to 64 of them (the host's ids are UUIDs).
  static bool isValidId(String id) => _contactId.hasMatch(id);

  @override
  MyDataAppId get app => MyDataAppId.mycontacts;

  @override
  Uri get uri => Uri.parse('mycontacts://contact/$id');

  @override
  bool operator ==(Object other) => other is OpenContact && other.id == id;

  @override
  int get hashCode => Object.hash(OpenContact, id);
}

/// Show one day in myCalendar.
final class OpenDay extends MyDataLink {
  /// The day of [date] (its time is dropped). Throws [ArgumentError] for a year outside 1 to 9999.
  OpenDay(DateTime date) : date = DateTime(date.year, date.month, date.day) {
    if (date.year < 1 || date.year > 9999) throw ArgumentError.value(date, 'date', 'year out of range');
  }

  /// The day, at local midnight.
  final DateTime date;

  /// `YYYY-MM-DD`.
  String get isoDate =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// A real calendar date written as `YYYY-MM-DD` (so not 2026-02-30), at local midnight; otherwise null.
  static DateTime? parseDate(String s) {
    final m = RegExp(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
    if (y < 1 || mo < 1 || mo > 12 || d < 1) return null;
    final date = DateTime(y, mo, d);
    return date.year == y && date.month == mo && date.day == d ? date : null;
  }

  @override
  MyDataAppId get app => MyDataAppId.mycalendar;

  @override
  Uri get uri => Uri.parse('mycalendar://day/$isoDate');

  @override
  bool operator ==(Object other) => other is OpenDay && other.date == date;

  @override
  int get hashCode => Object.hash(OpenDay, date);
}

/// Show the myData app at Settings, Sources.
final class OpenMyDataSources extends MyDataLink {
  const OpenMyDataSources();

  @override
  MyDataAppId get app => MyDataAppId.mydata;

  @override
  Uri get uri => Uri.parse('mydata://settings/sources');

  @override
  bool operator ==(Object other) => other is OpenMyDataSources;

  @override
  int get hashCode => (OpenMyDataSources).hashCode;
}

/// Show the myData app at Import, on the step that chooses a contacts file (myContacts' File > Import…;
/// design/components/ImportFlow, "Where it lives"). An import already in Review or Importing is not
/// restarted: myData comes forward on that step.
final class OpenMyDataImport extends MyDataLink {
  const OpenMyDataImport();

  @override
  MyDataAppId get app => MyDataAppId.mydata;

  @override
  Uri get uri => Uri.parse('mydata://import/contacts');

  @override
  bool operator ==(Object other) => other is OpenMyDataImport;

  @override
  int get hashCode => (OpenMyDataImport).hashCode;
}

/// Show myContacts at its list of contacts (the import's Done step: "Open in myContacts").
final class OpenContactList extends MyDataLink {
  const OpenContactList();

  @override
  MyDataAppId get app => MyDataAppId.mycontacts;

  @override
  Uri get uri => Uri.parse('mycontacts://contacts');

  @override
  bool operator ==(Object other) => other is OpenContactList;

  @override
  int get hashCode => (OpenContactList).hashCode;
}

/// Opening one myData app from another (macOS; elsewhere every answer is false).
///
/// - [isInstalled] asks LaunchServices for the app's bundle id, without launching anything and without
///   Spotlight: `osascript -l JavaScript` calling `NSWorkspace.urlForApplication(withBundleIdentifier:)`.
///   It sends no Apple Events, so it never causes a permission prompt. It takes about 50 ms: ask once per
///   screen, not on every build.
/// - [open] accepts only valid myData links ([MyDataLink.parse]) and hands their canonical spelling to
///   `/usr/bin/open -b <bundle id>`, so the link reaches that exact app and no other app that claims the
///   scheme. If the app is not running it is started and gets the link when it is ready.
class AppLinks {
  AppLinks({CommandRunner? run, bool? macOS, this.timeout = const Duration(seconds: 10)})
    : _run = run ?? runCommand,
      _macOS = macOS ?? platformIsMacOS;

  final CommandRunner _run;
  final bool _macOS;

  /// How long a lookup or an `open` may take before it counts as failed.
  final Duration timeout;

  static const osascript = '/usr/bin/osascript';
  static const openCommand = '/usr/bin/open';

  /// Prints the app's path, or nothing when LaunchServices knows no such app, it is in the Trash, or its
  /// folder is gone. The bundle id is an argument, never part of the script.
  static const lookupScript = '''
ObjC.import('AppKit');
function run(argv) {
  const url = \$.NSWorkspace.sharedWorkspace.URLForApplicationWithBundleIdentifier(argv[0]);
  if (url.isNil()) return '';
  const path = url.path.js;
  if (path.indexOf('/.Trash/') >= 0) return '';
  return \$.NSFileManager.defaultManager.fileExistsAtPath(path) ? path : '';
}''';

  /// Whether [app] is installed on this Mac. False on other platforms and when the lookup fails.
  Future<bool> isInstalled(MyDataAppId app) async {
    if (!_macOS) return false;
    try {
      final r = await _run(osascript, ['-l', 'JavaScript', '-e', lookupScript, app.bundleId]).timeout(timeout);
      return r.exitCode == 0 && r.stdout.trim().isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// Opens [link] in its app. Refuses (false) anything that is not a valid myData link; false also when the
  /// app is not installed, `open` fails, or this is not macOS.
  Future<bool> open(Uri link) async {
    final parsed = MyDataLink.parse(link);
    return parsed == null ? false : openLink(parsed);
  }

  /// Opens [link] in its app; see [open].
  Future<bool> openLink(MyDataLink link) async {
    if (!_macOS) return false;
    try {
      final r = await _run(openCommand, ['-b', link.app.bundleId, link.uri.toString()]).timeout(timeout);
      return r.exitCode == 0;
    } on Object {
      return false;
    }
  }

  /// Opens [app] as it is, with no link: starts it, or brings it forward where it was. False when it is not
  /// installed, `open` fails, or this is not macOS. Works for every app, also those that take no links
  /// (myAssistant).
  Future<bool> openApp(MyDataAppId app) async {
    if (!_macOS) return false;
    try {
      final r = await _run(openCommand, ['-b', app.bundleId]).timeout(timeout);
      return r.exitCode == 0;
    } on Object {
      return false;
    }
  }

  /// Brings the myData app forward at Settings, Sources (starting it if needed). A myData build that does
  /// not handle links yet still comes forward, on whatever screen it was. False where it could not.
  Future<bool> openMyDataSources() => openLink(const OpenMyDataSources());

  /// Brings the myData app forward at Import (starting it if needed). False where it could not.
  Future<bool> openMyDataImport() => openLink(const OpenMyDataImport());
}

/// The app links every app uses; tests may replace it.
AppLinks appLinks = AppLinks();

/// Brings the myData app forward at Settings, Sources; see [AppLinks.openMyDataSources].
Future<bool> openMyDataSources() => appLinks.openMyDataSources();
