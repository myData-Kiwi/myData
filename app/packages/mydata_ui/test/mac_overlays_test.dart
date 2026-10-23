// What opens over a window in the Mac frame, shared by every app (mac/mac_overlays.dart, the Mac branches of
// dialog.dart, menu.dart and toast.dart) and the one empty and error state (mac/mac_empty_state.dart): their
// behaviour as macOS, and screenshots (test/screenshots/mac_*.png) in light and dark. Refresh with
// `flutter test --update-goldens test/mac_overlays_test.dart` on a Mac.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// [home] in the Mac theme for [t], under the app's icon, at a Mac window's width.
Widget macApp(ThemeCase t, Widget home) => MacAppIcon(
      icon: MyDataAppIcons.mycontacts,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MacTheme.data(t.themeId, t.brightness,
            t.brightness == Brightness.dark ? MyDataMacColors.dark : MyDataMacColors.light),
        home: MyDataAccessibility(
          reduceMotion: true,
          reduceTransparency: false,
          child: Builder(builder: (context) => Scaffold(backgroundColor: context.mac.contentBackground, body: home)),
        ),
      ),
    );

const _size = Size(720, 480);

/// A button that opens what [open] shows.
class _Opener extends StatelessWidget {
  const _Opener(this.open);
  final void Function(BuildContext context) open;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(MyDataSpace.s5),
          child: Button(label: 'Open', onPressed: () => open(context)),
        ),
      );
}

void _purgeAlert(BuildContext context) => showMyDataDialog(
      context: context,
      builder: (_) => const MyDataDialog(
        title: 'Delete Pip Owned permanently?',
        message: 'This cannot be undone. Copies in your host’s backups are kept until 1 Oct 2027.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Delete permanently',
        destructive: true,
      ),
    );

void _menu(BuildContext context) => Menu.showAt(
      context,
      position: const Offset(MyDataSpace.s5, MyDataSpace.s12),
      entries: [
        MenuItem(label: 'Edit contact', shortcut: AppMenuBar.editShortcut.activator(TargetPlatform.macOS), onSelected: () {}),
        const MenuItem(
          label: 'Merge contacts…',
          onSelected: _none,
          enabled: false,
          disabledReason: 'Choose 2 to 20 of your own contacts.',
        ),
        const MenuSeparator(),
        const MenuItem(label: 'Delete contact', destructive: true, onSelected: _none),
      ],
    );

void _none() {}

void main() {
  // The Mac frame's fonts (the system font's names over the bundled Figtree, and Lucide).
  setUpAll(loadMacFonts);
  setUp(() => MacLook.debugOverride = true);
  tearDown(() => MacLook.debugOverride = false);

  group('the alert', () {
    macTestWidgets('shows the app’s icon; Cancel is the default and Return presses it', (tester) async {
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(macApp(macMatrix.first, const _Opener(_purgeAlert)));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is Image && w.image == MyDataAppIcons.mycontacts), findsOneWidget);
      // No scrim: the window behind a sheet stays as it is.
      expect(
        find.byWidgetPredicate((w) => w is ModalBarrier && w.color != null && w.color!.a > 0),
        findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(MyDataDialog), findsNothing, reason: 'Return pressed Cancel');
    });
  });

  group('the menu', () {
    macTestWidgets('writes shortcuts the Mac way and has no second line', (tester) async {
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(macApp(macMatrix.first, const _Opener(_menu)));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('⌘E'), findsOneWidget);
      expect(find.text('Choose 2 to 20 of your own contacts.'), findsNothing,
          reason: 'a disabled item’s reason is its help tag, not a second line');
    });
  });

  group('screenshots', () {
    macScreenMatrix('mac_alert', (t) => macApp(t, const _Opener(_purgeAlert)), size: _size,
        before: (tester) async {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    });
    macScreenMatrix('mac_menu', (t) => macApp(t, const _Opener(_menu)), size: _size, before: (tester) async {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    });
    macScreenMatrix(
      'mac_toast',
      (t) => macApp(t, ToastHost(child: Builder(builder: (context) => _Opener((c) {
        ToastHost.of(c).show('Contact deleted', undo: () async => const UndoResult('Contact restored'));
      })))),
      size: _size,
      before: (tester) async {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      },
    );
    macScreenMatrix(
      'mac_empty_state',
      (t) => macApp(
        t,
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: EmptyState(
              title: 'No contacts yet',
              sentence: 'Turn on This Mac in myData, or make one here.',
              actionLabel: 'New Contact',
              onAction: () {},
            ),
          ),
          Expanded(
            child: StatusPanel(
              kind: StatusPanelKind.error,
              title: AppConnection.lostText,
              message: 'The myData host stopped while the app was open.',
              detail: 'Its log is in /tmp/mydata-test/logs/mydatad.log',
              actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: () {})],
            ),
          ),
        ]),
      ),
      size: _size,
    );
  });
}
