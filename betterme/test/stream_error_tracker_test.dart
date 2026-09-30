import 'package:flutter_test/flutter_test.dart';
import 'package:betterme/utils/stream_error_tracker.dart';

void main() {
  group('StreamErrorTracker', () {
    test('starts with no failed streams', () {
      final tracker = StreamErrorTracker();
      expect(tracker.hasError, isFalse);
      expect(tracker.failedStreams, isEmpty);
    });

    test('record() marks a stream as failed', () {
      final tracker = StreamErrorTracker();
      tracker.record('friends', 'permission-denied');

      expect(tracker.hasError, isTrue);
      expect(tracker.failedStreams, ['friends']);
      expect(tracker.errorFor('friends'), contains('permission-denied'));
    });

    test('record() returns true only when the state actually changed', () {
      // A failing Firestore listener can re-emit the same error repeatedly.
      // The caller uses this return value to decide whether to rebuild the UI,
      // so an unchanged error must NOT report a change.
      final tracker = StreamErrorTracker();

      expect(tracker.record('friends', 'permission-denied'), isTrue);
      expect(tracker.record('friends', 'permission-denied'), isFalse);
    });

    test('record() reports a change when the same stream fails differently', () {
      final tracker = StreamErrorTracker();
      tracker.record('friends', 'permission-denied');

      expect(tracker.record('friends', 'unavailable'), isTrue);
      expect(tracker.errorFor('friends'), contains('unavailable'));
    });

    test('clear() removes a failed stream and reports the change', () {
      final tracker = StreamErrorTracker();
      tracker.record('logs', 'permission-denied');

      expect(tracker.clear('logs'), isTrue);
      expect(tracker.hasError, isFalse);
      expect(tracker.errorFor('logs'), isNull);
    });

    test('clear() on a healthy stream reports no change', () {
      // Every successful emission clears its own stream. On a healthy app that
      // is thousands of calls, none of which should trigger a rebuild.
      final tracker = StreamErrorTracker();
      expect(tracker.clear('logs'), isFalse);
    });

    test('failedStreams is sorted so the UI order is deterministic', () {
      final tracker = StreamErrorTracker();
      tracker.record('logs', 'e');
      tracker.record('friends', 'e');
      tracker.record('tasks', 'e');

      expect(tracker.failedStreams, ['friends', 'logs', 'tasks']);
    });

    test('clearAll() empties the tracker and reports the change', () {
      final tracker = StreamErrorTracker();
      tracker.record('logs', 'e');
      tracker.record('friends', 'e');

      expect(tracker.clearAll(), isTrue);
      expect(tracker.hasError, isFalse);
    });

    test('clearAll() on an empty tracker reports no change', () {
      final tracker = StreamErrorTracker();
      expect(tracker.clearAll(), isFalse);
    });

    test('summary names the single failing area', () {
      final tracker = StreamErrorTracker();
      tracker.record('friends', 'permission-denied');

      expect(tracker.summary, "Friends isn't syncing");
    });

    test('summary counts multiple failing areas', () {
      final tracker = StreamErrorTracker();
      tracker.record('friends', 'e');
      tracker.record('logs', 'e');

      expect(tracker.summary, "2 areas aren't syncing");
    });

    test('summary is empty when nothing has failed', () {
      expect(StreamErrorTracker().summary, isEmpty);
    });
  });
}
