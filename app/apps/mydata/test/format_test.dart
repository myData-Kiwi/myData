import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/format.dart';

void main() {
  test('a timestamp with no offset is shown as written, in every time zone', () {
    // The screenshot fixtures rely on this, so the screenshots do not depend on the machine's time zone.
    expect(formatWhen('2026-10-12T08:05:00', use24HourFormat: true), '12 Oct 2026, 08:05');
    expect(formatWhen('2026-10-12T08:05:00', use24HourFormat: false), '12 Oct 2026, 8:05 am');
  });

  test('a UTC timestamp from the host is shown in local time', () {
    final local = DateTime.utc(2026, 10, 12, 8, 5).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    expect(formatWhen('2026-10-12T08:05:00Z', use24HourFormat: true),
        '${formatDay(local)}, ${two(local.hour)}:${two(local.minute)}');
  });

  test('text that is not a timestamp is shown as it is', () {
    expect(formatWhen('soon'), 'soon');
  });
}
