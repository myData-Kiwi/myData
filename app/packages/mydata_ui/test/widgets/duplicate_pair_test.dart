import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

// Invented people only (design/components/DuplicatePair, "Copy").
const _ava = PairVersion(
  name: 'Ava Fictional',
  givenName: 'Ava',
  familyName: 'Fictional',
  caption: 'Added 2 Oct 2026',
  fields: {
    PairField.name: [PairValue('Ava Fictional')],
    PairField.jobTitle: [PairValue('Head of research')],
    PairField.phone: [PairValue('555-0142', label: 'mobile')],
    PairField.email: [PairValue('ava@example.org', label: 'work')],
    PairField.birthday: [PairValue('18 March')],
  },
);

const _avaM = PairVersion(
  name: 'Ava M. Fictional',
  givenName: 'Ava',
  familyName: 'Fictional',
  caption: 'Imported 14 Oct 2026',
  fields: {
    PairField.name: [PairValue('Ava M. Fictional')],
    PairField.jobTitle: [PairValue('Researcher')],
    PairField.phone: [PairValue('555 0142', label: 'mobile'), PairValue('555-0177', label: 'work')],
    PairField.email: [PairValue('AVA@example.org', label: 'work')],
    PairField.birthday: [PairValue('18 March 1990')],
  },
);

const _merged = PairAfter(
  title: PairAfter.mergingTitle,
  caption: 'A new contact. These two go to Recently deleted.',
  fields: {
    PairField.name: [PairValue('Ava Fictional')],
    PairField.jobTitle: [PairValue('Head of research')],
    PairField.phone: [PairValue('555-0142', label: 'mobile'), PairValue('555-0177', label: 'work')],
    PairField.email: [PairValue('ava@example.org', label: 'work')],
    PairField.birthday: [PairValue('18 March')],
  },
  leftOut: {
    PairField.jobTitle: ['Researcher'],
    PairField.birthday: ['18 March 1990'],
  },
);

Widget _merge({double width = 960}) => SizedBox(
      width: width,
      child: DuplicatePair(
        versions: const [_ava, _avaM],
        mode: PairMode.merge,
        after: _merged,
        note: 'What is left out stays with the originals in Recently deleted for 30 days.',
        actions: [
          const Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: _noop),
          const Button(label: 'Merge', variant: ButtonVariant.filled, onPressed: _noop),
        ],
      ),
    );

Widget _compare() => const SizedBox(
      width: 640,
      child: DuplicatePair(
        versions: [
          PairVersion(name: 'In the file', caption: 'Ava M. Fictional', fields: {
            PairField.name: [PairValue('Ava M. Fictional')],
            PairField.phone: [PairValue('555-0142', label: 'mobile')],
          }),
          PairVersion(name: 'In myData', caption: 'Ava Fictional', fields: {
            PairField.name: [PairValue('Ava Fictional')],
            PairField.phone: [PairValue('555 0142', label: 'mobile')],
          }),
        ],
      ),
    );

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(1100, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, child));
  await tester.pump();
}

void main() {
  goldenMatrix('duplicate_pair_merge', _merge, size: const Size(1008, 640));
  goldenMatrix('duplicate_pair_merge_narrow', () => _merge(width: 640), size: const Size(688, 900));
  goldenMatrix('duplicate_pair_compare', _compare, size: const Size(688, 320));
  goldenMatrix(
    'duplicate_pair_loading',
    () => const SizedBox(width: 640, child: DuplicatePair(versions: [_ava, _avaM], loading: true)),
    size: const Size(688, 360),
  );

  test('differences ignore the case of emails, the spacing of phones and spacing, not other values', () {
    final d = DuplicatePair.differing(const [_ava, _avaM]);
    expect(d, {PairField.name, PairField.jobTitle, PairField.phone, PairField.birthday});
    expect(d, isNot(contains(PairField.email)));
    // A value on one side only differs.
    expect(
      DuplicatePair.differing(const [
        PairVersion(name: 'a', caption: '', fields: {PairField.notes: [PairValue('x')]}),
        PairVersion(name: 'b', caption: '', fields: {}),
      ]),
      {PairField.notes},
    );
    expect(PairField.phone.normalise('+44 7700 900123'), '+447700900123');
    expect(PairField.email.normalise(' Ava@Example.org '), 'ava@example.org');
    expect(PairField.name.normalise('Ava   Fictional '), 'Ava Fictional');
  });

  testWidgets('merge shows every row, marks differing ones with "Differs" and writes what is left out',
      (tester) async {
    await _pump(tester, _merge());
    expect(find.text('Email'), findsOneWidget);
    expect(find.text(DuplicatePair.differsLabel), findsNWidgets(4));
    expect(find.text('Left out: Researcher'), findsOneWidget);
    expect(find.text('Left out: 18 March 1990'), findsOneWidget);
    expect(find.text(PairAfter.mergingTitle), findsOneWidget);
    expect(find.text('Show all fields'), findsNothing);
  });

  testWidgets('a differing row reads its label, "Differs" and each column', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _merge());
    expect(
      find.bySemanticsLabel(
        'Phone, Differs. Ava Fictional: mobile 555-0142. Ava M. Fictional: mobile 555 0142, work 555-0177. '
        'After merging: mobile 555-0142, work 555-0177',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Birthday, Differs\..*After merging: 18 March\. Left out: 18 March 1990$')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('under 900px of content, "After merging" is a group of its own under the grid', (tester) async {
    await _pump(tester, _merge(width: 640));
    final header = tester.getRect(find.text(PairAfter.mergingTitle));
    final grid = tester.getRect(find.text('Ava M. Fictional').first);
    expect(header.top, greaterThan(grid.bottom));
  });

  testWidgets('compare shows only differing rows until "Show all fields"', (tester) async {
    await _pump(tester, _compare());
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Phone'), findsNothing);
    await tester.tap(find.text(DuplicatePair.showAllLabel));
    await tester.pump();
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text(DuplicatePair.showDifferencesLabel), findsOneWidget);
  });

  testWidgets('changes: a Select in each differing after cell picks whose values to keep', (tester) async {
    final chosen = <PairField, int>{};
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 960,
          child: DuplicatePair(
            versions: const [_ava, _avaM],
            mode: PairMode.changes,
            differences: const {PairField.jobTitle},
            after: PairAfter(
              title: PairAfter.changesTitle,
              caption: 'Your contact after saving',
              fields: const {},
              choices: chosen,
              onChoose: (f, i) => setState(() => chosen[f] = i),
            ),
          ),
        ),
      ),
    );
    // Only the host's differences are marked.
    expect(find.text(DuplicatePair.differsLabel), findsOneWidget);
    expect(find.byType(MyDataSelect<int>), findsOneWidget);
    expect(find.text('Head of research'), findsNWidgets(2));
    await tester.tap(find.byType(MyDataSelect<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ava M. Fictional').last);
    await tester.pumpAndSettle();
    expect(chosen, {PairField.jobTitle: 1});
    expect(find.text('Researcher'), findsNWidgets(2));
  });

  testWidgets('loading shows the names and grey bars, no values', (tester) async {
    await _pump(tester, const SizedBox(width: 640, child: DuplicatePair(versions: [_ava, _avaM], loading: true)));
    expect(find.text('Ava Fictional'), findsOneWidget);
    expect(find.text('Head of research'), findsNothing);
    expect(find.byType(KiwiLoader), findsNothing);
  });

  testWidgets('under 600px a segmented control switches between the versions', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedFrame(themeMatrix.first, const SizedBox(width: 340, child: DuplicatePair(
      versions: [_ava, _avaM],
      mode: PairMode.merge,
      after: _merged,
    )), padding: const EdgeInsets.all(16)));
    expect(find.byType(SegmentedControl<int>), findsOneWidget);
    expect(find.text('Head of research'), findsOneWidget);
    await tester.tap(find.text('Ava M. Fictional'));
    await tester.pumpAndSettle();
    expect(find.text('Researcher'), findsOneWidget);
    // Differing rows keep their word in every segment.
    expect(find.text(DuplicatePair.differsLabel), findsWidgets);
  });

  testWidgets('unframed inside a group: no card of its own', (tester) async {
    await _pump(tester, const SizedBox(width: 640, child: DuplicatePair(versions: [_ava, _avaM], framed: false)));
    final cards = find.descendant(
      of: find.byType(DuplicatePair),
      matching: find.byWidgetPredicate((w) => w is Container && w.decoration.isBox &&
          (w.decoration!.box).boxShadow != null),
    );
    expect(cards, findsNothing);
  });
}
