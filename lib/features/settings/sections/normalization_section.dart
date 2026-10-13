import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';
import 'anchored_rows.dart';

/// Scan-based loudness normalization (EBU R128) with its live state. First
/// because it works on any track: the engine measures each file on load.
class LoudnessSection extends StatelessWidget {
  const LoudnessSection({super.key});

  static String _scanState(LoudnessScan? scan) => switch (scan?.state) {
    LoudnessScanState.scanning =>
      scan!.progress != null
          ? 'scanning ${(scan.progress! * 100).round()}%'
          : 'scanning',
    LoudnessScanState.ready => 'ready',
    LoudnessScanState.failed => 'failed',
    LoudnessScanState.unavailable => 'unavailable',
    LoudnessScanState.idle || null => 'idle',
  };

  @override
  Widget build(BuildContext context) {
    final normalizer = SettingsScope.of(context).normalizer;
    return ListenableBuilder(
      listenable: normalizer,
      builder: (context, _) {
        // The loudness is measured whether or not the gain is applied, so
        // the state is the real scan state.
        final scan = normalizer.lastScan;
        final g = normalizer.appliedGainDb;
        final integrated = scan?.state == LoudnessScanState.ready
            ? scan?.integrated
            : null;
        final gain = normalizer.enabled
            ? ', gain ${g >= 0 ? '+' : ''}${g.toStringAsFixed(1)} dB'
            : '';
        return SettingsGroup(
          label: SettingsSections.loudness,
          children: [
            SettingAnchor(
              entry: SettingsCatalog.normalize,
              child: SwitchRow(
                label: SettingsCatalog.normalize.title,
                subtitle: SettingsCatalog.normalize.description,
                value: normalizer.enabled,
                onChanged: normalizer.setEnabled,
              ),
            ),
            InfoRow(label: 'Scan state', value: _scanState(scan)),
            InfoRow(
              label: 'Measured',
              value: integrated == null
                  ? '-'
                  : '${integrated.toStringAsFixed(1)} LUFS$gain',
            ),
            SettingAnchor(
              entry: SettingsCatalog.normalizeTarget,
              child: SliderRow(
                label: SettingsCatalog.normalizeTarget.title,
                description: SettingsCatalog.normalizeTarget.description,
                value: normalizer.targetLufs,
                min: -24,
                max: -10,
                resetTo: -18,
                format: (x) => '${x.toStringAsFixed(0)} LUFS',
                enabled: normalizer.enabled,
                onChanged: normalizer.setTargetLufs,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tag-based ReplayGain.
class ReplayGainSection extends StatelessWidget {
  const ReplayGainSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return Live<ReplayGainSettings>(
      stream: p.stream.replayGain,
      initial: p.state.replayGain,
      builder: (context, rg) {
        final on = rg.mode != ReplayGain.no;
        return SettingsGroup(
          label: SettingsSections.replayGain,
          children: [
            anchoredSegments(
              scope,
              SettingsCatalog.replayGainMode,
              selected: rg.mode,
              set: (m) => p.setReplayGain(rg.copyWith(mode: m)),
              options: const [
                SegmentOption(ReplayGain.no, 'Off'),
                SegmentOption(ReplayGain.track, 'Track'),
                SegmentOption(ReplayGain.album, 'Album'),
              ],
            ),
            anchoredSlider(
              scope,
              SettingsCatalog.replayGainPreamp,
              value: rg.preamp,
              min: -15,
              max: 15,
              resetTo: 0,
              enabled: on,
              format: (x) => '${x.toStringAsFixed(1)} dB',
              set: (x) => p.setReplayGain(rg.copyWith(preamp: x)),
            ),
            anchoredSlider(
              scope,
              SettingsCatalog.replayGainFallback,
              value: rg.fallback,
              min: -15,
              max: 15,
              resetTo: 0,
              enabled: on,
              format: (x) => '${x.toStringAsFixed(1)} dB',
              set: (x) => p.setReplayGain(rg.copyWith(fallback: x)),
            ),
            anchoredSwitch(
              scope,
              SettingsCatalog.replayGainClip,
              value: rg.clip,
              enabled: on,
              set: (v) => p.setReplayGain(rg.copyWith(clip: v)),
            ),
          ],
        );
      },
    );
  }
}

/// Downmix normalization: read when the player is created, so a change
/// shows the restart banner.
class DownmixSection extends StatelessWidget {
  const DownmixSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings.changes,
      builder: (context, _) => SettingsGroup(
        label: SettingsSections.downmix,
        children: [
          SettingAnchor(
            entry: SettingsCatalog.normalizeDownmix,
            child: SwitchRow(
              label: SettingsCatalog.normalizeDownmix.title,
              subtitle: SettingsCatalog.normalizeDownmix.description,
              value: settings.normalizeDownmix,
              onChanged: settings.recordNormalizeDownmix,
            ),
          ),
        ],
      ),
    );
  }
}
