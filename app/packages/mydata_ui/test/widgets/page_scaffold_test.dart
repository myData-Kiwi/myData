import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

List<Widget> _sections() => [
      const MyDataCard(
        icon: Icons.storage_outlined,
        name: 'Storage',
        child: Text('412 GB free of 1 TB on Home drive.'),
      ),
      GroupedList(heading: 'Host', rows: const [
        GroupedRow(title: 'Host address', subtitle: 'This Mac', trailing: GroupedValue('127.0.0.1:8765')),
        GroupedRow(title: 'Started', trailing: GroupedValue('Today at 09:12')),
      ]),
    ];

/// [child] in a window of [size], so PageScaffold picks the layout for that width.
Widget _window(Size size, Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    );

Widget _desktop() => _window(
      const Size(900, 520),
      PageScaffold(
        title: 'Status',
        actions: [
          Button(label: 'Check for updates', onPressed: _noop),
          Button(label: 'Add a device', variant: ButtonVariant.filled, onPressed: _noop),
        ],
        children: _sections(),
      ),
    );

/// A phone screen in its frame: the app name is the large title, the section title sits under it.
Widget _phone() => _window(
      const Size(375, 520),
      AppFrame(
        appName: 'myData',
        sections: const [AppSection(icon: Icons.monitor_heart_outlined, label: 'Status')],
        current: 0,
        onSelect: (_) {},
        child: PageScaffold(
          title: 'Status',
          actions: [Button(label: 'Add a device', variant: ButtonVariant.filled, onPressed: _noop)],
          children: _sections(),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, Widget child, {Size view = const Size(1400, 900)}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, child, padding: EdgeInsets.zero));
}

void main() {
  goldenMatrix(
    'page_scaffold',
    () => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _desktop(),
      const SizedBox(width: MyDataSpace.s6),
      _phone(),
    ]),
    size: const Size(1347, 568),
  );

  testWidgets(
      'desktop: space-8 padding, a display-lg title, the first section space-6 down, sections space-4 apart, '
      'actions at the end',
      (tester) async {
    await _pump(tester, PageScaffold(
      title: 'Status',
      actions: [Button(label: 'Add a device', onPressed: _noop)],
      children: const [SizedBox(height: 40, key: Key('a')), SizedBox(height: 40, key: Key('b'))],
    ));
    final c = tester.element(find.byType(PageScaffold)).colors;
    final title = tester.widget<Text>(find.text('Status'));
    expect(title.style!.fontSize, MyDataType.displayLg.fontSize);
    expect(title.style!.color, c.ink);
    // The title row starts at the padding; the title is centred on the taller button.
    expect(tester.getTopLeft(find.text('Status')).dx, MyDataSpace.s8);
    expect(tester.getTopLeft(find.byType(Button)).dy, MyDataSpace.s8);
    expect(tester.getCenter(find.text('Status')).dy, tester.getCenter(find.byType(Button)).dy);
    final a = tester.getRect(find.byKey(const Key('a')));
    final b = tester.getRect(find.byKey(const Key('b')));
    expect(a.left, MyDataSpace.s8);
    expect(PageScaffold.gap(kiwiLook), MyDataSpace.s4, reason: 'cards are space-4 apart, as in a CardGrid');
    expect(PageScaffold.gap(kiwiLook), CardGrid.gap(kiwiLook));
    expect(b.top - a.bottom, PageScaffold.gap(kiwiLook));
    expect(PageScaffold.titleGap(kiwiLook), MyDataSpace.s6);
    expect(a.top, greaterThanOrEqualTo(tester.getBottomLeft(find.text('Status')).dy + PageScaffold.titleGap(kiwiLook)));
    // The title row is as tall as the button; the first section starts space-6 under it.
    expect(a.top, tester.getBottomLeft(find.byType(Button)).dy + PageScaffold.titleGap(kiwiLook));
    expect(a.width, MyDataSize.contentMax, reason: 'the column stops at content-max');
    // The action sits at the end of the title row.
    expect(tester.getTopRight(find.byType(Button)).dx, MyDataSpace.s8 + MyDataSize.contentMax);
    expect(tester.getSemantics(find.text('Status')), matchesSemantics(label: 'Status', isHeader: true));
  });

  testWidgets('fullWidth uses the whole width', (tester) async {
    await _pump(tester, const PageScaffold(
      title: 'Library',
      fullWidth: true,
      children: [SizedBox(height: 40, key: Key('grid'))],
    ));
    expect(tester.getSize(find.byKey(const Key('grid'))).width, 1400 - 2 * MyDataSpace.s8);
  });

  testWidgets(
      'phone with no frame above: space-4 padding, a display-xl title, actions under it, '
      'and the floating bar inset kept clear',
      (tester) async {
    await _pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 700), padding: EdgeInsets.only(bottom: 100)),
        child: PageScaffold(
          title: 'myPhotos',
          actions: [Button(label: 'Add photos', onPressed: _noop)],
          children: const [SizedBox(height: 900, key: Key('long'))],
        ),
      ),
      view: const Size(375, 700),
    );
    final title = tester.widget<Text>(find.text('myPhotos'));
    expect(title.style!.fontSize, MyDataType.displayXl.fontSize);
    expect(tester.getTopLeft(find.text('myPhotos')), const Offset(MyDataSpace.s4, MyDataSpace.s4));
    expect(tester.getTopLeft(find.byType(Button)).dy,
        tester.getBottomLeft(find.text('myPhotos')).dy + PageScaffold.actionsGap(kiwiLook));
    expect(tester.getSize(find.byKey(const Key('long'))).width, 375 - 2 * MyDataSpace.s4);
    // Scrolled to the end, the last section stops space-4 above the inset.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byKey(const Key('long'))).dy, 700 - 100 - MyDataSpace.s4);
  });

  testWidgets('in a phone frame: the app name is the large title, the section title is title-sized under it',
      (tester) async {
    Widget frame(String title) => MediaQuery(
          data: const MediaQueryData(size: Size(375, 700)),
          child: AppFrame(
            appName: 'myPhotos',
            sections: const [
              AppSection(icon: Icons.photo_library_outlined, label: 'Library'),
              AppSection(icon: Icons.photo_album_outlined, label: 'Albums'),
            ],
            current: 0,
            onSelect: (_) {},
            child: PageScaffold(
              title: title,
              actions: [Button(label: 'Add photos', onPressed: _noop)],
              children: const [SizedBox(height: 40, key: Key('a'))],
            ),
          ),
        );
    await _pump(tester, SizedBox(width: 375, height: 700, child: frame('Library')), view: const Size(375, 700));
    final c = tester.element(find.byType(PageScaffold)).colors;
    final app = tester.widget<Text>(find.text('myPhotos'));
    expect(app.style!.fontSize, MyDataType.displayXl.fontSize);
    expect(app.style!.color, c.ink);
    final section = tester.widget<Text>(find.descendant(of: find.byType(PageScaffold), matching: find.text('Library')));
    expect(section.style!.fontSize, MyDataType.title.fontSize);
    expect(section.style!.color, c.ink);
    final appRect = tester.getRect(find.text('myPhotos'));
    final sectionRect = tester.getRect(find.descendant(of: find.byType(PageScaffold), matching: find.text('Library')));
    expect(appRect.left, MyDataSpace.s4);
    expect(sectionRect.left, appRect.left, reason: 'the two titles line up');
    expect(sectionRect.top, greaterThan(appRect.bottom));
    expect(tester.getSemantics(find.text('myPhotos')), matchesSemantics(label: 'myPhotos', isHeader: true));
    // The actions sit under the section title, as on any phone screen.
    expect(tester.getTopLeft(find.byType(Button)).dy, sectionRect.bottom + PageScaffold.actionsGap(kiwiLook));

    // A section named like the app shows the name once.
    await _pump(tester, SizedBox(width: 375, height: 700, child: frame('myPhotos')), view: const Size(375, 700));
    expect(find.text('myPhotos'), findsOneWidget);
    expect(find.descendant(of: find.byType(PageScaffold), matching: find.text('myPhotos')), findsNothing);
    expect(tester.getTopLeft(find.byType(Button)).dy, greaterThan(tester.getBottomLeft(find.text('myPhotos')).dy));
  });

  testWidgets('a narrow desktop page: several actions wrap at the end instead of squeezing the title',
      (tester) async {
    // The narrowest rail window: 600 - 96 rail - 2 x space-8 padding leaves 440px of content.
    const width = 600 - AppFrame.railWidth;
    await _pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(size: Size(600, 600)),
        child: SizedBox(
          width: width,
          height: 600,
          child: PageScaffold(
            title: 'Status',
            actions: [
              Button(label: 'Check for updates', onPressed: _noop),
              Button(label: 'Add a device', onPressed: _noop),
              Button(label: 'Open the logs', variant: ButtonVariant.plain, onPressed: _noop),
            ],
            children: const [SizedBox(height: 40, key: Key('a'))],
          ),
        ),
      ),
      view: const Size(600, 600),
    );
    expect(tester.takeException(), isNull);
    const content = width - 2 * MyDataSpace.s8;
    final title = tester.getRect(find.text('Status'));
    expect(tester.getSize(find.ancestor(of: find.text('Status'), matching: find.byType(Expanded)).first).width,
        greaterThanOrEqualTo((content - PageScaffold.actionsGap(kiwiLook)) * (1 - PageScaffold.actionsMaxShare) - 0.01));
    expect(title.left, MyDataSpace.s8);
    for (final label in ['Check for updates', 'Add a device', 'Open the logs']) {
      final r = tester.getRect(find.widgetWithText(Button, label));
      expect(r.right, lessThanOrEqualTo(MyDataSpace.s8 + content + 0.01), reason: '$label stays inside the page');
      expect(r.left, greaterThan(title.left));
    }
    // They no longer fit on one line, so they wrap.
    final tops = {for (final l in ['Check for updates', 'Add a device', 'Open the logs']) tester.getTopLeft(find.widgetWithText(Button, l)).dy};
    expect(tops.length, greaterThan(1));
    expect(tester.getTopLeft(find.byKey(const Key('a'))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.widgetWithText(Button, 'Open the logs')).dy + PageScaffold.titleGap(kiwiLook)));
  });

  testWidgets('scrolls, and Tab reaches the actions', (tester) async {
    var pressed = 0;
    await _pump(
        tester,
        PageScaffold(
          title: 'Settings',
          actions: [Button(label: 'Add a device', onPressed: () => pressed++)],
          children: const [SizedBox(height: 2000)],
        ),
        view: const Size(1000, 600));
    expect(find.byType(Scrollable), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(pressed, 1);
  });
}
