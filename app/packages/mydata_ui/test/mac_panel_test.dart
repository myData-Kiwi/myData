// A pane as a panel on the window's ground (lib/src/mac/mac_shell.dart, MacPanel): in a theme whose lists
// are bordered panels with a slab's depth (Retro Desktop's bevel, Brutalist's offset shadow) the pane is the
// theme's card on the ground, the ground shows round it and the column ground is the window's; elsewhere,
// and in System, the pane is drawn as it is on `content-background`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void main() {
  for (final (slug, panel) in [
    ('retro-desktop', true),
    ('brutalist', true),
    ('high-contrast', false),
    ('sticker', false),
    (null, false),
  ]) {
    testWidgets('a pane is ${panel ? '' : 'not '}a panel in ${slug ?? 'System'}', (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: slug == null
            ? MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light)
            : MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light),
        themeAnimationDuration: Duration.zero,
        home: const Scaffold(body: MacContentGround(child: MacPanel(child: Text('Ava Fictional')))),
      ));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Ava Fictional'));
      expect(MacPanel.shown(context), panel);
      expect(MacContentGround.drawsMaterial(context.look), slug == 'retro-desktop' || slug == 'brutalist');
      final card = find.ancestor(of: find.text('Ava Fictional'), matching: find.byType(CardEdge));
      expect(card, panel ? findsOneWidget : findsNothing);
      if (!panel) return;
      // The panel is the theme's card, its gutter in from the pane's edges, with the theme's resting shadow.
      final fill = tester
          .widgetList<DecoratedBox>(find.ancestor(of: card, matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .firstWhere((d) => d.isBox && d.box.color == context.colors.surface)
          .box;
      expect(fill.boxShadow, context.shadows.shadow1);
      expect(fill.boxShadow, isNotEmpty);
      expect(tester.getTopLeft(card), const Offset(MacPanel.gutter, MacPanel.gutter));
    });
  }
}
