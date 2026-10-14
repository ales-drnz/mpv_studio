/// A [Stopwatch] that never moves: it starts and stops, but always reads
/// zero. Widgets that run something on by the wall clock between events
/// (the waveform's playhead) get one in a scene, so what a frame shows
/// depends on scene time alone.
class StillStopwatch implements Stopwatch {
  bool _running = false;

  @override
  int get frequency => 1000000;

  @override
  void start() => _running = true;

  @override
  void stop() => _running = false;

  @override
  void reset() {}

  @override
  int get elapsedTicks => 0;

  @override
  Duration get elapsed => Duration.zero;

  @override
  int get elapsedMicroseconds => 0;

  @override
  int get elapsedMilliseconds => 0;

  @override
  bool get isRunning => _running;
}

/// A [Stopwatch] that reads elapsed time from [now] (a test's fake
/// clock, say `tester.binding.clock.now`), so whatever it times moves
/// with scene time and the same way on every run.
class ClockStopwatch implements Stopwatch {
  ClockStopwatch(this.now);

  final DateTime Function() now;
  DateTime? _startedAt;
  Duration _banked = Duration.zero;

  @override
  int get frequency => 1000000;

  @override
  void start() => _startedAt ??= now();

  @override
  void stop() {
    final at = _startedAt;
    if (at == null) return;
    _banked += now().difference(at);
    _startedAt = null;
  }

  @override
  void reset() {
    _banked = Duration.zero;
    if (_startedAt != null) _startedAt = now();
  }

  @override
  Duration get elapsed {
    final at = _startedAt;
    return at == null ? _banked : _banked + now().difference(at);
  }

  @override
  int get elapsedTicks => elapsed.inMicroseconds;

  @override
  int get elapsedMicroseconds => elapsed.inMicroseconds;

  @override
  int get elapsedMilliseconds => elapsed.inMilliseconds;

  @override
  bool get isRunning => _startedAt != null;
}
