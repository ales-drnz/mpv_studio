import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/app_settings.dart';
import 'rack_catalog.dart';
import 'rack_chain.dart';

/// Where the rack's chain plays: the player, or a fake in tests.
abstract interface class EffectsEngine {
  /// The chain the engine holds now.
  List<AudioEffect> get current;

  /// The chain, on every change: the rack's own writes, rollbacks after a
  /// refused write, and writes from elsewhere.
  Stream<List<AudioEffect>> get changes;

  /// Plays [effects]. Throws [MpvCommandException] when mpv refuses them,
  /// with [current] back on the last chain it accepted.
  Future<void> apply(List<AudioEffect> effects);
}

/// [EffectsEngine] over a [Player].
class PlayerEffectsEngine implements EffectsEngine {
  final Player player;
  const PlayerEffectsEngine(this.player);

  @override
  List<AudioEffect> get current => player.state.audioEffects;

  @override
  Stream<List<AudioEffect>> get changes => player.stream.audioEffects;

  @override
  Future<void> apply(List<AudioEffect> effects) =>
      player.setAudioEffects(effects);
}

/// The state behind the Signal chain rack: the user's ordered chain, the
/// global bypass, which stages are open, and the last error. The player
/// stays the source of truth: the rack writes through [EffectsEngine.apply]
/// and follows what the engine reports.
///
/// Slider drags call [edit] with `live: true`: the rack shows the value
/// at once and sends the chain at most once per [throttle], then [flush]
/// sends the last value on release. A parameter change of the same shape
/// reaches mpv as a live `af-command`, so the drag is heard as it moves.
///
/// When mpv refuses a chain, the rack goes back to the last chain mpv
/// accepted and [error] says why.
class RackController extends ChangeNotifier {
  RackController(
    this._engine, {
    this.throttle = const Duration(milliseconds: 40),
    this.maxTappedStages = 6,
    void Function(List<AudioEffect>)? onRecord,
    void Function(bool hold)? onHold,
  })  : _onRecord = onRecord,
        _onHold = onHold {
    _chain = RackChain.of(_engine.current);
    _accepted = _chain;
    _sub = _engine.changes.listen(_onEngine);
  }

  /// The rack of [player], created on first use and kept for the life of
  /// the app, so the bypass and the open stages survive leaving the page.
  static RackController of(Player player, AppSettings settings) =>
      _registry[player] ??= RackController(
        PlayerEffectsEngine(player),
        onRecord: settings.recordEffects,
        onHold: (hold) => settings.holdEffects = hold,
      );

  static final Expando<RackController> _registry = Expando('rack');

  final EffectsEngine _engine;
  final void Function(List<AudioEffect>)? _onRecord;
  final void Function(bool hold)? _onHold;

  /// The shortest gap between two live writes.
  final Duration throttle;

  /// How many open stages get their before and after meters. libmpv taps
  /// eight stages at once across the process; the rest is left to other
  /// surfaces (the compressor curve on its quick editor, for one).
  final int maxTappedStages;

  late final StreamSubscription<List<AudioEffect>> _sub;

  late RackChain _chain;

  /// The last chain mpv accepted, to go back to on a refusal.
  late RackChain _accepted;

  bool _bypass = false;
  String? _error;
  final Set<int> _expanded = {};

  Timer? _throttleTimer;
  bool _dirty = false;
  int _inFlight = 0;
  int _seq = 0;
  int _acceptedSeq = 0;
  bool _disposed = false;

  RackChain get chain => _chain;
  bool get bypass => _bypass;
  bool get meterOn => _chain.meterOn;

  /// A readable message for the last refused chain, until [clearError].
  String? get error => _error;

  bool isExpanded(int id) => _expanded.contains(id);

  /// The list the engine plays for the current state.
  List<AudioEffect> get engineChain => _bypass ? _chain.bypassed : _chain.effects;

  // ---- Edits ----------------------------------------------------------

  /// Replaces stage [id] with [effect]. With [live] the write is throttled,
  /// for a control that moves continuously; call [flush] when it stops.
  void edit(int id, AudioEffect effect, {bool live = false}) {
    if (_chain.stage(id) == null) return;
    _set(_chain.replace(id, effect), live: live);
  }

  /// Sends a pending live write now.
  void flush() {
    if (_throttleTimer == null && !_dirty) return;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _push();
  }

  void setEnabled(int id, bool on) => _set(_chain.setEnabled(id, on));

  /// Adds [effect], at the end or at [index], opens it and returns its id.
  /// A stage added after the meter goes before it, so the meter stays the
  /// last stage unless the user moves it.
  int add(AudioEffect effect, {int? index}) {
    var at = index;
    if (at == null && _chain.isNotEmptyEndingWithMeter) {
      at = _chain.length - 1;
    }
    final (next, id) = _chain.insert(effect, index: at);
    _expanded.add(id);
    _set(next);
    return id;
  }

  void remove(int id) {
    _expanded.remove(id);
    _set(_chain.remove(id));
  }

  /// Copies stage [id] right after it and returns the copy's id.
  int? duplicate(int id) {
    final r = _chain.duplicate(id);
    if (r == null) return null;
    if (_expanded.contains(id)) _expanded.add(r.$2);
    _set(r.$1);
    return r.$2;
  }

  /// Moves the stage at [from] so it ends up at index [to].
  void move(int from, int to) => _set(_chain.move(from, to));

  void setMeter(bool on) => _set(_chain.withMeter(on));

  /// Plays the chain with every stage off (the meters stay on), or the
  /// chain again. The rack keeps showing and editing the chain meanwhile.
  void setBypass(bool on) {
    if (on == _bypass) return;
    _bypass = on;
    _onHold?.call(on);
    if (on) _onRecord?.call(_chain.effects);
    _throttleTimer?.cancel();
    _throttleTimer = null;
    notifyListeners();
    _push();
  }

  void toggleExpanded(int id) {
    if (!_expanded.remove(id)) _expanded.add(id);
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // ---- Taps -----------------------------------------------------------

  /// Whether stage [id] gets its before and after meters: open, switched
  /// on, with a filter, not bypassed, and within [maxTappedStages] of the
  /// open stages counted from the top.
  bool tapGranted(int id) => _tapped().contains(id);

  /// Open stages that would have meters but are over the tap budget.
  bool tapDenied(int id) =>
      _tappable().contains(id) && !_tapped().contains(id);

  List<int> _tappable() => [
        if (!_bypass)
          for (final s in _chain.stages)
            if (_expanded.contains(s.id) &&
                s.effect.enabled &&
                s.effect.filter != null)
              s.id,
      ];

  Set<int> _tapped() => _tappable().take(maxTappedStages).toSet();

  // ---- Engine ---------------------------------------------------------

  void _set(RackChain next, {bool live = false}) {
    if (next == _chain) return;
    _chain = next;
    if (_bypass) _onRecord?.call(_chain.effects);
    notifyListeners();
    if (live) {
      _dirty = true;
      if (_throttleTimer == null) {
        _push();
        _throttleTimer = Timer(throttle, _onThrottle);
      }
    } else {
      _throttleTimer?.cancel();
      _throttleTimer = null;
      _push();
    }
  }

  void _onThrottle() {
    _throttleTimer = null;
    if (_dirty) {
      _push();
      _throttleTimer = Timer(throttle, _onThrottle);
    } else if (_inFlight == 0) {
      _onEngine(_engine.current);
    }
  }

  void _push() {
    _dirty = false;
    final sent = _chain;
    final seq = ++_seq;
    _inFlight++;
    _engine.apply(engineChain).then((_) {
      if (seq > _acceptedSeq) {
        _acceptedSeq = seq;
        _accepted = sent;
      }
    }, onError: (Object e) {
      if (_disposed) return;
      if (e is MpvCommandException) {
        _error = 'mpv refused the chain (${e.message}). '
            'Back to the last chain that played.';
      } else if (e is PlayerDisposedException) {
        return;
      } else {
        _error = 'The chain could not be applied: $e';
      }
      // A later write already replaced this one: it decides.
      if (seq == _seq) {
        _throttleTimer?.cancel();
        _throttleTimer = null;
        _dirty = false;
        _chain = _accepted;
        if (_bypass) _onRecord?.call(_chain.effects);
      }
      notifyListeners();
    }).whenComplete(() {
      _inFlight--;
      if (_disposed || _inFlight > 0 || _throttleTimer != null) return;
      _onEngine(_engine.current);
    });
  }

  void _onEngine(List<AudioEffect> fx) {
    // Our own writes in flight: their echoes are older than the rack.
    if (_disposed || _inFlight > 0 || _throttleTimer != null) return;
    if (listEquals(fx, engineChain)) return;
    // Changed elsewhere. While bypassed the engine plays a copy, so the
    // rack's chain stays as the user left it.
    if (_bypass) return;
    _chain = _chain.reconcile(fx);
    _accepted = _chain;
    _expanded.removeWhere((id) => _chain.stage(id) == null);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _throttleTimer?.cancel();
    _sub.cancel();
    super.dispose();
  }
}

extension on RackChain {
  bool get isNotEmptyEndingWithMeter =>
      stages.isNotEmpty && isMeterStage(stages.last.effect);
}
