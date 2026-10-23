import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

final _kiwi = themeMatrix.first.data.extension<MyDataColors>()!;

const _calendars = [
  SelectItem.dotted(value: 'home', title: 'Home', dot: null),
  SelectItem.dotted(value: 'book', title: 'Book club', dot: null),
  SelectItem.dotted(value: 'work', title: 'Work', dot: null),
];

/// Calendars with their colours from the data.
List<SelectItem<String>> _dotted() => [
      SelectItem.dotted(value: 'home', title: 'Home', dot: _kiwi.dataBlue),
      SelectItem.dotted(value: 'book', title: 'Book club', dot: _kiwi.dataPurple),
      SelectItem.dotted(value: 'work', title: 'Work', dot: _kiwi.dataOrange),
      SelectItem.dotted(value: 'fam', title: 'Family', dot: _kiwi.dataGreen),
    ];

const _labels = [
  SelectItem(value: 'Mobile', title: 'Mobile'),
  SelectItem(value: 'Home', title: 'Home'),
  SelectItem(value: 'Work', title: 'Work'),
  SelectItem(value: 'Other', title: 'Other'),
];

const _zones = [
  SelectItem(value: 'Pacific/Auckland', title: 'Auckland', caption: 'New Zealand, GMT+13'),
  SelectItem(value: 'Europe/Berlin', title: 'Berlin', caption: 'Germany, GMT+2'),
  SelectItem(value: 'America/Bogota', title: 'Bogotá', caption: 'Colombia, GMT-5'),
  SelectItem(value: 'Europe/London', title: 'London', caption: 'United Kingdom, GMT+1'),
  SelectItem(value: 'America/New_York', title: 'New York', caption: 'United States, GMT-4'),
  SelectItem(value: 'Asia/Kolkata', title: 'Kolkata', caption: 'India, GMT+5:30'),
  SelectItem(value: 'Australia/Sydney', title: 'Sydney', caption: 'Australia, GMT+11'),
];

/// A Select that keeps its own value, as a form would.
class _Host<T> extends StatefulWidget {
  const _Host({
    required this.items,
    required this.initial,
    this.label = 'Calendar',
    this.onChanged,
    this.custom = false,
    this.searchable = false,
    this.width = 280,
    this.focusNode,
    this.suggested = const [],
  });
  final List<SelectItem<T>> suggested;
  final List<SelectItem<T>> items;
  final T? initial;
  final String label;
  final ValueChanged<T>? onChanged;
  final bool custom;
  final bool searchable;
  final double width;
  final FocusNode? focusNode;
  @override
  State<_Host<T>> createState() => _HostState<T>();
}

class _HostState<T> extends State<_Host<T>> {
  late T? value = widget.initial;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        child: MyDataSelect<T>(
          label: widget.label,
          items: widget.items,
          value: value,
          focusNode: widget.focusNode,
          onChanged: (v) {
            setState(() => value = v);
            widget.onChanged?.call(v);
          },
          onCustomLabel: widget.custom ? (t) => setState(() => value = t as T) : null,
          titleOf: (v) => '$v',
          searchPlaceholder: widget.searchable ? 'Search time zones' : null,
          suggested: widget.suggested,
          noMatches: (q) => 'No time zones match “$q”',
          matchCount: (n) => '$n time zones',
        ),
      );
}

Future<void> _desktop(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder get _field => find.byType(Pressable).first;

void main() {
  group('matchesWordStart', () {
    test('the start of any word, ignoring case and accents', () {
      expect(matchesWordStart('Auckland, New Zealand', 'auck'), isTrue);
      expect(matchesWordStart('Auckland, New Zealand', 'zeal'), isTrue);
      expect(matchesWordStart('Auckland, New Zealand', 'new z'), isTrue);
      expect(matchesWordStart('Auckland, New Zealand', 'land'), isFalse);
      expect(matchesWordStart('Bogotá', 'bogota'), isTrue);
      expect(matchesWordStart('Zürich', 'zur'), isTrue);
      expect(matchesWordStart('anything', '  '), isTrue);
    });
  });

  late FocusNode focusNode;
  goldenMatrix(
    'select',
    () {
      focusNode = FocusNode();
      Widget cell(Widget w) => SizedBox(width: 260, child: w);
      return Wrap(spacing: MyDataSpace.s5, runSpacing: MyDataSpace.s5, children: [
        cell(MyDataSelect<String>(label: 'Calendar', items: _dotted(), value: 'book', onChanged: (_) {})),
        cell(MyDataSelect<String>(
            label: 'Repeat',
            items: const [
              SelectItem(value: 'never', title: 'Never'),
              SelectItem(value: 'weekly', title: 'Every week'),
            ],
            value: 'never',
            help: 'Events repeat on their own weekday.',
            onChanged: (_) {})),
        cell(MyDataSelect<String>(
            label: 'Calendar',
            items: _dotted(),
            value: 'work',
            error: 'That calendar was deleted. Choose another.',
            focusNode: focusNode,
            onChanged: (_) {})),
        cell(MyDataSelect<String>(
            label: 'Calendar',
            items: _dotted(),
            value: 'home',
            disabledReason: 'Events organised by someone else cannot be moved to another calendar yet.',
            onChanged: null)),
        cell(Row(children: [
          MyDataSelect<String>(
              key: const ValueKey('hovered'),
              label: 'Label for phone 1',
              showLabel: false,
              fitToItems: true,
              items: _labels,
              value: 'Mobile',
              onChanged: (_) {}),
        ])),
      ]);
    },
    size: const Size(588, 420),
    before: (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      focusNode.requestFocus();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.byKey(const ValueKey('hovered'))));
      addTearDown(mouse.removePointer);
      await tester.pump();
    },
  );

  goldenMatrix(
    'select_open',
    () => const _Host<String>(items: _labels, initial: 'Home', label: 'Label for phone 1', custom: true),
    size: const Size(640, 400),
    before: (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    },
  );

  goldenMatrix(
    'select_open_dots',
    () => Builder(
      builder: (context) => _Host<String>(items: _dotted(), initial: 'book'),
    ),
    size: const Size(640, 340),
    before: (tester) async {
      await tester.tap(find.byType(Pressable).first);
      await tester.pumpAndSettle();
    },
  );

  goldenMatrix(
    'select_long_list',
    () => _Host<String>(items: _zones, initial: 'Europe/London', label: 'Time zone', searchable: true, suggested: [_zones.first]),
    size: const Size(640, 520),
    before: (tester) async {
      await tester.tap(find.byType(Pressable).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'new');
      await tester.pump();
      tester.state<EditableTextState>(find.byType(EditableText)).hideToolbar();
      await tester.pump();
    },
  );

  group('closed', () {
    testWidgets('looks like a TextField: label above, 44px, surface, line-strong, chevron at the end',
        (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host<String>(items: _calendars, initial: 'book')));
      final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, _kiwi.surface);
      expect((deco.border! as Border).top.color, _kiwi.lineStrong);
      expect(deco.borderRadius, MyDataRadii.md(kiwiLook));
      expect(tester.getSize(find.byType(AnimatedContainer).first).height, MyDataSize.controlHeight);
      expect(tester.getRect(find.text('Book club')).top - tester.getRect(find.text('Calendar')).bottom,
          greaterThanOrEqualTo(MyDataSpace.s2));
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
    });

    testWidgets('semantics: "Calendar, Book club, pop-up button", collapsed', (tester) async {
      await _desktop(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host<String>(items: _calendars, initial: 'book')));
      expect(
          tester.getSemantics(_field),
          isSemantics(
              label: 'Calendar',
              value: 'Book club',
              isButton: true,
              hasExpandedState: true,
              isExpanded: false,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true));
      handle.dispose();
    });

    testWidgets('Space, Return, Down, Up and Option-Down open it', (tester) async {
      await _desktop(tester);
      for (final open in [
        () => tester.sendKeyEvent(LogicalKeyboardKey.space),
        () => tester.sendKeyEvent(LogicalKeyboardKey.enter),
        () => tester.sendKeyEvent(LogicalKeyboardKey.arrowDown),
        () => tester.sendKeyEvent(LogicalKeyboardKey.arrowUp),
        () async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        },
      ]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host<String>(items: _calendars, initial: 'book')));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await open();
        await tester.pumpAndSettle();
        expect(find.text('Work'), findsOneWidget, reason: 'the list is open');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Work'), findsNothing);
      }
    });

    testWidgets('typing letters picks the next match without opening, and announces it', (tester) async {
      await _desktop(tester);
      final changes = <String>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _Host<String>(items: _labels, initial: 'Mobile', label: 'Label', onChanged: changes.add)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW, character: 'w');
      await tester.pump();
      expect(changes, ['Work']);
      expect(find.text('Other'), findsNothing, reason: 'the list stays closed');
      expect(tester.takeAnnouncements().map((a) => a.message), ['Work']);
      // Letters typed within a second add up; after a pause they start again.
      await tester.pump(ContactList.typeAheadTimeout);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH, character: 'h');
      await tester.pump();
      expect(changes.last, 'Home');
    });

    testWidgets('hover fills the field with surface-hover; a press dims it without shrinking', (tester) async {
      await _desktop(tester);
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host<String>(items: _calendars, initial: 'book')));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(_field));
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      final deco = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first).decoration! as BoxDecoration;
      expect(deco.color, _kiwi.surfaceHover);
      expect((deco.border! as Border).top.color, _kiwi.lineStrong);
      final pressable = tester.widget<Pressable>(_field);
      expect(pressable.scaleOnPress, isFalse);
    });

    testWidgets('disabled: 45%, not focusable, the reason as help and not faded', (tester) async {
      await _desktop(tester);
      final handle = tester.ensureSemantics();
      const reason = 'Events organised by someone else cannot be moved to another calendar yet.';
      final after = FocusNode();
      addTearDown(after.dispose);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 280,
            child: Column(children: [
              MyDataSelect<String>(
                  label: 'Calendar', items: _calendars, value: 'home', onChanged: null, disabledReason: reason),
              MyDataTextField(label: 'After', controller: TextEditingController(), focusNode: after),
            ]),
          )));
      expect(find.text(reason), findsOneWidget);
      expect(find.ancestor(of: find.text(reason), matching: find.byType(Opacity)), findsNothing);
      expect(
          tester.widget<AnimatedOpacity>(find.descendant(of: _field, matching: find.byType(AnimatedOpacity)).first).opacity,
          Pressable.disabledOpacity);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(after.hasFocus, isTrue);
      expect(tester.getSemantics(_field), isSemantics(label: 'Calendar', value: 'Home', hint: reason, isButton: true,
          hasEnabledState: true, isEnabled: false));
      handle.dispose();
    });

    testWidgets('error: 2px danger border, the error replaces the help, the focus ring is ink', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 280,
            child: MyDataSelect<String>(
                label: 'Calendar',
                items: _calendars,
                value: 'home',
                help: 'Help.',
                error: 'That calendar was deleted. Choose another.',
                onChanged: (_) {}),
          )));
      final deco = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first).decoration! as BoxDecoration;
      expect((deco.border! as Border).top.width, MyDataSelect.errorBorderWidth);
      expect((deco.border! as Border).top.color, _kiwi.danger);
      expect(find.text('Help.'), findsNothing);
      expect(tester.widget<Text>(find.text('That calendar was deleted. Choose another.')).style!.color, _kiwi.danger);
      expect(tester.widget<Pressable>(_field).danger, isTrue);
    });

    testWidgets('disabled: the label fades with the field; the reason under it does not', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 280,
            child: MyDataSelect<String>(
                label: 'Calendar',
                items: _calendars,
                value: 'home',
                disabledReason: 'Events organised by someone else cannot be moved yet.',
                onChanged: null),
          )));
      double opacityAbove(Finder f) => tester
          .widgetList<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)))
          .fold(1.0, (o, w) => o * w.opacity);
      expect(opacityAbove(find.text('Calendar')), Pressable.disabledOpacity);
      expect(opacityAbove(find.text('Events organised by someone else cannot be moved yet.')), 1.0);
    });

    testWidgets('fitToItems: a label the presets fit has no tooltip; a longer custom label is cut, with one',
        (tester) async {
      await _desktop(tester);
      Future<void> pump(String value) => tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Row(children: [
            MyDataSelect<String>(
                label: 'Label for phone 1',
                showLabel: false,
                fitToItems: true,
                items: _labels,
                value: value,
                titleOf: (v) => v,
                onChanged: (_) {}),
          ])));
      await pump('Mobile');
      final width = tester.getSize(_field).width;
      expect(find.byType(Tooltip), findsNothing);
      await pump('Grandmother’s boat phone');
      expect(tester.getSize(_field).width, width, reason: 'as wide as the longest preset, not the custom label');
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'Grandmother’s boat phone');
    });

    testWidgets('on a phone the value is body at 16px', (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host<String>(items: _calendars, initial: 'book')));
      expect(tester.widget<Text>(find.text('Book club')).style!.fontSize, PhoneType.bodySize);
    });

    testWidgets('fitToItems: as wide as the longest preset', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Row(children: [
            MyDataSelect<String>(
                label: 'Label for phone 1',
                showLabel: false,
                fitToItems: true,
                items: _labels,
                value: 'Mobile',
                onChanged: (_) {}),
          ])));
      final w = tester.getSize(_field).width;
      expect(w, lessThan(160));
      expect(w, greaterThan(80));
      expect(find.text('Label for phone 1'), findsNothing);
    });
  });

  group('open', () {
    testWidgets('a popover under the field: surface-raised, the current value checked in accent', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host<String>(items: _calendars, initial: 'book')));
      await tester.tap(_field);
      await tester.pumpAndSettle();
      final panel = find.ancestor(of: find.text('Work'), matching: find.byType(Container)).last;
      final deco = tester.widget<Container>(panel).decoration! as BoxDecoration;
      expect(deco.color, _kiwi.surfaceRaised);
      expect(deco.borderRadius, MyDataRadii.md(kiwiLook));
      final fieldRect = tester.getRect(_field);
      final panelRect = tester.getRect(panel);
      expect(panelRect.top - fieldRect.bottom, MyDataSpace.s1);
      expect(panelRect.width, greaterThanOrEqualTo(fieldRect.width));
      final check = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
      expect(check.color, _kiwi.accent);
      // The check sits on the current value's row.
      expect(tester.getCenter(find.byIcon(Icons.check_rounded)).dy,
          closeTo(tester.getCenter(find.text('Book club').last).dy, 1));
    });

    testWidgets('Up and Down move the highlight and stop at the ends; Return picks, closes and announces',
        (tester) async {
      await _desktop(tester);
      final changes = <String>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _Host<String>(items: _calendars, initial: 'book', onChanged: changes.add)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, ['work']);
      // Focus stays in the field, so each move of the highlight is heard, then the pick.
      expect(tester.takeAnnouncements().map((a) => a.message), ['Work, 3 of 3', 'Work']);
      // Up stops at the first.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(changes.last, 'home');
      // Focus is back on the field.
      expect(tester.widget<Pressable>(_field).focusNode!.hasFocus, isTrue);
    });

    testWidgets('Home and End jump; letters move the highlight to the next match', (tester) async {
      await _desktop(tester);
      final changes = <String>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _Host<String>(items: _labels, initial: 'Home', label: 'Label', onChanged: changes.add)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes.last, 'Other');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes.last, 'Mobile');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW, character: 'w');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes.last, 'Work');
    });

    testWidgets('Escape closes and keeps the old value; Tab closes, keeps it and moves focus on', (tester) async {
      await _desktop(tester);
      final changes = <String>[];
      final after = FocusNode();
      addTearDown(after.dispose);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 280,
            child: Column(children: [
              _Host<String>(items: _calendars, initial: 'book', onChanged: changes.add),
              MyDataTextField(label: 'After', controller: TextEditingController(), focusNode: after),
            ]),
          )));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(find.text('Work'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(find.text('Work'), findsNothing);
      expect(after.hasFocus, isTrue);
    });

    testWidgets('a click outside closes it and keeps the old value', (tester) async {
      await _desktop(tester);
      final changes = <String>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _Host<String>(items: _calendars, initial: 'book', onChanged: changes.add)));
      await tester.tap(_field);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 600));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsNothing);
      expect(changes, isEmpty);
    });

    testWidgets('a click on a row picks it', (tester) async {
      await _desktop(tester);
      final changes = <String>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _Host<String>(items: _calendars, initial: 'book', onChanged: changes.add)));
      await tester.tap(_field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(changes, ['work']);
      expect(find.text('Work'), findsOneWidget, reason: 'now the value in the closed field');
    });

    testWidgets('the current value is always in the list, above the presets', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(
          themedFrame(themeMatrix.first, const _Host<String>(items: _labels, initial: 'iPhone', label: 'Label')));
      expect(find.text('iPhone'), findsOneWidget);
      await tester.tap(_field);
      await tester.pumpAndSettle();
      final top = tester.getRect(find.text('iPhone').last).top;
      expect(top, lessThan(tester.getRect(find.text('Mobile')).top));
      expect(tester.getCenter(find.byIcon(Icons.check_rounded)).dy,
          closeTo(tester.getCenter(find.text('iPhone').last).dy, 1));
      // Opening and closing changes nothing.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('iPhone'), findsOneWidget);
    });

    testWidgets('each item reads its title, caption, whether chosen and its position', (tester) async {
      await _desktop(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, const _Host<String>(items: _zones, initial: 'Europe/Berlin', label: 'Time zone')));
      await tester.tap(_field);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Auckland, New Zealand, GMT+13'), findsOneWidget);
      final berlin = tester.getSemantics(find.bySemanticsLabel('Berlin, Germany, GMT+2'));
      expect(berlin.hint, '2 of 7');
      expect(berlin.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(tester.getSemantics(_field), isSemantics(label: 'Time zone', value: 'Berlin', isButton: true,
          hasExpandedState: true, isExpanded: true, hasEnabledState: true, isEnabled: true, isFocusable: true,
          isFocused: true, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('the keyboard highlight is surface-hover with the focus ring; the pointer gets no ring',
        (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host<String>(items: _calendars, initial: 'home')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      CustomPaint ringOf(String text) => tester.widget<CustomPaint>(
          find.ancestor(of: find.text(text).last, matching: find.byType(CustomPaint)).first);
      expect(ringOf('Home').foregroundPainter, isNotNull);
      final fill = tester
          .widget<Container>(find.ancestor(of: find.text('Home').last, matching: find.byType(Container)).first)
          .decoration! as BoxDecoration;
      expect(fill.color, _kiwi.surfaceHover);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Work')));
      addTearDown(mouse.removePointer);
      await mouse.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(ringOf('Work').foregroundPainter, isNull);
      expect(ringOf('Home').foregroundPainter, isNull);
    });
  });

  group('custom label', () {
    testWidgets('choosing it turns the field into a text field; Return keeps the label', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(
          themedFrame(themeMatrix.first, const _Host<String>(items: _labels, initial: 'Home', label: 'Label', custom: true)));
      await tester.tap(_field);
      await tester.pumpAndSettle();
      expect(find.text('Custom label…'), findsOneWidget);
      await tester.tap(find.text('Custom label…'));
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, 'Home');
      expect(editable.controller.selection, const TextSelection(baseOffset: 0, extentOffset: 4));
      await tester.enterText(find.byType(EditableText), 'Grandma');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('Grandma'), findsOneWidget);
    });

    testWidgets('Escape returns the previous label', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(
          themedFrame(themeMatrix.first, const _Host<String>(items: _labels, initial: 'Work', label: 'Label', custom: true)));
      await tester.tap(_field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom label…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Grandma');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Grandma'), findsNothing);
    });
  });

  group('long list', () {
    testWidgets('the search pill takes focus; typing filters on word starts and highlights the first',
        (tester) async {
      await _desktop(tester);
      final changes = <String>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          _Host<String>(
              items: _zones,
              initial: 'Pacific/Auckland',
              label: 'Time zone',
              searchable: true,
              suggested: [_zones.first],
              onChanged: changes.add)));
      await tester.tap(_field);
      await tester.pumpAndSettle();
      expect(find.text('Search time zones'), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
      expect(tester.state<EditableTextState>(find.byType(EditableText)).widget.focusNode.hasFocus, isTrue);
      await tester.enterText(find.byType(EditableText), 'bogo');
      await tester.pump();
      expect(find.text('Suggested'), findsNothing);
      expect(find.text('Bogotá'), findsOneWidget);
      expect(find.text('Berlin'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, ['America/Bogota']);
    });

    testWidgets('no match shows one line; the number of matches is announced after typing stops',
        (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          _Host<String>(items: _zones, initial: 'Europe/London', label: 'Time zone', searchable: true, suggested: [_zones.first])));
      await tester.tap(_field);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Aukl');
      await tester.pump();
      expect(find.text('No time zones match “Aukl”'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'a');
      await tester.pump();
      expect(tester.takeAnnouncements(), isEmpty);
      await tester.pump(MyDataSelect.announceDelay);
      // Auckland, Australia (Sydney's caption).
      expect(tester.takeAnnouncements().map((a) => a.message), ['2 time zones']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Search time zones'), findsNothing);
    });
  });

  testWidgets('on a phone, a tap opens a picker sheet; a tap on a row picks it and closes', (tester) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final changes = <String>[];
    await tester.pumpWidget(themedFrame(
        themeMatrix.first, _Host<String>(items: _calendars, initial: 'book', onChanged: changes.add, width: 340)));
    await tester.tap(_field);
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Calendar'), findsNWidgets(2), reason: 'the sheet is titled with the label');
    final row = tester.getSize(find.ancestor(of: find.text('Work'), matching: find.byType(Container)).first);
    expect(row.height, greaterThanOrEqualTo(MyDataSize.rowHeight));
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(changes, ['work']);
    expect(find.text('Cancel'), findsNothing);
  });
}
