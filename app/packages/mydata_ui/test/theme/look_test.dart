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

  test('the Mac shell\'s theme is the System look, with the system\'s colours', () {
    final data = MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light);
    final look = data.extension<MyDataLook>()!;
    expect(look.frame, LookFrame.system);
    expect(look.themeId, ThemeLibrary.systemId);
    expect(identical(look.colors, data.extension<MyDataColors>()), isTrue);
    expect(look.colors.accent, data.extension<MyDataMacColors>()!.accent);
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
    late bool window;
    await tester.pumpWidget(MaterialApp(
      theme: MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light),
      home: Builder(builder: (context) {
        window = MacWindow.of(context);
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
