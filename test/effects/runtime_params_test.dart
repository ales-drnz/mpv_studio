// The table of live options is checked against the library's own diff,
// which it keeps internal.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_audio_kit/src/generated/audio_effects_settings.dart'
    show audioEffectsDiff;
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/runtime_params.dart';
import 'package:mpv_studio/generated/filter_catalog.dart';

/// A different, valid value of [p] on [e], or null when there is none to
/// try (text options).
AudioEffect? _moved(ParamSpec p, AudioEffect e) => switch (p) {
  DoubleParam d => d.set(
    e,
    d.get(e) + (d.max - d.min) / 7 > d.max
        ? d.get(e) - (d.max - d.min) / 7
        : d.get(e) + (d.max - d.min) / 7,
  ),
  IntParam i =>
    i.max > i.min
        ? i.set(e, i.get(e) < i.max ? i.get(e) + 1 : i.get(e) - 1)
        : null,
  BoolParam b => b.set(e, !b.get(e)),
  EnumParam en =>
    en.options.length < 2
        ? null
        : en.set(e, en.options.firstWhere((o) => o.value != en.get(e)).value),
  StringParam _ => null,
};

void main() {
  test('the live options match what the library sends as af-command', () {
    final wrong = <String>[];
    for (final d in kRackCatalog) {
      final e = d.create();
      for (final p in d.params) {
        final moved = _moved(p, e);
        if (moved == null || moved == e) continue;
        final library = audioEffectsDiff([e], [moved]) != null;
        final app = changesLive(e, moved);
        if (library != app) wrong.add('${d.name}.${p.name}: library $library');
      }
    }
    expect(wrong, isEmpty);
  });
}
