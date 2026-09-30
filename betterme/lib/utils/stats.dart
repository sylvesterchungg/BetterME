// Small, pure statistics helpers shared across the app so the same rules are
// applied everywhere (avoids the Profile vs. Trends averaging drift).
//
// These functions are deliberately free of Flutter/Firebase dependencies so
// they can be unit-tested directly (see test/stats_test.dart).

/// Arithmetic mean of [values], ignoring non-positive entries.
///
/// The app lets users log mood and sleep independently, so a mood-only day
/// stores `sleepHours == 0` and a sleep-only day stores `moodScore == 0`.
/// Those zeros are "no data", not real measurements, so they must be excluded
/// from an average — otherwise the mean is dragged toward zero. Returns 0.0
/// when there is no positive data to average.
double meanIgnoringZero(Iterable<double> values) {
  var sum = 0.0;
  var count = 0;
  for (final v in values) {
    if (v > 0) {
      sum += v;
      count++;
    }
  }
  return count == 0 ? 0.0 : sum / count;
}

/// Hours of sleep between a bedtime and a wake-up time on a 24-hour clock,
/// wrapping past midnight. Inputs are clock components (hour 0–23, minute 0–59)
/// rather than a Flutter TimeOfDay, so this stays pure Dart and unit-testable.
///
/// The duration is `wake - bed`; when `wake <= bed` a full day (24h) is added so
/// an overnight sleep (e.g. 23:00 → 07:00) reads as 8.0 hours. Identical times
/// therefore yield 24.0 — an obvious mis-entry the user can see and correct.
double sleepHoursBetween(int bedHour, int bedMinute, int wakeHour, int wakeMinute) {
  final bed = bedHour * 60 + bedMinute;
  final wake = wakeHour * 60 + wakeMinute;
  var diff = wake - bed;
  if (diff <= 0) diff += 24 * 60;
  return diff / 60.0;
}

/// The current daily-log streak: the number of consecutive calendar days that
/// each have at least one log, ending at today (if there is a log today) or at
/// yesterday (if there is a log yesterday but not yet today, so the streak
/// stays alive for the day). Returns 0 when there are no logs, or when the most
/// recent log is older than yesterday (the streak is already broken).
///
/// [today] is injectable so the logic can be tested deterministically; it
/// defaults to `DateTime.now()`. Only the date component of each input is used.
int computeLogStreak(Iterable<DateTime> logDates, {DateTime? today}) {

  final loggedDays = <DateTime>{
    for (final d in logDates) DateTime(d.year, d.month, d.day),
  };
  if (loggedDays.isEmpty) return 0;

  final now = today ?? DateTime.now();
  final todayDay = DateTime(now.year, now.month, now.day);
  final yesterday = _previousDay(todayDay);

  DateTime cursor;
  if (loggedDays.contains(todayDay)) {
    cursor = todayDay;
  } else if (loggedDays.contains(yesterday)) {
    cursor = yesterday;
  } else {
    return 0;
  }

  var streak = 0;
  while (loggedDays.contains(cursor)) {
    streak++;
    cursor = _previousDay(cursor);
  }
  return streak;
}

DateTime _previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// The wall-clock instant at which the daily logging reminder (FR_905) should
/// next fire, or null when the reminder is off / the time is out of range.
///
/// [minutesFromMidnight] is the user's configured time (1260 = 21:00). The
/// occurrence is pushed to tomorrow in two cases: when today already has a log
/// entry ([loggedToday]) — the reminder exists only to reach users who have not
/// logged — and when today's time has already passed, since a notification
/// scheduled in the past fires immediately and would nag a user who has just
/// opened the app.
DateTime? nextLogReminderOccurrence(
  int minutesFromMidnight, {
  required bool loggedToday,
  required DateTime now,
}) {
  if (minutesFromMidnight < 0 || minutesFromMidnight > 1439) return null;

  final at = DateTime(now.year, now.month, now.day, minutesFromMidnight ~/ 60,
      minutesFromMidnight % 60);
  if (loggedToday || !at.isAfter(now)) {
    return DateTime(at.year, at.month, at.day + 1, at.hour, at.minute);
  }
  return at;
}
