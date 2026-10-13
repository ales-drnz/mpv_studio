import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
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

void main() {
  const bass = BassEffect(gain: 4);
  const comp = AcompressorEffect(ratio: 4);

  test('live edits are throttled and the last value always lands', () {
    fakeAsync((async) {
      final engine = FakeEngine([bass]);
      final rack = RackController(engine);
      final id = rack.chain.stages.first.id;
      for (var i = 1; i <= 20; i++) {
        rack.edit(id, BassEffect(gain: i.toDouble()), live: true);
        async.elapse(const Duration(milliseconds: 5));
      }
      // 100 ms of drag at a 40 ms throttle: a handful of writes, not 20.
      expect(engine.applied.length, lessThanOrEqualTo(4));
      expect(rack.chain.effects, [const BassEffect(gain: 20)]);
      rack.flush();
      async.flushMicrotasks();
      expect(engine.applied.last, [const BassEffect(gain: 20)]);
      async.elapse(const Duration(milliseconds: 100));
      expect(engine.current, [const BassEffect(gain: 20)]);
      rack.dispose();
    });
  });

  test('a refused chain goes back to the last accepted one', () {
    fakeAsync((async) {
      final engine = FakeEngine([bass])
        ..refuse = (fx) => fx.any((e) => e is RawAudioEffect);
      final rack = RackController(engine);
      rack.add(const RawAudioEffect('lavfi-nonsense=1'));
      expect(rack.chain.length, 2, reason: 'optimistic');
      async.flushMicrotasks();
      expect(rack.chain.effects, [bass]);
      expect(rack.error, contains('invalid parameter'));
      expect(engine.current, [bass]);
      rack.clearError();
      expect(rack.error, isNull);
      rack.dispose();
    });
  });

  test('a refused live edit restores the accepted value', () {
    fakeAsync((async) {
      final engine = FakeEngine([bass])
        ..refuse = (fx) => (fx.first as BassEffect).gain > 10;
      final rack = RackController(engine);
      final id = rack.chain.stages.first.id;
      rack.edit(id, const BassEffect(gain: 6), live: true);
      async.elapse(const Duration(milliseconds: 50));
      rack.edit(id, const BassEffect(gain: 12), live: true);
      rack.flush();
      async.elapse(const Duration(milliseconds: 50));
      expect(rack.chain.effects, [const BassEffect(gain: 6)]);
      expect(rack.error, isNotNull);
      rack.dispose();
    });
  });

  test('bypass plays a switched-off copy and holds persistence', () {
    fakeAsync((async) {
      final engine = FakeEngine([bass, comp, kMeterStage]);
      final recorded = <List<AudioEffect>>[];
      final holds = <bool>[];
      final rack = RackController(engine,
          onRecord: recorded.add, onHold: holds.add);
      rack.setBypass(true);
      async.flushMicrotasks();
      expect(engine.current, [
        bass.copyWith(enabled: false),
        comp.copyWith(enabled: false),
        kMeterStage,
      ]);
      expect(rack.chain.effects, [bass, comp, kMeterStage]);
      expect(holds, [true]);
      expect(recorded.last, [bass, comp, kMeterStage]);
      // Edits while bypassed stay in the rack and are recorded.
      rack.edit(rack.chain.stages.first.id, const BassEffect(gain: 2));
      async.flushMicrotasks();
      expect(engine.current.first, const BassEffect(gain: 2, enabled: false));
      expect(recorded.last.first, const BassEffect(gain: 2));
      rack.setBypass(false);
      async.flushMicrotasks();
      expect(engine.current, [const BassEffect(gain: 2), comp, kMeterStage]);
      expect(holds, [true, false]);
      rack.dispose();
    });
  });

  test('new stages go before a trailing meter and open', () {
    fakeAsync((async) {
      final engine = FakeEngine([bass]);
      final rack = RackController(engine);
      rack.setMeter(true);
      final id = rack.add(comp);
      async.flushMicrotasks();
      expect(engine.current, [bass, comp, kMeterStage]);
      expect(rack.isExpanded(id), isTrue);
      final copy = rack.duplicate(id)!;
      expect(rack.chain.effects, [bass, comp, comp, kMeterStage]);
      expect(rack.isExpanded(copy), isTrue);
      rack.move(0, 2);
      expect(rack.chain.effects, [comp, comp, bass, kMeterStage]);
      rack.remove(copy);
      rack.setMeter(false);
      async.flushMicrotasks();
      expect(engine.current, [comp, bass]);
      rack.dispose();
    });
  });

  test('changes from elsewhere are adopted, keeping ids', () {
    fakeAsync((async) {
      final engine = FakeEngine([bass, comp]);
      final rack = RackController(engine);
      final ids = [for (final s in rack.chain.stages) s.id];
      rack.toggleExpanded(ids[1]);
      engine.external([const BassEffect(gain: 1), comp]);
      expect(rack.chain.effects, [const BassEffect(gain: 1), comp]);
      expect([for (final s in rack.chain.stages) s.id], ids);
      engine.external([bass]);
      expect(rack.isExpanded(ids[1]), isFalse);
      rack.dispose();
    });
  });

  test('taps go to the first open, enabled stages within the budget', () {
    final engine = FakeEngine([
      for (var i = 0; i < 5; i++) BassEffect(gain: i.toDouble()),
      const RawAudioEffect('lavfi-anull'),
    ]);
    final rack = RackController(engine, maxTappedStages: 3);
    final ids = [for (final s in rack.chain.stages) s.id];
    for (final id in ids) {
      rack.toggleExpanded(id);
    }
    rack.setEnabled(ids[1], false);
    expect([for (final id in ids) rack.tapGranted(id)],
        [true, false, true, true, false, false]);
    expect(rack.tapDenied(ids[4]), isTrue);
    expect(rack.tapDenied(ids[5]), isFalse, reason: 'raw: never tapped');
    rack.setBypass(true);
    expect(ids.any(rack.tapGranted), isFalse);
    rack.dispose();
  });
}
