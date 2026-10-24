// The component variants (design/themes/ARCHITECTURE.md 3.2 and 5, phase 3): one golden per value of each
// `components` key, in light and dark, on a specimen of the shared widgets that draw it. Each look is Kiwi
// with that one value changed, so the golden shows what the variant does and nothing else.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'variant_harness.dart';

/// Every role of button, the primary focused by keyboard, then the disabled ones.
class ButtonSpecimen extends StatelessWidget {
  const ButtonSpecimen({super.key, required this.focus});
  final FocusNode focus;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButtonRow(children: [
            Button(label: 'Approve and send', variant: ButtonVariant.filled, focusNode: focus, onPressed: noop),
            const Button(label: 'Edit', onPressed: noop),
            const Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: noop),
            const Button(label: 'Delete', variant: ButtonVariant.danger, onPressed: noop),
          ]),
          SizedBox(height: context.space(4)),
          const ButtonRow(children: [
            Button(label: 'Add a device', variant: ButtonVariant.filled, onPressed: null),
            Button(label: 'Rename', onPressed: null),
            Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: noop),
          ]),
        ],
      );
}

void main() {
  group('buttons', () {
    for (final key in ['button.primary', 'button.secondary', 'button.shape']) {
      variantGoldens(key, (focus) => ButtonSpecimen(focus: focus), size: const Size(560, 150));
    }

    // An accent near `danger`'s red: the primary is drawn in `ink`, so Approve never looks like Delete.
    variantGoldens('button.primary', (focus) => ButtonSpecimen(focus: focus),
        size: const Size(560, 150), values: ['filled', 'outline'], also: nearRedAccent, name: 'near-red');

    testWidgets('a primary near red is ink with its label in bg; danger stays red', (tester) async {
      await pumpVariant(tester, kiwiWith(nearRedAccent), Brightness.light, ButtonSpecimen(focus: FocusNode()));
      final look = tester.element(find.byType(ButtonSpecimen)).look;
      expect(look.accentNearDanger, isTrue);
      final primary = ButtonPaint.of(look, ButtonVariant.filled);
      expect(primary.fill, look.colors.ink);
      expect(primary.foreground, look.colors.bg);
      expect(ButtonPaint.of(look, ButtonVariant.danger).fill, look.colors.danger);
    });

    test('every primary looks like a button: a fill or an outline, never text alone', () {
      for (final value in componentValues['button.primary']!) {
        for (final b in Brightness.values) {
          final look = ThemeLibrary.look(kiwiWith(component('button.primary', value)), brightness: b);
          final p = ButtonPaint.of(look, ButtonVariant.filled);
          expect(p.fill != null || (p.side?.width ?? 0) >= 2, isTrue, reason: value);
        }
      }
    });
  });

  group('the approval card', () {
    Widget card() => ApprovalCard(
          question: 'Send this email?',
          arguments: const [('To', 'ava@example.org'), ('Subject', 'Train on Friday')],
          approveLabel: 'Approve and send',
          decidedLabel: 'Sent',
          onApprove: noop,
          onEdit: noop,
          onReject: noop,
        );

    // Its structure stays in every theme: a brutal, bevelled or push primary draws its Approve filled, and an
    // outline primary outlined; the card keeps its solid surface and line-strong edge.
    variantGoldens('button.primary', (_) => card(),
        size: const Size(520, 260), focused: false, values: ['outline', 'brutal'], name: 'approval');

    test('Approve is filled or outlined, never brutal, bevelled or a push button', () {
      for (final value in componentValues['button.primary']!) {
        final look = ThemeLibrary.look(kiwiWith(component('button.primary', value)), brightness: Brightness.light);
        final approve = ButtonPaint.of(look, ButtonVariant.filled, approval: true);
        final filled = ButtonPaint.of(
            ThemeLibrary.look(kiwiWith(component('button.primary', 'filled')), brightness: Brightness.light),
            ButtonVariant.filled);
        if (value == 'outline') {
          expect(approve.fill, isNull);
        } else {
          expect((approve.fill, approve.side, approve.collapses), (filled.fill, filled.side, false), reason: value);
          expect(approve.shadows, filled.shadows, reason: value);
        }
      }
    });
  });
}
