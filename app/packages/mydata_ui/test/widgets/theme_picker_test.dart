import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAnimatedOpacity;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// Holds the current theme the way Settings does.
class _Host extends StatefulWidget {
  const _Host({this.initial = 'kiwi', this.onChanged});
  final String initial;
  final ValueChanged<String>? onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String current = widget.initial;

  @override
  Widget build(BuildContext context) => ThemePicker(
        selected: current,
        onChanged: (id) {
          widget.onChanged?.call(id);
          setState(() => current = id);
        },
      );
}

Finder _swatch(String name) => find.ancestor(of: find.text(name), matching: find.byType(Pressable));

/// The decorated pill of the swatch named [name].
BoxDecoration _pill(WidgetTester tester, String name) => tester
    .widget<AnimatedContainer>(find.ancestor(of: find.text(name), matching: find.byType(AnimatedContainer)).first)
    .decoration! as BoxDecoration;

/// The disc of the swatch named [name].
BoxDecoration _disc(WidgetTester tester, String name) {
  final row = find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
  return tester
      .widget<Container>(find.descendant(of: row, matching: find.byType(Container)).first)
      .decoration! as BoxDecoration;
}

double _checkOpacity(WidgetTester tester, String name) {
  final row = find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
  return tester.widget<AnimatedOpacity>(find.descendant(of: row, matching: find.byType(AnimatedOpacity))).opacity;
}

void main() {
  goldenMatrix(
    'theme_picker',
    () => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // Dusk selected, with the keyboard focus ring on it.
      ThemePicker(selected: 'dusk', onChanged: (_) {}),
      const SizedBox(height: MyDataSpace.s6),
      // Disabled.
      const ThemePicker(selected: 'kiwi', onChanged: null),
      const SizedBox(height: MyDataSpace.s6),
      // The sample of the chosen theme, light and dark side by side as in the preview, scaled to fit.
      const SizedBox(
        width: 712,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ThemeSample(themeId: 'dusk', brightness: Brightness.light)),
          SizedBox(width: MyDataSpace.s4),
          Expanded(child: ThemeSample(themeId: 'dusk', brightness: Brightness.dark)),
        ]),
      ),
    ]),
    size: const Size(760, 416),
    before: (tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    },
  );

  testWidgets('Swatches follow themes.json order: Kiwi, Graphite, Dusk, Plum, Rose, Amber', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host()));
    final names = ['Kiwi', 'Graphite', 'Dusk', 'Plum', 'Rose', 'Amber'];
    expect([for (final t in MyDataThemes.all) t.name], names);
    for (var i = 1; i < names.length; i++) {
      expect(tester.getCenter(_swatch(names[i])).dx, greaterThan(tester.getCenter(_swatch(names[i - 1])).dx));
    }
  });

  testWidgets('Tapping a swatch reports its id; tapping the selected one does not', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(themedFrame(themeMatrix.first, _Host(onChanged: picked.add)));
    await tester.tap(find.text('Plum'));
    await tester.pumpAndSettle();
    expect(picked, ['plum']);
    await tester.tap(find.text('Plum'));
    await tester.pumpAndSettle();
    expect(picked, ['plum']);
  });

  testWidgets('Selected: a 2px ink ring, no shadow and a check; others: shadow-1, no ring, no check',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(initial: 'rose')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ThemePicker));
    final c = context.colors;

    final on = _pill(tester, 'Rose');
    expect(on.color, c.surface);
    expect(on.boxShadow, isEmpty);
    final ring = (on.border! as Border).top;
    expect(ring.color, c.ink);
    expect(ring.width, 2);
    expect(ring.strokeAlign, BorderSide.strokeAlignOutside);
    expect(_checkOpacity(tester, 'Rose'), 1);

    final off = _pill(tester, 'Kiwi');
    expect(off.color, c.surface);
    expect(off.boxShadow, context.shadows.shadow1);
    expect((off.border! as Border).top.color.a, 0);
    expect(_checkOpacity(tester, 'Kiwi'), 0);
  });

  testWidgets('Each disc is its theme accent for the current brightness', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host()));
    for (final t in MyDataThemes.all) {
      expect(_disc(tester, t.name).color, t.accentLight);
    }
    await tester.pumpWidget(themedFrame(themeMatrix[1], const _Host()));
    await tester.pumpAndSettle(); // MaterialApp animates the theme change
    for (final t in MyDataThemes.all) {
      expect(_disc(tester, t.name).color, t.accentDark);
    }
  });

  testWidgets('An unknown id shows the fallback theme (Kiwi) as selected', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, ThemePicker(selected: 'nope', onChanged: (_) {})));
    await tester.pumpAndSettle();
    expect(_checkOpacity(tester, 'Kiwi'), 1);
    expect(_checkOpacity(tester, 'Dusk'), 0);
  });

  testWidgets('Tab reaches the selected swatch only; arrows, Home and End move and choose at once', (tester) async {
    final picked = <String>[];
    var after = 0;
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        Column(children: [
          _Host(initial: 'dusk', onChanged: picked.add),
          Pressable(onPressed: () => after++, borderRadius: MyDataRadii.control(kiwiLook), child: const SizedBox(width: 80, height: 44)),
        ])));
    FocusNode focusOf(String name) => Focus.of(tester.element(find.text(name)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusOf('Dusk').hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(picked, ['plum']);
    expect(focusOf('Plum').hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); // wraps to the first
    await tester.pumpAndSettle();
    expect(picked, ['plum', 'rose', 'amber', 'kiwi']);
    expect(focusOf('Kiwi').hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft); // wraps to the last
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(picked, ['plum', 'rose', 'amber', 'kiwi', 'amber', 'rose', 'kiwi', 'amber']);
    expect(_checkOpacity(tester, 'Amber'), 1);

    // Tab leaves the group instead of visiting the other swatches.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(after, 1);
  });

  testWidgets('Enter and Space choose the focused swatch', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(themedFrame(themeMatrix.first, ThemePicker(selected: 'kiwi', onChanged: picked.add)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(picked, isEmpty, reason: 'choosing the selected theme again reports nothing');
    // The parent here never updates the selection, so the focus moves but Kiwi stays selected.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(picked, ['graphite']);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(picked, ['graphite', 'graphite']);
  });

  testWidgets('Arrow keys follow reading order right to left', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        Directionality(textDirection: TextDirection.rtl, child: _Host(initial: 'graphite', onChanged: picked.add))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(picked, ['dusk']);
    expect(tester.getCenter(_swatch('Kiwi')).dx, greaterThan(tester.getCenter(_swatch('Dusk')).dx));
  });

  testWidgets('Semantics: a radio group named Theme, each swatch a radio, the selected one checked',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(initial: 'dusk')));
    expect(
        tester.getSemantics(find.text('Dusk')),
        matchesSemantics(
          label: 'Dusk',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ));
    expect(
        tester.getSemantics(find.text('Kiwi')),
        matchesSemantics(
          label: 'Kiwi',
          hasCheckedState: true,
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ));
    final group = tester.getSemantics(find.byType(ThemePicker));
    expect(group.getSemanticsData().role, SemanticsRole.radioGroup);
    expect(group.label, 'Theme');
    handle.dispose();
  });

  testWidgets('Every swatch is control-height tall and at least 44px wide', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host()));
    for (final t in MyDataThemes.all) {
      final size = tester.getSize(_swatch(t.name));
      expect(size.height, MyDataSize.controlHeight);
      expect(size.width, greaterThanOrEqualTo(MyDataSize.controlHeight));
    }
  });

  testWidgets('Swatches are space-2 apart and keep their size when the selection changes', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host()));
    expect(tester.getRect(_swatch('Graphite')).left - tester.getRect(_swatch('Kiwi')).right, MyDataSpace.s2);
    final before = [for (final t in MyDataThemes.all) tester.getRect(_swatch(t.name))];
    await tester.tap(find.text('Amber'));
    await tester.pumpAndSettle();
    expect([for (final t in MyDataThemes.all) tester.getRect(_swatch(t.name))], before);
  });

  testWidgets('A narrow picker wraps and stays inside its width', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const SizedBox(width: 300, child: _Host())));
    final box = tester.getRect(find.byType(ThemePicker));
    for (final t in MyDataThemes.all) {
      expect(tester.getRect(_swatch(t.name)).right, lessThanOrEqualTo(box.right));
    }
    expect(tester.getRect(_swatch('Amber')).top, greaterThan(tester.getRect(_swatch('Kiwi')).top));
  });

  testWidgets('The ring and check change over fast', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host()));
    await tester.tap(find.text('Dusk'));
    await tester.pump();
    await tester.pump(MyDataMotion.fast ~/ 2);
    final animated = tester
        .widget<AnimatedOpacity>(find.descendant(
            of: find.ancestor(of: find.text('Dusk'), matching: find.byType(Row)).first,
            matching: find.byType(AnimatedOpacity)))
        .duration;
    expect(animated, MyDataMotion.fast);
    final fade = tester.renderObject<RenderAnimatedOpacity>(find.descendant(
        of: find.ancestor(of: find.text('Dusk'), matching: find.byType(Row)).first,
        matching: find.byType(AnimatedOpacity)));
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
  });

  testWidgets('With reduced motion a press only dims (no scale)', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(), reduceMotion: true));
    expect(find.descendant(of: find.byType(ThemePicker), matching: find.byType(AnimatedScale)), findsNothing);
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host()));
    expect(find.descendant(of: find.byType(ThemePicker), matching: find.byType(AnimatedScale)), findsNWidgets(6));
  });

  testWidgets('Disabled: no choices, no focus, dimmed', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const ThemePicker(selected: 'kiwi', onChanged: null)));
    await tester.tap(find.text('Dusk'), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Kiwi'))).hasFocus, isFalse);
    final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(of: _swatch('Dusk'), matching: find.byType(AnimatedOpacity)).first);
    expect(opacity.opacity, Pressable.disabledOpacity);
  });

  group('ThemeSample', () {
    BoxDecoration switchTrack(WidgetTester tester) => tester
        .widget<AnimatedContainer>(
            find.descendant(of: find.byType(SwitchTrack), matching: find.byType(AnimatedContainer)).first)
        .decoration! as BoxDecoration;

    /// The decoration of the sidebar place named [name].
    BoxDecoration place(WidgetTester tester, String name) => tester
        .widget<Container>(find
            .ancestor(of: find.text(name).first, matching: find.byType(Container))
            .first)
        .decoration! as BoxDecoration;

    testWidgets('Draws the given theme and mode with real tokens, whatever the theme around it', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          const SizedBox(width: 360, child: ThemeSample(themeId: 'plum', brightness: Brightness.dark))));
      expect(switchTrack(tester).color, MyDataThemes.plum.accentDark);
      final title = tester.widget<Text>(find.text('Library').last); // the first is the sidebar's place
      expect(title.style, MyDataType.title.copyWith(color: MyDataColors.dark.ink));
    });

    testWidgets('The mode defaults to the brightness around it', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix[1], const ThemeSample(themeId: 'amber')));
      expect(switchTrack(tester).color, MyDataThemes.amber.accentDark);
      await tester.pumpWidget(themedFrame(themeMatrix[0], const ThemeSample(themeId: 'amber')));
      await tester.pumpAndSettle(); // MaterialApp animates the theme change
      expect(switchTrack(tester).color, MyDataThemes.amber.accentLight);
    });

    testWidgets('Scales down to fit a narrow parent and never grows past its natural width', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, const SizedBox(width: 180, child: ThemeSample(themeId: 'kiwi'))));
      expect(tester.getSize(find.byType(ThemeSample)).width, lessThanOrEqualTo(180));
      final natural = tester.getSize(find.byType(FittedBox));
      expect(natural.width, lessThanOrEqualTo(180));
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, const SizedBox(width: 600, child: Align(alignment: Alignment.topLeft, child: ThemeSample(themeId: 'kiwi')))));
      expect(tester.getSize(find.byType(ThemeSample)).width, ThemeSample.naturalWidth);
    });

    testWidgets('Uses the real switch, progress track and buttons', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          const ThemeSample(themeId: 'dusk', brightness: Brightness.light)));
      expect(find.byType(SwitchTrack), findsOneWidget);
      expect(tester.widget<SwitchTrack>(find.byType(SwitchTrack)).value, isTrue);
      expect(tester.getSize(find.byType(SwitchTrack)).height, lessThanOrEqualTo(SwitchTrack.height));
      expect(find.byType(ButtonRow), findsOneWidget);
      final buttons = tester.widgetList<Button>(find.byType(Button)).toList();
      expect([for (final b in buttons) b.label], ['Add photos', 'New album']);
      expect([for (final b in buttons) b.variant], [ButtonVariant.filled, ButtonVariant.tonal]);
      expect(switchTrack(tester).border, isNotNull, reason: 'the real track has its accent border');
    });

    testWidgets('Marks the current place: the selected row is accent-soft with accent body-strong text',
        (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          const SizedBox(width: 600, child: ThemeSample(themeId: 'rose', brightness: Brightness.light))));
      final light = MyDataTheme.data('rose', Brightness.light).extension<MyDataColors>()!;
      expect(place(tester, 'Library').color, light.accentSoft);
      final selected = tester.widget<Text>(find.text('Library').first);
      expect(selected.style, MyDataType.bodyStrong.copyWith(color: light.accent));
      for (final name in ['Albums', 'People', 'Places']) {
        expect(place(tester, name).color, isNull);
        expect(tester.widget<Text>(find.text(name)).style, MyDataType.body.copyWith(color: light.inkMuted));
      }
    });

    testWidgets('The host dot is brand, the same in every theme', (tester) async {
      Color dot() => (tester.widget<Container>(find.byKey(const ValueKey('theme-sample-host-dot'))).decoration!
              as BoxDecoration)
          .color!;
      for (final t in MyDataThemes.all) {
        await tester.pumpWidget(themedFrame(themeMatrix.first, ThemeSample(themeId: t.id, brightness: Brightness.light)));
        expect(dot(), MyDataColors.light.brand);
        await tester.pumpWidget(themedFrame(themeMatrix.first, ThemeSample(themeId: t.id, brightness: Brightness.dark)));
        expect(dot(), MyDataColors.dark.brand);
      }
      expect(find.textContaining('Connected to your host', findRichText: true), findsOneWidget);
    });

    testWidgets('Screen readers hear one description; nothing inside is a target or takes focus', (tester) async {
      final handle = tester.ensureSemantics();
      var after = 0;
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 400, child: ThemeSample(themeId: 'dusk', brightness: Brightness.light)),
            Pressable(
                onPressed: () => after++,
                borderRadius: MyDataRadii.control(kiwiLook),
                child: const SizedBox(width: 80, height: 44)),
          ])));
      expect(find.bySemanticsLabel('Sample of the Dusk theme in light mode'), findsOneWidget);
      expect(find.bySemanticsLabel('Add photos'), findsNothing);
      // The buttons cannot be hit by a pointer...
      final button = tester.renderObject(find.byType(Button).first);
      final hits = tester.hitTestOnBinding(tester.getCenter(find.byType(Button).first)).path;
      expect(hits.any((e) => e.target == button), isFalse);
      // ...and the first Tab skips past them to the next control.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(after, 1);
      handle.dispose();
    });
  });
}
