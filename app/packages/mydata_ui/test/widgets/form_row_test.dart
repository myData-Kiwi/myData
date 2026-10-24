import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show Assertiveness;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

final _kiwi = themeMatrix.first.data.extension<MyDataColors>()!;

const _phonePresets = ['Mobile', 'Home', 'Work', 'Other'];

List<SelectItem<String>> _labelItems() => [for (final p in _phonePresets) SelectItem(value: p, title: p)];

/// One phone row of the editor's state.
class _Phone {
  _Phone(this.id, this.label, String number) : controller = TextEditingController(text: number);
  final int id;
  String label;
  final TextEditingController controller;
  final focus = FocusNode();
}

/// The Phone group of a contact editor, as myContacts will build it.
class _Phones extends StatefulWidget {
  const _Phones({this.initial = const [('Mobile', '555-0142'), ('Home', '555-0177')]});
  final List<(String, String)> initial;
  @override
  State<_Phones> createState() => _PhonesState();
}

class _PhonesState extends State<_Phones> {
  late final rows = [for (var i = 0; i < widget.initial.length; i++) _Phone(i, widget.initial[i].$1, widget.initial[i].$2)];
  late var next = rows.length;

  @override
  Widget build(BuildContext context) => FormGroup(heading: 'Phone', children: [
        RepeatableFormGroup<int>(
          keys: [for (final r in rows) r.id],
          addLabel: 'Add phone',
          addedAnnouncement: 'Phone number added',
          removedAnnouncement: (id) => '${removedLabel ?? 'Phone'} number removed',
          valueFocusOf: (id) => rows.where((r) => r.id == id).firstOrNull?.focus,
          onAdd: () => setState(() => rows.add(_Phone(next++, nextPresetLabel(_phonePresets, rows.map((r) => r.label)), ''))),
          rowBuilder: (context, id, index) {
            final r = rows.firstWhere((r) => r.id == id);
            return RepeatableFormRow(
              labelPicker: MyDataSelect<String>(
                label: 'Label for phone ${index + 1}',
                showLabel: false,
                fitToItems: true,
                items: _labelItems(),
                value: r.label,
                onChanged: (v) => setState(() => r.label = v),
              ),
              value: MyDataTextField(
                  label: '${r.label}, phone number', showLabel: false, controller: r.controller, focusNode: r.focus),
              removeLabel: 'Remove ${r.label.toLowerCase()} number',
              onRemove: () => setState(() {
                removedLabel = r.label;
                rows.remove(r);
              }),
            );
          },
        ),
      ]);

  String? removedLabel;
}

TextEditingController _c([String t = '']) => TextEditingController(text: t);

Widget _panel(Widget child) => Builder(
      builder: (context) => Container(
        width: MyDataSize.inspectorWidth,
        color: context.colors.surface,
        padding: const EdgeInsets.all(MyDataSpace.s4),
        child: child,
      ),
    );

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  goldenMatrix(
    'form_row',
    () => _panel(MyDataForm(
      error: 'A contact needs a name, a company, a phone number or an email.',
      groups: [
        FormGroup(heading: 'Name', children: [
          MyDataTextField(label: 'First name', controller: _c('Ava')),
          MyDataTextField(label: 'Last name', controller: _c('Fictional')),
          MyDataTextField(
              label: 'Company',
              controller: _c(),
              help: 'A contact needs a name, a company, a phone number or an email.'),
        ]),
        const _Phones(),
        FormGroup(heading: 'Email', children: [
          RepeatableFormGroup<int>(
              keys: const [0],
              addLabel: 'Add email',
              onAdd: () {},
              valueFocusOf: (_) => null,
              rowBuilder: (context, _, _) => RepeatableFormRow(
                    labelPicker: MyDataSelect<String>(
                        label: 'Label for email 1',
                        showLabel: false,
                        fitToItems: true,
                        items: const [
                          SelectItem(value: 'Home', title: 'Home'),
                          SelectItem(value: 'Work', title: 'Work'),
                          SelectItem(value: 'Other', title: 'Other'),
                        ],
                        value: 'Home',
                        onChanged: (_) {}),
                    value: MyDataTextField(
                        label: 'Home, email',
                        showLabel: false,
                        controller: _c('ava@example'),
                        error: 'That email address is incomplete. It looks like name@example.org.'),
                    removeLabel: 'Remove home email',
                    onRemove: () {},
                  )),
        ]),
        FormGroup(heading: 'Address', children: [
          RepeatableFormGroup<int>(keys: const [], addLabel: 'Add address', onAdd: () {}, valueFocusOf: (_) => null,
              rowBuilder: (_, _, _) => const SizedBox()),
        ]),
        FormGroup(heading: 'Notes', children: [
          MyDataTextField.multiline(label: 'Notes', showLabel: false, controller: _c(), placeholder: 'Add notes'),
        ]),
      ],
    )),
    size: const Size(488, 1120),
  );

  goldenMatrix(
    'form_row_page',
    () => SizedBox(
      width: 520,
      child: MyDataForm(ground: FormGround.page, groups: [
        FormGroup(heading: 'Where the contacts go', children: [
          MyDataSelect<String>(
              label: 'Address book',
              items: const [
                SelectItem(value: 'family', title: 'Family'),
                SelectItem(value: 'work', title: 'Work'),
              ],
              value: 'family',
              help: 'The 12 contacts in the file are added to it.',
              onChanged: (_) {}),
          const MyDataCheckbox(label: 'Also add them to the group “Book club”', value: false, onChanged: _noop),
          const FormSwitchRow(title: 'Keep the file’s photos', value: true, onChanged: _noop),
        ]),
      ]),
    ),
    size: const Size(568, 380),
  );

  group('FormRow', () {
    testWidgets('the label stacked above in label/ink, space-2; help below; the error replaces it in danger',
        (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          const SizedBox(
              width: 300,
              child: Column(children: [
                FormRow(label: 'Starts', help: 'In your time zone.', child: SizedBox(height: 44)),
                FormRow(label: 'Ends', help: 'In your time zone.', error: 'The end is before the start.', child: SizedBox(height: 44)),
              ]))));
      final label = tester.widget<Text>(find.text('Starts'));
      expect(label.style!.fontWeight, MyDataType.label.fontWeight);
      expect(label.style!.color, _kiwi.ink);
      final labelRect = tester.getRect(find.text('Starts'));
      final help = tester.getRect(find.text('In your time zone.').first);
      expect(help.top - labelRect.bottom, MyDataSpace.s2 + 44 + MyDataSpace.s2);
      expect(help.left, labelRect.left);
      expect(find.text('In your time zone.'), findsOneWidget);
      expect(tester.widget<Text>(find.text('The end is before the start.')).style!.color, _kiwi.danger);
    });
  });

  group('MyDataForm and FormGroup', () {
    testWidgets('on a panel: no cards, headings in label/ink-muted, fields space-4 apart, groups space-6 apart',
        (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          _panel(MyDataForm(groups: [
            FormGroup(heading: 'Name', children: [
              MyDataTextField(label: 'First name', controller: _c()),
              MyDataTextField(label: 'Last name', controller: _c()),
            ]),
            FormGroup(heading: 'Notes', children: [
              MyDataTextField.multiline(label: 'Notes', showLabel: false, controller: _c()),
            ]),
          ]))));
      final heading = tester.widget<Text>(find.text('Name'));
      expect(heading.style!.color, _kiwi.inkMuted);
      final first = tester.getRect(find.byType(MyDataTextField).first);
      final second = tester.getRect(find.byType(MyDataTextField).at(1));
      expect(second.top - first.bottom, MyDataSpace.s4);
      expect(tester.getRect(find.text('Notes')).top - second.bottom, MyDataForm.groupGap(kiwiLook));
      // A one-field group shows no label of its own: "Notes" appears once, as the heading.
      expect(find.text('Notes'), findsOneWidget);
      expect(find.byType(DecoratedBox).evaluate().where((e) {
        final d = (e.widget as DecoratedBox).decoration;
        return d is BoxDecoration && d.boxShadow != null && d.boxShadow!.isNotEmpty;
      }), isEmpty, reason: 'no cards on a panel');
    });

    testWidgets('on a page: each group is a surface part with space-5 padding; fields space-5 apart',
        (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 520,
            child: MyDataForm(ground: FormGround.page, groups: [
              FormGroup(heading: 'Import', children: [
                MyDataTextField(label: 'A', controller: _c()),
                MyDataTextField(label: 'B', controller: _c()),
              ]),
            ]),
          )));
      final part = find.ancestor(of: find.byType(MyDataTextField).first, matching: find.byType(DecoratedBox)).first;
      final deco = tester.widget<DecoratedBox>(part).decoration as BoxDecoration;
      expect(deco.color, _kiwi.surface);
      expect(deco.borderRadius, MyDataRadii.lg(kiwiLook));
      expect(tester.getRect(find.byType(MyDataTextField).first).left - tester.getRect(part).left, MyDataSpace.s5);
      expect(tester.getRect(find.byType(MyDataTextField).at(1)).top - tester.getRect(find.byType(MyDataTextField).first).bottom,
          MyDataSpace.s5);
    });

    testWidgets('the heading starts where the fields start on a panel; on a page it is inset space-2',
        (tester) async {
      Future<double> inset(Widget form) async {
        await tester.pumpWidget(themedFrame(themeMatrix.first, form));
        return tester.getRect(find.text('Phone')).left - tester.getRect(find.byType(MyDataTextField)).left;
      }

      FormGroup group() => FormGroup(heading: 'Phone', children: [MyDataTextField(label: 'Mobile', controller: _c())]);
      expect(await inset(_panel(MyDataForm(groups: [group()]))), 0);
      // On a page the heading sits over the GroupedSection part, inset as GroupedSection's heading.
      final page = SizedBox(width: 520, child: MyDataForm(ground: FormGround.page, groups: [group()]));
      final part = await inset(page);
      expect(tester.getRect(find.text('Phone')).left - tester.getRect(find.byType(FormGroup)).left,
          FormGroupHeading.pageInset(kiwiLook));
      expect(part, FormGroupHeading.pageInset(kiwiLook) - MyDataSpace.s5);
    });

    testWidgets('on a phone, fields and the heading at 16px; no inset on a page', (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 342,
            child: MyDataForm(ground: FormGround.page, groups: [
              FormGroup(heading: 'Phone', children: [MyDataTextField(label: 'Mobile', controller: _c('555-0142'))]),
            ]),
          )));
      expect(tester.getRect(find.text('Phone')).left, tester.getRect(find.byType(FormGroup)).left);
      expect(tester.widget<EditableText>(find.byType(EditableText)).style.fontSize, PhoneType.bodySize);
    });

    testWidgets('a group is a semantics group named by its heading', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          _panel(FormGroup(heading: 'Phone', children: [MyDataTextField(label: 'Number', controller: _c())]))));
      expect(find.bySemanticsLabel('Phone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the form-level error sits at the top of the first group, with an alert icon, in danger',
        (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          _panel(MyDataForm(error: 'A contact needs a name.', groups: [
            FormGroup(heading: 'Name', children: [MyDataTextField(label: 'First name', controller: _c())]),
            FormGroup(heading: 'Phone', children: [MyDataTextField(label: 'Number', controller: _c())]),
          ]))));
      final message = tester.getRect(find.text('A contact needs a name.'));
      expect(message.top, greaterThan(tester.getRect(find.text('Name')).bottom));
      expect(message.bottom, lessThan(tester.getRect(find.text('First name')).top));
      expect(tester.widget<Text>(find.text('A contact needs a name.')).style!.color, _kiwi.danger);
      expect(findIcon(MyDataIcon.error), findsOneWidget);
      // It is not a Tab stop.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus, isTrue);
    });
  });

  group('repeatable rows', () {
    testWidgets('label picker, value and remove button in one line, space-2 apart; rows space-3 apart',
        (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, _panel(const _Phones())));
      final picker = tester.getRect(find.byType(MyDataSelect<String>).first);
      final value = tester.getRect(find.byType(MyDataTextField).first);
      final remove = tester.getRect(find.byType(FormRemoveButton).first);
      expect(value.left - picker.right, MyDataSpace.s2);
      expect(remove.left - value.right, MyDataSpace.s2);
      expect(remove.size, const Size.square(MyDataSize.controlHeight));
      final second = tester.getRect(find.byType(MyDataSelect<String>).at(1));
      expect(second.top - picker.bottom, RepeatableFormGroup.rowGap(kiwiLook));
      final add = tester.getRect(find.byType(Button).last);
      expect(add.top - tester.getRect(find.byType(FormRemoveButton).last).bottom, RepeatableFormGroup.rowGap(kiwiLook));
      expect(find.text('Add phone'), findsOneWidget);
    });

    testWidgets('the remove button: danger icon, danger-soft hover, named and tooltipped, ink focus ring',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first, _panel(const _Phones())));
      final p = tester.widget<Pressable>(find.descendant(of: find.byType(FormRemoveButton).first, matching: find.byType(Pressable)));
      expect(p.hoverFill, _kiwi.dangerSoft);
      expect(p.danger, isTrue);
      final tip = tester.widget<Tooltip>(
          find.descendant(of: find.byType(FormRemoveButton).first, matching: find.byType(Tooltip)));
      expect(tip.richMessage!.toPlainText(), 'Remove mobile number');
      expect(find.byType(MyDataIconButton), findsWidgets);
      expect(tester.widget<Icon>(findIcon(MyDataIcon.remove).first).color, _kiwi.danger);
      expect(find.bySemanticsLabel('Remove mobile number'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Add: a row with the next preset label, focus in its value, announced', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, _panel(const _Phones())));
      await tester.tap(find.text('Add phone'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Work'), findsOneWidget, reason: 'Mobile and Home are used; Work is next');
      final focused = FocusManager.instance.primaryFocus!;
      expect(find.descendant(of: find.byType(MyDataTextField).last, matching: find.byWidgetPredicate((w) => w is EditableText && w.focusNode == focused)),
          findsOneWidget);
      expect(tester.takeAnnouncements().map((a) => a.message), ['Phone number added']);
      await tester.pumpAndSettle();
    });

    testWidgets('Remove: the row goes at once, focus moves to the next value, announced', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          _panel(const _Phones(initial: [('Mobile', '555-0101'), ('Home', '555-0102'), ('Work', '555-0103')]))));
      await tester.tap(find.byType(FormRemoveButton).at(1));
      await tester.pump();
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!;
      final editable = tester.widgetList<EditableText>(find.byType(EditableText)).firstWhere((e) => e.focusNode == focused);
      expect(editable.controller.text, '555-0103');
      expect(tester.takeAnnouncements().map((a) => a.message), ['Home number removed']);
      await tester.pumpAndSettle();
      expect(find.text('555-0102'), findsNothing);
    });

    testWidgets('removing the last row moves focus to the previous value, or the Add button', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, _panel(const _Phones(initial: [('Mobile', '555-0101')]))));
      await tester.tap(find.byType(FormRemoveButton));
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus!;
      expect(find.descendant(of: find.byType(Button), matching: find.byWidgetPredicate((w) => w is Focus && w.focusNode == focused)),
          findsWidgets);
    });

    testWidgets('motion: an added row opens and fades over base; with reduced motion it only fades', (tester) async {
      Iterable<double?> growing() => tester
          .widgetList<Align>(find.byWidgetPredicate((w) => w is Align && w.alignment == Alignment.topCenter))
          .map((a) => a.heightFactor);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _panel(const _Phones())));
      await tester.tap(find.text('Add phone'));
      await tester.pump();
      await tester.pump(MyDataMotion.base ~/ 2);
      expect(growing().last, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(growing().every((f) => f == 1), isTrue);

      await tester.pumpWidget(themedFrame(themeMatrix.first, _panel(const _Phones()), reduceMotion: true));
      await tester.tap(find.text('Add phone'));
      await tester.pump();
      await tester.pump(MyDataMotion.fast ~/ 2);
      expect(growing().every((f) => f == 1), isTrue, reason: 'with reduced motion it only fades');
      await tester.pumpAndSettle();
    });

    testWidgets('a row at rest is not clipped, and its value keeps focus when the motion ends', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, _panel(const _Phones())));
      await tester.tap(find.text('Add phone'));
      await tester.pumpAndSettle();
      final state = tester.state<_PhonesState>(find.byType(_Phones));
      expect(state.rows.last.focus.hasPrimaryFocus, isTrue);
      final clips = tester.widgetList<ClipRect>(
          find.descendant(of: find.byType(RepeatableFormGroup<int>), matching: find.byType(ClipRect)));
      expect(clips.where((c) => c.clipBehavior != Clip.none), isEmpty,
          reason: 'the focus ring, 2px outside the field, shows whole');
    });

    test('nextPresetLabel: the first unused preset, then the last again', () {
      expect(nextPresetLabel(_phonePresets, []), 'Mobile');
      expect(nextPresetLabel(_phonePresets, ['Mobile', 'home']), 'Work');
      expect(nextPresetLabel(_phonePresets, _phonePresets), 'Other');
    });
  });

  group('FormChecks', () {
    testWidgets('checked on leaving, not while typing; once in error, re-checked on every change', (tester) async {
      final checks = FormChecks();
      addTearDown(checks.dispose);
      final email = _c();
      final node = FocusNode();
      final other = FocusNode();
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      checks.register('email', focusNode: node, check: () => email.text.contains('.') ? null : 'Incomplete.');
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          ListenableBuilder(
            listenable: checks,
            builder: (context, _) => SizedBox(
              width: 300,
              child: Column(children: [
                MyDataTextField(
                    label: 'Email',
                    controller: email,
                    focusNode: node,
                    error: checks.errorOf('email'),
                    onChanged: (_) => checks.changed('email')),
                MyDataTextField(label: 'Other', controller: _c(), focusNode: other),
              ]),
            ),
          )));
      node.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, 'ava@example');
      await tester.pump();
      expect(find.text('Incomplete.'), findsNothing, reason: 'never while first typed');
      other.requestFocus();
      await tester.pump();
      expect(find.text('Incomplete.'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, 'ava@example.org');
      await tester.pump();
      expect(find.text('Incomplete.'), findsNothing, reason: 'the error goes as soon as the value is right');
    });

    testWidgets('Save with errors: focus to the first field in error, announced assertively', (tester) async {
      final checks = FormChecks();
      addTearDown(checks.dispose);
      final a = FocusNode(), b = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      checks.register('first', focusNode: a, check: () => null);
      checks.register('second', focusNode: b, check: () => 'Wrong.');
      late BuildContext ctx;
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Builder(builder: (context) {
            ctx = context;
            return SizedBox(
              width: 300,
              child: Column(children: [
                MyDataTextField(label: 'First', controller: _c(), focusNode: a),
                MyDataTextField(label: 'Second', controller: _c(), focusNode: b),
              ]),
            );
          })));
      expect(checks.save(ctx), isFalse);
      await tester.pump();
      expect(b.hasFocus, isTrue);
      final said = tester.takeAnnouncements();
      expect(said.map((s) => s.message), ['Not saved. 1 field needs attention.']);
      expect(said.single.assertiveness, Assertiveness.assertive);
    });

    testWidgets('only the form rule fails: focus moves to its message', (tester) async {
      final checks = FormChecks();
      addTearDown(checks.dispose);
      final a = FocusNode();
      addTearDown(a.dispose);
      checks.register('first', focusNode: a, check: () => null);
      late BuildContext ctx;
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          ListenableBuilder(
            listenable: checks,
            builder: (context, _) {
              ctx = context;
              return _panel(MyDataForm(error: checks.formError, errorFocusNode: checks.formErrorFocus, groups: [
                FormGroup(heading: 'Name', children: [MyDataTextField(label: 'First', controller: _c(), focusNode: a)]),
              ]));
            },
          )));
      expect(checks.save(ctx, formRule: () => 'A contact needs a name.'), isFalse);
      await tester.pump();
      expect(find.text('A contact needs a name.'), findsOneWidget);
      expect(checks.formErrorFocus.hasFocus, isTrue);
      expect(checks.save(ctx, formRule: () => null), isTrue);
      await tester.pump();
      expect(find.text('A contact needs a name.'), findsNothing);
    });
  });
}

void _noop(bool _) {}
