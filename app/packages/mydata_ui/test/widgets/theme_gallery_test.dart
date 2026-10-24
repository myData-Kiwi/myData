import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _kiwi = ThemeChoice(ThemeLibrary.kiwiId, 'kiwi');
const _plum = ThemeChoice('mydata.journal', 'plum');

/// An app window with a stored choice and the gallery's preview over it, as ThemeController draws them.
class _Window extends StatefulWidget {
  const _Window({
    required this.stored,
    this.mode = MyDataMode.light,
    this.everywhere = true,
    this.apps,
    this.choosingEverywhere,
  });

  final ThemeChoice stored;
  final MyDataMode mode;
  final bool everywhere;
  final List<ThemeGalleryApp>? apps;

  /// The everywhere choice, for a gallery that chooses it.
  final ThemeChoice? choosingEverywhere;

  @override
  State<_Window> createState() => _WindowState();
}

class _WindowState extends State<_Window> {
  late ThemeChoice stored = widget.stored;
  ThemeChoice? preview;
  final previews = <ThemeChoice?>[];
  final uses = <(String, ThemeChoice)>[];
  final everywhere = <ThemeChoice>[];
  int undone = 0;

  /// Holds each store until completed, as a slow disk does.
  Completer<void>? gate;

  /// Each store fails while set.
  bool failing = false;

  /// What the Undo answers: whether it put the choices back.
  bool undoes = true;

  Future<void> _store() async {
    if (gate != null) await gate!.future;
    if (failing) throw StateError('disk full');
  }

  ThemeChoice get drawn => preview ?? stored;

  void open(BuildContext context) => showThemeGallery(
    context: context,
    apps:
        widget.apps ??
        [ThemeGalleryApp(id: 'mycontacts', name: 'myContacts', scene: ThemePreviewScenes.contacts, current: stored)],
    windowApp: 'mycontacts',
    everywhere: widget.choosingEverywhere,
    onPreview: (c) {
      // the gallery ends its preview after the frame it is removed in, as at the end of a test
      if (!mounted) return;
      setState(() {
        previews.add(c);
        preview = c;
      });
    },
    onUse: (app, c) async {
      await _store();
      uses.add((app, c));
      if (app == 'mycontacts') setState(() => stored = c);
    },
    onUseEverywhere: widget.everywhere
        ? (c) async {
            await _store();
            everywhere.add(c);
            final before = stored;
            setState(() => stored = c);
            return () async {
              undone++;
              if (undoes) setState(() => stored = before);
              return undoes;
            };
          }
        : null,
  );

  @override
  Widget build(BuildContext context) {
    final theme = MyDataTheme(choice: drawn, mode: widget.mode);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: theme.themeMode,
      home: Builder(
        builder: (context) => Material(
          color: context.colors.bg,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Button(label: 'Open', onPressed: () => open(context)),
          ),
        ),
      ),
    );
  }
}

Future<_WindowState> _open(WidgetTester tester, _Window window) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(window);
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return tester.state<_WindowState>(find.byType(_Window));
}

Color _windowAccent(WidgetTester tester) =>
    Theme.of(tester.element(find.text('Open'))).extension<MyDataColors>()!.accent;

void main() {
  testWidgets('opens on the theme in use, its card focused, with System first', (tester) async {
    await _open(tester, const _Window(stored: _plum));
    expect(find.text(ThemeGallery.title), findsOneWidget);
    expect(find.text(ThemeGallery.sentence('myContacts')), findsOneWidget);
    expect(find.text(ThemeGallery.builtInGroup), findsOneWidget);
    // the group's heading and the card's name
    expect(find.text('System'), findsNWidgets(2));
    // Journal's card (System, Kiwi, Hairline, Frosted, Journal) is focused and selected; its palette row
    // shows Plum chosen
    final focused = FocusManager.instance.primaryFocus!;
    expect(focused.debugLabel, 'ThemeGallery card 4');
    expect(find.text(ThemeGallery.paletteLabel), findsOneWidget);
    expect(find.text('Plum'), findsOneWidget);
    expect(find.text(ThemeGallery.useLabel('myContacts')), findsOneWidget);
  });

  testWidgets('the arrow keys preview each theme on the whole window; Escape puts it back', (tester) async {
    final w = await _open(tester, const _Window(stored: _plum));
    final plumAccent = _windowAccent(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    // another theme starts on its default palette
    expect(w.preview, const ThemeChoice('mydata.frosted', 'dusk'));
    expect(_windowAccent(tester), isNot(plumAccent));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    // back on the theme in use: its palette in use
    expect(w.preview, _plum);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(w.preview, ThemeChoice.system);
    // System has no palettes: no palette row
    expect(find.text(ThemeGallery.paletteLabel), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.title), findsNothing);
    expect(w.preview, isNull);
    expect(w.stored, _plum);
    expect(w.uses, isEmpty);
    expect(_windowAccent(tester), plumAccent);
  });

  testWidgets('Cancel also puts the window back', (tester) async {
    final w = await _open(tester, const _Window(stored: _plum));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ThemeGallery.cancelLabel));
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.title), findsNothing);
    expect(w.preview, isNull);
    expect(w.stored, _plum);
  });

  testWidgets('Return keeps the theme and palette shown, for this app, and closes', (tester) async {
    final w = await _open(tester, const _Window(stored: ThemeChoice.system));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    // another theme starts on its default palette (palette ids belong to one theme)
    expect(w.preview, _kiwi);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(w.uses, [('mycontacts', _kiwi)]);
    expect(w.stored, _kiwi);
    expect(find.text(ThemeGallery.title), findsNothing);
  });

  testWidgets('Tab reaches the palette row; its arrow keys preview each palette; Use keeps it', (tester) async {
    final w = await _open(tester, const _Window(stored: _kiwi));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(w.preview, const ThemeChoice(ThemeLibrary.kiwiId, 'sky'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(w.preview, const ThemeChoice(ThemeLibrary.kiwiId, 'violet'));
    expect(w.stored, _kiwi, reason: 'a preview stores nothing');
    await tester.tap(find.text(ThemeGallery.useLabel('myContacts')));
    await tester.pumpAndSettle();
    expect(w.uses, [('mycontacts', const ThemeChoice(ThemeLibrary.kiwiId, 'violet'))]);
  });

  testWidgets('Use everywhere applies theme and palette to every app and offers Undo', (tester) async {
    final w = await _open(tester, const _Window(stored: _kiwi));
    await tester.tap(find.text('Violet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ThemeGallery.everywhereLabel));
    await tester.pumpAndSettle();
    expect(w.everywhere, [const ThemeChoice(ThemeLibrary.kiwiId, 'violet')]);
    expect(find.text(ThemeGallery.everywhereDone('Kiwi, Violet')), findsOneWidget);
    // the gallery stays open
    expect(find.text(ThemeGallery.title), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(w.undone, 1);
    expect(w.stored, _kiwi);
    expect(find.text(ThemeGallery.everywhereUndone), findsOneWidget);
  });

  testWidgets('after Use everywhere, Cancel is Done; an Undo that finds later changes says so', (tester) async {
    final w = await _open(tester, const _Window(stored: _kiwi));
    expect(find.text(ThemeGallery.cancelLabel), findsOneWidget);
    await tester.tap(find.text(ThemeGallery.everywhereLabel));
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.doneLabel), findsOneWidget);
    expect(find.text(ThemeGallery.cancelLabel), findsNothing);
    w.undoes = false;
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.everywhereNotUndone), findsOneWidget);
  });

  testWidgets('choosing everywhere starts on it, and Use everywhere is the default action', (tester) async {
    final w = await _open(tester, const _Window(stored: _kiwi, choosingEverywhere: _plum));
    expect(find.text(ThemeGallery.everywhereSentence), findsOneWidget);
    expect(find.text(ThemeGallery.useLabel('myContacts')), findsNothing);
    final everywhere = tester.widget<Button>(find.widgetWithText(Button, ThemeGallery.everywhereLabel));
    expect(everywhere.variant, ButtonVariant.filled);
    // the selection starts on the everywhere choice, Journal in Plum, not on myContacts' Kiwi in Kiwi
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(w.everywhere, [_plum]);
    expect(w.uses, isEmpty);
    expect(find.text(ThemeGallery.everywhereDone('Journal, Plum')), findsOneWidget);
  });

  testWidgets('while a choice is being stored, Escape and the cards wait for it', (tester) async {
    final w = await _open(tester, const _Window(stored: _plum));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final shown = w.preview;
    w.gate = Completer<void>();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text(ThemeGallery.title), findsOneWidget, reason: 'Escape waits for the store');
    expect(w.preview, shown, reason: 'the selection waits too');
    expect(w.previews, isNot(contains(null)), reason: 'the window is not put back under a choice still landing');
    w.gate!.complete();
    w.gate = null;
    await tester.pumpAndSettle();
    expect(w.uses, [('mycontacts', shown!)]);
    expect(w.stored, shown);
    expect(find.text(ThemeGallery.title), findsNothing);
  });

  testWidgets('a choice that cannot be stored says so, and the gallery stays open', (tester) async {
    final w = await _open(tester, const _Window(stored: _plum));
    w.failing = true;
    await tester.tap(find.text(ThemeGallery.useLabel('myContacts')));
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.failed), findsOneWidget);
    expect(find.text(ThemeGallery.title), findsOneWidget);
    await tester.tap(find.text(ThemeGallery.everywhereLabel));
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.failed), findsOneWidget);
    expect(find.text(ThemeGallery.doneLabel), findsNothing);
    w.failing = false;
    await tester.tap(find.text(ThemeGallery.useLabel('myContacts')));
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.title), findsNothing);
  });

  testWidgets('one gallery at a time: opening another while one is open does nothing', (tester) async {
    final w = await _open(tester, const _Window(stored: _plum));
    expect(ThemeGallery.showing.value, isTrue);
    w.open(tester.element(find.text('Open')));
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.title), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(ThemeGallery.showing.value, isFalse);
    expect(find.text(ThemeGallery.title), findsNothing);
    // and it opens again once closed
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.title), findsOneWidget);
  });

  testWidgets('a gallery torn down with its window lets the next one open', (tester) async {
    await _open(tester, const _Window(stored: _plum));
    expect(ThemeGallery.showing.value, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(ThemeGallery.showing.value, isFalse);
  });

  testWidgets('phones have one theme per app: no Use everywhere', (tester) async {
    await _open(tester, const _Window(stored: _kiwi, everywhere: false));
    expect(find.text(ThemeGallery.everywhereLabel), findsNothing);
    expect(find.text(ThemeGallery.useLabel('myContacts')), findsOneWidget);
  });

  testWidgets("myData's gallery switches between apps; only this app's window previews", (tester) async {
    final w = await _open(
      tester,
      _Window(
        stored: _kiwi,
        apps: [
          ThemeGalleryApp(id: 'mycontacts', name: 'myContacts', scene: ThemePreviewScenes.contacts, current: _kiwi),
          ThemeGalleryApp(id: 'mycalendar', name: 'myCalendar', scene: ThemePreviewScenes.calendar, current: _plum),
        ],
      ),
    );
    await tester.tap(find.text('myCalendar'));
    await tester.pumpAndSettle();
    expect(find.text(ThemeGallery.useLabel('myCalendar')), findsOneWidget);
    expect(w.preview, isNull, reason: "myCalendar's choice is not drawn on myContacts' window");
    await tester.tap(find.text('System').last);
    await tester.pumpAndSettle();
    expect(w.preview, isNull);
    await tester.tap(find.text(ThemeGallery.useLabel('myCalendar')));
    await tester.pumpAndSettle();
    expect(w.uses, [('mycalendar', ThemeChoice.system)]);
    expect(w.stored, _kiwi);
  });

  testWidgets('screen readers: the themes and palettes are radio groups, named in words', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, const _Window(stored: _plum));
    final themes = find.bySemanticsLabel(ThemeGallery.themesLabel);
    expect(themes, findsOneWidget);
    expect(tester.getSemantics(themes).role, SemanticsRole.radioGroup);
    expect(
      tester.getSemantics(find.bySemanticsLabel('System, theme')),
      isSemantics(isInMutuallyExclusiveGroup: true, hasCheckedState: true, isChecked: false, isFocusable: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Journal, theme')),
      isSemantics(hasCheckedState: true, isChecked: true, isFocused: true),
    );
    final palettes = find.bySemanticsLabel('${ThemeGallery.paletteLabel} of Journal');
    expect(tester.getSemantics(palettes).role, SemanticsRole.radioGroup);
    for (final name in ['Plum', 'Ink blue', 'Forest']) {
      expect(find.bySemanticsLabel(RegExp('^$name\$')), findsWidgets, reason: name);
    }
    // the previews are pictures, never read: no contact name from a scene reaches the tree
    expect(find.bySemanticsLabel(RegExp('Ava Fictional')), findsNothing);
    semantics.dispose();
  });

  testWidgets('with reduced motion the gallery appears without sliding', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const _Window(stored: _kiwi),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(
      find.byType(SlideTransition).evaluate().where((e) {
        return find.descendant(of: find.byWidget(e.widget), matching: find.byType(ThemeGallery)).evaluate().isNotEmpty;
      }),
      isEmpty,
    );
    await tester.pumpAndSettle();
  });

  group('screenshots', () {
    setUpAll(loadMacFonts);

    for (final (choice, mode) in [
      (_kiwi, MyDataMode.light),
      (_kiwi, MyDataMode.dark),
      (_plum, MyDataMode.light),
      (_plum, MyDataMode.dark),
    ]) {
      final name = '${choice.theme.replaceFirst('mydata.', '')}-${choice.palette}-${mode.name}';
      testWidgets('the gallery over myContacts ($name)', (tester) async {
        painting.debugDisableShadows = false;
        try {
          await _open(tester, _Window(stored: choice, mode: mode));
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/theme_gallery.$name.png'));
        } finally {
          painting.debugDisableShadows = true;
        }
      });
    }

    for (final mode in [MyDataMode.light, MyDataMode.dark]) {
      macTestWidgets('the gallery in the Mac window, on System (${mode.name})', (tester) async {
        MacLook.debugOverride = true;
        addTearDown(() => MacLook.debugOverride = null);
        tester.view.physicalSize = const Size(1100, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        painting.debugDisableShadows = false;
        try {
          await tester.pumpWidget(
            MacShell(
              theme: MyDataTheme(mode: mode),
              builder: (context, light, dark, themeMode) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: light,
                darkTheme: dark,
                themeMode: themeMode,
                builder: MacShell.content,
                home: Builder(
                  builder: (context) => Material(
                    color: context.colors.bg,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Button(
                        label: 'Open',
                        onPressed: () => showThemeGallery(
                          context: context,
                          apps: [
                            ThemeGalleryApp(
                              id: 'mycalendar',
                              name: 'myCalendar',
                              scene: ThemePreviewScenes.calendar,
                              current: ThemeChoice.system,
                            ),
                          ],
                          windowApp: 'mycalendar',
                          onPreview: (_) {},
                          onUse: (_, _) async {},
                          onUseEverywhere: (_) async => () async => true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.text(ThemeGallery.systemNote(mac: true)), findsOneWidget);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/theme_gallery.mac-system-${mode.name}.png'),
          );
        } finally {
          painting.debugDisableShadows = true;
        }
      });
    }
  });
}
