// ContactList with several rows selected (design/components/MultiSelect) and its rows' Menu
// (design/components/Menu). Invented people only: example.com addresses.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

ContactListEntry _entry(String id, String name, {String organisation = '', List<String> emails = const []}) =>
    ContactListEntry(
      id: id,
      name: name,
      organisation: organisation,
      emails: emails,
      caption: contactCaption(name: name, organisation: organisation, emails: emails),
    );

List<ContactListEntry> _people() => [
      _entry('a1', 'Aaron Example', emails: ['aaron@example.com']),
      _entry('a2', 'Ava Fictional', organisation: 'Example Labs'),
      _entry('a3', 'Ayo Sample'),
      _entry('b1', 'Ben Testwell', emails: ['ben@example.com']),
      _entry('e1', 'Eli Sample'),
      _entry('e2', 'Example Labs', organisation: 'Example Labs'),
    ];

/// The list as myContacts holds it: the selection, the one open row, a Menu, Return and Delete.
class _Holder extends StatefulWidget {
  const _Holder({
    required this.selection,
    this.opened,
    this.menus,
    this.returned,
    this.deletes,
    this.focusNode,
    this.search,
  });

  final MultiSelectController<String> selection;
  final List<String>? opened;
  final List<String>? menus;
  final List<String>? returned;
  final List<int>? deletes;
  final FocusNode? focusNode;
  final TextEditingController? search;

  @override
  State<_Holder> createState() => _HolderState();
}

class _HolderState extends State<_Holder> {
  String? open = 'a1';

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_follow);
  }

  void _follow() {
    final s = widget.selection;
    setState(() => open = s.count == 1 ? s.selected.first : null);
  }

  @override
  void dispose() {
    widget.selection.removeListener(_follow);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 340,
        height: 600,
        child: ContactList(
          contacts: _people(),
          selectedId: open,
          selection: widget.selection,
          focusNode: widget.focusNode,
          searchController: widget.search,
          onOpen: (id) {
            widget.opened?.add(id);
            setState(() => open = id);
          },
          menuFor: (id) => [
            MenuItem(label: 'Edit contact', onSelected: () => widget.menus?.add('edit $id')),
            const MenuSeparator(),
            MenuItem(
                label: widget.selection.count > 1 && widget.selection.isSelected(id)
                    ? 'Delete ${widget.selection.count} contacts…'
                    : 'Delete contact',
                destructive: true,
                onSelected: () => widget.menus?.add('delete $id')),
          ],
          onReturn: (id) => widget.returned?.add(id),
          onDelete: () => widget.deletes?.add(widget.selection.count),
        ),
      );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, child));
  await tester.pump();
}

Finder _row(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(MouseRegion)).first;

Future<void> _clickWith(WidgetTester tester, String name, LogicalKeyboardKey modifier) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.tap(find.text(name));
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key, {LogicalKeyboardKey? with_}) async {
  if (with_ != null) await tester.sendKeyDownEvent(with_);
  await tester.sendKeyEvent(key);
  if (with_ != null) await tester.sendKeyUpEvent(with_);
  await tester.pump();
}

late FocusNode _goldenFocus;
late MultiSelectController<String> _goldenSelection;

void main() {
  // Aaron and Ava selected together (one ring around the run, no divider between them), Eli on his own,
  // and keyboard focus on Eli: the focus ring inside his selection ring.
  goldenMatrix(
    'contact_list_multi',
    () {
      _goldenFocus = FocusNode(debugLabel: 'golden list');
      _goldenSelection = MultiSelectController<String>();
      return _Holder(selection: _goldenSelection, focusNode: _goldenFocus);
    },
    size: const Size(620, 648),
    before: (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.pump();
      _goldenSelection
        ..select('a1')
        ..toggle('a2')
        ..toggle('e1');
      _goldenFocus.requestFocus();
      await tester.pump();
    },
  );

  group('ContactList with several selected', () {
    testWidgets('a click opens one; Control-click adds and removes; Shift-click takes the range across groups',
        (tester) async {
      final selection = MultiSelectController<String>();
      final opened = <String>[];
      await _pump(tester, _Holder(selection: selection, opened: opened));
      await tester.tap(find.text('Ava Fictional'));
      await tester.pump();
      expect(selection.selected, ['a2']);
      expect(opened, ['a2']);
      // Ctrl on Windows, Linux and the test's platform; ⌘ on macOS.
      await _clickWith(tester, 'Eli Sample', LogicalKeyboardKey.controlLeft);
      expect(selection.selected, ['a2', 'e1']);
      await _clickWith(tester, 'Eli Sample', LogicalKeyboardKey.controlLeft);
      expect(selection.selected, ['a2']);
      // The Control-click made Eli the anchor: Shift-click takes Eli up to Ben, keeping Ava.
      await _clickWith(tester, 'Ben Testwell', LogicalKeyboardKey.shiftLeft);
      expect(selection.selected, ['a2', 'b1', 'e1']);
      await tester.tap(find.text('Aaron Example'));
      await _clickWith(tester, 'Ben Testwell', LogicalKeyboardKey.shiftLeft);
      expect(selection.selected, ['a1', 'a2', 'a3', 'b1'], reason: 'across the letter groups');
      expect(opened, ['a2', 'a2', 'a1'], reason: 'one row left after a Control-click is the one open');
      await tester.tap(find.text('Example Labs').last);
      await tester.pump();
      expect(selection.selected, ['e2']);
    });

    testWidgets('keys: Shift-Down extends, Alt-Down moves the focus only, Space adds, Ctrl-A, Escape', (tester) async {
      final selection = MultiSelectController<String>();
      final list = FocusNode();
      addTearDown(list.dispose);
      final opened = <String>[];
      await _pump(tester, _Holder(selection: selection, focusNode: list, opened: opened));
      await tester.tap(find.text('Aaron Example'));
      await tester.pump();
      expect(list.hasFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown, with_: LogicalKeyboardKey.shiftLeft);
      expect(selection.selected, ['a1', 'a2']);
      await _key(tester, LogicalKeyboardKey.arrowDown, with_: LogicalKeyboardKey.altLeft);
      await _key(tester, LogicalKeyboardKey.arrowDown, with_: LogicalKeyboardKey.altLeft);
      expect(selection.selected, ['a1', 'a2']);
      expect(selection.focused, 'b1');
      await _key(tester, LogicalKeyboardKey.space);
      expect(selection.selected, ['a1', 'a2', 'b1']);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(selection.selected, ['b1'], reason: 'Escape goes back to the focused row');
      expect(opened.last, 'b1');
      await _key(tester, LogicalKeyboardKey.keyA, with_: LogicalKeyboardKey.controlLeft);
      expect(selection.count, 6);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(selection.selected, ['e1'], reason: 'a plain arrow selects one row');
      expect(opened.last, 'e1');
    });

    testWidgets('a run shares one ring with no divider; a row a search hides leaves the selection', (tester) async {
      final selection = MultiSelectController<String>();
      final search = TextEditingController();
      addTearDown(search.dispose);
      await _pump(tester, _Holder(selection: selection, search: search));
      await tester.tap(find.text('Aaron Example'));
      await _clickWith(tester, 'Ava Fictional', LogicalKeyboardKey.controlLeft);
      final c = themeMatrix.first.data.extension<MyDataColors>()!;
      // Ava's divider (between her and Aaron) takes the selection's fill, not the line.
      final dividers = tester.widgetList<EdgeRule>(find.descendant(of: find.byType(ContactList), matching: find.byType(EdgeRule)));
      expect(dividers.where((d) => d.colour == c.accentSoft), hasLength(1));
      search.text = 'Aaron';
      await tester.pump();
      await tester.pump();
      expect(selection.selected, ['a1']);
      search.clear();
      await tester.pump();
      await tester.pump();
      expect(selection.selected, ['a1'], reason: 'clearing the search does not bring the row back');
    });

    testWidgets('the Menu opens on a right-click and from the keyboard; Return and Delete go to the holder',
        (tester) async {
      final selection = MultiSelectController<String>();
      final list = FocusNode();
      addTearDown(list.dispose);
      final menus = <String>[];
      final returned = <String>[];
      final deletes = <int>[];
      await _pump(
          tester, _Holder(selection: selection, focusNode: list, menus: menus, returned: returned, deletes: deletes));
      await tester.tap(find.text('Aaron Example'));
      await _clickWith(tester, 'Ava Fictional', LogicalKeyboardKey.controlLeft);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await mouse.down(tester.getCenter(find.text('Ava Fictional')));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 contacts…'), findsOneWidget);
      expect(selection.selected, ['a1', 'a2'], reason: 'the right-click does not move the selection');
      await tester.tap(find.text('Delete 2 contacts…'));
      await tester.pumpAndSettle();
      expect(menus, ['delete a2']);

      list.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.f10, with_: LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsNothing);

      await tester.tap(find.text('Ben Testwell'));
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.enter);
      expect(returned, ['b1']);
      await _key(tester, LogicalKeyboardKey.delete);
      expect(deletes, [1]);
    });

    testWidgets('an action beside the search field, after it in the Tab order', (tester) async {
      final search = FocusNode();
      addTearDown(search.dispose);
      await _pump(
          tester,
          SizedBox(
            width: 340,
            height: 500,
            child: ContactList(
              contacts: _people(),
              selectedId: 'a1',
              onOpen: (_) {},
              searchFocusNode: search,
              searchTrailing: MyDataIconButton(icon: MyDataIcon.add, label: 'New contact', onPressed: () {}),
            ),
          ));
      final field = tester.getRect(find.byType(MyDataSearchField));
      final button = tester.getRect(find.byType(MyDataIconButton));
      expect(button.left - field.right, ContactList.searchTrailingGap(kiwiLook));
      expect(button.center.dy, closeTo(field.center.dy, 1));
      search.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.tab);
      expect(
          FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<MyDataIconButton>(), isNotNull);
    });

    testWidgets('each enabled Menu item is a custom action of its row', (tester) async {
      final handle = tester.ensureSemantics();
      final selection = MultiSelectController<String>();
      final menus = <String>[];
      await _pump(tester, _Holder(selection: selection, menus: menus));
      final node = tester.getSemantics(_row('Ben Testwell'));
      expect(node.getSemanticsData().customSemanticsActionIds, hasLength(2));
      handle.dispose();
    });
  });
}
