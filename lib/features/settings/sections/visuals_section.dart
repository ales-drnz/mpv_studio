import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/theme_host.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';
import 'anchored_rows.dart';

/// The spectrum analyzer behind the visualizers.
class VisualizerSection extends StatelessWidget {
  const VisualizerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return Live<SpectrumSettings>(
      stream: p.stream.spectrum,
      initial: p.state.spectrum,
      builder: (context, spec) => SettingsGroup(
        label: SettingsSections.visualizer,
        children: [
          anchoredSegments(
            scope,
            SettingsCatalog.fftWindow,
            selected: spec.window,
            set: (w) async => p.setSpectrum(spec.copyWith(window: w)),
            options: const [
              SegmentOption(WindowFunction.hann, 'Hann'),
              SegmentOption(WindowFunction.blackmanHarris, 'Blackman'),
              SegmentOption(
                WindowFunction.rectangular,
                'Rect',
                tooltip: 'Rectangular',
              ),
            ],
          ),
          anchoredSegments(
            scope,
            SettingsCatalog.fftSize,
            selected: spec.fftSize,
            set: (s) async => p.setSpectrum(spec.copyWith(fftSize: s)),
            options: const [
              SegmentOption(512, '512'),
              SegmentOption(1024, '1024'),
              SegmentOption(2048, '2048'),
              SegmentOption(4096, '4096'),
            ],
          ),
          anchoredSlider(
            scope,
            SettingsCatalog.spectrumBands,
            value: spec.bandCount.toDouble(),
            min: 16,
            max: 128,
            divisions: 112,
            format: (x) => x.round().toString(),
            set: (x) async =>
                p.setSpectrum(spec.copyWith(bandCount: x.round())),
          ),
        ],
      ),
    );
  }
}

/// Cover images found next to the audio file.
class CoverArtSection extends StatelessWidget {
  const CoverArtSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return SettingsGroup(
      label: SettingsSections.coverArt,
      children: [
        Live<Cover>(
          stream: p.stream.coverArtAuto,
          initial: p.state.coverArtAuto,
          builder: (context, v) => anchoredSegments(
            scope,
            SettingsCatalog.coverArt,
            selected: v,
            set: p.setCoverArtAuto,
            options: const [
              SegmentOption(Cover.no, 'Off'),
              SegmentOption(Cover.exact, 'Exact'),
              SegmentOption(Cover.fuzzy, 'Fuzzy'),
              SegmentOption(Cover.all, 'All'),
            ],
          ),
        ),
      ],
    );
  }
}

/// The app theme: dark, light, or the same as the system.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.maybeOf(context);
    return SettingsGroup(
      label: SettingsSections.appearance,
      children: [
        SettingAnchor(
          entry: SettingsCatalog.theme,
          child: SettingTile(
            title: SettingsCatalog.theme.title,
            description: SettingsCatalog.theme.description,
            enabled: theme != null,
            below: SegmentedControl<ThemeMode>(
              selected: theme?.mode ?? ThemeMode.dark,
              enabled: theme != null,
              onSelect: (m) => theme?.mode = m,
              options: const [
                SegmentOption(ThemeMode.dark, 'Dark'),
                SegmentOption(ThemeMode.light, 'Light'),
                SegmentOption(ThemeMode.system, 'System'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
