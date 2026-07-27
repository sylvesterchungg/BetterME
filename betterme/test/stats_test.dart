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

  group('sleepHoursBetween', () {
    test('overnight sleep wraps past midnight', () {
      // 23:00 -> 07:00 is 8 hours across midnight.
      expect(sleepHoursBetween(23, 0, 7, 0), 8.0);
    });

    test('same-day sleep (both times after midnight)', () {
      // 01:00 -> 09:00 is 8 hours.
      expect(sleepHoursBetween(1, 0, 9, 0), 8.0);
    });

    test('handles fractional minutes', () {
      // 22:30 -> 06:15 = 7h45m = 7.75h.
      expect(sleepHoursBetween(22, 30, 6, 15), 7.75);
    });

    test('a short nap the same evening', () {
      // 23:00 -> 23:30 = 0.5h.
      expect(sleepHoursBetween(23, 0, 23, 30), 0.5);
    });

    test('identical times yield 24h (obvious mis-entry, left as-is)', () {
      expect(sleepHoursBetween(23, 0, 23, 0), 24.0);
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


  group('nextLogReminderOccurrence (FR_905)', () {
    // 21:00 reminder, "now" is mid-afternoon on 15 Mar 2026.
    final now = DateTime(2026, 3, 15, 14, 30);
    const at2100 = 21 * 60;

    test('fires today when not yet logged and the time is still ahead', () {
      expect(
        nextLogReminderOccurrence(at2100, loggedToday: false, now: now),
        DateTime(2026, 3, 15, 21, 0),
      );
    });

    test('skips to tomorrow when today has already been logged', () {
      expect(
        nextLogReminderOccurrence(at2100, loggedToday: true, now: now),
        DateTime(2026, 3, 16, 21, 0),
      );
    });

    test('skips to tomorrow when the time has already passed today', () {
      final late = DateTime(2026, 3, 15, 22, 15);
      expect(
        nextLogReminderOccurrence(at2100, loggedToday: false, now: late),
        DateTime(2026, 3, 16, 21, 0),
      );
    });

    test('a reminder due exactly now rolls to tomorrow, never fires instantly', () {
      final exactly = DateTime(2026, 3, 15, 21, 0);
      expect(
        nextLogReminderOccurrence(at2100, loggedToday: false, now: exactly),
        DateTime(2026, 3, 16, 21, 0),
      );
    });

    test('rolls across a month boundary', () {
      final endOfMonth = DateTime(2026, 3, 31, 23, 0);
      expect(
        nextLogReminderOccurrence(at2100, loggedToday: false, now: endOfMonth),
        DateTime(2026, 4, 1, 21, 0),
      );
    });

    test('returns null when disabled (-1) or out of range', () {
      expect(nextLogReminderOccurrence(-1, loggedToday: false, now: now), isNull);
      expect(nextLogReminderOccurrence(1440, loggedToday: false, now: now), isNull);
    });

    test('midnight (0) is a valid time, not treated as disabled', () {
      expect(
        nextLogReminderOccurrence(0, loggedToday: false, now: now),
        DateTime(2026, 3, 16, 0, 0),
      );
    });
  });
}
