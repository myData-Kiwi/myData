import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';

/// The preview's storage meter: an 8px `surface-sunken` track with a 40% `accent` fill.
Widget _meter() => Builder(
      builder: (context) => SizedBox(
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.colors.surfaceSunken, borderRadius: MyDataRadii.pill(kiwiLook)),
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 0.4,
            child: DecoratedBox(
                decoration: BoxDecoration(color: context.colors.accent, borderRadius: MyDataRadii.pill(kiwiLook))),
          ),
        ),
      ),
    );

/// The preview's three stat cards, then a plain card with an action.
Widget _gallery() => SizedBox(
      width: 760,
      child: CardGrid(children: [
        StatCard(
          icon: MyDataIcon.host,
          name: 'Storage',
          figure: '412 GB',
          caption: 'Example: of 1 TB on Home drive',
          child: _meter(),
        ),
        StatCard(
          icon: MyDataIcon.photo,
          iconTone: MyDataTone.success,
          name: 'Photos',
          figure: '18,240',
          caption: 'Example count. 126 added this week.',
          action: Button(label: 'Open myPhotos', onPressed: () {}),
        ),
        StatCard(
          icon: MyDataIcon.thisMac,
          iconTone: MyDataTone.info,
          name: 'Devices',
          figure: '3',
          caption: 'Example. All seen today.',
          action: Button(label: 'Add a device', onPressed: () {}),
        ),
        MyDataCard(
          icon: MyDataIcon.cloud,
          name: 'Backups',
          action: Button(label: 'Back up now', onPressed: () {}),
          child: const Text('Last backup finished this morning. Your photos and mail are copied to the Home drive.'),
        ),
      ]),
    );

List<Widget> _cards(int n) => [
      for (var i = 0; i < n; i++)
        MyDataCard(
            icon: MyDataIcon.importFile, name: 'Card $i', child: Text('Line ${'more ' * (i == 1 ? 30 : 1)}')),
    ];

/// A block that grows when told to, without its card or grid being rebuilt (as text does when a font
/// finishes loading).
class _Grows extends StatefulWidget {
  const _Grows({super.key});

  @override
  State<_Grows> createState() => _GrowsState();
}

class _GrowsState extends State<_Grows> {
  double height = 20;

  void grow() => setState(() => height = 80);

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

Widget _grid(int n, {double width = 760, bool entrance = true}) =>
    SizedBox(width: width, child: CardGrid(entrance: entrance, children: _cards(n)));

Finder _card(int i) => find.ancestor(of: find.text('Card $i'), matching: find.byType(MyDataCard));

double _opacity(WidgetTester tester, int i) =>
    tester.widget<Opacity>(find.ancestor(of: find.text('Card $i'), matching: find.byType(Opacity)).first).opacity;

double _rise(WidgetTester tester, int i) => tester
    .widget<Transform>(find.ancestor(of: find.text('Card $i'), matching: find.byType(Transform)).first)
    .transform
    .getTranslation()
    .y;

void main() {
  goldenMatrix('card', _gallery, size: const Size(808, 540));

  testWidgets('a card is surface, radius-lg, shadow-1 and space-5 padding, with no border', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        const SizedBox(
            width: 300, child: MyDataCard(icon: MyDataIcon.host, name: 'Storage', child: Text('Content')))));
    final context = tester.element(find.byType(MyDataCard));
    final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(MyDataCard), matching: find.byType(DecoratedBox)).first);
    final d = box.decoration.box;
    expect(d.color, context.colors.surface);
    expect(d.borderRadius, MyDataRadii.lg(kiwiLook));
    expect(d.boxShadow, context.shadows.shadow1);
    expect(d.border, isNull);
    expect(MyDataCard.padding(kiwiLook), const EdgeInsets.all(MyDataSpace.s5));
    final tile = tester.getTopLeft(find.byType(IconTile)) - tester.getTopLeft(find.byType(MyDataCard));
    expect(tile, const Offset(MyDataSpace.s5, MyDataSpace.s5));
  });

  testWidgets('the header is the icon tile and the name in body-strong; text in the content is body',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        const SizedBox(width: 300, child: MyDataCard(icon: MyDataIcon.host, iconTone: MyDataTone.info,
            name: 'Storage', child: Text('Content')))));
    final context = tester.element(find.byType(MyDataCard));
    expect(tester.widget<IconTile>(find.byType(IconTile)).tone, MyDataTone.info);
    final name = tester.widget<Text>(find.text('Storage'));
    expect(name.style, MyDataType.bodyStrong.copyWith(color: context.colors.ink));
    expect(tester.getTopLeft(find.text('Storage')).dx - tester.getTopRight(find.byType(IconTile)).dx,
        MyDataCard.headerGap(kiwiLook));
    final content = DefaultTextStyle.of(tester.element(find.text('Content')));
    expect(content.style.fontSize, MyDataType.body.fontSize);
    expect(content.style.color, context.colors.ink);
  });

  testWidgets('a stat card shows the figure in display-lg and the caption in caption, ink-muted',
      (tester) async {
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        const SizedBox(
            width: 300,
            child: StatCard(icon: MyDataIcon.photo, name: 'Photos', figure: '18,240', caption: '126 added this week.'))));
    final context = tester.element(find.byType(StatCard));
    expect(tester.widget<Text>(find.text('18,240')).style, MyDataType.displayLg.copyWith(color: context.colors.ink));
    expect(tester.widget<Text>(find.text('126 added this week.')).style,
        MyDataType.caption.copyWith(color: context.colors.inkMuted));
    // Name, then figure, then caption, top to bottom.
    expect(tester.getTopLeft(find.text('18,240')).dy, greaterThan(tester.getTopLeft(find.text('Photos')).dy));
    expect(tester.getTopLeft(find.text('126 added this week.')).dy,
        greaterThan(tester.getBottomLeft(find.text('18,240')).dy));
  });

  testWidgets('the action is pressed by tap and by keyboard, and is at least 44px tall', (tester) async {
    var presses = 0;
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
            width: 300,
            child: StatCard(
              icon: MyDataIcon.thisMac,
              name: 'Devices',
              figure: '3',
              caption: 'All seen today.',
              action: Button(label: 'Add a device', onPressed: () => presses++),
            ))));
    await tester.tap(find.text('Add a device'));
    expect(presses, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(presses, 2);
    expect(tester.getSize(find.byType(Button)).height, greaterThanOrEqualTo(MyDataSize.controlHeight));
    // The action keeps its own width at the leading edge rather than filling the card.
    expect(tester.getSize(find.byType(Button)).width, lessThan(300 - 2 * MyDataSpace.s5));
    expect(tester.getTopLeft(find.byType(Button)).dx - tester.getTopLeft(find.byType(StatCard)).dx, MyDataSpace.s5);
  });

  testWidgets('screen readers get the card as a group with its name as the heading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
            width: 300,
            child: MyDataCard(
                icon: MyDataIcon.cloud,
                name: 'Backups',
                action: Button(label: 'Back up now', onPressed: () {}), child: const Text('Done')))));
    expect(tester.getSemantics(find.text('Backups')), matchesSemantics(label: 'Backups', isHeader: true));
    expect(find.bySemanticsLabel('Back up now'), findsOneWidget);
    expect(find.bySemanticsLabel('Done'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a card inside a card fails in debug', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        const SizedBox(
            width: 400,
            child: MyDataCard(
                icon: MyDataIcon.importFile,
                name: 'Outer',
                child: StatCard(icon: MyDataIcon.photo, name: 'Inner', figure: '1', caption: 'Nested.')))));
    FlutterError.onError = previous;
    expect(errors.first.exception, isA<FlutterError>());
    expect('${errors.first.exception}', contains('inside another card'));
  });

  testWidgets('cards side by side in a grid are not nested', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _grid(3)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('CardGrid layout', () {
    testWidgets('a card whose content grows on its own is measured again, never cut off', (tester) async {
      final grows = GlobalKey<_GrowsState>();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 760,
            child: CardGrid(entrance: false, children: [
              const MyDataCard(icon: MyDataIcon.host, name: 'Card 0', child: Text('Short')),
              MyDataCard(icon: MyDataIcon.host, name: 'Card 1', child: _Grows(key: grows)),
            ]),
          )));
      final before = tester.getSize(_card(1)).height;
      grows.currentState!.grow();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(tester.getSize(_card(1)).height, greaterThan(before + 50));
      expect(tester.getSize(_card(0)).height, tester.getSize(_card(1)).height,
          reason: 'the row is stretched to its tallest again');
    });

    testWidgets('columns of at least 220px share the width, space-4 apart; a row is as tall as its tallest card',
        (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _grid(5, entrance: false)));
      final column = (760 - 2 * CardGrid.gap(kiwiLook)) / 3;
      for (var i = 0; i < 5; i++) {
        expect(tester.getSize(_card(i)).width, moreOrLessEquals(column));
      }
      expect(tester.getTopLeft(_card(1)).dx - tester.getTopRight(_card(0)).dx, moreOrLessEquals(CardGrid.gap(kiwiLook)));
      // Card 1 has the long text; cards 0 and 2 stretch to its height.
      final rowHeight = tester.getSize(_card(1)).height;
      expect(tester.getSize(_card(0)).height, rowHeight);
      expect(tester.getSize(_card(2)).height, rowHeight);
      // The second row starts space-4 below the first, back at the leading edge.
      expect(tester.getTopLeft(_card(3)).dy - tester.getBottomLeft(_card(0)).dy, moreOrLessEquals(CardGrid.gap(kiwiLook)));
      expect(tester.getTopLeft(_card(3)).dx, tester.getTopLeft(_card(0)).dx);
      // Cards in the second row are only as tall as their own content.
      expect(tester.getSize(_card(3)).height, lessThan(rowHeight));
    });

    testWidgets('fewer cards than columns share the whole width; a narrow grid is one column', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _grid(2, entrance: false)));
      expect(tester.getSize(_card(0)).width, moreOrLessEquals((760 - CardGrid.gap(kiwiLook)) / 2));

      await tester.pumpWidget(themedFrame(themeMatrix.first, _grid(3, width: 400, entrance: false)));
      for (var i = 0; i < 3; i++) {
        expect(tester.getSize(_card(i)).width, 400);
      }
      expect(tester.getTopLeft(_card(1)).dy - tester.getBottomLeft(_card(0)).dy, moreOrLessEquals(CardGrid.gap(kiwiLook)));
    });

    testWidgets('right to left fills each row from the right', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, Directionality(textDirection: TextDirection.rtl, child: _grid(2, entrance: false))));
      expect(tester.getTopRight(_card(0)).dx, greaterThan(tester.getTopRight(_card(1)).dx));
    });
  });

  group('CardGrid entrance', () {
    testWidgets('cards fade and rise 8px over base, 30ms apart; after the sixth they enter together',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _grid(8)));
      expect(_opacity(tester, 0), 0);
      expect(_rise(tester, 0), MyDataMotion.entranceRise);

      await tester.pump(MyDataMotion.entranceStagger);
      expect(_opacity(tester, 0), greaterThan(0));
      expect(_rise(tester, 0), lessThan(MyDataMotion.entranceRise));
      expect(_opacity(tester, 1), 0);

      await tester.pump(MyDataMotion.base - MyDataMotion.entranceStagger);
      expect(_opacity(tester, 0), moreOrLessEquals(1, epsilon: 1e-6));
      expect(_rise(tester, 0), moreOrLessEquals(0, epsilon: 1e-5));
      expect(_opacity(tester, 5), lessThan(1));
      // The seventh and eighth share the sixth's start.
      expect(_opacity(tester, 6), _opacity(tester, 5));
      expect(_opacity(tester, 7), _opacity(tester, 5));

      await tester.pump(MyDataMotion.entranceStagger * (MyDataMotion.entranceMaxStaggered - 1));
      for (var i = 0; i < 8; i++) {
        expect(_opacity(tester, i), 1);
        expect(_rise(tester, i), 0);
      }
      // The controller stops on the frame after it reaches the end.
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('with reduced motion every card fades in together over fast, without moving', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, _grid(3), reduceMotion: true));
      expect(_opacity(tester, 0), 0);
      await tester.pump(MyDataMotion.fast ~/ 2);
      final mid = _opacity(tester, 0);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      for (var i = 0; i < 3; i++) {
        expect(_opacity(tester, i), mid);
        expect(_rise(tester, i), 0);
      }
      await tester.pump(MyDataMotion.fast ~/ 2);
      for (var i = 0; i < 3; i++) {
        expect(_opacity(tester, i), 1);
      }
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('with the entrance off, cards show at once', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, _grid(3, entrance: false)));
      for (var i = 0; i < 3; i++) {
        expect(_opacity(tester, i), 1);
        expect(_rise(tester, i), 0);
      }
      expect(tester.hasRunningAnimations, isFalse);
    });

    for (final (enter, rises, plays) in [('none', false, false), ('fade', false, true), ('fade-rise', true, true)]) {
      testWidgets('a theme whose entrance is $enter: ${plays ? 'the cards fade${rises ? ' and rise' : ''}' : 'cards show at once'}',
          (tester) async {
        final json = jsonDecode(builtInThemeJson[ThemeLibrary.kiwiId]!) as Map<String, dynamic>;
        (json['motion'] as Map<String, dynamic>)['enter'] = enter;
        final look = ThemeLibrary.look(ThemeFile.fromJson(json, base: json), brightness: Brightness.light);
        await tester.pumpWidget(MaterialApp(theme: MyDataTheme.fromLook(look), home: Material(child: _grid(3))));
        await tester.pump(MyDataMotion.entranceStagger);
        expect(_opacity(tester, 0), plays ? lessThan(1) : 1);
        expect(_rise(tester, 0), rises ? greaterThan(0) : 0);
        await tester.pumpAndSettle();
        expect(_opacity(tester, 2), 1);
      });
    }

    testWidgets('rebuilding the grid makes no new animations: every card listens to the one controller',
        (tester) async {
      // Each derived animation (a CurvedAnimation, say) adds a listener to the controller that outlives the
      // build; the cards must share the controller itself instead.
      Set<Listenable> listenables() => {
            for (final w in tester.widgetList<AnimatedWidget>(find.descendant(
                of: find.byType(CardGrid),
                matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Entrance'))))
              w.listenable,
          };

      await tester.pumpWidget(themedFrame(themeMatrix.first, _grid(3)));
      final first = listenables();
      expect(first, hasLength(1));
      expect(first.single, isA<AnimationController>());
      for (var i = 0; i < 6; i++) {
        await tester.pumpWidget(themedFrame(themeMatrix[i % themeMatrix.length], _grid(3, width: 700.0 + i)));
        await tester.pump(MyDataMotion.entranceStagger);
        expect(listenables(), first);
      }
      await tester.pumpAndSettle();
      expect(listenables(), first);
    });

    testWidgets('a card keeps its state through the entrance', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          const SizedBox(width: 400, child: CardGrid(children: [MyDataCard(icon: MyDataIcon.importFile, name: 'Card 0', child: _Stateful())]))));
      final before = tester.state(find.byType(_Stateful));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(_Stateful)), same(before));
    });
  });
}

class _Stateful extends StatefulWidget {
  const _Stateful();
  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  Widget build(BuildContext context) => const Text('Kept');
}
