import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _failure = 'Ava Fictional could not be saved. The host did not answer. Your changes are still here; '
    'check that the host is running, then press Save again.';

/// The contact form: names, then Phone and Email groups, then notes.
class _Form extends StatelessWidget {
  const _Form({required this.first, this.firstNode, this.emailError});
  final TextEditingController first;
  final FocusNode? firstNode;
  final String? emailError;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MyDataTextField(label: 'First name', controller: first, focusNode: firstNode),
        const SizedBox(height: MyDataSpace.s4),
        MyDataTextField(label: 'Last name', controller: TextEditingController(text: 'Fictional')),
        const SizedBox(height: MyDataSpace.s4),
        MyDataTextField(label: 'Organisation', controller: TextEditingController(text: 'Example Ltd')),
        const InspectorGroupHeading('Phone'),
        MyDataTextField(label: 'Mobile', controller: TextEditingController(text: '555-0142')),
        const InspectorGroupHeading('Email'),
        MyDataTextField(
            label: 'Home', controller: TextEditingController(text: 'ava.fictional@example'), error: emailError),
        const SizedBox(height: MyDataSpace.s4),
        MyDataTextField(label: 'Work', controller: TextEditingController(text: 'ava@example.org')),
      ]);
}

/// A list beside an inspector that opens with "Edit" and closes itself.
class _Holder extends StatefulWidget {
  const _Holder({this.onSave, this.check, this.firstNode, this.startOpen = false, this.inspectorKey});
  final HostAction? onSave;
  final FormCheck? check;
  final FocusNode? firstNode;
  final bool startOpen;
  final GlobalKey<InspectorState>? inspectorKey;

  @override
  State<_Holder> createState() => _HolderState();
}

class _HolderState extends State<_Holder> {
  late bool open = widget.startOpen;
  // A caret already placed, so focusing the field does not draw a phone's selection handle in the goldens.
  final first = TextEditingController(text: 'Ava')..selection = const TextSelection.collapsed(offset: 3);
  final closes = <bool>[];
  int taps = 0;

  @override
  void initState() {
    super.initState();
    first.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) => InspectorLayout(
        content: Padding(
          key: const Key('content'),
          padding: const EdgeInsets.all(MyDataSpace.s5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Button(label: 'Edit', onPressed: () => setState(() => open = true)),
            const SizedBox(height: MyDataSpace.s2),
            _Counter(onTap: () => taps++),
          ]),
        ),
        inspector: !open
            ? null
            : Inspector(
                key: widget.inspectorKey,
                title: 'Edit contact',
                form: _Form(first: first, firstNode: widget.firstNode),
                changed: first.text != 'Ava',
                discardMessage: 'Your changes to Ava Fictional are not saved.',
                savingAnnouncement: 'Saving Ava Fictional',
                check: widget.check,
                onSave: widget.onSave ?? () async => null,
                onClosed: (saved) => setState(() {
                  closes.add(saved);
                  open = false;
                }),
              ),
      );
}

/// Content with state of its own, to show the layout keeps it.
class _Counter extends StatefulWidget {
  const _Counter({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => Button(
      label: 'Count $n',
      onPressed: () {
        widget.onTap();
        setState(() => n++);
      });
}

_HolderState _holder(WidgetTester tester) => tester.state<_HolderState>(find.byType(_Holder));

Future<void> _pumpWide(WidgetTester tester, Widget holder, {Size size = const Size(1100, 700)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: size.width - 48, height: size.height - 48, child: holder)));
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

/// A list whose inspector moves from one record to another in place (no frame without an inspector).
class _Records extends StatefulWidget {
  const _Records({required this.inspectorKey, required this.saved});
  final GlobalKey<InspectorState> inspectorKey;
  final List<String> saved;

  @override
  State<_Records> createState() => _RecordsState();
}

class _RecordsState extends State<_Records> {
  String record = 'Ava';
  late var text = TextEditingController(text: record);

  void show(String next) => setState(() {
        record = next;
        text = TextEditingController(text: next)..addListener(() => setState(() {}));
      });

  @override
  void initState() {
    super.initState();
    text.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) => InspectorLayout(
        content: const SizedBox.expand(),
        inspector: Inspector(
          key: widget.inspectorKey,
          title: 'Edit contact',
          form: MyDataTextField(label: 'Name', controller: text),
          changed: text.text != record,
          discardMessage: 'Your changes to $record are not saved.',
          savingAnnouncement: 'Saving $record',
          onSave: () async {
            widget.saved.add(text.text);
            return null;
          },
          onClosed: (_) {},
        ),
      );
}

Finder get _panel => find.byType(Inspector);

Future<String?> _fails() async => _failure;

void main() {
  // The caret would blink forever; draw it still.
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  // Beside the content: the first field focused, the footer's line because the form goes on below.
  goldenMatrix('inspector_docked', () => const SizedBox(width: 952, height: 552, child: _Holder(startOpen: true)),
      size: const Size(1000, 600));

  // A window too narrow to dock: it covers the end of the content with shadow-2, scrolled so the header's
  // line shows, with a failed save above the footer.
  goldenMatrix('inspector_overlay',
      () => const SizedBox(width: 752, height: 552, child: _Holder(startOpen: true, onSave: _fails)),
      size: const Size(800, 600), before: (tester) async {
    _holder(tester).first.text = 'Ava Jane';
    await tester.pump();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  });

  // A phone: the editor sheet, after Save failed.
  goldenMatrix('inspector_phone', () => const SizedBox(width: 327, height: 600), size: const Size(375, 648),
      before: (tester) async {
    tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
    final first = TextEditingController(text: 'Cleo');
    unawaited(showSheet<void>(
      context: tester.element(find.byType(SizedBox).first),
      builder: (_) => Inspector(
        title: 'New contact',
        form: _Form(first: first, emailError: 'That address is incomplete. It looks like cleo@example.org.'),
        changed: true,
        discardMessage: 'This new contact is not saved.',
        savingAnnouncement: 'Saving Cleo Example',
        onSave: () async => _failure,
        onClosed: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  });

  group('Inspector', () {
    testWidgets('opening focuses the first field; the content narrows beside it and keeps its state',
        (tester) async {
      final firstNode = FocusNode();
      addTearDown(firstNode.dispose);
      await _pumpWide(tester, _Holder(firstNode: firstNode));
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      final before = tester.getSize(find.byType(InspectorLayout)).width;
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(firstNode.hasFocus, isTrue);
      expect(tester.getSize(_panel).width, MyDataSize.inspectorWidth);
      expect(tester.getTopRight(_panel).dx, tester.getTopRight(find.byType(InspectorLayout)).dx);
      expect(find.text('Count 1'), findsOneWidget, reason: 'the content kept its state');
      final content = find.byKey(const Key('content'));
      expect(tester.getSize(content).width, before - MyDataSize.inspectorWidth);
    });

    testWidgets('too narrow to dock: it covers the content, which keeps its width', (tester) async {
      await _pumpWide(tester, const _Holder(), size: const Size(800, 600));
      expect(InspectorLayout.docksAt(752), isFalse);
      expect(InspectorLayout.docksAt(880), isTrue);
      final before = tester.getSize(find.byKey(const Key('content'))).width;
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('content'))).width, before);
      expect(find.ancestor(of: _panel, matching: find.byType(DecoratedBox)), findsWidgets);
    });

    testWidgets('Save with no changes closes, as Cancel would, sending nothing', (tester) async {
      var sent = 0;
      await _pumpWide(tester, _Holder(startOpen: true, onSave: () async {
        sent++;
        return null;
      }));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent, 0);
      expect(_holder(tester).closes, [false]);
      expect(_panel, findsNothing);
    });

    testWidgets('saving: "Saving…" at the old width, fields busy, buttons inert; then it closes', (tester) async {
      final done = Completer<String?>();
      var sent = 0;
      await _pumpWide(tester, _Holder(startOpen: true, onSave: () {
        sent++;
        return done.future;
      }));
      await tester.pumpAndSettle();
      _holder(tester).first.text = 'Ava Jane';
      await tester.pump();
      final width = tester.getSize(find.byType(SteadyWidthButton)).width;
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(tester.getSize(find.byType(SteadyWidthButton)).width, width);
      expect(FormBusy.of(tester.element(find.text('First name'))), isTrue);
      await tester.tap(find.text('Cancel'));
      await tester.tap(find.text('Saving…'));
      await tester.pump();
      expect(sent, 1);
      expect(find.text(discardTitle), findsNothing);
      done.complete(null);
      await tester.pumpAndSettle();
      expect(_holder(tester).closes, [true]);
    });

    testWidgets('a failed save: the line above the footer, focus on Save, the changes kept', (tester) async {
      await _pumpWide(tester, _Holder(startOpen: true, onSave: () async => _failure));
      await tester.pumpAndSettle();
      _holder(tester).first.text = 'Ava Jane';
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(_failure), findsOneWidget);
      expect(tester.getBottomLeft(find.text(_failure)).dy, lessThan(tester.getTopLeft(find.text('Save')).dy));
      expect(Focus.of(tester.element(find.text('Save'))).hasPrimaryFocus, isTrue);
      expect(_holder(tester).first.text, 'Ava Jane');
      expect(_panel, findsOneWidget);
    });

    testWidgets('a wrong field: nothing is sent and focus moves to it', (tester) async {
      final firstNode = FocusNode();
      addTearDown(firstNode.dispose);
      var sent = 0;
      late _HolderState holder;
      await _pumpWide(
          tester,
          _Holder(
            startOpen: true,
            firstNode: firstNode,
            check: () => holder.first.text.trim().isEmpty ? [firstNode] : const [],
            onSave: () async {
              sent++;
              return null;
            },
          ));
      holder = _holder(tester);
      await tester.pumpAndSettle();
      holder.first.text = ' ';
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent, 0);
      expect(firstNode.hasFocus, isTrue);
    });

    testWidgets('leaving with changes asks first: Keep editing stays, Discard changes closes', (tester) async {
      await _pumpWide(tester, const _Holder(startOpen: true));
      await tester.pumpAndSettle();
      _holder(tester).first.text = 'Ava Jane';
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget);
      expect(find.text('Your changes to Ava Fictional are not saved.'), findsOneWidget);
      await tester.tap(find.text(keepEditingLabel));
      await tester.pumpAndSettle();
      expect(_panel, findsOneWidget);
      // Escape inside the inspector is Cancel too.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget);
      await tester.tap(find.text(discardLabel));
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(_holder(tester).closes, [false]);
    });

    testWidgets('requestClose: without changes it closes at once and answers true', (tester) async {
      final key = GlobalKey<InspectorState>();
      await _pumpWide(tester, _Holder(startOpen: true, inspectorKey: key));
      await tester.pumpAndSettle();
      final closed = key.currentState!.requestClose();
      await tester.pumpAndSettle();
      expect(await closed, isTrue);
      expect(_holder(tester).closes, [false]);
    });

    testWidgets('Ctrl+S saves wherever focus is in the window; Ctrl+Return saves from inside', (tester) async {
      var sent = 0;
      final firstNode = FocusNode();
      addTearDown(firstNode.dispose);
      await _pumpWide(tester, _Holder(startOpen: true, firstNode: firstNode, onSave: () async {
        sent++;
        return 'Not yet.';
      }));
      await tester.pumpAndSettle();
      _holder(tester).first.text = 'Ava Jane';
      await tester.pump();
      // From inside the inspector.
      await _ctrl(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sent, 1);
      // Plain Return in a single-line field does not save.
      firstNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sent, 1);
      // From the list beside it.
      Focus.of(tester.element(find.text('Count 0'))).requestFocus();
      await tester.pump();
      await _ctrl(tester, LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      expect(sent, 2);
    });

    testWidgets('reopened while the last one slides out, it is a fresh inspector: Save saves', (tester) async {
      var sent = 0;
      await _pumpWide(tester, _Holder(onSave: () async {
        sent++;
        return null;
      }));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Inspector.cancelLabel));
      await tester.pump();
      // Still sliding out (base): the next record opens in its place.
      await tester.pump(MyDataMotion.base ~/ 3);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      _holder(tester).first.text = 'Ben';
      await tester.pump();
      await tester.tap(find.text(Inspector.saveLabel));
      await tester.pumpAndSettle();
      expect(sent, 1);
      expect(_holder(tester).closes, [false, true]);
    });

    testWidgets('another record opened in place after requestClose: Save, Cancel and the check still work',
        (tester) async {
      final key = GlobalKey<InspectorState>();
      final saved = <String>[];
      await _pumpWide(tester, _Records(inspectorKey: key, saved: saved));
      await tester.pumpAndSettle();
      expect(await key.currentState!.requestClose(), isTrue);
      tester.state<_RecordsState>(find.byType(_Records)).show('Ben');
      await tester.pumpAndSettle();
      // A change, then Cancel: it asks, as for any record.
      await tester.enterText(find.byType(EditableText).first, 'Ben Sample');
      await tester.pump();
      await tester.tap(find.text(Inspector.cancelLabel));
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget);
      await tester.tap(find.text(keepEditingLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Inspector.saveLabel));
      await tester.pumpAndSettle();
      expect(saved, ['Ben Sample']);
    });

    testWidgets('under an AppMenuBar on Linux, one Ctrl+S saves once: the menu bar owns the key', (tester) async {
      var sent = 0, appSaves = 0;
      await _pumpWide(
        tester,
        AppMenuBar(
          appName: 'myContacts',
          file: [AppMenuItem(title: 'Save', shortcut: AppMenuBar.saveShortcut, onSelected: () => appSaves++)],
          child: _Holder(startOpen: true, onSave: () async {
            sent++;
            return 'Not yet.';
          }),
        ),
      );
      await tester.pumpAndSettle();
      _holder(tester).first.text = 'Ava Jane';
      await tester.pump();
      Focus.of(tester.element(find.text('Count 0'))).requestFocus();
      await tester.pump();
      await _ctrl(tester, LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      expect((sent, appSaves), (1, 0));
      expect(find.text('Not yet.'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('in a ToastHost: the toast sits over the content beside it, and Undo is the last Tab stop',
        (tester) async {
      final toasts = ToastController();
      addTearDown(toasts.dispose);
      await _pumpWide(tester, ToastHost(controller: toasts, child: const _Holder(startOpen: true)));
      await tester.pumpAndSettle();
      toasts.show('Contact deleted', undo: () async => const UndoResult('Contact restored'));
      await tester.pumpAndSettle();
      final content = tester.getRect(find.byType(InspectorLayout));
      final bar = tester.getRect(find.ancestor(of: find.text('Contact deleted'), matching: find.byType(Container)).first);
      expect(bar.center.dx, closeTo(content.left + (content.width - MyDataSize.inspectorWidth) / 2, 1));
      expect(bar.right, lessThanOrEqualTo(tester.getRect(_panel).left));
      // From Save, Tab goes to Undo: it comes after the inspector.
      Focus.of(tester.element(find.text(Inspector.saveLabel))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Toast undo');
      toasts.hide();
      await tester.pumpAndSettle();
    });

    testWidgets('a group heading is the form\'s heading, starting where the fields start', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 320,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const InspectorGroupHeading('Email', first: true),
              MyDataTextField(label: 'Home', showLabel: false, controller: TextEditingController(text: 'ava@example.org')),
            ]),
          )));
      expect(find.byType(FormGroupHeading), findsOneWidget);
      expect(tester.getRect(find.text('Email')).left, tester.getRect(find.byType(MyDataTextField)).left);
    });

    testWidgets('semantics: a region named by its title', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpWide(tester, const _Holder(startOpen: true));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.role == SemanticsRole.region && w.properties.label == 'Edit contact'));
      expect(node.label, 'Edit contact');
      handle.dispose();
    });

    testWidgets('on a phone it is the editor sheet: Cancel, the title and Save in its header', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final closes = <bool>[];
      final first = TextEditingController(text: 'Ava');
      addTearDown(first.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, Builder(
        builder: (context) => Button(
          label: 'Edit',
          onPressed: () => showSheet<void>(
            context: context,
            builder: (_) => StatefulBuilder(
              builder: (context, setState) => Inspector(
                title: 'Edit contact',
                form: _Form(first: first),
                changed: first.text != 'Ava',
                discardMessage: 'Your changes to Ava Fictional are not saved.',
                savingAnnouncement: 'Saving Ava Fictional',
                onSave: () async => null,
                onClosed: closes.add,
              ),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(Sheet), findsOneWidget);
      final header = tester.getRect(find.text('Edit contact'));
      expect(tester.getCenter(find.text('Cancel')).dy, closeTo(header.center.dy, 1));
      expect(tester.getCenter(find.text('Save')).dy, closeTo(header.center.dy, 1));
      expect(tester.getCenter(find.text('Save')).dx, greaterThan(header.right));
      // No changes: Save closes it.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(Sheet), findsNothing);
      expect(closes, [false]);
    });
  });
}
