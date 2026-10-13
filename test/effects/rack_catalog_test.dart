import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/generated/filter_catalog.dart';

void main() {
  test('every typed filter of the library has a descriptor', () {
    final missing = [
      for (final f in AudioFilter.values)
        if (descriptorOf(f) == null) f.name,
    ];
    expect(missing, isEmpty);
    expect(kRackCatalog.map((d) => d.filter).toSet().length,
        kRackCatalog.length, reason: 'one descriptor per filter');
  });

  test('descriptors create and switch their own stage', () {
    for (final d in kRackCatalog) {
      final e = d.create();
      expect(e.filter, d.filter, reason: d.name);
      expect(e.filterName, d.name, reason: d.name);
      expect(withEnabled(e, false).enabled, isFalse, reason: d.name);
      expect(withEnabled(withEnabled(e, false), true), e, reason: d.name);
    }
  });

  test('superequalizer bands read and write the params map', () {
    final d = descriptorOf(AudioFilter.superequalizer)!;
    final band = d.params.first as DoubleParam;
    var e = d.create();
    expect(band.get(e), 1);
    e = band.set(e, 2.5);
    expect((e as SuperequalizerEffect).params, {'1b': 2.5});
    e = band.set(e, 1);
    expect((e as SuperequalizerEffect).params, isEmpty);
  });

  test('meter stages and titles', () {
    expect(isMeterStage(kMeterStage), isTrue);
    expect(isMeterStage(const Ebur128Effect()), isFalse);
    expect(stageTitle(kMeterStage), 'Loudness meter');
    expect(stageTitle(const RawAudioEffect('lavfi-anull')), 'Raw lavfi');
    expect(stageTitle(const BassEffect()), 'Bass');
    expect(withEnabled(const RawAudioEffect('lavfi-anull'), false).enabled,
        isFalse);
  });
}
