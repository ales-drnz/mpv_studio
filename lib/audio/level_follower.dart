import 'pcm_analysis.dart';

/// A peak-program meter follower with peak-hold, in dBFS — the ballistics
/// behind a VU/PPM bar, as pure Dart state. Feed it frame peaks as they
/// arrive, then [tick] it once per render frame; read [db] for the live
/// bar and [holdDb] for the latched marker.
///
/// Keeping this off the widget means the meter widget is just "push peaks,
/// tick, paint" — no smoothing maths interleaved with the build.
class LevelFollower {
  LevelFollower({
    this.minDb = -120,
    this.attackTau = 0.005,
    this.releaseTau = 1.7,
    this.holdMillis = 1500,
    this.fallDbPerSecond = 12,
  }) : _db = minDb,
       _holdDb = minDb;

  /// Floor of the meter range; the follower never reports below this.
  final double minDb;

  /// Attack / release time constants (seconds). Fast attack snaps to
  /// transients; slow release decays smoothly.
  final double attackTau;
  final double releaseTau;

  /// How long the peak-hold marker stays latched before it starts to
  /// fall, and how fast it falls afterwards.
  final int holdMillis;
  final double fallDbPerSecond;

  double _db;
  double _holdDb;
  double _pendingAmp = 0;
  Duration _holdSetAt = Duration.zero;

  /// Current smoothed level, dBFS.
  double get db => _db;

  /// Latched peak-hold level, dBFS.
  double get holdDb => _holdDb;

  /// Accumulate the loudest amplitude seen since the last [tick].
  void push(double amplitude) {
    if (amplitude > _pendingAmp) _pendingAmp = amplitude;
  }

  /// Advance the ballistics by [dtSeconds]; [now] is a monotonic clock used
  /// only for the hold timing. Call once per render frame.
  void tick(double dtSeconds, Duration now) {
    if (dtSeconds <= 0) return;
    final targetDb = _pendingAmp <= 1e-9
        ? minDb
        : amplitudeToDb(_pendingAmp, floorDb: minDb);
    _pendingAmp = 0;

    final tau = targetDb > _db ? attackTau : releaseTau;
    _db = emaTowardsTau(_db, targetDb, dtSeconds, tau);

    if (_db > _holdDb) {
      _holdDb = _db;
      _holdSetAt = now;
    } else if ((now - _holdSetAt).inMilliseconds > holdMillis) {
      final next = _holdDb - fallDbPerSecond * dtSeconds;
      _holdDb = next < _db ? _db : next;
    }
  }
}
