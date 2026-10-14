import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// A content area with two buttons and a text field, inside a [ToastHost] driven by [controller].
Widget _area(ToastController controller,
        {FocusNode? first, FocusNode? field, TextEditingController? text, double width = 640, double height = 360}) =>
    SizedBox(
      width: width,
      height: height,
      child: ToastHost(
        controller: controller,
        child: Padding(
          padding: const EdgeInsets.all(MyDataSpace.s5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Button(label: 'Edit', focusNode: first, onPressed: () {}),
            const SizedBox(height: MyDataSpace.s2),
            Button(label: 'Share', onPressed: () {}),
            if (text != null) ...[
              const SizedBox(height: MyDataSpace.s2),
              SizedBox(width: 240, child: MyDataTextField(label: 'Notes', controller: text, focusNode: field)),
            ],
          ]),
        ),
      ),
    );

Future<UndoResult> _restored() async => const UndoResult('Contact restored');

Finder get _bar => find.ancestor(of: find.text('Contact deleted'), matching: find.byType(Container)).first;

void main() {
  // The Undo toast with keyboard focus on its button, at the bottom of a content area.
  goldenMatrix('toast', () {
    final controller = ToastController()..show('Contact deleted', undo: _restored);
    return _area(controller);
  }, size: const Size(688, 408), before: (tester) async {
    tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
  });

  // A phone, with a toast that has no action and wraps to two lines.
  goldenMatrix('toast_phone', () {
    final controller = ToastController()
      ..show('Following you@example.com. Its contacts and calendars are on their way.');
    return _area(controller, width: 375, height: 360);
  }, size: const Size(423, 408));

  group('Toast', () {
    testWidgets('it stays toast-duration, then leaves', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      expect(find.text('Contact deleted'), findsOneWidget);
      await tester.pump(MyDataMotion.toastDuration - const Duration(milliseconds: 100));
      expect(find.text('Contact deleted'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('Contact deleted'), findsNothing);
      expect(controller.current, isNull);
    });

    testWidgets('the pointer over it pauses the time; the full time starts again after', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 7));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.text('Contact deleted')));
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Contact deleted'), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Contact deleted'), findsOneWidget, reason: 'the full 8 seconds start again');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Contact deleted'), findsNothing);
    });

    testWidgets('an inactive window pauses the time', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Contact deleted'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.text('Contact deleted'), findsNothing);
    });

    testWidgets('Undo runs the undo and is replaced by what came back, with no action', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      var undone = 0;
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: () async {
        undone++;
        return const UndoResult('Contact restored');
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text(ToastHost.undoLabel));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Contact restored'), findsOneWidget);
      expect(find.text(ToastHost.undoLabel), findsNothing);
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('a ToastArea that goes away (an inspector closing) gives the toast back the whole host',
        (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      Widget host({required bool area}) => themedFrame(
            themeMatrix.first,
            SizedBox(
              width: 640,
              height: 360,
              child: ToastHost(
                controller: controller,
                child: Stack(children: [
                  const SizedBox.expand(),
                  if (area) const Positioned(left: 0, top: 0, bottom: 0, width: 320, child: ToastArea()),
                ]),
              ),
            ),
            padding: EdgeInsets.zero,
          );
      await tester.pumpWidget(host(area: true));
      controller.show('Contact added');
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Contact added')).dx, closeTo(160, 1));
      await tester.pumpWidget(host(area: false));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getCenter(find.text('Contact added')).dx, closeTo(320, 1));
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
    });

    testWidgets('a new toast replaces the one showing at once', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      controller.show('3 contacts deleted', undo: _restored);
      await tester.pumpAndSettle();
      expect(find.text('Contact deleted'), findsNothing);
      expect(find.text('3 contacts deleted'), findsOneWidget);
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('Ctrl+Z undoes the change, but undoes the typing while a text field has focus', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      final field = FocusNode();
      addTearDown(field.dispose);
      final text = TextEditingController();
      addTearDown(text.dispose);
      var undone = 0;
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller, field: field, text: text)));
      controller.show('Contact deleted', undo: () async {
        undone++;
        return const UndoResult('Contact restored');
      });
      await tester.pumpAndSettle();
      field.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(undone, 0);
      field.unfocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Contact restored'), findsOneWidget);
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('Undo is the last Tab stop; when it goes, focus returns to what had it', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      final first = FocusNode();
      addTearDown(first.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller, first: first)));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('Toast undo'), reason: 'it never takes focus');
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Share
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Undo
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Toast undo');
      // Focus on Undo pauses the time.
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Contact deleted'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Contact restored'), findsOneWidget);
      expect(Focus.of(tester.element(find.text('Share'))).hasPrimaryFocus, isTrue, reason: 'back on Share');
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('Escape on Undo closes the toast and returns focus', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      final first = FocusNode();
      addTearDown(first.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller, first: first)));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Toast undo');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Contact deleted'), findsNothing);
      expect(Focus.of(tester.element(find.text('Share'))).hasPrimaryFocus, isTrue);
    });

    testWidgets('a new toast replacing the one whose Undo has focus returns focus, never undoing the newer',
        (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      final first = FocusNode();
      addTearDown(first.dispose);
      var undone = <String>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller, first: first)));
      controller.show('Contact deleted', undo: () async {
        undone.add('first');
        return const UndoResult('Contact restored');
      });
      await tester.pumpAndSettle();
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Toast undo');
      controller.show('Contact moved', undo: () async {
        undone.add('second');
        return const UndoResult('Contact moved back');
      });
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Share'))).hasPrimaryFocus, isTrue, reason: 'back on Share');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(undone, isEmpty, reason: 'Return went to Share, not to the newer toast\'s Undo');
      controller.hide();
      await tester.pumpAndSettle();
      undone = [];
    });

    testWidgets('a toast taken away under the pointer does not keep the next one forever', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.text('Contact deleted')));
      await tester.pump();
      controller.hide();
      await tester.pumpAndSettle();
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      controller.show('Contact added', undo: _restored);
      await tester.pumpAndSettle();
      await tester.pump(MyDataMotion.toastDuration + const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Contact added'), findsNothing, reason: 'it leaves after toast-duration');
    });

    testWidgets('the time stops while the host undoes, so the result is still shown', (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      final undo = Completer<UndoResult>();
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: () => undo.future);
      await tester.pumpAndSettle();
      await tester.pump(MyDataMotion.toastDuration - const Duration(seconds: 1));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      // The undo takes longer than the time that was left.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Contact deleted'), findsOneWidget);
      undo.complete(const UndoResult('Contact restored'));
      await tester.pumpAndSettle();
      expect(find.text('Contact restored'), findsOneWidget);
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('a toast that went away while the undo ran is replaced by the result; a newer toast is not',
        (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      final undo = Completer<UndoResult>();
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: () => undo.future);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ToastHost.undoLabel));
      await tester.pump();
      controller.show('Event moved');
      await tester.pumpAndSettle();
      undo.complete(const UndoResult('Contact restored'));
      await tester.pumpAndSettle();
      expect(find.text('Event moved'), findsOneWidget);
      expect(find.text('Contact restored'), findsNothing);
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('under an AppMenuBar on Linux, one Ctrl+Z undoes once: the menu bar owns the key',
        (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      var toastUndos = 0, appUndos = 0;
      await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        AppMenuBar(
          appName: 'myContacts',
          undoAction: 'Delete Contact',
          onUndo: () => appUndos++,
          child: _area(controller),
        ),
      ));
      controller.show('Contact deleted', undo: () async {
        toastUndos++;
        return const UndoResult('Contact restored');
      });
      await tester.pumpAndSettle();
      Focus.of(tester.element(find.text('Share'))).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(toastUndos + appUndos, 1);
      expect(toastUndos, 1, reason: 'the toast showing Undo claims it, so its result is shown');
      expect(find.text('Contact restored'), findsOneWidget);
      // With no toast to claim it, Ctrl+Z is the app's own undo, once.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect((toastUndos, appUndos), (1, 1));
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('on desktop it is announced, not also a live region, so it is read once', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true), findsNothing);
      expect(tester.takeAnnouncements().map((a) => a.message), ['Contact deleted. Undo with Command Z.']);
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
      handle.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('on a phone, a replacement with the same words is a new live region, read again', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted');
      await tester.pumpAndSettle();
      final live = find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true);
      final before = tester.getSemantics(live).id;
      controller.show('Contact deleted');
      await tester.pumpAndSettle();
      expect(tester.getSemantics(live).id, isNot(before));
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('anatomy: surface-raised, radius-xl, at least control-height plus space-2 twice; space-6 up',
        (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller), padding: EdgeInsets.zero));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      final bar = tester.widget<Container>(_bar);
      final c = tester.element(_bar).colors;
      final decoration = bar.decoration! as BoxDecoration;
      expect(decoration.color, c.surfaceRaised);
      expect(decoration.borderRadius, MyDataRadii.xl);
      expect(tester.getSize(_bar).height, greaterThanOrEqualTo(MyDataSize.controlHeight + 2 * MyDataSpace.s2));
      expect(360 - tester.getBottomLeft(_bar).dy, MyDataSpace.s6);
      // Centred in the content area.
      expect(tester.getCenter(_bar).dx, closeTo(320, 1));
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('motion: a rise over base; with reduced motion a fast fade only', (tester) async {
      for (final reduced in [false, true]) {
        final controller = ToastController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller), reduceMotion: reduced));
        controller.show('Contact deleted', undo: _restored);
        await tester.pump();
        await tester.pump(MyDataMotion.fast ~/ 2);
        final rising = find.ancestor(of: find.text('Contact deleted'), matching: find.byType(Transform));
        expect(rising, reduced ? findsNothing : findsWidgets);
        await tester.pump(MyDataMotion.fast);
        final fades = tester
            .widgetList<FadeTransition>(find.ancestor(of: find.text('Contact deleted'), matching: find.byType(FadeTransition)))
            .map((f) => f.opacity.value);
        expect(fades.every((o) => o == 1.0), reduced, reason: reduced ? 'faded in over fast' : 'still rising over base');
        controller.hide();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('screen readers: a live region with the message and how to undo', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ToastController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _area(controller)));
      controller.show('Contact deleted', undo: _restored);
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true));
      expect(node.label, 'Contact deleted. Undo with Control Z.');
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(ToastHost.spoken(const ToastMessage('Contact deleted', undo: _restored), phone: true),
          'Contact deleted. Undo is in More actions.');
      expect(ToastHost.spoken(const ToastMessage('Contact deleted', undo: _restored), phone: false,
          platform: TargetPlatform.macOS), 'Contact deleted. Undo with Command Z.');
      await tester.pump(MyDataMotion.toastDuration);
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });
}
