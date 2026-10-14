import 'dart:async';
import 'dart:ui' show SemanticsAction, SemanticsRole, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _reason = 'Contacts from this Mac are changed in Contacts.';

List<MenuEntry> _contactItems(List<String> log, {bool followed = false}) => [
      MenuItem(
        label: 'Edit contact',
        icon: Icons.edit_outlined,
        shortcut: const SingleActivator(LogicalKeyboardKey.keyE, control: true),
        enabled: !followed,
        disabledReason: followed ? _reason : null,
        onSelected: () => log.add('edit'),
      ),
      MenuItem(label: 'Add to group…', icon: Icons.group_add_outlined, onSelected: () => log.add('group')),
      const MenuSeparator(),
      MenuItem(
        label: 'Delete contact',
        icon: Icons.delete_outline_rounded,
        shortcut: const SingleActivator(LogicalKeyboardKey.delete),
        destructive: true,
        enabled: !followed,
        onSelected: () => log.add('delete'),
      ),
    ];

/// A row to right-click, and a More actions button at the end.
Widget _page(List<String> log, {bool followed = false, FocusNode? rowNode}) => Builder(
      builder: (context) => SizedBox(
        width: 480,
        child: Row(children: [
          Expanded(
            child: ContextMenuRegion(
              entries: () => _contactItems(log, followed: followed),
              child: Pressable(
                key: const Key('row'),
                focusNode: rowNode,
                onPressed: () => log.add('row'),
                borderRadius: MyDataRadii.sm,
                semanticLabel: 'Ava Fictional',
                child: Container(
                  height: MyDataSize.rowHeight,
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s4),
                  color: context.colors.surface,
                  child: Text('Ava Fictional', style: MyDataType.body.copyWith(color: context.colors.ink)),
                ),
              ),
            ),
          ),
          MoreActionsButton(key: const Key('more'), entries: () => _contactItems(log, followed: followed)),
        ]),
      ),
    );

void _keyboardMode(WidgetTester tester) {
  tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
}

Finder _item(String label) => find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first;

void main() {
  // A context menu opened from the keyboard (Shift-F10), moved to the destructive item: its `danger-soft`
  // fill and the `ink` ring inside it.
  goldenMatrix('menu_context', () => _page([]), size: const Size(640, 320), before: (tester) async {
    _keyboardMode(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
  });

  // An overflow menu under its button, end edges lined up; Edit and Delete disabled with one reason; the
  // pointer over "Add to group…".
  goldenMatrix('menu_overflow', () => _page([], followed: true), size: const Size(640, 320), before: (tester) async {
    _keyboardMode(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(find.byKey(const Key('more'))));
    await tester.pump();
    await mouse.down(tester.getCenter(find.byKey(const Key('more'))));
    await mouse.up();
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(find.text('Add to group…')));
    await tester.pumpAndSettle();
  });

  group('Menu', () {
    testWidgets('a right-click opens it at the pointer and does not press the row', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page(log)));
      final at = tester.getCenter(find.byKey(const Key('row')));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await mouse.addPointer(location: at);
      await mouse.down(at);
      await mouse.up();
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsOneWidget);
      expect(log, isEmpty);
      final panel = find.ancestor(of: find.text('Edit contact'), matching: find.byType(IntrinsicWidth));
      expect(tester.getTopLeft(panel) - const Offset(MyDataSpace.s1, MyDataSpace.s1), at);
    });

    testWidgets('opened from the keyboard: the first enabled item has focus; arrows go round', (tester) async {
      final log = <String>[];
      final row = FocusNode();
      addTearDown(row.dispose);
      _keyboardMode(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page(log, rowNode: row)));
      row.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      String focused() => (FocusManager.instance.primaryFocus!.debugLabel ?? '').replaceFirst('Menu item ', '');
      expect(focused(), 'Edit contact');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(focused(), 'Delete contact', reason: 'Up from the first goes round to the last');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(focused(), 'Edit contact');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(focused(), 'Delete contact');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      expect(focused(), 'Edit contact');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(focused(), 'Add to group…', reason: 'typing moves to the next item starting with it');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsNothing, reason: 'it closes at once');
      expect(log, ['group']);
      expect(row.hasFocus, isTrue, reason: 'focus returns to what opened it');
    });

    testWidgets('screen readers hear which item has focus as the arrows move', (tester) async {
      final handle = tester.ensureSemantics();
      final row = FocusNode();
      addTearDown(row.dispose);
      _keyboardMode(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page([], rowNode: row)));
      row.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();
      Tristate focusOf(String label) => tester.getSemantics(find.text(label)).flagsCollection.isFocused;
      expect(focusOf('Edit contact'), Tristate.isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusOf('Edit contact'), Tristate.isFalse);
      expect(focusOf('Add to group…'), Tristate.isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('disabled items are stopped on but do nothing; the reason is under the first', (tester) async {
      final log = <String>[];
      final row = FocusNode();
      addTearDown(row.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page(log, followed: true, rowNode: row)));
      row.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text(_reason), findsOneWidget);
      expect(tester.getSize(_item('Edit contact')).height, MyDataSize.rowHeight);
      expect(tester.getSize(_item('Add to group…')).height, MyDataSize.controlHeight);
      // The first enabled item has focus; Up reaches the disabled Edit.
      expect(FocusManager.instance.primaryFocus!.debugLabel, 'Menu item Add to group…');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(FocusManager.instance.primaryFocus!.debugLabel, 'Menu item Edit contact');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(find.text('Edit contact'), findsOneWidget, reason: 'still open');
      await tester.tap(find.text('Delete contact'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      // The reason keeps full ink-muted; the label fades.
      final c = tester.element(find.text(_reason)).colors;
      expect(tester.widget<Text>(find.text(_reason)).style!.color, c.inkMuted);
      expect(tester.widgetList<Opacity>(find.ancestor(of: find.text(_reason), matching: find.byType(Opacity))).map((o) => o.opacity),
          everyElement(1.0));
      expect(
          tester.widget<Opacity>(find.ancestor(of: find.text('Edit contact'), matching: find.byType(Opacity)).first).opacity,
          Pressable.disabledOpacity);
    });

    testWidgets('Escape and Tab close it; a click outside closes it and reaches nothing', (tester) async {
      final log = <String>[];
      final row = FocusNode();
      addTearDown(row.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page(log, rowNode: row)));
      for (final key in [LogicalKeyboardKey.escape, LogicalKeyboardKey.tab]) {
        row.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
        await tester.pumpAndSettle();
        expect(find.text('Edit contact'), findsOneWidget);
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(find.text('Edit contact'), findsNothing, reason: '$key closes it');
        expect(row.hasFocus, isTrue);
      }
      await tester.tap(find.byKey(const Key('more')));
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byKey(const Key('row'))));
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsNothing);
      expect(log, isEmpty, reason: 'the click that closes the menu does not press the row');
    });

    testWidgets('a click on an item runs it after the menu has closed', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page(log)));
      await tester.tap(find.byKey(const Key('more')));
      await tester.pumpAndSettle();
      // Opened with the pointer: no item has focus yet.
      expect(FocusManager.instance.primaryFocus!.debugLabel, 'Menu');
      await tester.tap(find.text('Delete contact'));
      await tester.pump();
      expect(find.text('Delete contact'), findsNothing);
      expect(log, ['delete']);
    });

    testWidgets('the overflow menu sits space-1 under its button, end edges lined up', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page([])));
      await tester.tap(find.byKey(const Key('more')));
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byKey(const Key('more')));
      final panel = tester.getRect(find.ancestor(of: find.text('Edit contact'), matching: find.byType(Container)).last);
      expect(panel.right, button.right);
      expect(panel.top, button.bottom + MyDataSpace.s1);
    });

    testWidgets('it flips to stay space-2 inside the window', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const SizedBox()));
      unawaited(Menu.showAt(tester.element(find.byType(SizedBox).first),
          position: const Offset(390, 290), entries: _contactItems([])));
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.ancestor(of: find.text('Edit contact'), matching: find.byType(Container)).last);
      expect(panel.right, 390);
      expect(panel.bottom, 290);
      expect(panel.left, greaterThanOrEqualTo(MyDataSpace.s2));
    });

    testWidgets('items: control-height, the icon space kept, the shortcut written, destructive in danger', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page([])));
      await tester.tap(find.byKey(const Key('more')));
      await tester.pumpAndSettle();
      expect(tester.getSize(_item('Edit contact')).height, MyDataSize.controlHeight);
      expect(find.text('Ctrl+E'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      final c = tester.element(find.text('Delete contact')).colors;
      expect(tester.widget<Text>(find.text('Delete contact')).style!.color, c.danger);
      expect(tester.widget<Text>(find.text('Edit contact')).style!.color, c.ink);
      // Labels line up: every item starts its label at the same x.
      expect(tester.getTopLeft(find.text('Edit contact')).dx, tester.getTopLeft(find.text('Delete contact')).dx);
    });

    testWidgets('semantics: a menu of items, with shortcut and reason in the hint', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page([], followed: true)));
      await tester.tap(find.byKey(const Key('more')));
      await tester.pumpAndSettle();
      final edit = tester.getSemantics(find.ancestor(of: find.text('Edit contact'), matching: find.byType(Semantics)).first);
      expect(edit.role, SemanticsRole.menuItem);
      expect(edit.label, 'Edit contact');
      expect(edit.hint, 'Control E, $_reason');
      expect(edit.flagsCollection.isEnabled, Tristate.isFalse);
      final group = tester.getSemantics(find.ancestor(of: find.text('Add to group…'), matching: find.byType(Semantics)).first);
      expect(group.flagsCollection.isEnabled, Tristate.isTrue);
      expect(group.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('the context region offers each enabled item as a screen reader action', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _page(log)));
      final node = tester.getSemantics(find.byKey(const Key('row')));
      final actions = node.getSemanticsData().customSemanticsActionIds!
          .map((id) => CustomSemanticsAction.getAction(id)!.label)
          .toList();
      expect(actions, ['Edit contact', 'Add to group…', 'Delete contact']);
      handle.dispose();
    });

    testWidgets('More actions: Down opens it from the keyboard; it is announced as expanded', (tester) async {
      final handle = tester.ensureSemantics();
      final more = FocusNode();
      addTearDown(more.dispose);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Builder(
              builder: (_) => MoreActionsButton(focusNode: more, entries: () => _contactItems([])))));
      final button = find.descendant(of: find.byType(MoreActionsButton), matching: find.byType(Pressable));
      expect(tester.getSemantics(button).flagsCollection.isExpanded, Tristate.isFalse);
      more.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus!.debugLabel, 'Menu item Edit contact');
      // The window behind the menu is hidden from screen readers; the button says it is expanded.
      expect(tester.widget<MyDataIconButton>(find.byType(MyDataIconButton)).expanded, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(more.hasFocus, isTrue);
      handle.dispose();
    });
  });
}
