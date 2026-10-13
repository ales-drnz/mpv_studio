import 'dart:async';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';

/// Plays like the player: commits at once, emits, and on a refusal goes
/// back to the last accepted list and throws.
class FakeEngine implements EffectsEngine {
  FakeEngine([List<AudioEffect> initial = const []])
      : current = initial,
        _accepted = initial;

  @override
  List<AudioEffect> current;
  List<AudioEffect> _accepted;
  final _changes = StreamController<List<AudioEffect>>.broadcast(sync: true);
  final applied = <List<AudioEffect>>[];
  bool Function(List<AudioEffect>) refuse = (_) => false;

  @override
  Stream<List<AudioEffect>> get changes => _changes.stream;

  @override
  Future<void> apply(List<AudioEffect> effects) async {
    applied.add(effects);
    current = effects;
    _changes.add(effects);
    await Future<void>.microtask(() {});
    if (refuse(effects)) {
      current = _accepted;
      _changes.add(_accepted);
      throw const MpvCommandException(
          name: 'af', code: -12, message: 'invalid parameter');
    }
    _accepted = effects;
  }

  /// A write from outside the rack.
  void external(List<AudioEffect> effects) {
    current = _accepted = effects;
    _changes.add(effects);
  }
}
