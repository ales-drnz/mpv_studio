import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/rack_chain.dart';

void main() {
  const eqLow = EqualizerEffect(frequency: 100, gain: 3);
  const eqHigh = EqualizerEffect(frequency: 8000, gain: -2);
  const bass = BassEffect(gain: 4);
  const comp = AcompressorEffect(ratio: 4);

  test('move puts the stage at its final index', () {
    final c = RackChain.of([eqLow, bass, comp]);
    final ids = [for (final s in c.stages) s.id];
    final down = c.move(0, 2);
    expect(down.effects, [bass, comp, eqLow]);
    expect(down.stages.last.id, ids.first);
    // Up.
    final up = c.move(2, 0);
    expect(up.effects, [comp, eqLow, bass]);
    // No-ops.
    expect(c.move(1, 1), c);
    expect(c.move(0, 1).effects, [bass, eqLow, comp]);
    expect(c.move(9, 0), c);
  });

  test('duplicate inserts a copy with its own id right after', () {
    final c = RackChain.of([eqLow, bass]);
    final (next, id) = c.duplicate(c.stages.first.id)!;
    expect(next.effects, [eqLow, eqLow, bass]);
    expect(next.stages[1].id, id);
    expect(id, isNot(c.stages.first.id));
    expect(c.duplicate(-1), isNull);
  });

  test('remove, replace and enable act on one stage only', () {
    final c = RackChain.of([eqLow, eqLow]);
    final second = c.stages[1].id;
    final off = c.setEnabled(second, false);
    expect(off.effects, [eqLow, eqLow.copyWith(enabled: false)]);
    final edited = c.replace(second, eqHigh);
    expect(edited.effects, [eqLow, eqHigh]);
    expect(c.remove(second).effects, [eqLow]);
  });

  test('tap instances count earlier stages of the same filter', () {
    final c = RackChain.of([
      eqLow,
      bass,
      eqHigh.copyWith(enabled: false),
      eqLow,
      const RawAudioEffect('lavfi-aecho'),
    ]);
    final ids = [for (final s in c.stages) s.id];
    expect(c.tapInstance(ids[0]), 0);
    expect(c.tapInstance(ids[1]), 0);
    expect(c.tapInstance(ids[2]), 1);
    expect(c.tapInstance(ids[3]), 2, reason: 'disabled stages count');
    expect(c.tapInstance(ids[4]), isNull, reason: 'raw stages have no tap');
    // After a reorder the instance follows the position.
    final moved = c.move(3, 0);
    expect(moved.tapInstance(ids[3]), 0);
    expect(moved.tapInstance(ids[0]), 1);
  });

  test('reconcile keeps ids for value edits and moved stages', () {
    final c = RackChain.of([eqLow, bass, comp]);
    final ids = [for (final s in c.stages) s.id];
    final edited = c.reconcile([eqHigh, bass, comp]);
    expect([for (final s in edited.stages) s.id], ids);
    final reordered = c.reconcile([comp, eqLow, bass]);
    expect([for (final s in reordered.stages) s.id], [ids[2], ids[0], ids[1]]);
    final grown = c.reconcile([eqLow, bass, comp, kMeterStage]);
    expect(grown.stages.take(3).map((s) => s.id), ids);
    expect(ids, isNot(contains(grown.stages.last.id)));
  });

  test('bypassed switches every stage off but the meters', () {
    final c = RackChain.of([
      eqLow,
      const RawAudioEffect('lavfi-aecho'),
      kMeterStage,
    ]);
    expect(c.bypassed, [
      eqLow.copyWith(enabled: false),
      const RawAudioEffect('lavfi-aecho', enabled: false),
      kMeterStage,
    ]);
    expect(c.bypassed.length, c.length, reason: 'same shape, same taps');
  });

  test('the meter switch appends, enables and removes meter stages', () {
    var c = RackChain.of([bass]);
    expect(c.meterOn, isFalse);
    c = c.withMeter(true);
    expect(c.effects, [bass, kMeterStage]);
    expect(c.meterOn, isTrue);
    expect(c.withMeter(true), c, reason: 'no second meter');
    c = c.setEnabled(c.stages.last.id, false);
    expect(c.meterOn, isFalse);
    expect(c.withMeter(true).effects, [bass, kMeterStage]);
    expect(c.withMeter(false).effects, [bass]);
  });
}
