// The Mac frame's pieces in mydata_ui: its theme and the shared widgets' Mac branch (its icons: theme/icons_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

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
