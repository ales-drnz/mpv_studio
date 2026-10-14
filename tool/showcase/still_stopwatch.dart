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
