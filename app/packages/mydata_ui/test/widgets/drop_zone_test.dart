import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

// The spec's words (design/components/DropZone and ImportFlow), with an invented file name.
const _instruction = 'Drop a .vcf or .zip file here';
const _caption = 'A vCard file (.vcf) from Apple, Google or Samsung, or a .zip of them. Up to 50 MB.';
const _file = 'contacts-2026-10-14.vcf';
const _error = '$_file was not read. The host did not answer. Check that it is running, then try again.';
const _reason = 'The host cannot be reached. Import works when it is running.';

DropZone _zone(DropZoneState state, {VoidCallback? onRetry, String? dragName}) => DropZone(
      instruction: _instruction,
      caption: _caption,
      onChoose: _noop,
      state: state,
      dragName: dragName,
      readingName: _file,
      onCancel: _noop,
      error: state == DropZoneState.error ? _error : null,
      onRetry: onRetry,
      disabledReason: state == DropZoneState.disabled ? _reason : null,
    );

/// Every state, one under the other, at the reading column's width.
Widget _allStates() => SizedBox(
      width: 640,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _zone(DropZoneState.idle),
        const SizedBox(height: MyDataSpace.s4),
        _zone(DropZoneState.dragging, dragName: _file),
        const SizedBox(height: MyDataSpace.s4),
        _zone(DropZoneState.reading),
        const SizedBox(height: MyDataSpace.s4),
        _zone(DropZoneState.error, onRetry: _noop),
        const SizedBox(height: MyDataSpace.s4),
        _zone(DropZoneState.disabled),
      ]),
    );

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(900, 700)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: 640, child: child)));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  goldenMatrix('drop_zone', _allStates, size: const Size(688, 1300), before: (tester) async {
    // The reading state's loader turns for as long as it shows: let it come to rest for the picture.
    await tester.pump(const Duration(milliseconds: 300));
  }, reduceMotion: true);

  testWidgets('idle: a surface-sunken radius-lg well with the tile, instruction, caption and a filled button',
      (tester) async {
    var chosen = 0;
    await _pump(tester, DropZone(instruction: _instruction, caption: _caption, onChoose: () => chosen++));
    final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    final c = tester.element(find.byType(DropZone)).colors;
    final decoration = box.decoration!.box;
    expect(decoration.color, c.surfaceSunken);
    expect(decoration.borderRadius, MyDataRadii.lg(kiwiLook));
    expect(find.text(_instruction), findsOneWidget);
    expect(find.text(_caption), findsOneWidget);
    final button = tester.widget<Button>(find.byType(Button));
    expect(button.label, DropZone.defaultChooseLabel);
    expect(button.variant, ButtonVariant.filled);
    await tester.tap(find.text(DropZone.defaultChooseLabel));
    expect(chosen, 1);
  });

  testWidgets('dragging names the file, or says "Drop to import" when the name is not known', (tester) async {
    await _pump(tester, _zone(DropZoneState.dragging, dragName: _file));
    expect(find.text('Drop to import $_file'), findsOneWidget);
    final c = tester.element(find.byType(DropZone)).colors;
    final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    expect((box.decoration!.box).color, c.accentSoft);
    final line = (box.foregroundDecoration!.box).border! as Border;
    expect(line.top.color, c.accent);
    expect(line.top.width, DropZone.dragLineWidth);
    await _pump(tester, _zone(DropZoneState.dragging));
    expect(find.text(DropZone.dropLabel), findsOneWidget);
  });

  testWidgets('reading: the loader, "Reading <file>…", the caption about time, and Cancel', (tester) async {
    var cancelled = 0;
    await _pump(
      tester,
      DropZone(
        instruction: _instruction,
        caption: _caption,
        onChoose: _noop,
        state: DropZoneState.reading,
        readingName: _file,
        onCancel: () => cancelled++,
      ),
    );
    expect(find.byType(KiwiLoader), findsOneWidget);
    expect(find.text('Reading $_file…'), findsOneWidget);
    expect(find.text(DropZone.defaultReadingCaption), findsOneWidget);
    expect(find.text(DropZone.defaultChooseLabel), findsNothing);
    await tester.tap(find.text(DropZone.cancelLabel));
    expect(cancelled, 1);
  });

  testWidgets('error: the sentence in danger in place of the caption, and Try again when given', (tester) async {
    var retried = 0;
    await _pump(tester, _zone(DropZoneState.error, onRetry: () => retried++));
    final c = tester.element(find.byType(DropZone)).colors;
    expect(find.text(_caption), findsNothing);
    expect(tester.widget<Text>(find.text(_error)).style!.color, c.danger);
    await tester.tap(find.text(DropZone.retryLabel));
    expect(retried, 1);
    await _pump(tester, _zone(DropZoneState.error));
    expect(find.text(DropZone.retryLabel), findsNothing);
  });

  testWidgets('disabled: the reason in full ink-muted, the button not pressable', (tester) async {
    var chosen = 0;
    await _pump(
      tester,
      DropZone(
        instruction: _instruction,
        caption: _caption,
        onChoose: () => chosen++,
        state: DropZoneState.disabled,
        disabledReason: _reason,
      ),
    );
    final c = tester.element(find.byType(DropZone)).colors;
    expect(tester.widget<Text>(find.text(_reason)).style!.color, c.inkMuted);
    expect(find.ancestor(of: find.text(_reason), matching: find.byType(Opacity)), findsNothing);
    expect(tester.widget<Button>(find.byType(Button)).onPressed, isNull);
    await tester.tap(find.text(DropZone.defaultChooseLabel), warnIfMissed: false);
    expect(chosen, 0);
  });

  testWidgets('under 600px there is no instruction: the tile, the caption and the button', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: 340, child: _zone(DropZoneState.idle))));
    expect(find.text(_instruction), findsNothing);
    expect(find.text(_caption), findsOneWidget);
    expect(find.text(DropZone.defaultChooseLabel), findsOneWidget);
  });

  testWidgets('screen readers: a group named by its instruction, described by its caption', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _zone(DropZoneState.idle));
    expect(find.bySemanticsLabel(_instruction), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel(_instruction));
    expect(node.hint, _caption);
    handle.dispose();
  });
}
