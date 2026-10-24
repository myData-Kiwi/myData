// Each designed theme as a whole (design/themes/ARCHITECTURE.md 5, phase 3): one app scene per drawn built-in
// in its default palette, light and dark, in its own type, shape, density, borders, elevation, materials and
// every component variant together, so a look can be judged against its RULES.md and the variants' meeting
// points show (Approve in a brutal theme, a near-red palette, the window ground).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'designed_themes.dart';

void _noop() {}

/// myContacts' list and a contact beside it in the branded frame, with tabs, fields, the buttons and an
/// approval card.
class ThemeScene extends StatefulWidget {
  const ThemeScene({super.key});

  static final people = [
    ContactListEntry(id: 'a1', name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional', caption: 'Example Labs'),
    ContactListEntry(id: 'a2', name: 'Amy Example', givenName: 'Amy', familyName: 'Example', caption: 'amy@example.org'),
    ContactListEntry(id: 'b1', name: 'Ben Sample', givenName: 'Ben', familyName: 'Sample', caption: 'ben@example.org'),
    ContactListEntry(id: 'c1', name: 'Cleo Placeholder', givenName: 'Cleo', familyName: 'Placeholder'),
  ];

  @override
  State<ThemeScene> createState() => _ThemeSceneState();
}

class _ThemeSceneState extends State<ThemeScene> {
  final _name = TextEditingController(text: 'Kitchen Mac');
  final _note = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFrame(
        appName: 'myContacts',
        sections: const [
          AppSection(icon: MyDataIcon.people, label: 'Contacts'),
          AppSection(icon: MyDataIcon.trash, label: 'Deleted'),
          AppSection(icon: MyDataIcon.review, label: 'Review', count: 4),
        ],
        current: 0,
        onSelect: (_) {},
        child: Padding(
          padding: EdgeInsets.all(context.space(6)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 300,
              child: ContactList(contacts: ThemeScene.people, selectedId: 'a2', onOpen: (_) {}, showSearch: false),
            ),
            SizedBox(width: context.space(6)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ContactHeader(
                  name: 'Amy Example',
                  jobTitle: 'Head of research',
                  organisation: 'Example Labs',
                  sourceLine: 'From iCloud, amy@example.org',
                  avatar: const Avatar(name: 'Amy Example', size: AvatarSize.large),
                ),
                SizedBox(height: context.space(4)),
                MyDataTabs(tabs: const ['Details', 'Notes', 'History'], current: 0, onChanged: (_) {}),
                SizedBox(height: context.space(4)),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: GroupedList(heading: 'Phone', rows: const [
                      GroupedRow(icon: MyDataIcon.call, title: 'Mobile', subtitle: '+44 7700 900123'),
                      GroupedRow(icon: MyDataIcon.cloud, title: 'iCloud', trailing: GroupedBadge('Connected', tone: MyDataTone.success)),
                      GroupedRow(title: 'Open in myCalendar', trailing: GroupedChevron(), onPressed: _noop),
                    ]),
                  ),
                  SizedBox(width: context.space(4)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      MyDataTextField(label: 'Device name', controller: _name, help: 'Shown to your other devices.'),
                      SizedBox(height: context.space(3)),
                      MyDataTextField(label: 'Notes', controller: _note, placeholder: 'Add a note'),
                    ]),
                  ),
                ]),
                SizedBox(height: context.space(4)),
                const ButtonRow(children: [
                  Button(label: 'Save', variant: ButtonVariant.filled, onPressed: _noop),
                  Button(label: 'Edit', onPressed: _noop),
                  Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: _noop),
                  Button(label: 'Delete', variant: ButtonVariant.danger, onPressed: _noop),
                ]),
                SizedBox(height: context.space(4)),
                const ApprovalCard(
                  question: 'Send this email?',
                  arguments: [('To', 'amy@example.org'), ('Subject', 'Train on Friday')],
                  approveLabel: 'Approve and send',
                  decidedLabel: 'Sent',
                  onApprove: _noop,
                  onEdit: _noop,
                  onReject: _noop,
                ),
              ]),
            ),
          ]),
        ),
      );
}

void main() {
  for (final id in drawnBuiltIns) {
    for (final b in Brightness.values) {
      final slug = id.substring('mydata.'.length);
      testWidgets('theme scene golden: $slug, ${b.name}', (tester) async {
        tester.view.physicalSize = const Size(1280, 860);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        debugDisableShadows = false;
        try {
          final look = designedLook(id, b, platform: TargetPlatform.linux);
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: MyDataTheme.fromLook(look).copyWith(platform: TargetPlatform.linux),
            home: const ThemeScene(),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(const MinimumTapTargetGuideline(size: Size(24, 24), link: '')));
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/scene.$slug.${b.name}.png'));
        } finally {
          debugDisableShadows = true;
        }
      });
    }
  }
}
