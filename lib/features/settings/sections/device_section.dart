import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';
import 'anchored_rows.dart';

/// The output device and what is sent to it: format, channels, rate,
/// buffer, delay and the media role.
class DeviceSection extends StatelessWidget {
  const DeviceSection({super.key});

  static const _channels = <(Channels, String)>[
    (Channels.auto, 'Automatic'),
    (Channels.mono, 'Mono'),
    (Channels.stereo, 'Stereo'),
    (Channels.twoOne, '2.1'),
    (Channels.quad, '4.0'),
    (Channels.fiveOne, '5.1'),
    (Channels.sevenOne, '7.1'),
  ];

  // The curated list leaves out the planar variants; the engine reporting
  // one shows as the hint.
  static const _formats = <(Format, String)>[
    (Format.auto, 'Automatic'),
    (Format.s16, '16-bit integer'),
    (Format.s32, '32-bit integer'),
    (Format.s64, '64-bit integer'),
    (Format.float32, '32-bit float'),
    (Format.float64, '64-bit float'),
  ];

  static const _sampleRates = <int>[0, 44100, 48000, 88200, 96000, 192000];

  static String _rate(int hz) =>
      hz == 0 ? 'Automatic' : '${(hz / 1000).toStringAsFixed(1)} kHz';

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return SettingsGroup(
      label: SettingsSections.device,
      children: [
        Live<List<Device>>(
          stream: p.stream.audioDevices,
          initial: p.state.audioDevices,
          builder: (context, devices) => Live<Device>(
            stream: p.stream.audioDevice,
            initial: p.state.audioDevice,
            builder: (context, current) {
              final known = devices.contains(current);
              return anchoredDropdown<Device>(
                scope,
                SettingsCatalog.device,
                value: known ? current : null,
                hint: known ? null : current.description,
                items: [
                  // The same device often shows up once per driver with
                  // the same description: its id (driver and node) under
                  // it tells them apart.
                  for (final d in devices)
                    DropdownMenuItem(
                      value: d,
                      child: DropdownOption(
                        label: d.description,
                        caption: d == Device.auto ? null : d.name,
                      ),
                    ),
                ],
                set: p.setAudioDevice,
              );
            },
          ),
        ),
        Live<bool>(
          stream: p.stream.audioExclusive,
          initial: p.state.audioExclusive,
          builder: (context, v) => anchoredSwitch(
            scope,
            SettingsCatalog.exclusive,
            value: v,
            set: p.setAudioExclusive,
          ),
        ),
        Live<Format>(
          stream: p.stream.audioFormat,
          initial: p.state.audioFormat,
          builder: (context, v) {
            final known = _formats.any((f) => f.$1 == v);
            return anchoredDropdown<Format>(
              scope,
              SettingsCatalog.sampleFormat,
              value: known ? v : null,
              hint: known ? null : v.mpvValue,
              items: [
                for (final (f, label) in _formats)
                  DropdownMenuItem(value: f, child: Text(label)),
              ],
              set: p.setAudioFormat,
            );
          },
        ),
        Live<Channels>(
          stream: p.stream.audioChannels,
          initial: p.state.audioChannels,
          builder: (context, v) {
            Channels? match;
            for (final (c, _) in _channels) {
              if (c.mpvValue == v.mpvValue) match = c;
            }
            return anchoredDropdown<Channels>(
              scope,
              SettingsCatalog.channels,
              value: match,
              hint: match == null ? v.mpvValue : null,
              items: [
                for (final (c, label) in _channels)
                  DropdownMenuItem(value: c, child: Text(label)),
              ],
              set: p.setAudioChannels,
            );
          },
        ),
        Live<int>(
          stream: p.stream.audioSampleRate,
          initial: p.state.audioSampleRate,
          builder: (context, v) => anchoredDropdown<int>(
            scope,
            SettingsCatalog.sampleRate,
            value: v,
            items: [
              for (final r in ({..._sampleRates, v}.toList()..sort()))
                DropdownMenuItem(value: r, child: Text(_rate(r))),
            ],
            set: p.setAudioSampleRate,
          ),
        ),
        Live<Duration>(
          stream: p.stream.audioBuffer,
          initial: p.state.audioBuffer,
          builder: (context, v) => anchoredSlider(
            scope,
            SettingsCatalog.outputBuffer,
            value: v.inMilliseconds.toDouble(),
            min: 0,
            max: 2000,
            resetTo: 200,
            format: (x) => '${x.round()} ms',
            set: (x) => p.setAudioBuffer(Duration(milliseconds: x.round())),
          ),
        ),
        Live<Duration>(
          stream: p.stream.audioDelay,
          initial: p.state.audioDelay,
          builder: (context, v) => anchoredSlider(
            scope,
            SettingsCatalog.audioDelay,
            value: v.inMicroseconds / 1e6,
            min: -5,
            max: 5,
            resetTo: 0,
            format: (x) => '${x.toStringAsFixed(3)} s',
            set: (x) =>
                p.setAudioDelay(Duration(microseconds: (x * 1e6).round())),
          ),
        ),
        // Reports a "music" media role to the OS audio server (PulseAudio
        // and PipeWire on Linux, AudioTrack and AAudio on Android) so it
        // routes the stream as music.
        Live<bool>(
          stream: p.stream.audioMediaRole,
          initial: p.state.audioMediaRole,
          builder: (context, v) => anchoredSwitch(
            scope,
            SettingsCatalog.mediaRole,
            value: v,
            set: p.setAudioMediaRole,
          ),
        ),
      ],
    );
  }
}
