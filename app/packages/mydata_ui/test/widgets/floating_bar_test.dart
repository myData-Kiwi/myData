import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _stageWidth = 480.0;
const _stageHeight = 96.0;

/// A phone: 375px wide, so the bar is 343px between its space-4 insets.
const _phoneWidth = 375.0;

/// The preview's stage: `surface-sunken` with four coloured blocks the bar floats over.
Widget _stage(Widget bar, {bool solid = false, double width = _stageWidth}) {
  Widget stage = Builder(builder: (context) {
    final c = context.colors;
    Widget block(int flex, Color color) => Expanded(
        flex: flex,
        child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: MyDataRadii.sm(kiwiLook))));
    return SizedBox(
      width: width,
      height: _stageHeight,
      child: ClipRRect(
        borderRadius: MyDataRadii.lg(kiwiLook),
        child: ColoredBox(
          color: c.surfaceSunken,
          child: FloatingBarHost(
            bar: bar,
            child: Padding(
              padding: const EdgeInsets.all(MyDataSpace.s3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                block(30, c.accent),
                const SizedBox(width: MyDataSpace.s2),
                block(22, c.skin),
                const SizedBox(width: MyDataSpace.s2),
                block(20, c.success),
                const SizedBox(width: MyDataSpace.s2),
                block(18, c.warning),
              ]),
            ),
          ),
        ),
      ),
    );
  });
  if (solid) {
    stage = MyDataAccessibility(reduceMotion: false, reduceTransparency: true, child: stage);
  }
  return stage;
}

FloatingBar _tabs({int current = 0, ValueChanged<int>? onTab, bool icons = false}) => FloatingBar(
      semanticLabel: 'myPhotos',
      current: current,
      items: [
        for (final (i, (label, icon)) in const [
          ('Library', MyDataIcon.photo),
          ('Albums', MyDataIcon.photo),
          ('People', MyDataIcon.people),
          ('Places', MyDataIcon.map),
        ].indexed)
          FloatingBarItem(label: label, icon: icons ? icon : null, onPressed: () => onTab?.call(i)),
      ],
    );

/// The phone tab bar at its limit: five tabs, each with an icon and a one-word label.
FloatingBar _fiveTabs({int current = 0, bool icons = true, bool forceSolid = false}) => FloatingBar(
      semanticLabel: 'myPhotos',
      current: current,
      forceSolid: forceSolid,
      items: [
        for (final (label, icon) in const [
          ('Library', MyDataIcon.photo),
          ('Albums', MyDataIcon.photo),
          ('People', MyDataIcon.people),
          ('Places', MyDataIcon.map),
          ('Search', MyDataIcon.search),
        ])
          FloatingBarItem(label: label, icon: icons ? icon : null, onPressed: () {}),
      ],
    );

FloatingBar _toolbar({VoidCallback? onShare}) => FloatingBar(items: [
      FloatingBarItem(label: 'Share', icon: MyDataIcon.send, showLabel: false, onPressed: onShare ?? () {}),
      FloatingBarItem(label: 'Add to album', icon: MyDataIcon.photo, showLabel: false, onPressed: () {}),
      FloatingBarItem(label: 'Add to favourites', icon: MyDataIcon.check, showLabel: false, onPressed: () {}),
      const FloatingBarItem(label: 'Delete', icon: MyDataIcon.trash, showLabel: false),
    ]);

/// A stand-in for the assistant's input bar, built on the bare surface.
Widget _composer() => FloatingBarSurface(
      child: Builder(
        builder: (context) => Row(children: [
          const SizedBox(width: MyDataSpace.s3),
          Expanded(
            child: Text('Ask about your data',
                style: MyDataType.body.copyWith(color: context.colors.inkMuted)),
          ),
          Pressable(
            onPressed: () {},
            borderRadius: MyDataRadii.pill(kiwiLook),
            semanticLabel: 'Send',
            child: SizedBox.square(
              dimension: MyDataSize.controlHeight,
              child: Icon(context.icon(MyDataIcon.send), size: MyDataSize.icon, color: context.colors.accent),
            ),
          ),
        ]),
      ),
    );

Widget _all() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stage(_tabs()),
      const SizedBox(height: MyDataSpace.s3),
      _stage(_toolbar()),
      const SizedBox(height: MyDataSpace.s3),
      _stage(_composer()),
      const SizedBox(height: MyDataSpace.s3),
      _stage(_tabs(current: 2, icons: true), solid: true),
      const SizedBox(height: MyDataSpace.s3),
      _stage(_composer(), solid: true),
      const SizedBox(height: MyDataSpace.s3),
      _stage(_fiveTabs(current: 1), width: _phoneWidth),
      const SizedBox(height: MyDataSpace.s3),
      _stage(_fiveTabs(current: 4, icons: false), width: _phoneWidth),
    ]);

Finder get _thumb =>
    find.descendant(of: find.byType(FloatingBar), matching: find.byType(AnimatedPositionedDirectional));

void main() {
  goldenMatrix('floating_bar', _all,
      size: const Size(_stageWidth + 48, 7 * _stageHeight + 6 * MyDataSpace.s3 + 48));

  testWidgets('pressing an item calls its callback; a disabled item ignores taps', (tester) async {
    final tapped = <int>[];
    var shares = 0;
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        Column(children: [_stage(_tabs(onTab: tapped.add)), _stage(_toolbar(onShare: () => shares++))])));
    await tester.pump();
    await tester.tap(find.text('People'));
    await tester.tap(find.text('Library'));
    expect(tapped, [2, 0]);
    await tester.tap(find.byTooltip('Share'));
    expect(shares, 1);
    await tester.tap(findIcon(MyDataIcon.trash), warnIfMissed: false);
    expect(shares, 1);
  });

  testWidgets('Tab reaches the items in order; Enter and Space activate them', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(themedFrame(themeMatrix.first, _stage(_tabs(onTab: tapped.add))));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(tapped, [0, 1]);
  });

  testWidgets('semantics: the bar is named, the current tab is selected, icon-only items are named',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, Column(children: [_stage(_tabs(current: 1)), _stage(_toolbar())])));
    await tester.pump();
    expect(find.bySemanticsLabel('myPhotos'), findsOneWidget);
    expect(tester.getSemantics(find.text('Albums')),
        matchesSemantics(label: 'Albums', isButton: true, hasSelectedState: true, isSelected: true,
            hasEnabledState: true, isEnabled: true, isFocusable: true, hasTapAction: true, hasFocusAction: true));
    expect(tester.getSemantics(find.text('Library')),
        matchesSemantics(label: 'Library', isButton: true, hasSelectedState: true, isSelected: false,
            hasEnabledState: true, isEnabled: true, isFocusable: true, hasTapAction: true, hasFocusAction: true));
    expect(find.bySemanticsLabel('Add to album'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Delete')),
        matchesSemantics(label: 'Delete', isButton: true, hasEnabledState: true, isEnabled: false));
    handle.dispose();
  });

  testWidgets('items are at least control-height; the bar is a radius-xl pill of the stated height', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, Column(children: [_stage(_tabs()), _stage(_toolbar())])));
    await tester.pump();
    for (final p in tester.widgetList<Pressable>(find.descendant(of: find.byType(FloatingBar), matching: find.byType(Pressable)))) {
      final size = tester.getSize(find.byWidget(p));
      expect(size.height, greaterThanOrEqualTo(MyDataSize.controlHeight));
      expect(size.width, greaterThanOrEqualTo(MyDataSize.controlHeight));
    }
    expect(tester.getSize(find.byType(FloatingBar).first).height, FloatingBar.height(kiwiLook));
    expect(FloatingBar.height(kiwiLook), MyDataSize.controlHeight + 2 * MyDataSpace.s1 + 2);
  });

  testWidgets('the current tab is an accent-soft pill with accent bodyStrong text; others are ink body',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _stage(_tabs(current: 1))));
    await tester.pumpAndSettle();
    final c = tester.element(find.byType(FloatingBar)).colors;
    final pill = tester.widget<DecoratedBox>(find.descendant(of: _thumb, matching: find.byType(DecoratedBox)));
    expect((pill.decoration.box).color, c.accentSoft);
    expect((pill.decoration.box).borderRadius, MyDataRadii.pill(kiwiLook));
    expect(tester.getRect(find.descendant(of: _thumb, matching: find.byType(DecoratedBox))),
        tester.getRect(find.ancestor(of: find.text('Albums'), matching: find.byType(Pressable))));
    final albums = tester.widget<Text>(find.text('Albums')).style!;
    expect(albums.color, c.accent);
    expect(albums.fontWeight, MyDataType.bodyStrong.fontWeight);
    final library = tester.widget<Text>(find.text('Library')).style!;
    expect(library.color, c.ink);
    expect(library.fontWeight, MyDataType.body.fontWeight);
  });

  testWidgets('a toolbar (current null) has no pill', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _stage(_toolbar())));
    expect(_thumb, findsNothing);
  });

  testWidgets('the pill slides to a new tab with spring; with reduced motion it jumps', (tester) async {
    Future<void> run({required bool reduce}) async {
      Widget frame(int current) => themedFrame(themeMatrix.first, _stage(_tabs(current: current)), reduceMotion: reduce);
      await tester.pumpWidget(frame(0));
      await tester.pumpAndSettle();
      final pillFinder = find.descendant(of: _thumb, matching: find.byType(DecoratedBox));
      final start = tester.getRect(pillFinder).left;
      final end = tester.getRect(find.ancestor(of: find.text('Places'), matching: find.byType(Pressable))).left;
      await tester.pumpWidget(frame(3));
      await tester.pump(MyDataMotion.springDuration ~/ 4);
      final mid = tester.getRect(pillFinder).left;
      if (reduce) {
        expect(mid, end);
      } else {
        expect(mid, greaterThan(start));
        expect(mid, lessThan(end));
      }
      await tester.pumpAndSettle();
      expect(tester.getRect(pillFinder).left, closeTo(end, 0.01));
    }

    await run(reduce: false);
    await run(reduce: true);
  });

  testWidgets('glass: glass-fill, 1px glass-stroke, backdrop blur, radius-xl', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _stage(_tabs())));
    final c = tester.element(find.byType(FloatingBar)).colors;
    expect(find.descendant(of: find.byType(FloatingBar), matching: find.byType(BackdropFilter)), findsOneWidget);
    final box = tester.widget<DecoratedBox>(find
        .descendant(of: find.byType(BackdropFilter), matching: find.byType(DecoratedBox))
        .first);
    final d = box.decoration.box;
    expect(d.color, c.glassFill);
    expect(d.borderRadius, MyDataRadii.xl(kiwiLook));
    expect((d.border! as Border).top, BorderSide(color: c.glassStroke, width: FloatingBarSurface.strokeWidth));
  });

  testWidgets('reduced transparency: surface with shadow-2, no blur, no stroke, same size', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _stage(_tabs()), reduceTransparency: true));
    final ctx = tester.element(find.byType(FloatingBar));
    expect(find.byType(BackdropFilter), findsNothing);
    final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(FloatingBarSurface), matching: find.byType(DecoratedBox)).first);
    final d = box.decoration.box;
    expect(d.color, ctx.colors.surface);
    expect(d.boxShadow, ctx.shadows.shadow2);
    expect(d.border, isNull);
    expect(d.borderRadius, MyDataRadii.xl(kiwiLook));
    expect(tester.getSize(find.byType(FloatingBar)).height, FloatingBar.height(kiwiLook));
  });

  testWidgets('five tabs fit a 375px phone without cutting a label, with icons and without', (tester) async {
    for (final icons in [true, false]) {
      await tester.pumpWidget(themedFrame(themeMatrix.first, _stage(_fiveTabs(icons: icons), width: _phoneWidth)));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FloatingBar)).width, _phoneWidth - 2 * MyDataSpace.s4);
      final labels = find.descendant(
          of: find.descendant(of: find.byType(FloatingBar), matching: find.byType(Text)),
          matching: find.byType(RichText));
      expect(labels, findsNWidgets(5));
      for (final element in labels.evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, isFalse, reason: '${paragraph.text.toPlainText()} is cut');
        expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
            reason: '${paragraph.text.toPlainText()} is narrower than its text');
      }
      if (icons) {
        // The icon sits above its label, both inside the control-height item.
        final item = tester.getRect(find.ancestor(of: find.text('Library'), matching: find.byType(Pressable)));
        final icon = tester.getRect(findIcon(MyDataIcon.photo).first);
        final label = tester.getRect(find.text('Library'));
        expect(icon.bottom, lessThanOrEqualTo(label.top));
        expect(icon.top, greaterThanOrEqualTo(item.top));
        expect(label.bottom, lessThanOrEqualTo(item.bottom));
        expect(tester.widget<Text>(find.text('Library')).style!.fontWeight, MyDataType.label.fontWeight);
        expect(tester.widget<Text>(find.text('Albums')).style!.fontSize, MyDataType.caption.fontSize);
      }
    }
  });

  testWidgets('right to left: the pill sits under the current item and slides with it', (tester) async {
    Widget frame(int current) => themedFrame(
        themeMatrix.first, Directionality(textDirection: TextDirection.rtl, child: _stage(_tabs(current: current))));
    final pill = find.descendant(of: _thumb, matching: find.byType(DecoratedBox));
    Rect item(String label) => tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(Pressable)));
    await tester.pumpWidget(frame(0));
    await tester.pumpAndSettle();
    // In right-to-left reading order the first tab is the rightmost.
    expect(item('Library').left, greaterThan(item('Places').left));
    expect(tester.getRect(pill), item('Library'));
    await tester.pumpWidget(frame(2));
    await tester.pumpAndSettle();
    expect(tester.getRect(pill), item('People'));
  });

  testWidgets('forceSolid (a slow device): surface with shadow-2 and no blur, without reduced transparency',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _stage(_fiveTabs(forceSolid: true), width: _phoneWidth)));
    final ctx = tester.element(find.byType(FloatingBar));
    expect(MyDataAccessibility.of(ctx).reduceTransparency, isFalse);
    expect(find.byType(BackdropFilter), findsNothing);
    final d = tester
        .widget<DecoratedBox>(find.descendant(of: find.byType(FloatingBarSurface), matching: find.byType(DecoratedBox)).first)
        .decoration.box;
    expect(d.color, ctx.colors.surface);
    expect(d.boxShadow, ctx.shadows.shadow2);
    expect(d.border, isNull);
    expect(tester.getSize(find.byType(FloatingBar)).height, FloatingBar.height(kiwiLook));

    await tester.pumpWidget(themedFrame(
        themeMatrix.first, const FloatingBarSurface(forceSolid: true, child: SizedBox(height: MyDataSize.controlHeight))));
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpWidget(
        themedFrame(themeMatrix.first, const FloatingBarSurface(child: SizedBox(height: MyDataSize.controlHeight))));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  test('a bar holds one to five items', () {
    FloatingBarItem item(int i) => FloatingBarItem(label: 'Tab $i', onPressed: () {});
    expect(() => FloatingBar(items: [for (var i = 0; i < 6; i++) item(i)]), throwsAssertionError);
    expect(() => FloatingBar(items: const []), throwsAssertionError);
    expect(() => FloatingBar(items: [item(0)], current: 1), throwsAssertionError);
    expect(FloatingBar(items: [for (var i = 0; i < 5; i++) item(i)], current: 4).items, hasLength(5));
  });

  testWidgets('FloatingBarHost: the bar sits space-4 from the edges and the safe area; content scrolls clear of it',
      (tester) async {
    const safeBottom = 20.0;
    await tester.pumpWidget(themedFrame(
      themeMatrix.first,
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: safeBottom)),
        child: SizedBox(
          width: 360,
          height: 400,
          child: FloatingBarHost(
            bar: _tabs(),
            child: ListView(children: [
              for (var i = 0; i < 20; i++) SizedBox(height: MyDataSize.rowHeight, child: Text('Row $i')),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();
    final host = tester.getRect(find.byType(FloatingBarHost));
    final bar = tester.getRect(find.byType(FloatingBar));
    expect(bar.left - host.left, MyDataSpace.s4);
    expect(host.right - bar.right, MyDataSpace.s4);
    expect(host.bottom - bar.bottom, MyDataSpace.s4 + safeBottom);
    expect(bar.height, FloatingBar.height(kiwiLook));
    // The list fills the host, so it scrolls beneath the bar.
    expect(tester.getRect(find.byType(ListView)).bottom, host.bottom);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Row 19')).bottom, lessThanOrEqualTo(bar.top - MyDataSpace.s4));
  });

  testWidgets('FloatingBarHost measures a taller bar and pads the content to match', (tester) async {
    late EdgeInsets seen;
    await tester.pumpWidget(themedFrame(
      themeMatrix.first,
      SizedBox(
        width: 360,
        height: 400,
        child: FloatingBarHost(
          bar: const FloatingBarSurface(child: SizedBox(height: 100)),
          child: Builder(builder: (context) {
            seen = MediaQuery.paddingOf(context);
            return const SizedBox.expand();
          }),
        ),
      ),
    ));
    await tester.pump();
    final barHeight = tester.getSize(find.byType(FloatingBarSurface)).height;
    expect(barHeight, 100 + 2 * (FloatingBar.padding(kiwiLook) + FloatingBarSurface.strokeWidth));
    expect(seen.bottom, MyDataSpace.s4 + barHeight + MyDataSpace.s4);
  });
}
