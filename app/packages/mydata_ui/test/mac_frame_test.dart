// The Mac frame's pieces in mydata_ui: its theme and the shared widgets' Mac branch (its icons: theme/icons_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/widgets/group_frame.dart' show GroupFrame;

void main() {
  test("the Mac theme's text is in the system font, never under mydata_ui's package", () {
    for (final b in Brightness.values) {
      final mac = b == Brightness.dark ? MyDataMacColors.dark : MyDataMacColors.light;
      final theme = MacTheme.data('kiwi', b, mac);
      final styles = [
        theme.textTheme.bodyMedium!, theme.textTheme.bodySmall!, theme.textTheme.titleLarge!,
        theme.textTheme.displayLarge!, theme.textTheme.labelLarge!,
      ];
      for (final s in styles) {
        expect(s.fontFamily, MyDataMacFont.text);
      }
      expect(theme.textTheme.bodyMedium!.fontSize, 13);
      // A style merged onto the default text style keeps the plain family name.
      expect(theme.textTheme.bodyMedium!.merge(MyDataMacType.caption).fontFamily, MyDataMacFont.text);
      expect(theme.extension<MyDataMacColors>(), mac);
      expect(theme.extension<MyDataColors>()!.accent, mac.accent);
    }
  });

  test('typeFor gives each branded role its Mac counterpart', () {
    const kiwi = MyDataTypeScale.kiwi;
    expect(MacTheme.typeFor(MyDataTypeRole.body, kiwi), MyDataMacType.body);
    expect(MacTheme.typeFor(MyDataTypeRole.bodyStrong, kiwi), MyDataMacType.bodyEmphasized);
    expect(MacTheme.typeFor(MyDataTypeRole.displayLg, kiwi), MyDataMacType.name);
    expect(MacTheme.typeFor(MyDataTypeRole.caption, kiwi), MyDataMacType.caption);
    expect(MacTheme.typeFor(MyDataTypeRole.mono, kiwi).fontFamily, MyDataMacFont.text);
    expect(MacTheme.typeFor(MyDataTypeRole.mono, kiwi).fontSize, MyDataType.mono.fontSize);
  });

  test('the system palette reads the channel and keeps defaults for what is missing', () {
    final p = MacSystemPalette.fromChannel({
      'light': {'accent': 0xFFFF2D55},
      'dark': 'not a map',
    });
    expect(p.light.accent, const Color(0xFFFF2D55));
    expect(p.light.label, MyDataMacColors.light.label);
    expect(p.dark, MyDataMacColors.dark);
    expect(MacSystemPalette.fromChannel(null), MacSystemPalette.fallback);
  });

  Widget frame(Widget child, {bool mac = true}) => MaterialApp(
        theme: mac ? MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light) : MyDataTheme.data('kiwi', Brightness.light),
        home: Scaffold(body: Center(child: child)),
      );

  test('the Mac widgets draw System in the Mac tokens and a drawn theme in its own type, density and corners', () {
    final system = MacLookMetrics.forLook(
        MacTheme.data(null, Brightness.light, MyDataMacColors.light).extension<MyDataLook>()!, system: true);
    expect(system.body, MyDataMacType.body);
    expect(system.name, MyDataMacType.name);
    expect(system.rowHeight, MyDataMacSize.rowHeight);
    expect(system.toolbarItemHeight, MyDataMacSize.toolbarItemHeight);
    expect(system.controlRadius, const BorderRadius.all(Radius.circular(MyDataMacRadius.field)));
    expect(system.secondary(MyDataMacType.body), MyDataMacType.body);

    MyDataLook drawn(String slug) => MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light)
        .extension<MyDataLook>()!;
    // Hairline's desktop density (its RULES.md: 30 px controls, 40 px rows), its round 5 px controls.
    final hairline = MacLookMetrics.forLook(drawn('hairline'), system: false);
    expect(hairline.rowHeight, 40);
    expect(hairline.toolbarItemHeight, 30);
    expect(hairline.controlRadius, const BorderRadius.all(Radius.circular(5)));
    expect(hairline.itemSide, isNotNull, reason: 'Hairline outlines its controls');
    // Journal: a name in its display face (Fraunces), square controls, secondary text italic.
    final journalLook = drawn('journal');
    final journal = MacLookMetrics.forLook(journalLook, system: false);
    expect(journal.name.fontFamily, journalLook.typeScale.title.fontFamily);
    expect(journal.name.fontFamily, contains('Fraunces'));
    expect(journal.body.fontFamily, isNot(contains('Fraunces')));
    expect(journal.controlRadius, BorderRadius.zero);
    expect(journal.secondary(journal.body).fontStyle, FontStyle.italic);
    // Kiwi's capsules, never taller than the toolbar band leaves room for.
    final kiwi = MacLookMetrics.forLook(drawn('kiwi'), system: false);
    expect(kiwi.toolbarItemHeight, MacLookMetrics.toolbarItemMax);
    expect(kiwi.controlRadius.topLeft.x, greaterThan(kiwi.toolbarItemHeight / 2));
  });

  testWidgets("the Mac's plain list marks the selection in a drawn theme's own style and rows", (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final people = [
      ContactListEntry(id: 'a', name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional'),
      ContactListEntry(id: 'b', name: 'Ben Sample', givenName: 'Ben', familyName: 'Sample'),
    ];
    for (final (slug, rows) in [('hairline', 40.0), ('journal', 52.0)]) {
      final theme = MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: ContactList(
                style: ContactListStyle.plain, showSearch: false, contacts: people, selectedId: 'a', onOpen: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final look = theme.extension<MyDataLook>()!;
      expect(look.variants.selection, SelectionStyle.bar, reason: slug);
      // The theme's selection (a tint and a bar), never the Mac's accent fill.
      expect(find.byWidgetPredicate((w) => w is SelectionMark && w.selected), findsOneWidget, reason: slug);
      expect(tester.getSize(find.ancestor(of: find.text('Ben Sample', findRichText: true), matching: find.byType(Semantics)).first).height,
          rows, reason: '$slug rows are its own');
    }
  });

  // Where the theme's lists are cards (Arcade), each row of the plain list is a card on the pane with the
  // card gap under it, its edge and corners the theme's; the row heights the keyboard and scrolling use count
  // the gap. Elsewhere no row is a card.
  testWidgets("the Mac's plain list draws each row as a card where the theme's lists are cards", (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final people = [
      ContactListEntry(id: 'a', name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional'),
      ContactListEntry(id: 'b', name: 'Ben Sample', givenName: 'Ben', familyName: 'Sample'),
    ];
    for (final (slug, cards) in [('arcade', true), ('hairline', false)]) {
      final theme = MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 400,
            child: ContactList(
                style: ContactListStyle.plain, showSearch: false, contacts: people, selectedId: 'a', onOpen: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final look = theme.extension<MyDataLook>()!;
      Finder card(String name) =>
          find.ancestor(of: find.text(name, findRichText: true), matching: find.byType(CardEdge));
      expect(card('Ben Sample'), cards ? findsOneWidget : findsNothing, reason: slug);
      if (!cards) continue;
      final row = find.ancestor(of: find.text('Ben Sample', findRichText: true), matching: find.byType(Semantics)).first;
      expect(tester.getSize(row).height - tester.getSize(card('Ben Sample')).height, GroupFrame.cardGap(look));
      expect(tester.getSize(card('Ben Sample')).height, MacLookMetrics.forLook(look, system: false).rowHeight);
    }
  });

  // Where the theme's lists are tables (Ledger), the plain list is a table across the pane: each letter a
  // header band on `surface-sunken` with a `line-strong` rule under it, and every second row of a letter group
  // on `stripe` (zebra stripes, started again under each letter), lighter than the band so a striped last row
  // never runs into the next band. A selected striped row shows the selection's fill over its stripe. Hairline
  // draws neither, and nor does System (the Mac's own list).
  testWidgets("the Mac's plain list draws a table theme's header bands and zebra stripes", (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final people = [
      ContactListEntry(id: 'a', name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional'),
      ContactListEntry(id: 'b', name: 'Abe Dummy', givenName: 'Abe', familyName: 'Dummy'),
      ContactListEntry(id: 'c', name: 'Aaron Example', givenName: 'Aaron', familyName: 'Example'),
      ContactListEntry(id: 'd', name: 'Ben Sample', givenName: 'Ben', familyName: 'Sample'),
      ContactListEntry(id: 'e', name: 'Bea Testa', givenName: 'Bea', familyName: 'Testa'),
    ];
    for (final (slug, table) in [('ledger', true), ('hairline', false), ('system', false)]) {
      final theme = MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
            body: SizedBox(
              width: 280,
              height: 400,
              child: ContactList(
                style: ContactListStyle.plain,
                showSearch: false,
                contacts: people,
                // The second row of A: a striped row.
                selectedId: 'b',
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final look = theme.extension<MyDataLook>()!;
      expect(look.variants.list == ListStyle.table, table, reason: slug);
      expect(look.frame == LookFrame.system, slug == 'system', reason: slug);
      final sunken = look.colors.surfaceSunken, stripe = look.colors.stripe;
      // The band and the stripe are told apart.
      expect(stripe, isNot(sunken), reason: slug);
      Finder text(String name) => find.text(name, findRichText: true);
      final isStripe = find.byWidgetPredicate((w) => w is ColoredBox && w.color == stripe);
      bool striped(String name) => find.ancestor(of: text(name), matching: isStripe).evaluate().isNotEmpty;
      // The rows in the order given: A is Ava, Abe, Aaron; B is Ben, Bea.
      expect(striped('Ava Fictional'), isFalse, reason: '$slug: the first row of A');
      expect(striped('Abe Dummy'), table, reason: '$slug: the second row of A');
      expect(striped('Aaron Example'), isFalse, reason: '$slug: the third row of A');
      expect(striped('Ben Sample'), isFalse, reason: '$slug: the first row of B starts again');
      expect(striped('Bea Testa'), table, reason: '$slug: the second row of B');
      final bands = tester
          .widgetList<DecoratedBox>(find.ancestor(of: find.text('B'), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == sunken || d.color == stripe);
      expect(bands, table ? hasLength(1) : isEmpty, reason: slug);
      if (table) {
        expect(bands.single.color, sunken);
        expect((bands.single.border! as Border).bottom.color, look.colors.lineStrong);
        // The letter lines up with the names under it.
        expect(tester.getTopLeft(find.text('B')).dx, tester.getTopLeft(text('Ben Sample')).dx);
        // The selected striped row: the selection's fill over the stripe, across the whole row, so the row
        // reads as selected, not as another stripe.
        final fill = SelectionPaint.of(look).fill!;
        expect(fill, isNot(stripe));
        final isFill = find.byWidgetPredicate((w) =>
            w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == fill);
        final over = find.descendant(of: find.ancestor(of: text('Abe Dummy'), matching: isStripe), matching: isFill);
        expect(over, findsOneWidget);
        expect(find.ancestor(of: text('Abe Dummy'), matching: over), findsOneWidget);
        expect(tester.getSize(over), tester.getSize(find.ancestor(of: text('Abe Dummy'), matching: isStripe)));
      }
    }
  });

  testWidgets('a web address on a record is underlined in a drawn theme, in the accent in System', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final table = MacFieldTable(groups: [
      [const MacField(label: 'work', value: 'ava@example.com')],
      [MacField(label: 'website', value: 'example.com/ava', onOpen: () {})],
    ]);
    TextStyle style(String text) => tester.widget<Text>(find.text(text)).style!;

    await tester.pumpWidget(frame(table));
    expect(style('example.com/ava').decoration, isNot(TextDecoration.underline));
    expect(style('example.com/ava').color, MyDataMacColors.light.accent);

    // Hairline's link is almost its ink (14.3:1 on bg, as ink is): only the underline tells it apart.
    for (final slug in ['hairline', 'kiwi', 'sticker']) {
      final theme = MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light);
      await tester.pumpWidget(MaterialApp(
          theme: theme, themeAnimationDuration: Duration.zero, home: Scaffold(body: Center(child: table))));
      final c = theme.extension<MyDataColors>()!;
      expect(style('example.com/ava').decoration, TextDecoration.underline, reason: slug);
      expect(style('example.com/ava').color, c.link, reason: slug);
      expect(style('ava@example.com').decoration, isNot(TextDecoration.underline), reason: slug);
    }
  });

  testWidgets('Button is a push button in the Mac frame', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var pressed = 0;
    await tester.pumpWidget(frame(Button(label: 'Restore', onPressed: () => pressed++)));
    expect(tester.getSize(find.byType(Button)).height, MyDataMacSize.pushButtonHeight);
    expect(tester.widget<Text>(find.text('Restore')).style!.fontFamily, MyDataMacFont.text);
    await tester.tap(find.byType(Button));
    expect(pressed, 1);
  });

  testWidgets('Button keeps the branded pill outside the Mac frame', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(frame(Button(label: 'Restore', onPressed: () {}), mac: false));
    expect(tester.getSize(find.byType(Button)).height, MyDataSize.controlHeight);
  });

  Future<Color> ring(WidgetTester tester, {bool mac = true, bool danger = false}) async {
    late Color out;
    await tester.pumpWidget(frame(mac: mac, Builder(builder: (context) {
      out = FocusRing.colourFor(context, danger: danger);
      return const SizedBox();
    })));
    return out;
  }

  testWidgets("the Mac frame's focus ring is the system's, on red controls too", (tester) async {
    expect(await ring(tester), MyDataMacColors.light.focusRing);
    expect(await ring(tester, danger: true), MyDataMacColors.light.focusRing);
  });

  testWidgets('outside the Mac frame the focus ring keeps the branded rule', (tester) async {
    expect(await ring(tester, mac: false), MyDataColors.light.focus);
    expect(await ring(tester, mac: false, danger: true), MyDataColors.light.ink);
  });

  testWidgets('a phone-sized window never draws the Mac frame', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late bool on;
    await tester.pumpWidget(frame(Builder(builder: (context) {
      on = MacWindow.of(context);
      return const SizedBox();
    })));
    expect(on, isFalse);
  });
}
