import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../generated/filter_catalog.dart';
import 'rack_catalog.dart';
import 'rack_controller.dart';

/// Whether every mandatory text option of [e] has a value, so the stage
/// can be switched on without mpv refusing the chain.
bool stageReady(AudioEffect e) {
  final d = descriptorOf(e.filter);
  if (d == null) return e is! RawAudioEffect || e.entry.trim().isNotEmpty;
  return d.params
      .whereType<StringParam>()
      .where((p) => p.required)
      .every((p) => p.get(e).trim().isNotEmpty);
}

/// Copies a bundled asset (a noise model) to a temp file mpv can open.
Future<String> materializeAsset(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final dir = Directory('${Directory.systemTemp.path}/mpv_studio_models');
  await dir.create(recursive: true);
  final file = File('${dir.path}/${assetPath.split('/').last}');
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file.path;
}

/// Applies [preset] to stage [id] and switches it on. A bundled model that
/// cannot be copied out is reported on the rack and leaves the stage as
/// it was.
Future<void> applyPreset(
  RackController rack,
  int id,
  FilterDescriptor d,
  FilterPreset preset,
) async {
  var values = preset.values;
  final fp = d.fileParam;
  if (d.fileBacked && fp != null && values[fp] != null) {
    try {
      values = {fp: await materializeAsset(values[fp]!)};
    } on Object catch (e) {
      rack.reportError('The model ${preset.name} could not be prepared: $e');
      return;
    }
  }
  final stage = rack.chain.stage(id);
  if (stage == null) return;
  var e = stage.effect;
  for (final p in d.params.whereType<StringParam>()) {
    final v = values[p.name];
    if (v != null) e = p.set(e, v);
  }
  rack.edit(id, d.setEnabled(e, true));
}

/// Switches stage [id] on or off. A filter with an empty mandatory option
/// would be refused: it starts from its first preset instead, or, with no
/// preset, opens and says what to fill in.
Future<void> powerStage(RackController rack, int id, bool on) async {
  final e = rack.chain.stage(id)?.effect;
  if (e == null) return;
  if (on && !stageReady(e)) {
    final d = descriptorOf(e.filter);
    if (d != null && d.presets.isNotEmpty) {
      await applyPreset(rack, id, d, d.presets.first);
      return;
    }
    rack.open(id);
    final missing = [
      for (final p in d?.params.whereType<StringParam>() ?? <StringParam>[])
        if (p.required && p.get(e).trim().isEmpty) p.name,
    ];
    rack.reportError(
      missing.isEmpty
          ? 'Write the lavfi entry before switching the stage on.'
          : 'Fill in ${missing.join(', ')} before switching the stage on.',
    );
    return;
  }
  rack.setEnabled(id, on);
}
