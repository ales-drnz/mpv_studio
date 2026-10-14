import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../generated/filter_catalog.dart';
import 'featured_catalog.dart';

export 'featured_catalog.dart';

// Every filter the rack can hold, described the same way: the generated
// catalog plus the featured filters ([kFeaturedCatalog]). One list drives
// "Add stage", the generic stage editor and the effects codec, so a stage
// of any filter is edited and persisted alike.

/// Every filter the rack can add: featured first, then the generated
/// catalog.
final List<FilterDescriptor> kRackCatalog = [
  ...kFeaturedCatalog,
  ...kFilterCatalog,
];

final Map<AudioFilter, FilterDescriptor> _byFilter = {
  for (final d in kRackCatalog) d.filter: d,
};

final Map<String, FilterDescriptor> _byName = {
  for (final d in kRackCatalog) d.name: d,
};

/// The descriptor of [filter], or `null` when the rack does not know it.
FilterDescriptor? descriptorOf(AudioFilter? filter) =>
    filter == null ? null : _byFilter[filter];

/// The descriptor whose lavfi name is [name] (`'acompressor'`).
FilterDescriptor? descriptorNamed(String name) => _byName[name];

/// Whether [e] is a measuring stage: an `ebur128` with its metadata on,
/// which feeds `stream.loudnessMeter` and leaves the audio unchanged.
bool isMeterStage(AudioEffect e) => e is Ebur128Effect && e.metadata;

/// The stage the loudness meter switch adds at the end of the chain.
const Ebur128Effect kMeterStage = Ebur128Effect(metadata: true);

/// The title a stage shows in the rack.
String stageTitle(AudioEffect e) {
  if (e is RawAudioEffect) return 'Raw lavfi';
  if (isMeterStage(e)) return 'Loudness meter';
  return descriptorOf(e.filter)?.title ?? e.filterName;
}

/// The one-line subtitle a stage shows under its title.
String stageSubtitle(AudioEffect e) {
  if (e is RawAudioEffect) return e.entry.isEmpty ? 'Empty entry' : e.entry;
  if (isMeterStage(e)) return 'Measures here, audio unchanged';
  final f = e.filter;
  if (f != null && kFeaturedSubtitles[f] != null) return kFeaturedSubtitles[f]!;
  return descriptorOf(f)?.wire ?? e.filterName;
}

/// The icon a stage shows in the rack.
IconData stageIcon(AudioEffect e) {
  if (e is RawAudioEffect) return Icons.code_rounded;
  if (isMeterStage(e)) return Icons.speed_rounded;
  return descriptorOf(e.filter)?.icon ?? Icons.tune_rounded;
}

/// [e] switched on or off, for any stage.
AudioEffect withEnabled(AudioEffect e, bool on) {
  if (e.enabled == on) return e;
  if (e is RawAudioEffect) return e.copyWith(enabled: on);
  final d = descriptorOf(e.filter);
  if (d == null) {
    throw ArgumentError('No descriptor for ${e.filterName}');
  }
  return d.setEnabled(e, on);
}

/// Raw stage [e] with [entry] written in. A blank stage (fresh from the
/// catalog) switches on with its first entry; a blank entry switches the
/// stage off, since there is nothing for mpv to play.
RawAudioEffect rawEntrySubmitted(RawAudioEffect e, String entry) {
  final v = entry.trim();
  if (v.isEmpty) return e.copyWith(entry: '', enabled: false);
  return e.copyWith(entry: v, enabled: e.entry.trim().isEmpty ? true : null);
}
