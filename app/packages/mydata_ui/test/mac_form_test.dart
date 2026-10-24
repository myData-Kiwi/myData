// The Mac frame's grouped forms (lib/src/mac/mac_form.dart): what the controls do.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

Widget frame(Widget child) => MaterialApp(
  theme: MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light),
  home: Scaffold(body: MacForm(children: [MacFormSection(heading: 'Group', footer: 'A note.', rows: [child])])),
);

void main() {
  testWidgets('a switch flips on a click and is announced as toggled', (tester) async {
    var value = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => frame(
          MacFormRow(
            title: 'Assistant',
            trailing: [MacSwitch(value: value, onChanged: (v) => setState(() => value = v), semanticLabel: 'Assistant')],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MacSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('Assistant').last).flagsCollection.isToggled, isNotNull);
  });

  testWidgets('a disabled switch does nothing', (tester) async {
    await tester.pumpWidget(frame(const MacSwitch(value: false, onChanged: null)));
    await tester.tap(find.byType(MacSwitch));
    await tester.pumpAndSettle();
  });

  testWidgets('a segmented control changes on a click and with the arrow keys', (tester) async {
    var mode = 'light';
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => frame(
          MacSegmented<String>(
            segments: const [('light', 'Light'), ('dark', 'Dark'), ('system', 'Match system')],
            selected: mode,
            onChanged: (m) => setState(() => mode = m),
            semanticLabel: 'Appearance',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(mode, 'dark');
    Focus.of(tester.element(find.text('Dark'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(mode, 'system');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(mode, 'system', reason: 'the last segment stays');
  });

  testWidgets('a disclosure shows its content only while open', (tester) async {
    var open = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => frame(
          MacDisclosure(
            title: 'Details',
            open: open,
            onToggle: () => setState(() => open = !open),
            child: const Text('Host version'),
          ),
        ),
      ),
    );
    expect(find.text('Host version'), findsNothing);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Host version'), findsOneWidget);
  });

  testWidgets('a text field takes typing and names itself', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(frame(MacEditField(controller: controller, label: 'Name', placeholder: 'For example')));
    await tester.enterText(find.byType(TextField), 'Claude');
    expect(controller.text, 'Claude');
    expect(find.bySemanticsLabel(RegExp('^Name')), findsWidgets);
  });

  // A drawn theme's form, in the Mac window: [slug]'s look.
  Widget drawn(String slug, Widget child, {String heading = 'Included from this Mac'}) => MaterialApp(
        theme: MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light),
        themeAnimationDuration: Duration.zero,
        home: Scaffold(body: MacForm(children: [MacFormSection(heading: heading, rows: [child])])),
      );

  // "Square: every radius 0": a square theme's switch is a square track with a square thumb, as its other
  // controls are; System and round themes keep the system's capsule and round thumb.
  for (final (slug, square) in [('terminal', true), ('brutalist', true), ('hairline', false), ('kiwi', false)]) {
    testWidgets('a switch in $slug is ${square ? 'square' : 'a capsule'}', (tester) async {
      await tester.pumpWidget(drawn(slug, MacSwitch(value: true, onChanged: (_) {}, semanticLabel: 'On')));
      final boxes = tester
          .widgetList<Container>(find.descendant(of: find.byType(MacSwitch), matching: find.byType(Container)))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      final track = boxes.firstWhere((d) => d.borderRadius != null);
      final thumb = boxes.firstWhere((d) => d.borderRadius == null);
      expect(track.borderRadius, square ? BorderRadius.zero : isNot(BorderRadius.zero));
      expect(thumb.shape, square ? BoxShape.rectangle : BoxShape.circle);
    });
  }
  testWidgets('a switch in System is the system\'s capsule', (tester) async {
    await tester.pumpWidget(frame(MacSwitch(value: true, onChanged: (_) {})));
    final thumb = tester
        .widgetList<Container>(find.descendant(of: find.byType(MacSwitch), matching: find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.borderRadius == null);
    expect(thumb.shape, BoxShape.circle);
  });

  // A bare group (a theme whose lists are plain with no separators: Terminal, Notebook) has no box to say
  // where it starts, so its heading is set apart from the rows' titles: Terminal's in its label role, in
  // capitals at 700 (read as written); Notebook's in its heading role. A boxed group keeps body-emphasized.
  testWidgets('a bare group\'s heading stands apart from its rows', (tester) async {
    const row = MacFormRow(title: 'iCloud');
    await tester.pumpWidget(drawn('terminal', row));
    var look = MyDataLook.of(tester.element(find.text('iCloud')));
    expect(find.text('INCLUDED FROM THIS MAC'), findsOneWidget);
    expect(find.bySemanticsLabel('Included from this Mac'), findsOneWidget);
    final terminal = tester.widget<Text>(find.text('INCLUDED FROM THIS MAC')).style!;
    expect(terminal.fontWeight, FontWeight.w700);
    expect(terminal.fontSize, look.typeScale.label.fontSize);
    expect(tester.widget<Text>(find.text('iCloud')).style!.fontWeight, isNot(FontWeight.w700));

    await tester.pumpWidget(drawn('notebook', row));
    await tester.pumpAndSettle();
    look = MyDataLook.of(tester.element(find.text('iCloud')));
    final notebook = tester.widget<Text>(find.text('Included from this Mac')).style!;
    expect(notebook.fontFamily, look.typeScale.heading.fontFamily);
    expect(notebook.fontSize, look.typeScale.heading.fontSize);

    await tester.pumpWidget(drawn('high-contrast', row));
    await tester.pumpAndSettle();
    look = MyDataLook.of(tester.element(find.text('iCloud')));
    final boxed = tester.widget<Text>(find.text('Included from this Mac')).style!;
    expect(boxed.fontSize, look.typeScale.bodyStrong.fontSize);
    expect(boxed.fontWeight, look.typeScale.bodyStrong.fontWeight);
  });
}
