import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';
import '../setting_anchor.dart';
import 'anchored_rows.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';

/// Speed, pitch, repeat, shuffle and gapless.
class PlaybackSection extends StatelessWidget {
  const PlaybackSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return SettingsGroup(
      label: SettingsSections.playback,
      children: [
        Live<double>(
          stream: p.stream.rate,
          initial: p.state.rate,
          builder: (context, v) => anchoredSlider(
            scope,
            SettingsCatalog.speed,
            value: v,
            min: 0.25,
            max: 4,
            resetTo: 1,
            format: (x) => '${x.toStringAsFixed(2)}x',
            set: p.setRate,
          ),
        ),
        Live<double>(
          stream: p.stream.pitch,
          initial: p.state.pitch,
          builder: (context, v) => anchoredSlider(
            scope,
            SettingsCatalog.pitch,
            value: v,
            min: 0.5,
            max: 2,
            resetTo: 1,
            format: (x) => '${x.toStringAsFixed(2)}x',
            set: p.setPitch,
          ),
        ),
        Live<bool>(
          stream: p.stream.pitchCorrection,
          initial: p.state.pitchCorrection,
          builder: (context, v) => anchoredSwitch(
            scope,
            SettingsCatalog.pitchCorrection,
            value: v,
            set: p.setPitchCorrection,
          ),
        ),
        Live<Loop>(
          stream: p.stream.loop,
          initial: p.state.loop,
          builder: (context, v) => anchoredSegments(
            scope,
            SettingsCatalog.repeat,
            selected: v,
            set: p.setLoop,
            options: const [
              SegmentOption(Loop.off, 'Off'),
              SegmentOption(Loop.file, 'Track'),
              SegmentOption(Loop.playlist, 'Queue'),
            ],
          ),
        ),
        Live<bool>(
          stream: p.stream.shuffle,
          initial: p.state.shuffle,
          builder: (context, v) => anchoredSwitch(
            scope,
            SettingsCatalog.shuffle,
            value: v,
            set: p.setShuffle,
          ),
        ),
        Live<Gapless>(
          stream: p.stream.gapless,
          initial: p.state.gapless,
          builder: (context, v) => anchoredSegments(
            scope,
            SettingsCatalog.gapless,
            selected: v,
            set: p.setGapless,
            options: const [
              SegmentOption(Gapless.no, 'Off'),
              SegmentOption(Gapless.weak, 'Weak'),
              SegmentOption(Gapless.yes, 'Strict'),
            ],
          ),
        ),
      ],
    );
  }
}

/// The volume ceiling, the gain stage and the OS mixer.
class VolumeSection extends StatelessWidget {
  const VolumeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return SettingsGroup(
      label: SettingsSections.volume,
      children: [
        Live<double>(
          stream: p.stream.volumeMax,
          initial: p.state.volumeMax,
          builder: (context, v) => anchoredSlider(
            scope,
            SettingsCatalog.volumeLimit,
            value: v,
            min: 100,
            max: 1000,
            resetTo: 130,
            format: (x) => '${x.round()}%',
            set: p.setVolumeMax,
          ),
        ),
        Live<double>(
          stream: p.stream.volumeGain,
          initial: p.state.volumeGain,
          builder: (context, v) => anchoredSlider(
            scope,
            SettingsCatalog.volumeGain,
            value: v,
            min: -24,
            max: 24,
            resetTo: 0,
            format: (x) => '${x.toStringAsFixed(1)} dB',
            set: p.setVolumeGain,
          ),
        ),
        Live<double>(
          stream: p.stream.volumeGainMin,
          initial: p.state.volumeGainMin,
          builder: (context, v) => anchoredSlider(
            scope,
            SettingsCatalog.gainFloor,
            value: v,
            min: -96,
            max: 0,
            resetTo: -96,
            format: (x) => '${x.toStringAsFixed(0)} dB',
            set: p.setVolumeGainMin,
          ),
        ),
        Live<double>(
          stream: p.stream.volumeGainMax,
          initial: p.state.volumeGainMax,
          builder: (context, v) => anchoredSlider(
            scope,
            SettingsCatalog.gainCeiling,
            value: v,
            min: 0,
            max: 24,
            resetTo: 12,
            format: (x) => '${x.toStringAsFixed(0)} dB',
            set: p.setVolumeGainMax,
          ),
        ),
        // The OS per-app mixer (mpv's ao-volume and ao-mute). Best-effort:
        // the active audio output may not expose it, and then the stream
        // value is null.
        Live<double?>(
          stream: p.stream.systemVolume,
          initial: p.state.systemVolume,
          builder: (context, v) => v == null
              ? _unavailable(SettingsCatalog.systemVolume)
              : anchoredSlider(
                  scope,
                  SettingsCatalog.systemVolume,
                  value: v,
                  min: 0,
                  max: 100,
                  format: (x) => '${x.round()}%',
                  set: p.setSystemVolume,
                ),
        ),
        Live<bool?>(
          stream: p.stream.systemMute,
          initial: p.state.systemMute,
          builder: (context, v) => v == null
              ? _unavailable(SettingsCatalog.systemMute)
              : anchoredSwitch(
                  scope,
                  SettingsCatalog.systemMute,
                  value: v,
                  set: p.setSystemMute,
                ),
        ),
      ],
    );
  }

  static Widget _unavailable(SettingEntry entry) => SettingAnchor(
    entry: entry,
    child: SettingTile(
      title: entry.title,
      description: 'Not exposed by the active audio output',
      trailing: const ValueBadge('unavailable'),
    ),
  );
}
