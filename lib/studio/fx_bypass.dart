import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../generated/filter_catalog.dart';

/// Before and after comparison for the effects chain.
///
/// [engage] saves the current chain and swaps in a copy with every stage
/// switched off, so the audio plays dry while each stage keeps its settings
/// (the Effects page still shows them). [release] puts the saved chain back.
///
/// Whoever else writes the chain while the bypass is on wins: a chain that
/// differs from the muted copy ends the bypass and stays as written, with
/// [onHold] told so it can record it. Surfaces that edit the chain (the
/// Effects page) should show [active] and call [release] before editing.
///
/// [onHold] is called with `true` when the bypass starts and with `false`
/// and the chain now live when it ends, so persistence can skip the muted
/// copy (see `AppSettings.holdEffects`).
class FxBypass extends ChangeNotifier {
  FxBypass(
    this._player, {
    void Function(bool hold, List<AudioEffect>? current)? onHold,
  }) : _onHold = onHold;

  final PlayerApi _player;
  final void Function(bool hold, List<AudioEffect>? current)? _onHold;

  List<AudioEffect>? _saved;
  List<AudioEffect>? _muted;
  StreamSubscription<List<AudioEffect>>? _watch;
  bool _switching = false;

  /// Whether the chain is bypassed right now.
  bool get active => _saved != null;

  /// The chain that [release] restores, empty when not [active].
  List<AudioEffect> get savedChain => _saved ?? const [];

  /// Whether [chain] has at least one stage switched on, i.e. whether a
  /// bypass would change what you hear.
  static bool hasActiveStages(List<AudioEffect> chain) =>
      chain.any((e) => e.enabled);

  /// Flips between [engage] and [release].
  Future<void> toggle() => active ? release() : engage();

  /// Saves the current chain and plays it with every stage switched off.
  Future<void> engage() async {
    if (active || _switching) return;
    final chain = _player.state.audioEffects;
    final muted = [
      for (final e in chain) ?bypassedStage(e),
    ];
    _saved = chain;
    _muted = muted;
    _onHold?.call(true, null);
    notifyListeners();
    _switching = true;
    try {
      await _player.setAudioEffects(muted);
    } catch (_) {
      _end(chain);
      rethrow;
    } finally {
      _switching = false;
    }
    if (!active) return;
    _watch = _player.stream.audioEffects.listen(_onChain);
  }

  /// Puts the saved chain back. Does nothing when not [active].
  Future<void> release() async {
    final saved = _saved;
    if (saved == null || _switching) return;
    _switching = true;
    try {
      await _watch?.cancel();
      _watch = null;
      await _player.setAudioEffects(saved);
    } finally {
      _switching = false;
      _end(saved);
    }
  }

  void _onChain(List<AudioEffect> chain) {
    if (_switching || listEquals(chain, _muted)) return;
    // Someone else wrote the chain: their chain stays.
    _watch?.cancel();
    _watch = null;
    _end(chain);
  }

  void _end(List<AudioEffect> live) {
    if (_saved == null) return;
    _saved = null;
    _muted = null;
    _onHold?.call(false, live);
    notifyListeners();
  }

  /// [stage] switched off, or `null` for a stage that cannot be switched
  /// off in place (it is then left out of the muted copy).
  static AudioEffect? bypassedStage(AudioEffect stage) {
    if (!stage.enabled) return stage;
    if (stage is RawAudioEffect) return stage.copyWith(enabled: false);
    final descriptor = _catalogByFilter[stage.filter];
    if (descriptor != null) return descriptor.setEnabled(stage, false);
    // The featured stages (equalizer, compressor, bass and so on) are not in
    // the catalog; every generated effect has `copyWith(enabled:)`.
    try {
      final off = (stage as dynamic).copyWith(enabled: false);
      return off is AudioEffect ? off : null;
    } on NoSuchMethodError {
      return null;
    }
  }

  static final Map<AudioFilter, FilterDescriptor> _catalogByFilter = {
    for (final d in kFilterCatalog) d.filter: d,
  };

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }
}
