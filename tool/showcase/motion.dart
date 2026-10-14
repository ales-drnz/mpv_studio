import 'dart:math' as math;
import 'dart:ui';

/// The easing of every cursor glide: a slow start, a slow landing.
double easeInOut(double t) {
  final x = t.clamp(0.0, 1.0);
  return x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;
}

/// The easing of things that pop out and settle, like the click ring.
double easeOut(double t) {
  final x = t.clamp(0.0, 1.0);
  return 1 - math.pow(1 - x, 3).toDouble();
}

/// How long a glide over [distance] logical pixels takes: longer for
/// longer trips, between [min] and [max] milliseconds.
int glideMillis(double distance, {int min = 300, int max = 650}) =>
    (230 + distance * 0.5).clamp(min.toDouble(), max.toDouble()).round();

/// A hand's path from [from] to [to]: a quadratic curve bowed a little to
/// one side, the way a wrist swings, sampled with [easeInOut].
class GlidePath {
  GlidePath(this.from, this.to, {double bow = 0.12})
    : _control = _controlPoint(from, to, bow);

  final Offset from;
  final Offset to;
  final Offset _control;

  static Offset _controlPoint(Offset a, Offset b, double bow) {
    final d = b - a;
    final len = d.distance;
    if (len < 1) return a;
    // The bow always lifts the path the same way for a given direction,
    // so a trip and its return trace different arcs, like a real hand.
    final normal = Offset(-d.dy, d.dx) / len;
    final side = d.dx >= 0 ? -1.0 : 1.0;
    return a + d / 2 + normal * (len * bow * side);
  }

  double get length => (to - from).distance;

  /// The point at [t] (0 to 1) of the trip, eased.
  Offset at(double t) {
    final s = easeInOut(t);
    final u = 1 - s;
    return from * (u * u) + _control * (2 * u * s) + to * (s * s);
  }
}

/// A small deterministic random source (an xorshift), so a scene draws
/// the same jitter, typing rhythm and noise on every run.
class SceneRandom {
  SceneRandom([int seed = 0x9E3779B9]) : _state = seed == 0 ? 1 : seed;

  int _state;

  /// The next value in 0 (inclusive) to 1 (exclusive).
  double next() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state / 4294967296.0;
  }

  /// A value in [lo] to [hi].
  double range(double lo, double hi) => lo + (hi - lo) * next();
}
