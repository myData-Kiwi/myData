// The Mac shell (lib/src/mac/mac_shell.dart) and its Runner side (macos_snippets/MacShell.swift).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

void main() {
  tearDown(() => MacLook.debugOverride = null);

  test("every app's Runner copy of MacShell.swift is the snippet, unchanged", () {
    final snippet = File('macos_snippets/MacShell.swift').readAsStringSync();
    final copies = [
      for (final app in Directory('../../apps').listSync().whereType<Directory>())
        if (File('${app.path}/macos/Runner/MacShell.swift') case final f when f.existsSync()) f,
    ];
    expect(copies, isNotEmpty, reason: 'myContacts uses the shell');
    for (final f in copies) {
      expect(f.readAsStringSync(), snippet, reason: f.path);
      // The app's own AccessibilityChannel would be a second class of that name.
      final window = File('${f.parent.path}/MainFlutterWindow.swift').readAsStringSync();
      expect(window, isNot(contains('class AccessibilityChannel')), reason: f.parent.path);
      expect(window, contains('MacShell.install('), reason: f.parent.path);
    }
  });

  test('the snippet reads every system colour the Mac theme has a token for', () {
    final snippet = File('macos_snippets/MacShell.swift').readAsStringSync();
    // Fallback only: the sidebar's flat colour, the selected sidebar row, hover and the toolbar's glass stand-in.
    const notFromTheSystem = {'sidebar-background', 'sidebar-selection', 'hover', 'toolbar-item'};
    for (final name in MyDataMacColors.tokenNames) {
      if (notFromTheSystem.contains(name)) continue;
      expect(snippet, contains('("$name", .'), reason: name);
    }
  });

  Widget shell(MyDataTheme theme, void Function(ThemeData light, ThemeData dark, ThemeMode mode) seen) => MacShell(
        theme: theme,
        builder: (context, light, dark, mode) {
          seen(light, dark, mode);
          return MaterialApp(theme: light, darkTheme: dark, themeMode: mode, builder: MacShell.content, home: const SizedBox());
        },
      );

  testWidgets('off a Mac the shell gives the branded themes and no window chrome', (tester) async {
    MacLook.debugOverride = false;
    late ThemeData light;
    late ThemeMode mode;
    final theme = MyDataTheme(themeId: 'graphite', mode: MyDataMode.dark);
    await tester.pumpWidget(shell(theme, (l, _, m) => (light, mode) = (l, m)));
    expect(light.extension<MyDataMacColors>(), isNull);
    expect(light.extension<MyDataColors>()!.accent, theme.light.extension<MyDataColors>()!.accent);
    expect(mode, ThemeMode.dark);
    expect(find.byType(MyDataAccessibilityScope), findsOneWidget);
    expect(find.byType(MacChrome), findsNothing);
  });

  testWidgets("on a Mac the shell gives the Mac themes, the system's accent and the window chrome", (tester) async {
    MacLook.debugOverride = true;
    late ThemeData light, dark;
    await tester.pumpWidget(shell(MyDataTheme(themeId: 'plum'), (l, d, _) => (light, dark) = (l, d)));
    expect(light.extension<MyDataMacColors>(), MyDataMacColors.light);
    expect(dark.extension<MyDataMacColors>(), MyDataMacColors.dark);
    // The accent is the system's (its fallback here), not the host's Plum.
    expect(light.extension<MyDataColors>()!.accent, MyDataMacColors.light.accent);
    expect(find.byType(MyDataAccessibilityScope), findsOneWidget);
    expect(find.byType(MacChrome), findsOneWidget);
    expect(MacChrome.of(tester.element(find.byType(SizedBox).last)).windowActive, isTrue);
  });

  testWidgets('MacAppFrame: the sidebar beside the content, or the content alone without a host', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget app(AppConnection? connection) => MaterialApp(
          theme: MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light),
          home: Scaffold(
            body: MacAppFrame(
              sections: const [
                AppSection(icon: MacIcons.people, label: 'Contacts'),
                AppSection(icon: MacIcons.trash, label: 'Recently Deleted'),
              ],
              current: 0,
              onSelect: (_) {},
              connection: connection,
              child: const MacPane(toolbar: MacToolbar(title: 'Contacts'), child: Text('the list')),
            ),
          ),
        );
    await tester.pumpWidget(app(const AppConnection.starting()));
    expect(find.byType(MacSourceList), findsOneWidget);
    expect(find.text('Recently Deleted'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(MacToolbar)).dx, MyDataMacSize.sidebarWidth);
    expect(tester.getSize(find.byType(MacToolbar)).height, MyDataMacSize.toolbarHeight);
    expect(find.text('the list'), findsOneWidget);

    await tester.pumpWidget(app(null));
    expect(find.byType(MacSourceList), findsNothing);
    expect(tester.getTopLeft(find.byType(MacToolbar)).dx, 0);
  });
}
