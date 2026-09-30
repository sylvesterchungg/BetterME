/// Tracks which background Firestore listeners are currently in a failed
/// state, so the interface can tell the user that something stopped syncing
/// instead of silently showing stale data.
///
/// Kept free of Firebase and Flutter types so it can be unit tested on its
/// own — [AppProvider] holds one and forwards its stream callbacks into it.
///
/// Every mutator returns whether the tracked state actually changed. A failing
/// listener re-emits the same error repeatedly, and every *successful*
/// emission clears its own stream, so reacting to each call unconditionally
/// would rebuild the whole interface thousands of times on a healthy app.
class StreamErrorTracker {
  final Map<String, String> _errors = {};

  bool get hasError => _errors.isNotEmpty;

  /// Failed stream names, sorted so the interface renders them in a stable
  /// order rather than in map-insertion order.
  List<String> get failedStreams => _errors.keys.toList()..sort();

  String? errorFor(String stream) => _errors[stream];

  /// Records [error] against [stream]. Returns true when this is new
  /// information — a newly failed stream, or a different error than before.
  bool record(String stream, Object error) {
    final text = error.toString();
    if (_errors[stream] == text) return false;
    _errors[stream] = text;
    return true;
  }

  /// Marks [stream] healthy again. Returns true only if it was failing.
  bool clear(String stream) => _errors.remove(stream) != null;

  /// Clears every recorded error, e.g. before a manual retry. Returns true
  /// only if anything was actually cleared.
  bool clearAll() {
    if (_errors.isEmpty) return false;
    _errors.clear();
    return true;
  }

  /// A short, user-facing description of what stopped syncing. Empty when
  /// nothing has failed.
  String get summary {
    final failed = failedStreams;
    if (failed.isEmpty) return '';
    if (failed.length == 1) {
      final name = failed.first;
      final label = name[0].toUpperCase() + name.substring(1);
      return "$label isn't syncing";
    }
    return "${failed.length} areas aren't syncing";
  }
}
