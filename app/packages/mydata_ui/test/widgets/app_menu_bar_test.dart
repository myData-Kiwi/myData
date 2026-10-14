import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The menus the app last sent to macOS over the 'flutter/menu' channel.
List<Map<Object?, Object?>> _sent = [];

void _captureMenus(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.menu, (call) async {
    if (call.method == 'Menu.setMenus') {
      _sent = [for (final m in ((call.arguments as Map)['0'] as List)) m as Map<Object?, Object?>];
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.menu, null));
}

/// The items of the top-level menu [menu], flattened, as (label, enabled, id).
List<({String label, bool enabled, int id})> _items(String menu) {
  final top = _sent.firstWhere((m) => m['label'] == menu);
  return [
    for (final c in (top['children'] as List).cast<Map<Object?, Object?>>())
      if (c['isDivider'] != true)
        (label: (c['label'] ?? 'provided:${c['platformProvidedMenu']}') as String, enabled: c['enabled'] == true, id: c['id'] as int),
  ];
}

Future<void> _select(WidgetTester tester, int id) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.menu.name, SystemChannels.menu.codec.encodeMethodCall(MethodCall('Menu.selectedCallback', id)), (_) {});
  await tester.pump();
}

void main() {
  test('title case for the menu bar', () {
    expect(menuTitleCase('New contact'), 'New Contact');
    expect(menuTitleCase('Delete 3 contacts…'), 'Delete 3 Contacts…');
    expect(menuTitleCase('Go to today'), 'Go to Today');
    expect(menuTitleCase('Bring all to front'), 'Bring All to Front');
    expect(menuTitleCase('Quit myContacts'), 'Quit myContacts');
    expect(menuTitleCase('Edit calendar…'), 'Edit Calendar…');
  });

  test('shortcuts as each platform writes them', () {
    expect(AppMenuBar.newShortcut.label(TargetPlatform.macOS), '⌘N');
    expect(AppMenuBar.newShortcut.label(TargetPlatform.windows), 'Ctrl+N');
    expect(const AppShortcut(LogicalKeyboardKey.keyN, option: true).label(TargetPlatform.macOS), '⌥⌘N');
    expect(AppMenuBar.redoShortcut.label(TargetPlatform.macOS), '⇧⌘Z');
    expect(AppMenuBar.deleteLabel(TargetPlatform.macOS), '⌘⌫');
    expect(AppMenuBar.deleteLabel(TargetPlatform.windows), 'Delete');
    expect(AppMenuBar.deleteLabel(TargetPlatform.linux), 'Delete');
    expect(AppMenuBar.sectionShortcut(2).label(TargetPlatform.macOS), '⌘2');
    expect(AppMenuBar.listDeleteActivator(TargetPlatform.windows).trigger, LogicalKeyboardKey.delete);
    expect(AppMenuBar.listDeleteActivator(TargetPlatform.windows).control, isFalse);
  });

  test('Undo and Redo name the action', () {
    expect(AppMenuBar.undoTitle('Delete Contact'), 'Undo Delete Contact');
    expect(AppMenuBar.undoTitle(null), 'Undo');
    expect(AppMenuBar.undoTitle('Delete Contact', typing: true), 'Undo Typing');
    expect(AppMenuBar.redoTitle('Edit Event'), 'Redo Edit Event');
  });

  group('macOS', () {
    Widget app({
      String? undo,
      VoidCallback? onUndo,
      VoidCallback? onNew,
      VoidCallback? onDelete,
      VoidCallback? onSettings,
      Widget child = const SizedBox(),
    }) =>
        AppMenuBar(
          appName: 'myContacts',
          platform: TargetPlatform.macOS,
          undoAction: undo,
          onUndo: onUndo,
          onSettings: onSettings,
          file: [
            AppMenuItem(title: 'New Contact', shortcut: AppMenuBar.newShortcut, onSelected: onNew),
            const AppMenuItem(title: 'Import…'),
            const AppMenuItem(title: 'Save', shortcut: AppMenuBar.saveShortcut),
          ],
          edit: [
            const AppMenuItem(title: 'Edit Contact', shortcut: AppMenuBar.editShortcut),
            AppMenuItem.delete(title: 'Delete Contact', onSelected: onDelete),
          ],
          view: [AppMenuItem(title: 'Contacts', shortcut: AppMenuBar.sectionShortcut(1), onSelected: () {})],
          child: child,
        );

    testWidgets('the menus in order, with macOS’s own items', (tester) async {
      _captureMenus(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, app()));
      expect(_sent.map((m) => m['label']), ['myContacts', 'File', 'Edit', 'View', 'Window']);
      expect(_items('File').map((i) => i.label), ['New Contact', 'Import…', 'Save', 'Close Window']);
      expect(_items('Edit').map((i) => i.label),
          ['Undo', 'Redo', 'Cut', 'Copy', 'Paste', 'Select All', 'Edit Contact', 'Delete Contact']);
      // Disabled, never hidden.
      expect(_items('File').firstWhere((i) => i.label == 'Import…').enabled, isFalse);
      expect(_items('Edit').firstWhere((i) => i.label == 'Undo').enabled, isFalse);
      expect(_items('myContacts').map((i) => i.label).where((l) => l.startsWith('Settings')), isEmpty,
          reason: 'only myData has Settings…');
      expect(_items('View').last.label, startsWith('provided:'), reason: 'Enter Full Screen is macOS’s own');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('myData adds Settings… ⌘,', (tester) async {
      _captureMenus(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, app(onSettings: () {})));
      expect(_items('myContacts').map((i) => i.label), contains('Settings…'));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Undo names the action and runs it; items call back when chosen', (tester) async {
      _captureMenus(tester);
      var undone = 0, created = 0, deleted = 0;
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          app(undo: 'Delete Contact', onUndo: () => undone++, onNew: () => created++, onDelete: () => deleted++)));
      final undo = _items('Edit').first;
      expect(undo.label, 'Undo Delete Contact');
      expect(undo.enabled, isTrue);
      await _select(tester, undo.id);
      await _select(tester, _items('File').first.id);
      await _select(tester, _items('Edit').firstWhere((i) => i.label == 'Delete Contact').id);
      expect((undone, created, deleted), (1, 1, 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('text comes first: Undo Typing, and Delete is disabled while a field has focus', (tester) async {
      _captureMenus(tester);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          app(undo: 'Delete Contact', onUndo: () {}, onDelete: () {}, child: TextField(controller: controller))));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(_items('Edit').first.label, 'Undo Typing');
      expect(_items('Edit').firstWhere((i) => i.label == 'Delete Contact').enabled, isFalse);
      expect(_items('Edit').firstWhere((i) => i.label == 'Select All').enabled, isTrue);
      // Select All acts on the field's text.
      await tester.enterText(find.byType(TextField), 'Ava Fictional');
      await _select(tester, _items('Edit').firstWhere((i) => i.label == 'Select All').id);
      expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 13));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('Windows and Linux', () {
    testWidgets('the same keys with Control; Undo gives way to a focused text field', (tester) async {
      var created = 0, undone = 0, deleted = 0;
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          AppMenuBar(
            appName: 'myContacts',
            platform: TargetPlatform.windows,
            undoAction: 'Delete Contact',
            onUndo: () => undone++,
            file: [AppMenuItem(title: 'New Contact', shortcut: AppMenuBar.newShortcut, onSelected: () => created++)],
            edit: [AppMenuItem.delete(title: 'Delete Contact', onSelected: () => deleted++)],
            child: Column(children: [
              Button(label: 'Somewhere', onPressed: () {}),
              const TextField(),
            ]),
          )));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      expect((created, undone, deleted), (1, 1, 0), reason: 'Delete is the list’s own key there');
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      expect(undone, 1, reason: 'Ctrl+Z undoes the typing in the field');
    });

    testWidgets('phones have no menu bar and no window keys', (tester) async {
      var created = 0;
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          AppMenuBar(
            appName: 'myContacts',
            platform: TargetPlatform.iOS,
            file: [AppMenuItem(title: 'New Contact', shortcut: AppMenuBar.newShortcut, onSelected: () => created++)],
            child: Button(label: 'Somewhere', onPressed: () {}),
          )));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      expect(created, 0);
    });
  });

  test('AppMenuCommands: the newest claim that can act runs; a released one does not', () {
    final commands = AppMenuCommands();
    addTearDown(commands.dispose);
    final ran = <String>[];
    final toast = Object(), other = Object();
    expect(commands.runUndo(), isFalse);
    commands.claimUndo(toast, () {
      ran.add('toast');
      return true;
    });
    commands.claimUndo(other, () => false);
    expect(commands.hasUndo, isTrue);
    expect(commands.runUndo(), isTrue, reason: 'the newest cannot act now, so the one before runs');
    expect(ran, ['toast']);
    commands.releaseUndo(toast);
    expect(commands.runUndo(), isFalse);
    commands.releaseUndo(other);
    expect(commands.hasUndo, isFalse);
    var saves = 0;
    commands.claimSave(toast, () {
      saves++;
      return true;
    });
    expect(commands.runSave(), isTrue);
    expect(saves, 1);
  });

  testWidgets('Windows and Linux: Ctrl+Z is the app\'s undo once, unless a claim takes it', (tester) async {
    var undos = 0;
    await tester.pumpWidget(themedFrame(
      themeMatrix.first,
      AppMenuBar(
        appName: 'myContacts',
        undoAction: 'Delete Contact',
        onUndo: () => undos++,
        child: Builder(
          builder: (context) => Button(
            label: 'Claim',
            onPressed: () => AppMenuBar.commandsOf(context)!.claimUndo(context, () => true),
          ),
        ),
      ),
    ));
    Focus.of(tester.element(find.text('Claim'))).requestFocus();
    await tester.pump();
    Future<void> ctrlZ() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    await ctrlZ();
    expect(undos, 1);
    await tester.tap(find.text('Claim'));
    await tester.pump();
    await ctrlZ();
    expect(undos, 1, reason: 'the claim ran in its place');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
