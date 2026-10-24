// A pane as a panel on the window's ground (lib/src/mac/mac_shell.dart, MacPanel): in a theme whose lists
// are bordered panels with a slab's depth (Retro Desktop's bevel, Brutalist's offset shadow) the pane is the
// theme's card on the ground, the ground shows round it and the column ground is the window's; elsewhere,
// and in System, the pane is drawn as it is on `content-background`.
import 'package:flutter/gestures.dart' show kPressTimeout;
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

  // Where the panes are slabs, the Mac controls and form groups are too: a toolbar item has the theme's drop
  // under it, gone while it is pressed (Brutalist collapses it) and on a disabled item, and a form's group
  // its resting shadow. High Contrast draws neither.
  for (final (slug, slab) in [('brutalist', true), ('high-contrast', false)]) {
    testWidgets('toolbar items and form groups ${slab ? 'are' : 'are not'} slabs in $slug', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light),
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: Column(children: [
            MacToolbarButton.text(text: 'Edit', label: 'Edit', onPressed: () {}),
            MacToolbarButton.text(text: 'Delete', label: 'Delete', onPressed: null, disabledReason: 'Nothing chosen'),
            const Expanded(child: MacForm(children: [MacFormSection(heading: 'Group', rows: [MacFormRow(title: 'One')])])),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('One'));
      List<BoxShadow>? shadowOf(String text) => tester
          .widgetList<AnimatedContainer>(find.ancestor(of: find.text(text), matching: find.byType(AnimatedContainer)))
          .first
          .decoration
          .box
          .boxShadow;
      final drop = context.look.elevation.controlShadows();
      expect(shadowOf('Edit'), slab ? drop : isEmpty);
      if (slab) expect(drop, isNotEmpty);
      expect(shadowOf('Delete'), isNull);
      final gesture = await tester.startGesture(tester.getCenter(find.text('Edit')));
      await tester.pump(kPressTimeout + const Duration(milliseconds: 50));
      expect(shadowOf('Edit'), isEmpty, reason: 'a press collapses the drop');
      await gesture.up();
      await tester.pumpAndSettle();
      final group = tester
          .widgetList<DecoratedBox>(find.ancestor(of: find.text('One'), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .firstWhere((d) => d.isBox && d.box.color == MacFormSection.fill(context))
          .box;
      expect(group.boxShadow, slab ? context.shadows.shadow1 : isEmpty);
    });
  }
}
