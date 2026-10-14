import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';

/// Records every command and answers with [answer] (or throws [error]).
class FakeRunner {
  FakeRunner({this.answer = const CommandResult(0, ''), this.error, this.delay});
  CommandResult answer;
  Object? error;
  Duration? delay;
  final calls = <List<String>>[];

  Future<CommandResult> call(String executable, List<String> arguments) async {
    calls.add([executable, ...arguments]);
    if (delay != null) await Future<void>.delayed(delay!);
    if (error != null) throw error!;
    return answer;
  }
}

const _id = '2f1c9a52-7d3e-4b8a-9c61-0e5d4f3a2b10';

void main() {
  group('MyDataLink.parse', () {
    test('the three kinds of link', () {
      expect(MyDataLink.parse('mycontacts://contact/$_id'), OpenContact(_id));
      expect(MyDataLink.parse('mycalendar://day/2026-03-18'), OpenDay(DateTime(2026, 3, 18)));
      expect(MyDataLink.parse('mydata://settings/sources'), const OpenMyDataSources());
      expect(MyDataLink.parse(Uri.parse('mycalendar://day/2026-12-31')), OpenDay(DateTime(2026, 12, 31)));
    });

    test('the import and contact list links', () {
      expect(MyDataLink.parse('mydata://import/contacts'), const OpenMyDataImport());
      expect(MyDataLink.parse('MyData://Import/contacts'), const OpenMyDataImport());
      expect(const OpenMyDataImport().app, MyDataAppId.mydata);
      expect(const OpenMyDataImport().uri.toString(), 'mydata://import/contacts');
      expect(MyDataLink.parse('mycontacts://contacts'), const OpenContactList());
      expect(const OpenContactList().app, MyDataAppId.mycontacts);
      expect(const OpenContactList().uri.toString(), 'mycontacts://contacts');
      for (final bad in [
        'mydata://import',
        'mydata://import/',
        'mydata://import/contacts/',
        'mydata://import/calendars',
        'mydata://import/contacts?file=x',
        'mycontacts://contacts/',
        'mycontacts://contacts#x',
      ]) {
        expect(MyDataLink.parse(bad), isNull, reason: bad);
      }
    });

    test('scheme and first part are case-insensitive, the id keeps its case', () {
      final link = MyDataLink.parse('MyContacts://Contact/AbC-12');
      expect(link, OpenContact('AbC-12'));
      expect(link!.uri.toString(), 'mycontacts://contact/AbC-12');
    });

    test('each link knows its app and canonical spelling', () {
      expect(OpenContact(_id).app, MyDataAppId.mycontacts);
      expect(OpenDay(DateTime(2026, 3, 8, 17, 45)).uri.toString(), 'mycalendar://day/2026-03-08');
      expect(const OpenMyDataSources().uri.toString(), 'mydata://settings/sources');
      expect(const OpenMyDataSources().app, MyDataAppId.mydata);
    });

    test('anything else is not a link', () {
      final bad = [
        '',
        'mycontacts://contact/',
        'mycontacts://contact/${'a' * 65}',
        'mycontacts://contact/abc/',
        'mycontacts://contact/abc/def',
        'mycontacts://contact/a_b',
        'mycontacts://contact/a%2Fb',
        'mycontacts://contact/%41bc',
        'mycontacts://contact/abc?x=1',
        'mycontacts://contact/abc#x',
        'mycontacts://user@contact/abc',
        'mycontacts://contact:80/abc',
        'mycontacts:contact/abc',
        'mycontacts://person/abc',
        ' mycontacts://contact/abc',
        'mycontacts://contact/abc\n',
        'mycalendar://day/2026-02-30',
        'mycalendar://day/2026-13-01',
        'mycalendar://day/0000-01-01',
        'mycalendar://day/2026-3-18',
        'mycalendar://day/20260318',
        'mycalendar://day/2026-03-18T10:00',
        'mycalendar://day/２０２６-03-18',
        'mycalendar://week/2026-03-18',
        'mydata://settings/sources/',
        'mydata://settings/agents',
        'mydata://settings',
        'myassistant://chat',
        'https://example.com/contact/abc',
        'file:///etc/passwd',
        'x-apple.systempreferences:com.apple.preference.security',
        '-a Calculator',
      ];
      for (final s in bad) {
        expect(MyDataLink.parse(s), isNull, reason: s);
      }
      expect(MyDataLink.parse(null), isNull);
      expect(MyDataLink.parse(42), isNull);
    });

    test('leap days are real dates only in leap years', () {
      expect(MyDataLink.parse('mycalendar://day/2028-02-29'), OpenDay(DateTime(2028, 2, 29)));
      expect(MyDataLink.parse('mycalendar://day/2026-02-29'), isNull);
    });

    test('links cannot be built from bad values', () {
      expect(() => OpenContact('a/b'), throwsArgumentError);
      expect(() => OpenContact(''), throwsArgumentError);
      expect(() => OpenDay(DateTime(10000)), throwsArgumentError);
    });
  });

  group('MyDataAppId', () {
    test('bundle ids and schemes', () {
      expect(MyDataAppId.mycontacts.bundleId, 'kiwi.mydata.mycontacts');
      expect(MyDataAppId.mydata.bundleId, 'kiwi.mydata.mydata');
      expect(MyDataAppId.mycalendar.scheme, 'mycalendar');
      expect(MyDataAppId.myassistant.scheme, isNull);
      expect(MyDataAppId.mycalendar.displayName, 'myCalendar');
    });
  });

  group('AppLinks.isInstalled', () {
    test('asks LaunchServices through osascript, with the bundle id as an argument', () async {
      final run = FakeRunner(answer: const CommandResult(0, '/Applications/myContacts.app\n'));
      final links = AppLinks(run: run.call, macOS: true);
      expect(await links.isInstalled(MyDataAppId.mycontacts), isTrue);
      expect(run.calls.single, ['/usr/bin/osascript', '-l', 'JavaScript', '-e', AppLinks.lookupScript, 'kiwi.mydata.mycontacts']);
      expect(AppLinks.lookupScript, isNot(contains('kiwi.mydata')));
      expect(AppLinks.lookupScript, contains('URLForApplicationWithBundleIdentifier'));
    });

    test('not installed when nothing is printed, the lookup fails, throws or hangs', () async {
      final run = FakeRunner(answer: const CommandResult(0, '\n'));
      final links = AppLinks(run: run.call, macOS: true, timeout: const Duration(milliseconds: 50));
      expect(await links.isInstalled(MyDataAppId.mycalendar), isFalse);
      run.answer = const CommandResult(1, '/Applications/myCalendar.app');
      expect(await links.isInstalled(MyDataAppId.mycalendar), isFalse);
      run.error = Exception('no osascript');
      expect(await links.isInstalled(MyDataAppId.mycalendar), isFalse);
      run
        ..error = null
        ..answer = const CommandResult(0, '/Applications/myCalendar.app')
        ..delay = const Duration(seconds: 1);
      expect(await links.isInstalled(MyDataAppId.mycalendar), isFalse);
    });

    test('never installed, and nothing is run, off macOS', () async {
      final run = FakeRunner(answer: const CommandResult(0, '/Applications/myContacts.app'));
      final links = AppLinks(run: run.call, macOS: false);
      expect(await links.isInstalled(MyDataAppId.mycontacts), isFalse);
      expect(run.calls, isEmpty);
    });
  });

  group('AppLinks.open', () {
    test('opens a valid link with exactly its app, in canonical spelling', () async {
      final run = FakeRunner();
      final links = AppLinks(run: run.call, macOS: true);
      expect(await links.open(Uri.parse('MYCALENDAR://day/2026-03-18')), isTrue);
      expect(await links.open(Uri.parse('mycontacts://contact/$_id')), isTrue);
      expect(run.calls, [
        ['/usr/bin/open', '-b', 'kiwi.mydata.mycalendar', 'mycalendar://day/2026-03-18'],
        ['/usr/bin/open', '-b', 'kiwi.mydata.mycontacts', 'mycontacts://contact/$_id'],
      ]);
    });

    test('refuses anything that is not a myData link, without running anything', () async {
      final run = FakeRunner();
      final links = AppLinks(run: run.call, macOS: true);
      for (final s in [
        'https://example.com',
        'file:///Applications/Calculator.app',
        'mycontacts://contact/abc?open=1',
        'mycalendar://day/2026-02-30',
        'x-apple.systempreferences:com.apple.preference.security',
      ]) {
        expect(await links.open(Uri.parse(s)), isFalse, reason: s);
      }
      expect(run.calls, isEmpty);
    });

    test('false when open fails (app not installed) or this is not macOS', () async {
      final run = FakeRunner(answer: const CommandResult(1, '', 'Unable to find application'));
      expect(await AppLinks(run: run.call, macOS: true).open(Uri.parse('mycontacts://contact/abc')), isFalse);
      final run2 = FakeRunner();
      expect(await AppLinks(run: run2.call, macOS: false).open(Uri.parse('mycontacts://contact/abc')), isFalse);
      expect(run2.calls, isEmpty);
      final run3 = FakeRunner(error: Exception('no open'));
      expect(await AppLinks(run: run3.call, macOS: true).openLink(OpenContact('abc')), isFalse);
    });

    test('openApp opens an app by its bundle id alone, also one that takes no links', () async {
      final run = FakeRunner();
      final links = AppLinks(run: run.call, macOS: true);
      expect(await links.openApp(MyDataAppId.myassistant), isTrue);
      expect(run.calls.single, ['/usr/bin/open', '-b', 'kiwi.mydata.myassistant']);
      run.answer = const CommandResult(1, '', 'Unable to find application');
      expect(await links.openApp(MyDataAppId.mycalendar), isFalse);
      final off = FakeRunner();
      expect(await AppLinks(run: off.call, macOS: false).openApp(MyDataAppId.mycontacts), isFalse);
      expect(off.calls, isEmpty);
    });

    test('openMyDataImport sends myData its import link', () async {
      final run = FakeRunner();
      expect(await AppLinks(run: run.call, macOS: true).openMyDataImport(), isTrue);
      expect(run.calls, [
        ['/usr/bin/open', '-b', 'kiwi.mydata.mydata', 'mydata://import/contacts'],
      ]);
    });

    test('openMyDataSources sends myData its settings link', () async {
      final run = FakeRunner();
      final saved = appLinks;
      appLinks = AppLinks(run: run.call, macOS: true);
      addTearDown(() => appLinks = saved);
      expect(await openMyDataSources(), isTrue);
      expect(run.calls.single, ['/usr/bin/open', '-b', 'kiwi.mydata.mydata', 'mydata://settings/sources']);
    });
  });
}
