// The drawn built-ins on real components at a larger text size (1.3x): rows, a form row, a badge, the
// contact header and every button role in each look's type, density and colours, so overflow from a bigger
// body or label shows up. One golden per look and mode.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'designed_themes.dart';

void _noop() {}

class ComponentSpecimen extends StatelessWidget {
  const ComponentSpecimen({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContactHeader(
            name: 'Ava Fictional',
            jobTitle: 'Head of research',
            organisation: 'Example Labs',
            sourceLine: 'From iCloud, ava@example.org',
            avatar: const Avatar(name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional', size: AvatarSize.large),
          ),
          SizedBox(height: context.space(4)),
          GroupedList(heading: 'Phone', rows: const [
            GroupedRow(icon: MyDataIcon.call, title: 'Mobile', subtitle: '+44 7700 900123'),
            GroupedRow(
              icon: MyDataIcon.cloud,
              title: 'The iCloud account ava@example.org',
              subtitle: '128 contacts, as of 13 Oct 2026 at 08:40',
              trailing: GroupedBadge('Connected', tone: MyDataTone.success),
            ),
            GroupedRow(title: 'Open in myContacts', trailing: GroupedChevron(), onPressed: _noop),
          ]),
          SizedBox(height: context.space(4)),
          MyDataTextField(label: 'Device name', controller: controller, help: 'Shown to your other devices.'),
          SizedBox(height: context.space(4)),
          // Every button role, the plain ones last: underlined where a theme outlines every control.
          const ButtonRow(children: [
            Button(label: 'Save', variant: ButtonVariant.filled, onPressed: _noop),
            Button(label: 'Edit', onPressed: _noop),
            Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: _noop),
            Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: _noop),
          ]),
        ],
      );
}

void main() {
  for (final id in drawnBuiltIns) {
    for (final b in Brightness.values) {
      final slug = id.substring('mydata.'.length);
      testWidgets('component golden at 1.3x text ($slug-${b.name})', (tester) async {
        // Large's 19 px text at 1.3x needs a taller page; its rows themselves fit.
        final size = Size(560, id == 'mydata.large' ? 1000 : 840);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        debugDisableShadows = false;
        final controller = TextEditingController(text: 'Kitchen Mac');
        addTearDown(controller.dispose);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MyDataTheme.fromLook(designedLook(id, b)),
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.3)),
            child: Builder(
              builder: (context) => Material(
                color: context.colors.bg,
                child: Padding(
                  padding: EdgeInsets.all(context.space(4)),
                  child: ComponentSpecimen(controller: controller),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'no overflow at 1.3x');
        try {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/components.$slug-${b.name}.png'));
        } finally {
          debugDisableShadows = true;
        }
      });
    }
  }
}
