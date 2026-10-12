import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void main() {
  goldenMatrix(
    'primitives',
    () => Builder(
      builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: MyDataSpace.s3, children: [
          for (final t in MyDataTone.values) IconTile(icon: Icons.folder_outlined, tone: t),
        ]),
        const SizedBox(height: MyDataSpace.s4),
        Text('Your data, kept at home', style: MyDataType.displayLg.copyWith(color: context.colors.ink)),
        Text('Each app works by itself and reads the data your host keeps.',
            style: MyDataType.body.copyWith(color: context.colors.inkMuted)),
        Text('192.168.1.20', style: MyDataType.mono.copyWith(color: context.colors.ink)),
        const SizedBox(height: MyDataSpace.s4),
        const Row(children: [KiwiTile(size: 72), SizedBox(width: MyDataSpace.s4), KiwiLoader()]),
      ]),
    ),
    reduceMotion: true,
  );

  testWidgets('Pressable: Enter activates it, Tab reaches it, disabled ignores everything', (tester) async {
    var taps = 0;
    await tester.pumpWidget(themedFrame(themeMatrix.first, Column(children: [
      Pressable(onPressed: () => taps++, borderRadius: MyDataRadii.control, child: const SizedBox(width: 80, height: 44)),
      const Pressable(onPressed: null, borderRadius: MyDataRadii.control, child: SizedBox(width: 80, height: 44)),
    ])));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    await tester.tap(find.byType(Pressable).first);
    expect(taps, 2);
    await tester.tap(find.byType(Pressable).last, warnIfMissed: false);
    expect(taps, 2);
  });
}
