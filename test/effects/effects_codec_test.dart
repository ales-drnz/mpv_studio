import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/effects_codec.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/generated/filter_catalog.dart';

/// Through JSON text, as `AppSettings` stores it.
List<AudioEffect> roundTrip(List<AudioEffect> fx) =>
    EffectsCodec.decode(jsonDecode(jsonEncode(EffectsCodec.encode(fx))));

/// A stage of [d] with every parameter moved off its default.
AudioEffect touched(FilterDescriptor d) {
  var e = d.create();
  for (final p in d.params) {
    switch (p) {
      case DoubleParam x:
        e = x.set(e, x.def == x.max ? x.min : x.max);
      case IntParam x:
        e = x.set(e, x.def == x.max ? x.min : x.max);
      case BoolParam x:
        e = x.set(e, !x.get(e));
      case StringParam x:
        e = x.set(e, '${x.get(e)}1');
      case EnumParam x:
        e = x.set(e, x.options.last.value);
    }
  }
  return e;
}

void main() {
  test('every filter survives a round trip with changed values', () {
    for (final d in kRackCatalog) {
      final stage = touched(d);
      expect(roundTrip([stage]), [stage], reason: d.name);
      final off = withEnabled(stage, false);
      expect(roundTrip([off]), [off], reason: '${d.name} disabled');
    }
  });

  test('order, duplicates and raw stages are kept', () {
    final fx = <AudioEffect>[
      const BassEffect(gain: 3),
      const RawAudioEffect('lavfi-aeval=val(0)|val(1)', enabled: false),
      const EqualizerEffect(frequency: 100, gain: 2),
      const EqualizerEffect(frequency: 8000, gain: -2),
      kMeterStage,
    ];
    expect(roundTrip(fx), fx);
  });

  test('unknown stages and bad values are skipped, not fatal', () {
    final fx = EffectsCodec.decode({
      'version': 2,
      'chain': [
        {'filter': 'nosuchfilter', 'params': {}},
        'garbage',
        {
          'filter': 'bass',
          'enabled': false,
          'params': {'gain': 'loud', 'frequency': 120, 'nope': 1},
        },
      ],
    });
    expect(fx, [const BassEffect(enabled: false, frequency: 120)]);
    expect(EffectsCodec.decode(null), isEmpty);
    expect(EffectsCodec.decode('x'), isEmpty);
  });

  test('migrates the 0.2 blob, keeping only touched modules', () {
    // What MPV Studio 0.2.18 wrote: every module, always.
    final legacy = {
      'eq': {
        'enabled': true,
        'params': {'4b': 1.5},
      },
      'comp': {
        'enabled': false,
        'threshold': 0.125,
        'ratio': 2,
        'attack': 20,
        'release': 250,
        'makeup': 1,
        'knee': 2.82843,
      },
      'bass': {'enabled': false, 'gain': 6, 'frequency': 100},
      'treble': {'enabled': false, 'gain': 0, 'frequency': 3000},
      'crossfeed': {'enabled': false, 'strength': 0.2, 'range': 0.5},
      'crystalizer': {'enabled': false, 'i': 2},
      'stereo': {'enabled': false, 'm': 2.5},
      'subboost': {
        'enabled': false,
        'boost': 2,
        'cutoff': 100,
        'dry': 1,
        'wet': 1,
        'feedback': 0.9,
      },
      'loudnorm': {
        'enabled': true,
        'i': -16,
        'lra': 11,
        'tp': -1.5,
        'linear': true,
      },
    };
    expect(EffectsCodec.isLegacy(legacy), isTrue);
    final fx = EffectsCodec.decode(jsonDecode(jsonEncode(legacy)));
    expect(fx, [
      const SuperequalizerEffect(params: {'4b': 1.5}),
      const BassEffect(enabled: false, gain: 6),
      const LoudnormEffect(i: -16, lra: 11, tp: -1.5),
    ]);
    // Written back in the current format.
    final again = EffectsCodec.encode(fx);
    expect(again['version'], EffectsCodec.version);
    expect(EffectsCodec.isLegacy(again), isFalse);
    expect(roundTrip(fx), fx);
  });
}
