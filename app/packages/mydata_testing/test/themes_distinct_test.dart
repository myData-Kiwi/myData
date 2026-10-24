// themesDistinct's rules (distinctProblems): a pair under the bar fails unless named in `alike`, a named
// pair has a floor, a stale exception fails, and a key in either order counts while one that names no pair
// of drawn themes fails.
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';

void main() {
  const themes = ['kiwi', 'paperback', 'notebook'];
  Map<String, double> scores({double notebookPaperback = 0.26}) => {
        themePair('kiwi', 'paperback'): 0.5,
        themePair('kiwi', 'notebook'): 0.45,
        themePair('paperback', 'notebook'): notebookPaperback,
      };

  test('a pair is named the same way whatever its order', () {
    expect(themePair('paperback', 'notebook'), 'notebook and paperback');
    expect(themePair('notebook', 'paperback'), 'notebook and paperback');
  });

  test('a pair under the bar fails unless it is named', () {
    expect(distinctProblems(scores(), least: 0.3, alike: const {}, themes: themes), ['notebook and paperback: 0.26']);
  });

  test('a named pair passes at its measured score, in either order of its key', () {
    for (final key in ['notebook and paperback', 'paperback and notebook']) {
      expect(distinctProblems(scores(), least: 0.3, alike: {key: (0.26, 'ruled paper')}, themes: themes), isEmpty,
          reason: key);
      expect(
          distinctProblems(scores(notebookPaperback: 0.245), least: 0.3, alike: {key: (0.26, 'ruled paper')}, themes: themes),
          isEmpty,
          reason: '$key, within the slack');
    }
  });

  test('a named pair that drifts under its floor fails', () {
    final problems = distinctProblems(scores(notebookPaperback: 0.1),
        least: 0.3, alike: const {'notebook and paperback': (0.26, 'ruled paper')}, themes: themes);
    expect(problems, hasLength(1));
    expect(problems.single, contains('under the 0.26'));
  });

  test('a named pair that clears the bar is a stale exception', () {
    final problems = distinctProblems(scores(notebookPaperback: 0.35),
        least: 0.3, alike: const {'notebook and paperback': (0.26, 'ruled paper')}, themes: themes);
    expect(problems.single, contains('drop its exception'));
  });

  test('a key that names no pair of drawn themes fails', () {
    for (final key in ['notebook and notebook', 'notebook and zen', 'notebook, paperback', 'a and b and c']) {
      final problems = distinctProblems(scores(),
          least: 0.3, alike: {key: (0.26, 'x'), 'notebook and paperback': (0.26, 'ruled paper')}, themes: themes);
      expect(problems.single, contains('names no pair'), reason: key);
    }
  });
}
