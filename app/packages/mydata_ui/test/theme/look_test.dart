// The run-time look (design/themes/ARCHITECTURE.md 3.1 and 3.3): MyDataTheme carries it, widgets read it
// through their context, and the Mac shell's theme is the System look in the Mac window.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';
import 'package:mydata_ui/src/theme/theme_file.dart';

import 'designed_themes.dart';

void main() {
  test('MyDataTheme carries the look: the named theme, its colours and shadows as their own extensions', () {
    for (final b in Brightness.values) {
      final data = MyDataTheme.data('plum', b);
      final look = data.extension<MyDataLook>()!;
      expect(look.themeId, 'mydata.journal', reason: 'plum is a palette of Journal now');
      expect(look.paletteId, 'plum');
      expect(look.frame, LookFrame.drawn);
      expect(look.brightness, b);
      expect(identical(data.extension<MyDataColors>(), look.colors), isTrue);
      expect(identical(data.extension<MyDataShadows>(), look.elevation.shadows), isTrue);
      expect(MyDataTheme.data('nonsense', b).extension<MyDataLook>()!.paletteId, 'kiwi');
      expect(MyDataTheme.data('hairline', b).extension<MyDataLook>()!.paletteId, 'graphite');
      expect(MyDataTheme.data('mydata.sticker', b).extension<MyDataLook>()!.themeId, 'mydata.sticker');
    }
  });

  test('looks are resolved once and kept', () {
    ThemeData frosted() => MyDataTheme.dataFor(const ThemeChoice('mydata.frosted', 'aurora'), Brightness.dark);
    expect(identical(frosted().extension<MyDataLook>(), frosted().extension<MyDataLook>()), isTrue);
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
            expect(look.colors.accent, ThemeLibrary.look(ThemeLibrary.kiwi, brightness: b).colors.accent);
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
    final a = ThemeLibrary.look(theme, paletteId: 'sky', brightness: Brightness.dark);
    expect(identical(a, ThemeLibrary.look(theme, paletteId: 'sky', brightness: Brightness.dark)), isTrue);
    expect(identical(a, ThemeLibrary.look(theme, paletteId: 'sky', brightness: Brightness.light)), isFalse);
    expect(identical(a, ThemeLibrary.look(read(), paletteId: 'sky', brightness: Brightness.dark)), isFalse);
  });

  test('a theme change cross-fades colours and sizes and switches the rest half way', () {
    final a = ThemeLibrary.look(ThemeLibrary.kiwi, brightness: Brightness.light);
    final b = MyDataLook.fallback(Brightness.dark).copyWith(frame: LookFrame.system, themeId: 'mydata.system');
    final mid = a.lerp(b, 0.4);
    expect(mid.frame, LookFrame.drawn);
    expect(a.lerp(b, 0.6).frame, LookFrame.system);
    expect(mid.colors.bg, Color.lerp(a.colors.bg, b.colors.bg, 0.4));
    expect(a.lerp(b, 0).colors.ink, a.colors.ink);
  });

  test('the shape gives each corner style its border', () {
    final kiwi = MyDataLook.fallback(Brightness.light).shape;
    expect(kiwi.border(kiwi.lg), RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(kiwi.lg)));
    for (final (corners, type) in [
      (CornerStyle.round, RoundedRectangleBorder),
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
      theme: MyDataTheme.dataFor(const ThemeChoice('mydata.kiwi', 'sky'), Brightness.light),
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
    expect(inInit.paletteId, 'sky');
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

    test('increased contrast outlines every control at 3:1 or more against surface and bg, in every palette', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
      }

      final failures = <String>[];
      for (final id in drawnBuiltIns) {
        final theme = designedTheme(id);
        for (final palette in theme.palettes) {
          for (final b in Brightness.values) {
            final look = ThemeLibrary.look(theme,
                paletteId: palette.id, brightness: b, increasedContrast: true, platform: TargetPlatform.linux);
            final border = MyDataEdgesPaint.control(look)!;
            for (final (name, ground) in [('surface', look.colors.surface), ('bg', look.colors.bg)]) {
              final r = contrast(border.top.color, ground);
              if (r < 3) failures.add('$id ${palette.id} ${b.name} on $name: ${r.toStringAsFixed(2)}');
            }
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('dashes are one path, fitted so a closed outline has no odd dash at its seam', () {
      final closed = MyDataEdgesPaint.dashes(Path()..addRect(const Rect.fromLTWH(0, 0, 101, 52)), 1);
      final lengths = [for (final m in closed.computeMetrics()) m.length];
      expect(lengths.length, (306 / 5).round());
      expect(lengths.reduce(math.max) - lengths.reduce(math.min), lessThan(0.01), reason: 'every dash alike');
      final open = MyDataEdgesPaint.dashes(Path()..moveTo(0, 0)..lineTo(100, 0), 1);
      final bounds = open.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, closeTo(100, 0.01), reason: 'an open line ends on a dash');
    });

    test('a control is never outlined in the faint line: line-strong stands in', () {
      // A theme (a custom one, say) that outlines controls in `line`.
      final json = jsonDecode(builtInThemeJson[ThemeLibrary.kiwiId]!) as Map<String, dynamic>;
      (json['borders'] as Map<String, dynamic>).addAll({'controls': true, 'colour': 'line'});
      for (final b in Brightness.values) {
        final outlined = ThemeLibrary.look(ThemeFile.fromJson(json, base: json), brightness: b, platform: TargetPlatform.linux);
        expect(MyDataEdgesPaint.control(outlined)!.top.color, outlined.colors.lineStrong, reason: b.name);
      }
      final look = MyDataLook.fallback(Brightness.light);
      expect(look.edges.colour, look.colors.line);
      expect(look.edges.controlColour, look.colors.lineStrong);
      final system = look.asSystem(colors: look.colors.copyWith(lineStrong: const Color(0xFF123456)));
      expect(system.edges.controlColour, const Color(0xFF123456));
    });

    test('Kiwi as drawn today: no card or control edges, full-width separators in line, no title rule', () {
      for (final b in Brightness.values) {
        final e = ThemeLibrary.look(ThemeLibrary.kiwi, brightness: b).edges;
        expect(e.card, isNull);
        expect(e.controls, isFalse);
        expect(e.separators, Separators.full);
        expect(e.titleRule, TitleRule.none);
        expect(e.colour, ThemeLibrary.look(ThemeLibrary.kiwi, brightness: b).colors.line);
        // Increased contrast outlines every control (ARCHITECTURE.md 2.3).
        expect(ThemeLibrary.look(ThemeLibrary.kiwi, brightness: b, increasedContrast: true).edges.controls, isTrue);
      }
    });
  });

  group('elevation (phase 3)', () {
    MyDataElevation of(ElevationStyle style, {bool collapse = false}) => MyDataElevation.of(
          ElevationSpec(style: style, strength: 1, offset: 4, collapse: collapse),
          shadow: const Color(0xFF000000),
          accent: const Color(0xFF00AA00),
          surface: const Color(0xFFFFFFFF),
          ink: const Color(0xFF111111),
          dark: false,
        );

    test('hard drops straight down, offset and bevel down and to the right, with no blur', () {
      expect(of(ElevationStyle.hard).control.single.offset, const Offset(0, 4));
      expect(of(ElevationStyle.hard).control.single.blurRadius, 0);
      expect(of(ElevationStyle.offset).control.single.offset, const Offset(4, 4));
      expect(of(ElevationStyle.bevel).control.single.offset, const Offset(4, 4));
      expect(of(ElevationStyle.bevel).bevel, isNotNull);
      expect(of(ElevationStyle.hard).shadows.shadow1, of(ElevationStyle.hard).control);
    });

    test('soft and none put nothing under controls; glow only under the primary', () {
      expect(of(ElevationStyle.soft).controlShadows(primary: true), isEmpty);
      expect(of(ElevationStyle.none).controlShadows(primary: true), isEmpty);
      expect(of(ElevationStyle.glow).controlShadows(), isEmpty);
      expect(of(ElevationStyle.glow).controlShadows(primary: true), isNotEmpty);
      expect(of(ElevationStyle.glow).shadows.shadow1, isEmpty, reason: 'never on cards');
    });

    test('collapse drops a pressed control\'s shadow; without it the shadow stays', () {
      expect(of(ElevationStyle.hard, collapse: true).controlShadows(pressed: true), isEmpty);
      expect(of(ElevationStyle.hard).controlShadows(pressed: true), isNotEmpty);
      expect(of(ElevationStyle.hard, collapse: true).sink, const Offset(0, 4));
      // A sinking control drops its shadow even without collapse, or the shadow would sink with it.
      expect(of(ElevationStyle.hard).controlShadows(pressed: true, sinks: true), isEmpty);
      expect(of(ElevationStyle.hard).controlShadows(sinks: true), isNotEmpty);
    });

    test('a bevel\'s light line is lifted to 1.5:1 against its fill where it can reach it', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
      }

      for (final b in Brightness.values) {
        final look = ThemeLibrary.look(ThemeLibrary.kiwi, brightness: b);
        final bevel = MyDataElevation.of(
          const ElevationSpec(style: ElevationStyle.bevel, strength: 1, offset: 4, collapse: false),
          shadow: look.colors.shadow,
          accent: look.colors.accent,
          surface: look.colors.surface,
          ink: look.colors.ink,
          dark: b == Brightness.dark,
        ).bevel!;
        for (final fill in [look.colors.accent, look.colors.danger]) {
          final lifted = BevelPainter.liftedLight(bevel.light, fill);
          if (contrast(bevel.light.withValues(alpha: 1), fill) >= BevelPainter.lightContrast) {
            expect(contrast(lifted, fill), greaterThanOrEqualTo(BevelPainter.lightContrast), reason: '$b $fill');
          }
        }
      }
    });

    test('Kiwi as drawn today: soft, nothing under controls', () {
      final e = ThemeLibrary.look(ThemeLibrary.kiwi, brightness: Brightness.light).elevation;
      expect(e.style, ElevationStyle.soft);
      expect(e.controlShadows(primary: true), isEmpty);
      expect(e.bevel, isNull);
    });
  });

  group('density floors (phase 3)', () {
    setUp(() => MyDataDensity.debugFloor = null);
    tearDown(() => MyDataDensity.debugFloor = MyDataDensity.desktopFloor);

    ThemeFile small() {
      final json = jsonDecode(builtInThemeJson[ThemeLibrary.kiwiId]!) as Map<String, dynamic>;
      json['density'] = {
        'desktop': {'control': 24, 'row': 24, 'icon': 14, 'space': 0.75},
        'phone': {'control': 24, 'row': 24, 'icon': 14, 'space': 0.75},
      };
      return ThemeFile.fromJson(json, base: json);
    }

    test('no file goes under the platform floor: 24 on a desktop, 44 on iOS, 48 on Android', () {
      for (final (platform, floor) in [
        (TargetPlatform.macOS, 24.0),
        (TargetPlatform.linux, 24.0),
        (TargetPlatform.windows, 24.0),
        (TargetPlatform.iOS, 44.0),
        (TargetPlatform.android, 48.0),
      ]) {
        final d = ThemeLibrary.look(small(), brightness: Brightness.light, platform: platform).density;
        expect(d.controlHeight, floor, reason: platform.name);
        expect(d.rowHeight, floor, reason: platform.name);
        expect(d.controlHeightCompact, floor, reason: platform.name);
        expect(d.minTarget, floor, reason: platform.name);
      }
    });

    test('Kiwi keeps its 44 on a desktop and iOS, and rises to 48 on Android', () {
      // A fresh file: the library keeps looks it resolved under the tests' held floor.
      final json = jsonDecode(builtInThemeJson[ThemeLibrary.kiwiId]!) as Map<String, dynamic>;
      final kiwi = ThemeFile.fromJson(json, base: json);
      expect(ThemeLibrary.look(kiwi, brightness: Brightness.light, platform: TargetPlatform.macOS)
          .density.controlHeight, 44);
      expect(ThemeLibrary.look(kiwi, brightness: Brightness.light, platform: TargetPlatform.iOS)
          .density.controlHeight, 44);
      final android = ThemeLibrary.look(kiwi, brightness: Brightness.light, platform: TargetPlatform.android);
      expect(android.density.controlHeight, 48);
      expect(android.density.rowHeight, 56);
    });

    testWidgets('a finger on a desktop raises every target to 44; a mouse puts them back', (tester) async {
      final look = ThemeLibrary.look(small(), brightness: Brightness.light, platform: TargetPlatform.linux);
      late double height;
      await tester.pumpWidget(MaterialApp(
        theme: MyDataTheme.fromLook(look),
        home: MyDataAccessibilityScope(
          child: Builder(builder: (context) {
            height = context.density.controlHeight;
            return const SizedBox.expand();
          }),
        ),
      ));
      expect(height, 24);
      await tester.tapAt(const Offset(10, 10), kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(height, 44);
      await tester.tapAt(const Offset(10, 10), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(height, 24);
    });
  });

  group('motion (phase 3)', () {
    MyDataMotionSpec of(MotionPersonality p, {double scale = 1, PressStyle press = PressStyle.dimScale, EnterStyle enter = EnterStyle.fadeRise}) =>
        MyDataMotionSpec.of(MotionSpec(personality: p, scale: scale, press: press, enter: enter));

    test('standard is motion.md; calm is longer, crisp shorter, none takes no time', () {
      final standard = of(MotionPersonality.standard);
      expect(standard.fast, MyDataMotion.fast);
      expect(standard.base, MyDataMotion.base);
      expect(standard.slow, MyDataMotion.slow);
      expect(of(MotionPersonality.calm).base, greaterThan(standard.base));
      expect(of(MotionPersonality.crisp).base, lessThan(standard.base));
      final none = of(MotionPersonality.none);
      expect([none.fast, none.base, none.slow, none.springDuration], everyElement(Duration.zero));
    });

    test('each personality springs its own way, ends at exactly 1, and reduced motion does not spring', () {
      double peak(Curve c) => [for (var i = 0; i <= 200; i++) c.transform(i / 200)].reduce(math.max);
      final calm = of(MotionPersonality.calm).springCurve;
      final lively = of(MotionPersonality.lively).springCurve;
      expect(peak(calm), lessThanOrEqualTo(1.0 + 1e-9), reason: 'calm has no overshoot');
      expect(peak(lively), greaterThan(peak(of(MotionPersonality.standard).springCurve)), reason: 'lively bounces');
      // 100 ms in: crisp is further along than calm.
      double at(MotionPersonality p) => of(p).springCurve.transform(100 / of(p).springDuration.inMilliseconds);
      expect(at(MotionPersonality.crisp), greaterThan(at(MotionPersonality.calm)), reason: 'crisp gets there sooner');
      for (final p in MotionPersonality.values) {
        final m = of(p);
        expect(m.springCurve.transform(1), 1, reason: p.name);
        if (p != MotionPersonality.none) {
          expect(m.springCurve.transform(0.999), closeTo(1, 0.02), reason: '${p.name}: no jump at the end');
        }
        expect(identical(m.springCurve, m.springCurve), isTrue, reason: 'made once');
        expect(m.reduced.springCurve, m.standard, reason: p.name);
      }
    });

    test('scale multiplies every duration and slow stops at 500 ms', () {
      expect(of(MotionPersonality.standard, scale: 0.5).fast, MyDataMotion.fast * 0.5);
      expect(of(MotionPersonality.calm, scale: 1.5).slow, const Duration(milliseconds: 500));
    });

    test('press styles: dim-scale dims and shrinks, dim only dims, none, sink and invert neither', () {
      expect(of(MotionPersonality.standard).pressScale, MyDataMotion.pressScale);
      expect(of(MotionPersonality.standard, press: PressStyle.dim).pressScale, 1);
      expect(of(MotionPersonality.standard, press: PressStyle.dim).pressOpacity, MyDataMotion.pressOpacity);
      for (final p in [PressStyle.none, PressStyle.sink, PressStyle.invert]) {
        expect(of(MotionPersonality.standard, press: p).pressScale, 1, reason: p.name);
        expect(of(MotionPersonality.standard, press: p).pressOpacity, 1, reason: p.name);
      }
      expect(of(MotionPersonality.standard, enter: EnterStyle.fade).entranceRise, 0);
    });

    test('reduced motion: every personality is a fast fade with nothing moving; none stays nothing', () {
      for (final p in MotionPersonality.values) {
        for (final press in PressStyle.values) {
          final r = of(p, press: press).reduced;
          expect([r.base, r.slow, r.springDuration], everyElement(lessThanOrEqualTo(r.fast)), reason: '$p $press');
          expect(r.pressScale, 1);
          expect(r.entranceRise, 0);
          expect(r.sheetDrop, 0);
          expect(r.press, isNot(anyOf(PressStyle.sink, PressStyle.dimScale)));
          if (p == MotionPersonality.none) expect(r.fast, Duration.zero);
        }
      }
    });

    testWidgets('context.motion is the reduced form while the system reduces motion', (tester) async {
      late MyDataMotionSpec motion;
      await tester.pumpWidget(MaterialApp(
        theme: MyDataTheme.fromLook(MyDataLook.fallback(Brightness.light)),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(builder: (context) {
            motion = context.motion;
            return const SizedBox();
          }),
        ),
      ));
      expect(motion.base, MyDataMotion.fast);
      expect(motion.pressScale, 1);
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
