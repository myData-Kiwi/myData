// The run-time look (design/themes/ARCHITECTURE.md 3.1 and 3.3): MyDataTheme carries it, widgets read it
// through their context, and the Mac shell's theme is the System look in the Mac window.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/theme_file.dart';

void main() {
  test('MyDataTheme carries the look: Kiwi in the chosen colour, its colours and shadows as their own extensions', () {
    for (final b in Brightness.values) {
      final data = MyDataTheme.data('plum', b);
      final look = data.extension<MyDataLook>()!;
      expect(look.themeId, 'mydata.kiwi');
      expect(look.paletteId, 'plum');
      expect(look.frame, LookFrame.drawn);
      expect(look.brightness, b);
      expect(identical(data.extension<MyDataColors>(), look.colors), isTrue);
      expect(identical(data.extension<MyDataShadows>(), look.elevation.shadows), isTrue);
      expect(MyDataTheme.data('nonsense', b).extension<MyDataLook>()!.paletteId, 'kiwi');
    }
  });

  test('looks are resolved once and kept', () {
    expect(identical(ThemeLibrary.kiwiLook('dusk', Brightness.dark), ThemeLibrary.kiwiLook('dusk', Brightness.dark)),
        isTrue);
  });

  test('the Mac shell\'s theme is the System look, with the system\'s colours and no palette', () {
    for (final b in Brightness.values) {
      final system = b == Brightness.dark ? MyDataMacColors.dark : MyDataMacColors.light;
      // Plum: none of the host's colour may show through in the System look.
      final data = MacTheme.data('plum', b, system);
      final look = data.extension<MyDataLook>()!;
      final mac = data.extension<MyDataMacColors>()!;
      expect(look.frame, LookFrame.system);
      expect(look.themeId, ThemeLibrary.systemId);
      expect(look.paletteId, isNull);
      expect(identical(look.colors, data.extension<MyDataColors>()), isTrue);
      final c = look.colors;
      expect(c.accent, mac.accent);
      expect(c.link, mac.accent);
      expect(c.selection, mac.accent);
      expect(c.onSelection, mac.onAccent);
      expect(c.selectionInactive, mac.selectionInactive);
      expect(c.focus, mac.focusRing);
      expect(c.focusOnDanger, mac.focusRing);
      expect(c.sidebar, mac.sidebarBackground);
      expect(c.toolbar, mac.windowBackground);
      expect(c.edge, mac.label);
    }
  });

  test('every built-in resolves in both brightnesses, System with no palette', () {
    for (final theme in ThemeLibrary.builtIns) {
      for (final b in Brightness.values) {
        for (final platform in [TargetPlatform.macOS, TargetPlatform.linux, TargetPlatform.android]) {
          final look = ThemeLibrary.look(theme, brightness: b, platform: platform);
          expect(look.themeId, theme.id);
          expect(look.brightness, b);
          if (theme.frame == ThemeFrame.system) {
            expect(look.frame, LookFrame.system);
            expect(look.paletteId, isNull);
            // Off the Mac, System is Kiwi in its own colour until each platform's pass.
            expect(look.colors.accent, ThemeLibrary.kiwiLook(null, b).colors.accent);
          } else {
            expect(look.paletteId, theme.defaultPaletteId);
          }
        }
      }
    }
    expect(ThemeLibrary.system.palette(null), isNull);
    expect(ThemeLibrary.system.palette('kiwi'), isNull);
  });

  test('any theme\'s look is resolved once per file and kept; a file read again is resolved again', () {
    ThemeFile read() => ThemeFile.fromJson(
        {...ThemeLibrary.kiwi.json, 'id': '0b6e2f3a-1c4d-4e5f-8a9b-0c1d2e3f4a5b'}, base: ThemeLibrary.kiwi.json);
    final theme = read();
    final a = ThemeLibrary.look(theme, paletteId: 'rose', brightness: Brightness.dark);
    expect(identical(a, ThemeLibrary.look(theme, paletteId: 'rose', brightness: Brightness.dark)), isTrue);
    expect(identical(a, ThemeLibrary.look(theme, paletteId: 'rose', brightness: Brightness.light)), isFalse);
    expect(identical(a, ThemeLibrary.look(read(), paletteId: 'rose', brightness: Brightness.dark)), isFalse);
  });

  test('a theme change cross-fades colours and sizes and switches the rest half way', () {
    final a = ThemeLibrary.kiwiLook('kiwi', Brightness.light);
    final b = MyDataLook.fallback(Brightness.dark).copyWith(frame: LookFrame.system, themeId: 'mydata.system');
    final mid = a.lerp(b, 0.4);
    expect(mid.frame, LookFrame.drawn);
    expect(a.lerp(b, 0.6).frame, LookFrame.system);
    expect(mid.colors.bg, Color.lerp(a.colors.bg, b.colors.bg, 0.4));
    expect(a.lerp(b, 0).colors.ink, a.colors.ink);
  });

  test('the shape gives each corner style its border', () {
    final kiwi = MyDataLook.fallback(Brightness.light).shape;
    expect(kiwi.border(kiwi.lg), RoundedRectangleBorder(borderRadius: BorderRadius.circular(kiwi.lg)));
    for (final (corners, type) in [
      (CornerStyle.continuous, RoundedSuperellipseBorder),
      (CornerStyle.cut, BeveledRectangleBorder),
      (CornerStyle.square, RoundedRectangleBorder),
    ]) {
      final s = MyDataShape.of(ShapeSpec(
          corners: corners, xs: 2, sm: 4, md: 6, lg: 8, xl: 10, pillControls: false, cutSize: 6));
      expect(s.border(s.lg).runtimeType, type);
      if (corners == CornerStyle.square) expect([s.lg, s.control, s.pill], [0, 0, 0]);
      if (corners == CornerStyle.cut) expect(s.control, 4, reason: 'controls match radius.sm');
    }
  });

  testWidgets('widgets read the look through their context, also where it may not be depended on', (tester) async {
    late double space;
    late TextStyle body;
    late double radius;
    late Duration fast;
    late MyDataLook inInit;
    await tester.pumpWidget(MaterialApp(
      theme: MyDataTheme.data('graphite', Brightness.light),
      home: Builder(builder: (context) {
        space = context.space(4);
        body = context.typeScale.body;
        radius = context.radius.lg;
        fast = context.motion.fast;
        return _ReadsInInitState(onRead: (l) => inInit = l);
      }),
    ));
    expect(space, MyDataSpace.s4);
    expect(body, MyDataType.body);
    expect(radius, MyDataRadius.lg);
    expect(fast, MyDataMotion.fast);
    expect(inInit.paletteId, 'graphite');
  });

  testWidgets('outside any MyDataTheme the look is Kiwi\'s fallback, never missing', (tester) async {
    late MyDataLook look;
    await tester.pumpWidget(Builder(builder: (context) {
      look = context.look;
      return const SizedBox();
    }));
    expect(look.themeId, ThemeLibrary.kiwiId);
    expect(look.paletteId, 'kiwi');
  });

  testWidgets('the System look is drawn only in the Mac window: context.type maps roles to the Mac\'s styles there',
      (tester) async {
    late TextStyle mac, branded;
    late bool window, system;
    await tester.pumpWidget(MaterialApp(
      theme: MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light),
      home: Builder(builder: (context) {
        window = MacWindow.of(context);
        system = context.isSystemLook;
        mac = context.type(MyDataTypeRole.body);
        return Theme(
          data: MyDataTheme.data('kiwi', Brightness.light),
          child: Builder(builder: (context) {
            branded = context.type(MyDataTypeRole.body);
            return const SizedBox();
          }),
        );
      }),
    ));
    expect(window, isTrue);
    expect(system, isTrue);
    expect(mac, MyDataMacType.body);
    expect(branded, MyDataType.body);
  });
  group('shape (phase 3)', () {
    MyDataShape shape(CornerStyle corners) => MyDataShape(
        corners: corners, xs: 4, sm: 8, md: 12, lg: 20, xl: 28, control: 999, pill: 999, cutSize: 10);
    final r = BorderRadius.circular(20);

    test('each corner style draws its own outline', () {
      expect(shape(CornerStyle.round).outline(r), isA<RoundedRectangleBorder>());
      expect(shape(CornerStyle.continuous).outline(r), isA<RoundedSuperellipseBorder>());
      expect(shape(CornerStyle.cut).outline(r), isA<BeveledRectangleBorder>());
      final square = shape(CornerStyle.square).outline(r) as RoundedRectangleBorder;
      expect(square.borderRadius, BorderRadius.zero);
    });

    test('a cut is the cut size, never more than the radius it replaces, and a square corner stays square', () {
      final cut = shape(CornerStyle.cut);
      expect((cut.outline(r) as BeveledRectangleBorder).borderRadius, BorderRadius.circular(10));
      expect((cut.outline(BorderRadius.circular(4)) as BeveledRectangleBorder).borderRadius, BorderRadius.circular(4));
      final top = cut.outline(const BorderRadius.vertical(top: Radius.circular(20))) as BeveledRectangleBorder;
      expect((top.borderRadius as BorderRadius).bottomLeft, Radius.zero);
    });

    test('decorate keeps a box for round and square corners, and draws the others as shapes', () {
      final box = BoxDecoration(color: const Color(0xFF00FF00), borderRadius: r, boxShadow: const [BoxShadow()]);
      expect(identical(shape(CornerStyle.round).decorate(box), box), isTrue);
      expect(identical(shape(CornerStyle.square).decorate(box), box), isTrue);
      final cut = shape(CornerStyle.cut).decorate(box) as ShapeDecoration;
      expect(cut.color, box.color);
      expect(cut.shadows, box.boxShadow);
      expect(cut.shape, isA<BeveledRectangleBorder>());
      // A border on every side goes onto the shape; an underline stays a box.
      final edged = shape(CornerStyle.continuous)
          .decorate(BoxDecoration(borderRadius: r, border: Border.all(width: 2))) as ShapeDecoration;
      expect((edged.shape as OutlinedBorder).side.width, 2);
      final underline = BoxDecoration(borderRadius: r, border: const Border(bottom: BorderSide()));
      expect(identical(shape(CornerStyle.cut).decorate(underline), underline), isTrue);
    });

    test('a ring around a shape keeps an even gap: round corners grow by the gap, a chamfer by (2 - √2) of it', () {
      expect(shape(CornerStyle.round).grow(r, 3).topLeft, const Radius.circular(23));
      expect(shape(CornerStyle.cut).grow(r, 3).topLeft.x, closeTo(10 + 3 * 0.5858, 0.001));
      expect(shape(CornerStyle.cut).grow(BorderRadius.zero, 3).topLeft, Radius.zero);
    });
  });


  group('borders (phase 3)', () {
    const spec = BordersSpec(
      width: BorderWidth.two,
      style: BorderStyleKind.doubleLine,
      colour: BorderColour.edge,
      cards: true,
      controls: false,
      separators: Separators.inset,
      titleRule: TitleRule.doubleLine,
    );

    test('a double rule is three widths tall; none takes no room', () {
      final e = MyDataEdges(spec, colour: const Color(0xFF000000));
      expect(e.width, 2);
      expect(e.separatorExtent, 6);
      expect(e.titleRuleExtent, 6);
      expect(e.card, isNotNull);
      expect(e.controls, isFalse);
      const none = BordersSpec(
        width: BorderWidth.one,
        style: BorderStyleKind.solid,
        colour: BorderColour.line,
        cards: false,
        controls: false,
        separators: Separators.none,
        titleRule: TitleRule.none,
      );
      final n = MyDataEdges(none, colour: const Color(0xFF000000));
      expect(n.separatorExtent, 0);
      expect(n.titleRuleExtent, 0);
      expect(n.card, isNull);
    });

    test('the colour is the palette\'s, and follows a look whose colours are replaced (the Mac shell)', () {
      final look = MyDataLook.fallback(Brightness.light);
      expect(look.edges.colour, look.colors.line);
      final system = look.asSystem(colors: look.colors.copyWith(line: const Color(0xFF123456)));
      expect(system.edges.colour, const Color(0xFF123456));
    });

    test('Kiwi as drawn today: no card or control edges, full-width separators in line, no title rule', () {
      for (final b in Brightness.values) {
        final e = ThemeLibrary.kiwiLook(null, b).edges;
        expect(e.card, isNull);
        expect(e.controls, isFalse);
        expect(e.separators, Separators.full);
        expect(e.titleRule, TitleRule.none);
        expect(e.colour, ThemeLibrary.kiwiLook(null, b).colors.line);
        // Increased contrast outlines every control (ARCHITECTURE.md 2.3).
        expect(ThemeLibrary.kiwiLook(null, b, increasedContrast: true).edges.controls, isTrue);
      }
    });
  });
}

class _ReadsInInitState extends StatefulWidget {
  const _ReadsInInitState({required this.onRead});
  final ValueChanged<MyDataLook> onRead;

  @override
  State<_ReadsInInitState> createState() => _ReadsInInitStateState();
}

class _ReadsInInitStateState extends State<_ReadsInInitState> {
  @override
  void initState() {
    super.initState();
    widget.onRead(context.lookNow);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();

}
