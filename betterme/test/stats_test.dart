import 'package:flutter_test/flutter_test.dart';
import 'package:betterme/utils/stats.dart';

void main() {
  group('meanIgnoringZero', () {
    test('returns 0 for an empty iterable', () {
      expect(meanIgnoringZero(const []), 0.0);
    });

    test('returns 0 when every value is non-positive', () {
      expect(meanIgnoringZero(const [0.0, 0.0, 0.0]), 0.0);
      expect(meanIgnoringZero(const [-1.0, 0.0]), 0.0);
    });

    test('averages only the positive values (zeros are "no data")', () {
      // Two real values (6 and 8) plus three "no data" zeros -> mean is 7,
      // NOT 20/5 = 4 as a naive average over all entries would give.
      expect(meanIgnoringZero(const [6.0, 0.0, 8.0, 0.0, 0.0]), 7.0);
    });

    test('averages normally when all values are positive', () {
      expect(meanIgnoringZero(const [2.0, 4.0, 6.0]), 4.0);
    });
  });

  group('computeLogStreak', () {
    // Fixed reference "today" so the tests are deterministic.
    final today = DateTime(2026, 7, 22);
    DateTime daysAgo(int n) => today.subtract(Duration(days: n));

    test('is 0 when there are no logs', () {
      expect(computeLogStreak(const [], today: today), 0);
    });

    test('counts a single log made today', () {
      expect(computeLogStreak([today], today: today), 1);
    });

    test('stays alive when the latest log was yesterday (not yet today)', () {
      expect(computeLogStreak([daysAgo(1)], today: today), 1);
    });

    test('is 0 when the most recent log is older than yesterday', () {
      expect(computeLogStreak([daysAgo(2)], today: today), 0);
    });

    test('counts consecutive days ending today', () {
      final logs = [today, daysAgo(1), daysAgo(2), daysAgo(3)];
      expect(computeLogStreak(logs, today: today), 4);
    });

    test('stops at the first gap in the run', () {
      // today, yesterday, then a gap at day-2, then more history.
      final logs = [today, daysAgo(1), daysAgo(3), daysAgo(4)];
      expect(computeLogStreak(logs, today: today), 2);
    });

    test('collapses multiple logs on the same day and ignores time-of-day', () {
      final logs = [
        DateTime(2026, 7, 22, 8, 30),
        DateTime(2026, 7, 22, 22, 15),
        DateTime(2026, 7, 21, 12, 0),
      ];
      expect(computeLogStreak(logs, today: today), 2);
    });
  });
}
