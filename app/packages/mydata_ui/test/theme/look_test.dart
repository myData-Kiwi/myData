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
