// The Mac frame's grouped forms (lib/src/mac/mac_form.dart): what the controls do.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'theme/designed_themes.dart';

Widget frame(Widget child) => MaterialApp(
  theme: MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light),
  home: Scaffold(body: MacForm(children: [MacFormSection(heading: 'Group', footer: 'A note.', rows: [child])])),
);

void main() {
  // The window's columns are divided by the theme's edge where its borders are its edge (Swiss's ink, Geometric's
  // 2 px of ink), as its toolbar and rows are ruled; elsewhere (Zen) by the Mac's separator.
  for (final (id, edge) in [('mydata.swiss', true), ('mydata.geometric', true), ('mydata.zen', false)]) {
    testWidgets('the Mac column divider in $id is ${edge ? 'its edge' : 'the separator'}', (tester) async {
      final look = designedLook(id, Brightness.light, platform: TargetPlatform.macOS);
      await tester.pumpWidget(MaterialApp(theme: MacTheme.drawn(look), home: const Material(child: SizedBox())));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SizedBox).last);
      final side = MacPanel.divider(context);
      if (edge) {
        expect(side.color, look.colors.edge);
        expect(side.width, look.edges.width < 1 ? 1 : look.edges.width);
      } else {
        expect(side.color, context.mac.separator);
        expect(side.width, MacPanel.dividerWidth);
      }
    });
  }

  // A drawn theme that outlines its cards fills a form's group as one of its cards, in its own panel colour
  // (`surface-raised`: Arcade's and Geometric's white panels), never a neutral shade of ink that sat grey on a
  // tinted ground; one without card edges (Zen) keeps the Mac's shade, which the group needs to show at all.
  for (final (id, card) in [('mydata.arcade', true), ('mydata.geometric', true), ('mydata.zen', false)]) {
    testWidgets('a form group in $id is filled ${card ? 'as its card' : 'with the Mac\'s shade'}', (tester) async {
      for (final b in Brightness.values) {
        final look = designedLook(id, b, platform: TargetPlatform.macOS);
        await tester.pumpWidget(MaterialApp(
          theme: MacTheme.drawn(look),
          home: const Material(child: MacFormSection(heading: 'Apps', rows: [SizedBox(height: 40)])),
        ));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(MacFormSection));
        final mac = context.mac;
        expect(MacFormSection.fill(context),
            card ? look.colors.surfaceRaised : Color.alphaBlend(mac.hover, mac.contentBackground),
            reason: b.name);
      }
    });
  }

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

  // The toolbar's search field in a theme whose fields are underlined (Terminal, Notebook) is a line under
  // the text, no box; an outlined theme (High Contrast) and System keep the box.
  for (final (slug, underlined) in [('terminal', true), ('notebook', true), ('high-contrast', false)]) {
    testWidgets('the Mac search field is ${underlined ? 'underlined' : 'boxed'} in $slug', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light),
        themeAnimationDuration: Duration.zero,
        home: Scaffold(body: Center(child: MacSearchField(controller: controller, placeholder: 'Search'))),
      ));
      await tester.pumpAndSettle();
      final look = MyDataLook.of(tester.element(find.byType(MacSearchField)));
      final d = tester
          .widgetList<Container>(find.descendant(of: find.byType(MacSearchField), matching: find.byType(Container)))
          .map((c) => c.decoration)
          .firstWhere((d) => d != null);
      if (underlined) {
        final border = (d! as BoxDecoration).border! as Border;
        expect(border.bottom, FloatingBarSurface.fieldSide(look));
        expect(border.top, BorderSide.none);
        expect((d as BoxDecoration).color, isNull);
      } else {
        expect(d.isBox, isTrue);
        expect(d.box.color, isNotNull);
      }
    });
  }

  // A record's quick actions in a theme whose icons have no tiles (Notebook, Terminal) have no grey ground:
  // the icon and its word (in the control outline where the theme outlines controls); a tinted theme
  // (Sticker) keeps the ground.
  for (final (slug, bare) in [('notebook', true), ('terminal', true), ('sticker', false)]) {
    testWidgets('a quick action in $slug ${bare ? 'has no ground' : 'keeps its ground'}', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light),
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
            body: Center(child: MacQuickAction(icon: MyDataIcon.call, label: 'call', onPressed: () {}))),
      ));
      await tester.pumpAndSettle();
      final d = tester
          .widgetList<Container>(find.descendant(of: find.byType(MacQuickAction), matching: find.byType(Container)))
          .map((c) => c.decoration)
          .firstWhere((d) => d != null);
      expect(d.box.color, bare ? isNull : isNotNull);
    });
  }

  // A disabled toolbar item's outline recedes with its label in a theme that outlines its controls in full
  // ink (Brutalist's 3 px), at the theme's width; an enabled one keeps the ink.
  testWidgets('a disabled toolbar item\'s outline recedes in brutalist', (tester) async {
    Future<BorderSide> edge(VoidCallback? onPressed) async {
      await tester.pumpWidget(MaterialApp(
        theme: MacTheme.forChoice(ThemeChoice('mydata.brutalist'), Brightness.light, MyDataMacColors.light),
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
            body: Center(
                child: MacToolbarButton.text(
                    text: 'Edit', label: 'Edit', onPressed: onPressed, disabledReason: 'Nothing to edit'))),
      ));
      await tester.pumpAndSettle();
      final d = tester
          .widgetList<AnimatedContainer>(
              find.descendant(of: find.byType(MacToolbarButton), matching: find.byType(AnimatedContainer)))
          .first
          .decoration;
      return (d.box.border! as Border).top;
    }

    BuildContext context() => tester.element(find.byType(MacToolbarButton));
    final enabled = await edge(() {});
    final m = context().macLook;
    expect(enabled, m.itemSide);
    final disabled = await edge(null);
    expect(disabled.color, context().mac.tertiaryLabel);
    expect(disabled.width, m.itemSide!.width);
    expect(disabled.color, isNot(m.itemSide!.color));
  });

  // The rule between a form's rows is the theme's own where its separators are full (Brutalist's 3 px and
  // High Contrast's 2 px of ink, Large's 2 px of line-strong), the system's hairline in System and where the
  // theme's separators are inset (Sticker).
  for (final (slug, width) in [('brutalist', 3.0), ('high-contrast', 2.0), ('large', 2.0), ('sticker', 1.0), (null, 1.0)]) {
    testWidgets('a form\'s rows are ruled ${slug ?? 'System'}\'s way', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: slug == null
            ? MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light)
            : MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light),
        themeAnimationDuration: Duration.zero,
        home: const Scaffold(
          body: MacForm(children: [
            MacFormSection(heading: 'Group', rows: [MacFormRow(title: 'One'), MacFormRow(title: 'Two')]),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('One'));
      final rule = tester.widget<Container>(
          find.descendant(of: find.byType(MacRowRule), matching: find.byType(Container)));
      final edges = context.look.edges;
      final colour = slug == null || edges.separators != Separators.full ? context.mac.separator : edges.colour;
      expect((rule.constraints?.maxHeight, (rule.color)), (width, colour));
    });
  }
}
