import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

// Invented people and places only: example.com addresses and the UK's reserved drama numbers (07700 900xxx).

/// A made-up portrait, drawn like the preview's: a head and shoulders on cream. Test data, not a token.
late ui.Image _portrait;

Future<ui.Image> _drawPortrait() {
  const size = 96.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = const Color(0xFFFBF7EC));
  final skin = Paint()..color = const Color(0xFF6B4F35);
  canvas.drawCircle(const Offset(48, 38), 17, skin);
  canvas.drawPath(
    Path()
      ..moveTo(14, 96)
      ..cubicTo(17, 76, 31, 65, 48, 65)
      ..cubicTo(65, 65, 79, 76, 82, 96)
      ..close(),
    skin,
  );
  return recorder.endRecording().toImage(size.toInt(), size.toInt());
}

/// The portrait, already in memory, so it shows at once.
class _Portrait extends ImageProvider<_Portrait> {
  const _Portrait();

  @override
  Future<_Portrait> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Portrait key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: _portrait.clone())));
}

ContactListEntry _entry(
  String id,
  String name, {
  String given = '',
  String family = '',
  String organisation = '',
  List<String> emails = const [],
  List<String> phones = const [],
  bool photo = false,
  String? letter,
}) => ContactListEntry(
  id: id,
  name: name,
  givenName: given,
  familyName: family,
  organisation: organisation,
  emails: emails,
  phones: phones,
  caption: contactCaption(name: name, organisation: organisation, emails: emails, phones: phones),
  letter: letter,
  photo: photo ? const _Portrait() : null,
);

/// The preview's contacts, plus one with an accent, in the locale's order (the "+44" card first, as a
/// code-point sort would give it; the list still puts "#" last).
List<ContactListEntry> _people({bool photo = true}) => [
  _entry('n1', '+44 7700 900456', phones: ['+44 7700 900456']),
  _entry('a1', 'Aaron Example', given: 'Aaron', family: 'Example', phones: ['+44 7700 900123']),
  _entry(
    'a2',
    'Ava Fictional',
    given: 'Ava',
    family: 'Fictional',
    organisation: 'Example Labs',
    emails: ['ava@example.com'],
    photo: photo,
  ),
  _entry('e1', 'Eli Sample', given: 'Eli', family: 'Sample'),
  _entry('e2', 'Élodie Placeholder', given: 'Élodie', family: 'Placeholder', emails: ['elodie@example.com']),
  _entry('e3', 'Example Labs', organisation: 'Example Labs', emails: ['info@example.com']),
];

/// [count] invented people for scrolling, in order: "Person 001 Example" and on.
List<ContactListEntry> _many(int count) => [
  for (var i = 1; i <= count; i++)
    _entry('p$i', 'Person ${i.toString().padLeft(3, '0')} Example', emails: ['person$i@example.com']),
];

/// Holds the selection as an app does: [ContactList.onOpen] selects the contact.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.contacts,
    this.selected,
    this.opened,
    this.focusNode,
    this.searchFocusNode,
    this.search,
    this.height = 520,
    this.after = false,
  });

  final List<ContactListEntry> contacts;
  final String? selected;
  final List<String>? opened;
  final FocusNode? focusNode;
  final FocusNode? searchFocusNode;
  final TextEditingController? search;
  final double height;

  /// A focusable button after the list, standing in for the contact pane.
  final bool after;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String? _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    final list = SizedBox(
      width: 340,
      height: widget.height,
      child: ContactList(
        contacts: widget.contacts,
        selectedId: _selected,
        searchController: widget.search,
        focusNode: widget.focusNode,
        searchFocusNode: widget.searchFocusNode,
        onOpen: (id) {
          widget.opened?.add(id);
          setState(() => _selected = id);
        },
      ),
    );
    if (!widget.after) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        list,
        const SizedBox(width: 16),
        Button(label: 'In the contact pane', onPressed: () {}),
      ],
    );
  }
}

/// Renders [child] in a window [width] wide: 600 and over is the list pane, under 600 a phone.
Future<void> _pump(WidgetTester tester, Widget child, {double width = 900, double height = 700}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, child));
  await tester.pump();
}

Finder _row(String name) => find.ancestor(of: find.text(name), matching: find.byType(MouseRegion)).first;

SemanticsNode _rowNode(WidgetTester tester, String name) => tester.getSemantics(
  find
      .ancestor(
        of: find.text(name),
        matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true),
      )
      .first,
);

bool _hasFocus(FocusNode node) => node.hasPrimaryFocus;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// The two goldens' lists side by side, each in a pane with the screen padding inside it.
Widget _pair(Widget left, Widget right, {double height = 520}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(width: 360, height: height, child: left),
    const SizedBox(width: 24),
    SizedBox(width: 360, height: height, child: right),
  ],
);

late FocusNode _goldenFocus;

void main() {
  setUpAll(() async => _portrait = await _drawPortrait());

  // From 600px: the selected row (ring over accent-soft), the hover fill on Eli Sample (left), and, on the right,
  // keyboard focus on the selected row: the focus ring inside the selection ring.
  goldenMatrix(
    'contact_list_wide',
    () {
      _goldenFocus = FocusNode(debugLabel: 'golden list');
      return _pair(
        ContactList(
          contacts: _people(),
          selectedId: 'a2',
          onOpen: (_) {},
          padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s4),
        ),
        ContactList(
          contacts: _people(),
          selectedId: 'a2',
          onOpen: (_) {},
          focusNode: _goldenFocus,
          padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s4),
        ),
      );
    },
    size: const Size(792, 568),
    before: (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      _goldenFocus.requestFocus();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Eli Sample').first));
      addTearDown(mouse.removePointer);
      await tester.pump();
    },
  );

  // Under 600px: chevrons, no row selected, keyboard focus on a row.
  goldenMatrix(
    'contact_list_phone',
    () {
      _goldenFocus = FocusNode(debugLabel: 'golden list');
      return SizedBox(
        width: 342,
        height: 560,
        child: ContactList(contacts: _people(), selectedId: 'a2', onOpen: (_) {}, focusNode: _goldenFocus),
      );
    },
    size: const Size(390, 608),
    before: (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      _goldenFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    },
  );

  // Searching: on the left "ex" keeps the groups that have matches, and the selected contact (Eli Sample)
  // stays selected though it is not listed; on the right, nothing matches.
  goldenMatrix(
    'contact_list_search',
    () => _pair(
      ContactList(
        contacts: _people(),
        selectedId: 'e1',
        onOpen: (_) {},
        searchController: TextEditingController(text: 'ex'),
        padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s4),
      ),
      ContactList(
        contacts: _people(),
        selectedId: 'e1',
        onOpen: (_) {},
        searchController: TextEditingController(text: 'Zed'),
        padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s4),
      ),
      height: 400,
    ),
    size: const Size(792, 448),
  );

  group('search helpers', () {
    test('foldForSearch ignores case and accents', () {
      expect(foldForSearch('Élodie'), 'elodie');
      expect(foldForSearch('ÉLODIE'), 'elodie');
      expect(foldForSearch('élodie'), 'elodie', reason: 'decomposed accents are dropped too');
      expect(foldForSearch('Straße'), 'strasse');
      expect(foldForSearch('Łódź'), 'lodz');
      expect(foldForSearch('Ærøskøbing'), 'aeroskobing');
      expect(foldForSearch('Nguyễn'), 'nguyen');
      expect(foldForSearch('Çağlar Şahin'), 'caglar sahin');
      expect(foldForSearch('Άννα'), 'αννα');
      expect(foldForSearch('王小明'), '王小明');
      expect(foldForSearch('+44 7700 900123'), '+44 7700 900123');
    });

    test('contactGroupLetter: the host\'s sort_letter rule', () {
      // The same cases as the host's test_sort_letter (host/tests/test_app_views.py), so the two agree.
      const host = {
        'Ava Fictional': 'A',
        'émile Example': 'E',
        'Øyvind Example': 'Ø',
        'Ölaf': 'O',
        'zed': 'Z',
        '+1 202 555 0101': '#',
        '42 Example Street': '#',
        'someone@example.net': 'S',
        '': '#',
        '  ': '#',
        'Ψ Example': 'Ψ',
        'Ярослава': 'Я',
        '田中': '#',
        '김': '#',
        '😀 Fun': '#',
        'Æsa Example': 'Æ',
        'Łukasz Example': 'Ł',
        'Ёжик Example': 'Е',
        'Άννα Example': 'Α',
        'ßtest': 'ß',
        'ひかり Example': 'ひ',
        'ㄱ Example': '#',
      };
      for (final MapEntry(key: name, value: letter) in host.entries) {
        expect(contactGroupLetter(name), letter, reason: name);
      }
      expect(contactGroupLetter('  ava fictional'), 'A');
      expect(contactGroupLetter('Élodie Placeholder'), 'E', reason: 'decomposed accents too');
      expect(contactGroupLetter('(Example)'), '#');
      expect(contactOtherGroup, '#');
    });

    test('contactCaption: the organisation, else the first email or phone that is not the name', () {
      expect(
        contactCaption(name: 'Ava Fictional', organisation: 'Example Labs', emails: ['ava@example.com']),
        'Example Labs',
      );
      expect(
        contactCaption(name: 'Example Labs', organisation: 'example labs', emails: ['info@example.com']),
        'info@example.com',
        reason: 'the organisation is already the name',
      );
      expect(contactCaption(name: 'Aaron Example', phones: ['+44 7700 900123']), '+44 7700 900123');
      expect(
        contactCaption(name: 'Aaron Example', emails: ['aaron@example.com'], phones: ['+44 7700 900123']),
        'aaron@example.com',
      );
      expect(contactCaption(name: '+44 7700 900456', phones: ['+447700900456']), isNull);
      expect(
        contactCaption(name: 'ava@example.com', emails: ['AVA@example.com', 'ava.work@example.com']),
        'ava.work@example.com',
      );
      expect(contactCaption(name: 'Eli Sample'), isNull);
      expect(contactCaption(name: 'Eli Sample', organisation: '  ', emails: ['']), isNull);
      expect(
        contactCaption(name: 'Élodie Example', organisation: 'Elodie Example', emails: ['elodie@example.com']),
        'elodie@example.com',
        reason: 'the same ignoring accents',
      );
      expect(
        contactCaption(name: '+44 7700 900456', phones: ['+447700900456', '+44 7700 900789']),
        '+44 7700 900789',
        reason: 'the same digits are the name; another number is not',
      );
      expect(
        contactCaption(name: 'Example 2000', phones: ['2000']),
        '2000',
        reason: 'digits are compared only when the name is a phone number',
      );
    });

    test('contactCaption: the host\'s contact_caption cases', () {
      // The same cases as the host's caption tests (host/tests/test_app_views.py), so the two agree.
      const email = ['ava@example.com'];
      const phone = ['+1 202 555 0101'];
      expect(
        contactCaption(name: 'Ava Fictional', organisation: 'Example Labs', emails: email, phones: phone),
        'Example Labs',
      );
      expect(contactCaption(name: 'Ava Fictional', emails: email, phones: phone), 'ava@example.com');
      expect(contactCaption(name: 'Ava Fictional', phones: phone), '+1 202 555 0101');
      expect(
        contactCaption(name: 'Acme Plumbing (Example)', organisation: 'Acme Plumbing (Example)', phones: phone),
        '+1 202 555 0101',
      );
      expect(contactCaption(name: 'ava@example.com', emails: email), isNull);
      expect(contactCaption(name: 'ava@example.com', emails: email, phones: phone), '+1 202 555 0101');
      expect(contactCaption(name: 'Ava Fictional'), isNull);
      expect(contactCaption(name: '+1 202 555 0101', phones: ['+12025550101']), isNull);
      expect(contactCaption(name: 'AVA@example.com', emails: email), isNull);
    });

    test('contactMatches: names, organisations, emails and phones, ignoring case and accents', () {
      final ava = _people()[2];
      final elodie = _people()[4];
      final aaron = _people()[1];
      expect(contactMatches(ava, ''), isTrue);
      expect(contactMatches(ava, '   '), isTrue);
      expect(contactMatches(ava, 'ava'), isTrue);
      expect(contactMatches(ava, 'FICT'), isTrue);
      expect(contactMatches(ava, 'labs'), isTrue, reason: 'organisation');
      expect(contactMatches(ava, 'ava@example'), isTrue, reason: 'email');
      expect(contactMatches(ava, 'ava lab'), isTrue, reason: 'every word, anywhere');
      expect(contactMatches(ava, 'ava zed'), isFalse);
      expect(contactMatches(ava, 'fictionalexample'), isFalse, reason: 'a word never spans two fields');
      expect(contactMatches(elodie, 'elodie'), isTrue);
      expect(contactMatches(elodie, 'ÉLO'), isTrue);
      expect(contactMatches(_entry('x', 'Elodie Example'), 'élodie'), isTrue);
      expect(contactMatches(aaron, '7700 900123'), isTrue);
      expect(contactMatches(aaron, '07700900123'), isFalse, reason: 'digits must appear as given');
      expect(contactMatches(aaron, '7700900123'), isTrue, reason: 'spacing ignored');
      expect(contactMatches(aaron, '+44 (7700) 900-123'), isTrue);
      expect(contactMatches(aaron, '900456'), isFalse);
    });

    test('filterContacts keeps the order; groupContacts puts "#" last', () {
      final people = _people();
      expect(filterContacts(people, '').map((c) => c.id), people.map((c) => c.id));
      expect(filterContacts(people, 'example').map((c) => c.id), ['a1', 'a2', 'e2', 'e3']);
      final groups = groupContacts(people);
      expect(groups.map((g) => g.letter), ['A', 'E', '#']);
      expect(groups[1].contacts.map((c) => c.id), ['e1', 'e2', 'e3']);
      final given = groupContacts([_entry('x', 'Zed Example', letter: 'Z'), _entry('y', 'Ava Fictional', letter: 'Z')]);
      expect(given.single.letter, 'Z', reason: 'a letter given by the host is kept');
      expect(groupContacts(const []), isEmpty);
    });

    test('initialContactSelection: the last one opened if still there, else the first', () {
      final people = _people();
      expect(initialContactSelection(people, 'e3'), 'e3');
      expect(
        initialContactSelection(people, 'gone'),
        'a1',
        reason: 'the first row shown, not the "#" card given first',
      );
      expect(initialContactSelection(people, null), 'a1');
      expect(initialContactSelection([people.first], null), 'n1', reason: 'only "#" contacts: the first of them');
      expect(initialContactSelection(const [], 'e3'), isNull);
    });

    test('noMatches quotes the search', () {
      expect(ContactList.noMatches(' Ava '), 'No contacts match “Ava”.');
    });
  });

  group('ContactList', () {
    testWidgets('letter groups in order with "#" last; the letters are headings', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Harness(contacts: _people(), selected: 'a2'));
      final a = tester.getTopLeft(find.text('A')).dy;
      final e = tester.getTopLeft(find.text('E')).dy;
      final hash = tester.getTopLeft(find.text('#')).dy;
      expect(a < e && e < hash, isTrue);
      expect(tester.getTopLeft(find.text('+44 7700 900456')).dy, greaterThan(hash));
      expect(tester.getSemantics(find.text('E')).flagsCollection.isHeader, isTrue);
      semantics.dispose();
    });

    testWidgets('a row is one button named by the name and the caption; the selected row is marked', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _Harness(contacts: _people(), selected: 'a2'));
      final ava = _rowNode(tester, 'Ava Fictional');
      expect(ava.label, 'Ava Fictional, Example Labs');
      expect(ava.flagsCollection.isButton, isTrue);
      expect(ava.flagsCollection.isSelected, ui.Tristate.isTrue);
      final eli = _rowNode(tester, 'Eli Sample');
      expect(eli.label, 'Eli Sample', reason: 'no caption line');
      expect(eli.flagsCollection.isSelected, ui.Tristate.isFalse);
      expect(find.text('+44 7700 900123'), findsOneWidget, reason: "Aaron's caption is his phone");
      expect(findIcon(MyDataIcon.chevronRight), findsNothing, reason: 'nothing at the end from 600px');
      semantics.dispose();
    });

    testWidgets('the selected row has the ink ring over accent-soft', (tester) async {
      await _pump(tester, _Harness(contacts: _people(), selected: 'a2'));
      final c = MyDataTheme.data('kiwi', Brightness.light).extension<MyDataColors>()!;
      final rings = tester
          .widgetList<DecoratedBox>(find.descendant(of: _row('Ava Fictional'), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration.box)
          .toList();
      expect(rings.any((d) => d.color == c.accentSoft), isTrue);
      expect(rings.any((d) => d.border == Border.all(color: c.ink, width: ContactList.selectionRingWidth)), isTrue);
      final other = tester
          .widgetList<DecoratedBox>(find.descendant(of: _row('Eli Sample'), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration.box);
      expect(other.any((d) => d.border != null || d.color == c.accentSoft), isFalse);
    });

    // A theme that outlines its tint (Zen: its 2 px edge in the colour, as its sidebar draws it) rings the
    // selected row in `selection`, never in `ink`: an ink box was the strongest mark on a screen of hairlines.
    testWidgets('an outlined tint rings the selected row in selection (zen)', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          themedFrame(const ThemeCase('zen', Brightness.light), _Harness(contacts: _people(), selected: 'a2')));
      await tester.pump();
      final look = MyDataLook.of(tester.element(_row('Ava Fictional')));
      expect(look.variants.selection, SelectionStyle.tint);
      expect(SelectionPaint.of(look).outline, isNotNull);
      final rings = tester
          .widgetList<DecoratedBox>(find.descendant(of: _row('Ava Fictional'), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration.box)
          .toList();
      final ring = Border.all(color: look.colors.selection, width: ContactList.selectionRingWidth);
      expect(rings.any((d) => d.border == ring), isTrue);
      expect(look.colors.selection, look.colors.accent);
      expect(rings.any((d) => d.border == Border.all(color: look.colors.ink, width: ContactList.selectionRingWidth)),
          isFalse);
    });

    // A card list draws each row as the theme's card, with its card edge (Arcade's bright 1 px edge).
    testWidgets('a card list\'s rows carry the card edge (arcade)', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          themedFrame(const ThemeCase('arcade', Brightness.light), _Harness(contacts: _people(), selected: 'a2')));
      await tester.pump();
      final look = MyDataLook.of(tester.element(find.text('Eli Sample')));
      expect(look.variants.list, ListStyle.cards);
      expect(look.edges.card, isNotNull);
      for (final name in ['Eli Sample', 'Ava Fictional']) {
        expect(find.ancestor(of: find.text(name), matching: find.byType(CardEdge)), findsOneWidget, reason: name);
      }
    });

    testWidgets('hover fills an unselected row with surface-sunken; the selected row keeps accent-soft', (
      tester,
    ) async {
      await _pump(tester, _Harness(contacts: _people(), selected: 'a2'));
      final c = MyDataTheme.data('kiwi', Brightness.light).extension<MyDataColors>()!;
      Color? fill(String name) =>
          (tester
                      .widget<AnimatedContainer>(
                        find.descendant(of: _row(name), matching: find.byType(AnimatedContainer)),
                      )
                      .decoration!.box)
              .color;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Eli Sample')));
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      expect(fill('Eli Sample'), c.surfaceHover);
      await mouse.moveTo(tester.getCenter(find.text('Ava Fictional')));
      await tester.pumpAndSettle();
      expect(fill('Eli Sample')!.a, 0);
      expect(fill('Ava Fictional')!.a, 0, reason: 'no hover fill over the selected fill');
    });

    testWidgets('pressing a row opens it and focuses the list', (tester) async {
      final opened = <String>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _pump(tester, _Harness(contacts: _people(), selected: 'a2', opened: opened, focusNode: focus));
      await tester.tap(find.text('Eli Sample'));
      await tester.pump();
      expect(opened, ['e1']);
      expect(_hasFocus(focus), isTrue);
      expect(_rowNode(tester, 'Eli Sample').flagsCollection.isSelected, ui.Tristate.isTrue);
    });

    testWidgets('a mouse press focuses the list without the focus ring, until a key moves the cursor', (tester) async {
      final semantics = tester.ensureSemantics();
      final list = FocusNode();
      addTearDown(list.dispose);
      await _pump(tester, _Harness(contacts: _people(), selected: 'a2', focusNode: list));
      expect(tester.binding.focusManager.highlightMode, FocusHighlightMode.traditional);
      Finder ring(String name) => find.descendant(of: _row(name), matching: find.byType(FocusRing));
      await tester.tap(find.text('Eli Sample'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(_hasFocus(list), isTrue);
      expect(tester.binding.focusManager.highlightMode, FocusHighlightMode.traditional);
      expect(find.descendant(of: find.byType(ListView), matching: find.byType(FocusRing)), findsNothing);
      expect(
        _rowNode(tester, 'Eli Sample').flagsCollection.isFocused,
        ui.Tristate.isTrue,
        reason: 'a screen reader still follows',
      );
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(ring('Élodie Placeholder'), findsOneWidget, reason: 'a key shows the ring');
      // Pressing again while the list has keyboard focus keeps the ring, on the row pressed.
      await tester.tap(find.text('Aaron Example'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(ring('Aaron Example'), findsOneWidget);
      // Leaving the list forgets how it was focused: a press hides the ring again, and focus that comes
      // back from the keyboard (Tab) shows it.
      list.unfocus();
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Eli Sample'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(find.descendant(of: find.byType(ListView), matching: find.byType(FocusRing)), findsNothing);
      list.unfocus();
      await tester.pump();
      await tester.pump();
      list.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(ring('Eli Sample'), findsOneWidget);
      semantics.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('screen readers follow the keys: the row the keyboard is on is the focused node', (tester) async {
      final semantics = tester.ensureSemantics();
      final list = FocusNode();
      addTearDown(list.dispose);
      await _pump(tester, _Harness(contacts: _people(), selected: 'a2', focusNode: list));
      ui.Tristate focused(String name) => _rowNode(tester, name).flagsCollection.isFocused;
      expect(focused('Ava Fictional'), ui.Tristate.isFalse, reason: 'focusable, the tab stop, not yet focused');
      expect(focused('Eli Sample'), ui.Tristate.none);
      list.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(focused('Ava Fictional'), ui.Tristate.isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(focused('Eli Sample'), ui.Tristate.isTrue);
      expect(focused('Ava Fictional'), ui.Tristate.none);
      await _key(tester, LogicalKeyboardKey.end);
      expect(focused('+44 7700 900456'), ui.Tristate.isTrue);
      await _key(tester, LogicalKeyboardKey.home);
      expect(focused('Aaron Example'), ui.Tristate.isTrue);
      await _key(tester, LogicalKeyboardKey.keyE);
      await _key(tester, LogicalKeyboardKey.keyL);
      await _key(tester, LogicalKeyboardKey.keyO);
      expect(focused('Élodie Placeholder'), ui.Tristate.isTrue, reason: 'type-ahead');
      await tester.pump(ContactList.typeAheadTimeout);
      list.unfocus();
      await tester.pump();
      await tester.pump();
      expect(list.hasFocus, isFalse);
      expect(focused('Élodie Placeholder'), ui.Tristate.isFalse);
      semantics.dispose();
    });

    testWidgets('from 600px: one tab stop; Up and Down move the selection across groups', (tester) async {
      final opened = <String>[];
      final list = FocusNode();
      final search = FocusNode();
      addTearDown(list.dispose);
      addTearDown(search.dispose);
      await _pump(
        tester,
        _Harness(
          contacts: _people(),
          selected: 'a2',
          opened: opened,
          focusNode: list,
          searchFocusNode: search,
          after: true,
        ),
      );
      await _key(tester, LogicalKeyboardKey.tab);
      expect(search.hasFocus, isTrue, reason: 'the search field comes first');
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_hasFocus(list), isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(opened, ['e1'], reason: 'from the last A to the first E');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(opened, ['e1', 'a2', 'a1']);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(opened, ['e1', 'a2', 'a1'], reason: 'already at the top');
      await _key(tester, LogicalKeyboardKey.end);
      expect(opened.last, 'n1', reason: 'the last row is the "#" group');
      await _key(tester, LogicalKeyboardKey.home);
      expect(opened.last, 'a1');
      // Tab leaves the list for the contact pane.
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_hasFocus(list), isFalse);
      expect(search.hasFocus, isFalse);
    });

    testWidgets('the focus ring is drawn inside the selection ring', (tester) async {
      final list = FocusNode();
      addTearDown(list.dispose);
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await _pump(tester, _Harness(contacts: _people(), selected: 'a2', focusNode: list));
      final rows = find.descendant(of: find.byType(ListView), matching: find.byType(FocusRing));
      expect(rows, findsNothing);
      list.requestFocus();
      await tester.pump();
      await tester.pump();
      final ring = find.descendant(of: _row('Ava Fictional'), matching: find.byType(FocusRing));
      expect(ring, findsOneWidget);
      final row = tester.getRect(_row('Ava Fictional'));
      final box = tester.getRect(ring);
      // FocusRing draws 2px to 4px outside its box: 2px to 4px inside the row, inside the 2px ink ring.
      expect(box, row.deflate(ContactList.focusRingInset));
    });

    testWidgets('Down in the search field moves into the list at the first result', (tester) async {
      final opened = <String>[];
      final list = FocusNode();
      final search = FocusNode();
      final text = TextEditingController();
      addTearDown(list.dispose);
      addTearDown(search.dispose);
      addTearDown(text.dispose);
      await _pump(
        tester,
        _Harness(
          contacts: _people(),
          selected: 'a2',
          opened: opened,
          focusNode: list,
          searchFocusNode: search,
          search: text,
        ),
      );
      search.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'sample');
      await tester.pump();
      expect(opened, isEmpty, reason: 'searching never changes the open contact');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_hasFocus(list), isTrue);
      expect(opened, ['e1']);
    });

    testWidgets('search filters by group, keeps the open contact, and Escape clears it', (tester) async {
      final semantics = tester.ensureSemantics();
      final opened = <String>[];
      final search = FocusNode();
      final text = TextEditingController();
      addTearDown(search.dispose);
      addTearDown(text.dispose);
      await _pump(
        tester,
        _Harness(contacts: _people(), selected: 'a1', opened: opened, searchFocusNode: search, search: text),
      );
      search.requestFocus();
      await tester.enterText(find.byType(EditableText), 'LABS');
      await tester.pump();
      expect(find.text('Ava Fictional'), findsOneWidget);
      expect(find.text('Example Labs'), findsNWidgets(2), reason: "Ava's caption and the organisation's card");
      expect(find.text('Aaron Example'), findsNothing);
      expect(find.text('#'), findsNothing, reason: 'a group with no matches is left out');
      expect(find.text('A'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);
      expect(opened, isEmpty);

      await tester.enterText(find.byType(EditableText), 'élo');
      await tester.pump();
      expect(find.text('Élodie Placeholder'), findsOneWidget);
      expect(find.text('Eli Sample'), findsNothing);

      await tester.enterText(find.byType(EditableText), 'Zed');
      await tester.pump();
      expect(find.text('No contacts match “Zed”.'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.escape);
      expect(text.text, isEmpty);
      expect(find.text('Aaron Example'), findsOneWidget);
      expect(find.text('No contacts match “Zed”.'), findsNothing);
      semantics.dispose();
    });

    testWidgets('Escape in the list clears the search too', (tester) async {
      final list = FocusNode();
      final text = TextEditingController(text: 'eli');
      addTearDown(list.dispose);
      addTearDown(text.dispose);
      await _pump(tester, _Harness(contacts: _people(), selected: 'e1', focusNode: list, search: text));
      list.requestFocus();
      await tester.pump();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.escape);
      expect(text.text, isEmpty);
    });

    testWidgets('typing letters moves to the first name that starts with them', (tester) async {
      final opened = <String>[];
      final list = FocusNode();
      addTearDown(list.dispose);
      await _pump(tester, _Harness(contacts: _people(), selected: 'a1', opened: opened, focusNode: list));
      list.requestFocus();
      await tester.pump();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.keyE);
      expect(opened, ['e1']);
      await _key(tester, LogicalKeyboardKey.keyL);
      await _key(tester, LogicalKeyboardKey.keyO);
      expect(opened, ['e1', 'e2'], reason: '"elo" finds Élodie, ignoring the accent');
      await tester.pump(ContactList.typeAheadTimeout);
      await _key(tester, LogicalKeyboardKey.keyA);
      expect(opened.last, 'a1', reason: 'after a pause the letters start again');
      await tester.pump(ContactList.typeAheadTimeout);
    });

    testWidgets('under 600px: chevrons, nothing selected; arrows move focus and Return or Space opens', (tester) async {
      final semantics = tester.ensureSemantics();
      final opened = <String>[];
      final list = FocusNode();
      addTearDown(list.dispose);
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await _pump(tester, _Harness(contacts: _people(), selected: 'a2', opened: opened, focusNode: list), width: 390);
      expect(findIcon(MyDataIcon.chevronRight), findsNWidgets(6));
      expect(_rowNode(tester, 'Ava Fictional').flagsCollection.isSelected, ui.Tristate.none);
      list.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(of: _row('Ava Fictional'), matching: find.byType(FocusRing)),
        findsOneWidget,
        reason: 'focus starts on the contact last opened, though it is not shown selected',
      );
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(opened, isEmpty, reason: 'moving focus opens nothing');
      expect(find.descendant(of: _row('Eli Sample'), matching: find.byType(FocusRing)), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(opened, ['e1']);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.space);
      expect(opened, ['e1', 'e2']);
      semantics.dispose();
    });

    testWidgets('only the rows on screen are built', (tester) async {
      await _pump(tester, _Harness(contacts: _many(500), height: 600));
      expect(find.byType(Avatar).evaluate().length, lessThan(30));
    });

    testWidgets('the selected row is scrolled into view when the list opens', (tester) async {
      await _pump(tester, _Harness(contacts: _many(200), selected: 'p150', height: 400));
      await tester.pump();
      final row = tester.getRect(_row('Person 150 Example'));
      final list = tester.getRect(find.byType(ListView));
      expect(list.contains(row.topLeft) && list.contains(row.bottomRight - const Offset(1, 1)), isTrue);
    });

    testWidgets('End, Home, Page Down and Page Up keep the row in view', (tester) async {
      final opened = <String>[];
      final list = FocusNode();
      addTearDown(list.dispose);
      await _pump(tester, _Harness(contacts: _many(100), selected: 'p1', opened: opened, focusNode: list, height: 400));
      list.requestFocus();
      await tester.pump();
      await tester.pump();
      Rect view() => tester.getRect(find.byType(ListView));
      void inView(String name) {
        final r = tester.getRect(_row(name));
        expect(r.top >= view().top - 0.5 && r.bottom <= view().bottom + 0.5, isTrue, reason: '$name in view');
      }

      await _key(tester, LogicalKeyboardKey.end);
      await tester.pump();
      expect(opened.last, 'p100');
      inView('Person 100 Example');

      await _key(tester, LogicalKeyboardKey.home);
      await tester.pump();
      expect(opened.last, 'p1');
      inView('Person 001 Example');

      await _key(tester, LogicalKeyboardKey.pageDown);
      await tester.pump();
      final down = int.parse(opened.last.substring(1));
      expect(down, inInclusiveRange(5, 9), reason: 'a screenful of 57px rows in a 340px viewport');
      inView('Person ${down.toString().padLeft(3, '0')} Example');

      await _key(tester, LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(opened.last, 'p1');
    });

    testWidgets('large text: rows grow and nothing overflows', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themedFrame(
          themeMatrix.first,
          MediaQuery.withClampedTextScaling(
            minScaleFactor: 2,
            maxScaleFactor: 2,
            child: _Harness(contacts: _people(), selected: 'a2'),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_row('Ava Fictional')).height, greaterThan(MyDataSize.rowHeight));
    });

    testWidgets('with no contacts the list is not a tab stop', (tester) async {
      final list = FocusNode();
      addTearDown(list.dispose);
      await _pump(tester, _Harness(contacts: const [], focusNode: list));
      expect(list.canRequestFocus, isFalse);
      expect(find.byType(ListView), findsNothing);
    });
  });
}
