import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/app_settings.dart';
import '../../studio/player_scope.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/back_bar.dart';
import '../../ui/widgets/controls.dart';
import '../../ui/widgets/grid_card.dart';
import '../../ui/widgets/section_body.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/section_switcher.dart';
import '../../util/reactive.dart';
import 'groups/audio_engine_group.dart';
import 'groups/audio_track_group.dart';
import 'groups/demuxer_group.dart';
import 'groups/session_group.dart';
import 'groups/streaming_group.dart';

/// One settings category — a squircle grid box whose detail is built lazily.
class _Category {
  final String title;
  final IconData icon;
  final WidgetBuilder build;
  const _Category(this.title, this.icon, this.build);
}

/// Full engine configuration, split into categories. Every control writes
/// straight through to the live [Player]; the [AppSettings] observer
/// snapshots each change to disk, so the configuration is restored on the
/// next launch.
///
/// The landing view is a grid of squircle category boxes; tapping one pushes
/// its detail with a back affordance.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<_Category> get _categories => const [
    _Category('Playback', Icons.play_arrow_rounded, _playback),
    _Category('Resume', Icons.bookmark_outline_rounded, _resume),
    _Category('Audio output', Icons.speaker_rounded, _output),
    _Category('Audio engine', Icons.tune_rounded, _engine),
    _Category('Audio track', Icons.audiotrack_rounded, _track),
    _Category('Normalization', Icons.equalizer_rounded, _normalization),
    _Category('Cache & network', Icons.cloud_outlined, _cache),
    _Category('Demuxer', Icons.dns_outlined, _demuxer),
    _Category('Streaming', Icons.podcasts_rounded, _streaming),
    _Category('Session', Icons.lock_outline_rounded, _session),
    _Category('Visualizer', Icons.graphic_eq_rounded, _visualizer),
    _Category('Cover art', Icons.image_outlined, _coverArt),
    _Category('About', Icons.info_outline_rounded, _about),
  ];

  static Widget _playback(BuildContext c) => _PlaybackGroup(PlayerScope.of(c));
  static Widget _resume(BuildContext c) =>
      _ResumeGroup(PlayerScope.of(c), PlayerScope.settingsOf(c));
  static Widget _output(BuildContext c) =>
      _OutputGroup(PlayerScope.of(c), PlayerScope.settingsOf(c));
  static Widget _engine(BuildContext c) => AudioEngineGroup(PlayerScope.of(c));
  static Widget _track(BuildContext c) => AudioTrackGroup(PlayerScope.of(c));
  static Widget _normalization(BuildContext c) =>
      _NormalizationGroup(PlayerScope.of(c), PlayerScope.settingsOf(c));
  static Widget _cache(BuildContext c) => _CacheGroup(PlayerScope.of(c));
  static Widget _demuxer(BuildContext c) =>
      DemuxerGroup(PlayerScope.of(c), PlayerScope.settingsOf(c));
  static Widget _streaming(BuildContext c) =>
      StreamingGroup(PlayerScope.of(c), PlayerScope.settingsOf(c));
  static Widget _session(BuildContext c) =>
      SessionGroup(PlayerScope.of(c), PlayerScope.settingsOf(c));
  static Widget _visualizer(BuildContext c) =>
      _VisualizerGroup(PlayerScope.of(c));
  static Widget _coverArt(BuildContext c) => _CoverArtGroup(PlayerScope.of(c));
  static Widget _about(BuildContext c) => _AboutGroup(PlayerScope.of(c));

  @override
  Widget build(BuildContext context) {
    // A grid of category boxes; tapping one pushes its detail as a route with
    // the shared fade+slide transition (see fadeSlidePageRoute).
    return _CategoryGrid(
      categories: _categories,
      onSelect: (j) => Navigator.of(context).push(
        fadeSlidePageRoute(_CategoryDetailScreen(category: _categories[j])),
      ),
    );
  }
}

/// A pushed full-page settings detail (one category): a back row above the
/// category's controls. Pushed via [fadeSlidePageRoute].
class _CategoryDetailScreen extends StatelessWidget {
  final _Category category;
  const _CategoryDetailScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            BackBar(
              title: category.title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(child: SectionBody(children: [category.build(context)])),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<_Category> categories;
  final ValueChanged<int> onSelect;

  const _CategoryGrid({required this.categories, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.s20,
        Tokens.s8,
        Tokens.s20,
        Tokens.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Categories'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 168,
              crossAxisSpacing: Tokens.s12,
              mainAxisSpacing: Tokens.s12,
              childAspectRatio: 1,
            ),
            itemCount: categories.length,
            itemBuilder: (context, i) => GridCard(
              icon: categories[i].icon,
              title: categories[i].title,
              onTap: () => onSelect(i),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Playback -------------------------------------------------------

class _PlaybackGroup extends StatelessWidget {
  final Player player;
  const _PlaybackGroup(this.player);

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      label: 'Playback',
      children: [
        Live<double>(
          stream: player.stream.rate,
          initial: player.state.rate,
          builder: (context, v) => SliderRow(
            label: 'Speed',
            description: 'Playback rate without changing pitch',
            value: v,
            min: 0.25,
            max: 4,
            resetTo: 1,
            format: (x) => '${x.toStringAsFixed(2)}x',
            onChanged: player.setRate,
          ),
        ),
        Live<double>(
          stream: player.stream.pitch,
          initial: player.state.pitch,
          builder: (context, v) => SliderRow(
            label: 'Pitch',
            description: 'Shift pitch without changing speed',
            value: v,
            min: 0.5,
            max: 2,
            resetTo: 1,
            format: (x) => '${x.toStringAsFixed(2)}x',
            onChanged: player.setPitch,
          ),
        ),
        Live<bool>(
          stream: player.stream.pitchCorrection,
          initial: player.state.pitchCorrection,
          builder: (context, v) => SwitchRow(
            label: 'Pitch correction',
            subtitle: 'Keep pitch constant when changing speed',
            value: v,
            onChanged: player.setPitchCorrection,
          ),
        ),
        Live<Loop>(
          stream: player.stream.loop,
          initial: player.state.loop,
          builder: (context, v) => _LabelledControl(
            label: 'Repeat',
            description: 'Loop the current track or the whole queue',
            child: SegmentedControl<Loop>(
              selected: v,
              onSelect: player.setLoop,
              options: const [
                SegmentOption(Loop.off, 'Off'),
                SegmentOption(Loop.file, 'Track'),
                SegmentOption(Loop.playlist, 'Queue'),
              ],
            ),
          ),
        ),
        Live<bool>(
          stream: player.stream.shuffle,
          initial: player.state.shuffle,
          builder: (context, v) => SwitchRow(
            label: 'Shuffle',
            subtitle: 'Play the queue in random order',
            value: v,
            onChanged: player.setShuffle,
          ),
        ),
        Live<Gapless>(
          stream: player.stream.gapless,
          initial: player.state.gapless,
          builder: (context, v) => _LabelledControl(
            label: 'Gapless',
            description: 'Remove the silence between consecutive tracks',
            child: SegmentedControl<Gapless>(
              selected: v,
              onSelect: player.setGapless,
              options: const [
                SegmentOption(Gapless.no, 'Off'),
                SegmentOption(Gapless.weak, 'Weak'),
                SegmentOption(Gapless.yes, 'Strict'),
              ],
            ),
          ),
        ),
        Live<double>(
          stream: player.stream.volumeMax,
          initial: player.state.volumeMax,
          builder: (context, v) => SliderRow(
            label: 'Volume limit',
            description: 'Ceiling for the soft volume control',
            value: v,
            min: 100,
            max: 1000,
            resetTo: 130,
            format: (x) => '${x.round()}%',
            onChanged: player.setVolumeMax,
          ),
        ),
        Live<double>(
          stream: player.stream.volumeGain,
          initial: player.state.volumeGain,
          builder: (context, v) => SliderRow(
            label: 'Volume gain',
            description: 'Decoder-side gain applied before output',
            value: v,
            min: -24,
            max: 24,
            resetTo: 0,
            format: (x) => '${x.toStringAsFixed(1)} dB',
            onChanged: player.setVolumeGain,
          ),
        ),
        Live<double>(
          stream: player.stream.volumeGainMin,
          initial: player.state.volumeGainMin,
          builder: (context, v) => SliderRow(
            label: 'Gain clamp (min)',
            description: 'Floor for the applied volume gain',
            value: v,
            min: -96,
            max: 0,
            resetTo: -96,
            format: (x) => '${x.toStringAsFixed(0)} dB',
            onChanged: player.setVolumeGainMin,
          ),
        ),
        Live<double>(
          stream: player.stream.volumeGainMax,
          initial: player.state.volumeGainMax,
          builder: (context, v) => SliderRow(
            label: 'Gain clamp (max)',
            description: 'Ceiling for the applied volume gain',
            value: v,
            min: 0,
            max: 24,
            resetTo: 12,
            format: (x) => '${x.toStringAsFixed(0)} dB',
            onChanged: player.setVolumeGainMax,
          ),
        ),
        // OS per-app mixer (mpv's ao-volume / ao-mute). Best-effort: the
        // active audio output may not expose it, in which case the stream
        // value is null and we show "unavailable".
        StreamBuilder<double?>(
          stream: player.stream.systemVolume,
          initialData: player.state.systemVolume,
          builder: (context, snap) {
            final sv = snap.data;
            if (sv == null) {
              return const SettingTile(
                title: 'System volume',
                description: 'Not exposed by the active audio output',
                trailing: ValueBadge('unavailable'),
              );
            }
            return SliderRow(
              label: 'System volume',
              description: 'OS per-app mixer (distinct from soft volume)',
              value: sv,
              min: 0,
              max: 100,
              format: (x) => '${x.round()}%',
              onChanged: player.setSystemVolume,
            );
          },
        ),
        StreamBuilder<bool?>(
          stream: player.stream.systemMute,
          initialData: player.state.systemMute,
          builder: (context, snap) {
            final sm = snap.data;
            if (sm == null) {
              return const SettingTile(
                title: 'System mute',
                description: 'Not exposed by the active audio output',
                trailing: ValueBadge('unavailable'),
              );
            }
            return SwitchRow(
              label: 'System mute',
              subtitle: 'OS per-app mixer mute',
              value: sm,
              onChanged: player.setSystemMute,
            );
          },
        ),
      ],
    );
  }
}

// ---- Resume (watch later) -------------------------------------------

class _ResumeGroup extends StatefulWidget {
  final Player player;
  final AppSettings settings;
  const _ResumeGroup(this.player, this.settings);

  @override
  State<_ResumeGroup> createState() => _ResumeGroupState();
}

class _ResumeGroupState extends State<_ResumeGroup> {
  Player get player => widget.player;
  AppSettings get settings => widget.settings;

  late bool _resume = settings.resumePlayback;
  late String _dir = settings.watchLaterDir;

  Future<void> _pickDir() async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    setState(() => _dir = dir);
    settings.recordWatchLaterDir(dir);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Resume playback (applied on next launch)',
          children: [
            SwitchRow(
              label: 'Resume from last position',
              subtitle:
                  'Restore position, speed, volume and track on reopen, '
                  'ideal for audiobooks and podcasts',
              value: _resume,
              onChanged: (v) {
                setState(() => _resume = v);
                settings.recordResumePlayback(v);
              },
            ),
            SettingTile(
              title: 'Watch-later directory',
              description: _dir.isEmpty
                  ? 'mpv default (often not writable on mobile)'
                  : _dir,
              trailing: GestureDetector(
                onTap: _pickDir,
                child: const ValueBadge('Choose…', color: Tokens.accent),
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Current file',
          children: [
            SettingTile(
              title: 'Save resume point now',
              description: 'Write a watch-later config for the current file',
              trailing: GestureDetector(
                onTap: () async {
                  await player.writeResumeConfig();
                  _toast('Resume point saved');
                },
                child: const ValueBadge('Save', color: Tokens.accent),
              ),
            ),
            SettingTile(
              title: 'Clear resume point',
              description: 'Delete the saved position for the current file',
              trailing: GestureDetector(
                onTap: () async {
                  await player.deleteResumeConfig();
                  _toast('Resume point cleared');
                },
                child: const ValueBadge('Clear'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---- Output ---------------------------------------------------------

class _OutputGroup extends StatelessWidget {
  final Player player;
  final AppSettings settings;
  const _OutputGroup(this.player, this.settings);

  static const _channels = <(Channels, String)>[
    (Channels.auto, 'Auto'),
    (Channels.mono, 'Mono'),
    (Channels.stereo, 'Stereo'),
    (Channels.twoOne, '2.1'),
    (Channels.quad, '4.0'),
    (Channels.fiveOne, '5.1'),
    (Channels.sevenOne, '7.1'),
  ];

  static const _sampleRates = <int>[0, 44100, 48000, 88200, 96000, 192000];

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      label: 'Audio output',
      children: [
        // Device picker.
        StreamBuilder<List<Device>>(
          stream: player.stream.audioDevices,
          initialData: player.state.audioDevices,
          builder: (context, devSnap) {
            final devices = devSnap.data ?? const <Device>[];
            return Live<Device>(
              stream: player.stream.audioDevice,
              initial: player.state.audioDevice,
              builder: (context, current) {
                final known = devices.any((d) => d == current);
                return DropdownRow<Device>(
                  label: 'Device',
                  description: 'Hardware output the audio is sent to',
                  value: known ? current : null,
                  hint: known ? null : current.description,
                  items: [
                    for (final d in devices)
                      DropdownMenuItem(
                        value: d,
                        child: Text(
                          d.description,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (d) {
                    if (d != null) player.setAudioDevice(d);
                  },
                );
              },
            );
          },
        ),
        SwitchRow(
          label: 'Exclusive mode',
          subtitle: 'Take exclusive control of the output device',
          value: settings.audioExclusive,
          onChanged: (v) {
            player.setAudioExclusive(v);
            settings.recordExclusive(v);
          },
        ),
        Live<Format>(
          stream: player.stream.audioFormat,
          initial: player.state.audioFormat,
          builder: (context, v) {
            // The curated list omits planar variants; if the engine
            // reports one, show it as a hint rather than asserting.
            const shown = [
              Format.auto,
              Format.s16,
              Format.s32,
              Format.s64,
              Format.float32,
              Format.float64,
            ];
            final known = shown.contains(v);
            return DropdownRow<Format>(
              label: 'Sample format',
              description: 'Bit depth and number type sent to the device',
              value: known ? v : null,
              hint: known ? null : v.mpvValue,
              items: const [
                DropdownMenuItem(value: Format.auto, child: Text('Auto')),
                DropdownMenuItem(value: Format.s16, child: Text('16-bit int')),
                DropdownMenuItem(value: Format.s32, child: Text('32-bit int')),
                DropdownMenuItem(value: Format.s64, child: Text('64-bit int')),
                DropdownMenuItem(
                  value: Format.float32,
                  child: Text('32-bit float'),
                ),
                DropdownMenuItem(
                  value: Format.float64,
                  child: Text('64-bit float'),
                ),
              ],
              onChanged: (f) {
                if (f != null) player.setAudioFormat(f);
              },
            );
          },
        ),
        Live<Channels>(
          stream: player.stream.audioChannels,
          initial: player.state.audioChannels,
          builder: (context, v) {
            Channels? match;
            for (final c in _channels) {
              if (c.$1.mpvValue == v.mpvValue) {
                match = c.$1;
                break;
              }
            }
            return DropdownRow<Channels>(
              label: 'Channels',
              description: 'Speaker layout requested from the output',
              value: match,
              hint: match == null ? v.mpvValue : null,
              items: [
                for (final c in _channels)
                  DropdownMenuItem(value: c.$1, child: Text(c.$2)),
              ],
              onChanged: (c) {
                if (c != null) player.setAudioChannels(c);
              },
            );
          },
        ),
        Live<int>(
          stream: player.stream.audioSampleRate,
          initial: player.state.audioSampleRate,
          builder: (context, v) {
            final rates = {..._sampleRates, v}.toList()..sort();
            return DropdownRow<int>(
              label: 'Sample rate',
              description: 'Output sampling frequency',
              value: v,
              items: [
                for (final r in rates)
                  DropdownMenuItem(
                    value: r,
                    child: Text(
                      r == 0 ? 'Auto' : '${r ~/ 1000}.${(r % 1000) ~/ 100} kHz',
                    ),
                  ),
              ],
              onChanged: (r) {
                if (r != null) player.setAudioSampleRate(r);
              },
            );
          },
        ),
        Live<Duration>(
          stream: player.stream.audioBuffer,
          initial: player.state.audioBuffer,
          builder: (context, v) => SliderRow(
            label: 'Output buffer',
            description: 'Audio queued at the device; higher hides dropouts',
            value: v.inMilliseconds.toDouble(),
            min: 0,
            max: 2000,
            resetTo: 200,
            format: (x) => '${x.round()} ms',
            onChanged: (x) =>
                player.setAudioBuffer(Duration(milliseconds: x.round())),
          ),
        ),
        Live<Duration>(
          stream: player.stream.audioDelay,
          initial: player.state.audioDelay,
          builder: (context, v) => SliderRow(
            label: 'Audio delay',
            description: 'Shift audio earlier or later to fix sync',
            value: v.inMicroseconds / 1e6,
            min: -5,
            max: 5,
            resetTo: 0,
            format: (x) => '${x.toStringAsFixed(3)} s',
            onChanged: (x) =>
                player.setAudioDelay(Duration(microseconds: (x * 1e6).round())),
          ),
        ),
        // Report a "music" media role to the OS audio server (PulseAudio /
        // PipeWire on Linux; audtrack / aaudio on Android) for correct routing.
        Live<bool>(
          stream: player.stream.audioMediaRole,
          initial: player.state.audioMediaRole,
          builder: (context, v) => SwitchRow(
            label: 'Music media role',
            subtitle: 'Tag the stream as "music" for the OS audio server',
            value: v,
            onChanged: player.setAudioMediaRole,
          ),
        ),
      ],
    );
  }
}

// ---- Normalization --------------------------------------------------

class _NormalizationGroup extends StatefulWidget {
  final Player player;
  final AppSettings settings;
  const _NormalizationGroup(this.player, this.settings);

  @override
  State<_NormalizationGroup> createState() => _NormalizationGroupState();
}

class _NormalizationGroupState extends State<_NormalizationGroup> {
  Player get player => widget.player;

  late bool _normalizeDownmix = widget.settings.normalizeDownmix;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ReplayGainSettings>(
      stream: player.stream.replayGain,
      initialData: player.state.replayGain,
      builder: (context, snap) {
        final rg = snap.data ?? const ReplayGainSettings();
        final normalizer = PlayerScope.normalizerOf(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scan-based normalization first: it works on ANY track (no
            // tags needed) — the engine measures each file on load.
            ListenableBuilder(
              listenable: normalizer,
              builder: (context, _) {
                // Live scan status shown as read-only rows, mirroring the
                // Prefetch state pattern (a state row plus a value row). The
                // loudness is measured regardless of the toggle, so the state
                // is the real scan state.
                final scan = normalizer.lastScan;
                final scanState = switch (scan?.state) {
                  LoudnessScanState.scanning =>
                    scan!.progress != null
                        ? 'scanning ${(scan.progress! * 100).round()}%'
                        : 'scanning',
                  LoudnessScanState.ready => 'ready',
                  LoudnessScanState.failed => 'failed',
                  LoudnessScanState.unavailable => 'unavailable',
                  _ => 'idle',
                };
                final g = normalizer.appliedGainDb;
                final isReady =
                    scan?.state == LoudnessScanState.ready &&
                    scan?.integrated != null;
                final measured = !isReady
                    ? '-'
                    : '${scan!.integrated!.toStringAsFixed(1)} LUFS'
                          '${normalizer.enabled ? ' · gain ${g >= 0 ? '+' : ''}${g.toStringAsFixed(1)} dB' : ''}';
                return SettingsGroup(
                  label: 'Loudness normalization (EBU R128)',
                  children: [
                    SwitchRow(
                      label: 'Normalize volume',
                      subtitle:
                          'Measure each track on load and steer it to '
                          'the target loudness. Works without ReplayGain tags.',
                      value: normalizer.enabled,
                      onChanged: normalizer.setEnabled,
                    ),
                    InfoRow(label: 'Scan state', value: scanState),
                    InfoRow(label: 'Measured', value: measured),
                    SliderRow(
                      label: 'Target',
                      description:
                          'Integrated loudness target. -18 LUFS is the '
                          'ReplayGain 2.0 reference; streaming services sit '
                          'around -14',
                      value: normalizer.targetLufs,
                      min: -24,
                      max: -10,
                      resetTo: -18,
                      format: (x) => '${x.toStringAsFixed(0)} LUFS',
                      enabled: normalizer.enabled,
                      onChanged: normalizer.setTargetLufs,
                    ),
                  ],
                );
              },
            ),
            SettingsGroup(
              label: 'ReplayGain normalization',
              children: [
                _LabelledControl(
                  label: 'Mode',
                  description: 'Match loudness per track or per album',
                  child: SegmentedControl<ReplayGain>(
                    selected: rg.mode,
                    onSelect: (m) => player.setReplayGain(rg.copyWith(mode: m)),
                    options: const [
                      SegmentOption(ReplayGain.no, 'Off'),
                      SegmentOption(ReplayGain.track, 'Track'),
                      SegmentOption(ReplayGain.album, 'Album'),
                    ],
                  ),
                ),
                SliderRow(
                  label: 'Pre-amp',
                  description: 'Extra gain applied on top of ReplayGain',
                  value: rg.preamp,
                  min: -15,
                  max: 15,
                  resetTo: 0,
                  format: (x) => '${x.toStringAsFixed(1)} dB',
                  enabled: rg.mode != ReplayGain.no,
                  onChanged: (x) =>
                      player.setReplayGain(rg.copyWith(preamp: x)),
                ),
                SliderRow(
                  label: 'Fallback gain',
                  description: 'Gain used when a track has no ReplayGain tags',
                  value: rg.fallback,
                  min: -15,
                  max: 15,
                  resetTo: 0,
                  format: (x) => '${x.toStringAsFixed(1)} dB',
                  enabled: rg.mode != ReplayGain.no,
                  onChanged: (x) =>
                      player.setReplayGain(rg.copyWith(fallback: x)),
                ),
                SwitchRow(
                  label: 'Allow clipping',
                  subtitle: 'Permit output clipping on loud tracks',
                  value: rg.clip,
                  enabled: rg.mode != ReplayGain.no,
                  onChanged: (v) => player.setReplayGain(rg.copyWith(clip: v)),
                ),
              ],
            ),
            SettingsGroup(
              label: 'Downmix (applied on next launch)',
              children: [
                SwitchRow(
                  label: 'Normalize downmix',
                  subtitle:
                      'Loudness-normalize surround downmixed to fewer '
                      'channels, avoiding clipping when 5.1 becomes stereo',
                  value: _normalizeDownmix,
                  onChanged: (v) {
                    setState(() => _normalizeDownmix = v);
                    widget.settings.recordNormalizeDownmix(v);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---- Cache / network ------------------------------------------------

class _CacheGroup extends StatelessWidget {
  final Player player;
  const _CacheGroup(this.player);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CacheSettings>(
      stream: player.stream.cache,
      initialData: player.state.cache,
      builder: (context, snap) {
        final cache = snap.data ?? const CacheSettings();
        return SettingsGroup(
          label: 'Cache & network',
          children: [
            _LabelledControl(
              label: 'Cache',
              description: 'Buffer the stream ahead of playback',
              child: SegmentedControl<Cache>(
                selected: cache.mode,
                onSelect: (m) => player.setCache(cache.copyWith(mode: m)),
                options: const [
                  SegmentOption(Cache.auto, 'Auto'),
                  SegmentOption(Cache.yes, 'On'),
                  SegmentOption(Cache.no, 'Off'),
                ],
              ),
            ),
            SliderRow(
              label: 'Cache duration',
              description: 'How much audio to keep buffered ahead',
              value: cache.secs.inSeconds.toDouble(),
              min: 30,
              max: 7200,
              format: (x) => '${(x / 60).round()} min',
              onChanged: (x) => player.setCache(
                cache.copyWith(secs: Duration(seconds: x.round())),
              ),
            ),
            SwitchRow(
              label: 'Cache on disk',
              subtitle: 'Spill cache to disk instead of memory',
              value: cache.onDisk,
              onChanged: (v) => player.setCache(cache.copyWith(onDisk: v)),
            ),
            SwitchRow(
              label: 'Pause on buffer',
              subtitle: 'Pause playback while the cache refills',
              value: cache.pause,
              onChanged: (v) => player.setCache(cache.copyWith(pause: v)),
            ),
            SwitchRow(
              label: 'Pre-buffer on start',
              subtitle: 'Buffer before playback starts, and again after a seek',
              value: cache.pauseInitial,
              onChanged: (v) =>
                  player.setCache(cache.copyWith(pauseInitial: v)),
            ),
            SliderRow(
              label: 'Buffer wait',
              description: 'How long to wait while the cache refills',
              value: cache.pauseWait.inMicroseconds / 1e6,
              min: 0.1,
              max: 60,
              resetTo: 1,
              enabled: cache.pause,
              format: (x) => '${x.toStringAsFixed(1)} s',
              onChanged: (x) => player.setCache(
                cache.copyWith(
                  pauseWait: Duration(microseconds: (x * 1e6).round()),
                ),
              ),
            ),
            Live<Duration>(
              stream: player.stream.networkTimeout,
              initial: player.state.networkTimeout,
              builder: (context, v) => SliderRow(
                label: 'Network timeout',
                description: 'Give up on a stalled connection after this',
                value: v.inSeconds.toDouble().clamp(5, 120),
                min: 5,
                max: 120,
                resetTo: 60,
                format: (x) => '${x.round()} s',
                onChanged: (x) =>
                    player.setNetworkTimeout(Duration(seconds: x.round())),
              ),
            ),
            Live<bool>(
              stream: player.stream.tlsVerify,
              initial: player.state.tlsVerify,
              builder: (context, v) => SwitchRow(
                label: 'Verify TLS certificates',
                subtitle: 'Reject servers with an untrusted certificate',
                value: v,
                onChanged: player.setTlsVerify,
              ),
            ),
            Live<double>(
              stream: player.stream.cacheSpeed,
              initial: player.state.cacheSpeed,
              builder: (context, v) => InfoRow(
                label: 'Cache speed',
                value: '${(v / 1024).toStringAsFixed(1)} KiB/s',
              ),
            ),
            Live<int>(
              stream: player.stream.cacheBufferingState,
              initial: player.state.cacheBufferingState,
              builder: (context, v) =>
                  InfoRow(label: 'Cache buffering', value: '$v%'),
            ),
            StreamBuilder<double>(
              stream: player.stream.bufferingPercentage,
              initialData: player.state.bufferingPercentage,
              builder: (context, snap) => InfoRow(
                label: 'Buffer fill',
                value: '${(snap.data ?? 0).toStringAsFixed(1)}%',
              ),
            ),
            Live<bool>(
              stream: player.stream.pausedForCache,
              initial: player.state.pausedForCache,
              builder: (context, v) =>
                  InfoRow(label: 'Paused for cache', value: v ? 'yes' : 'no'),
            ),
          ],
        );
      },
    );
  }
}

// ---- Visualizer -----------------------------------------------------

class _VisualizerGroup extends StatelessWidget {
  final Player player;
  const _VisualizerGroup(this.player);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SpectrumSettings>(
      stream: player.stream.spectrum,
      initialData: player.state.spectrum,
      builder: (context, snap) {
        final spec = snap.data ?? const SpectrumSettings();
        return SettingsGroup(
          label: 'Visualizer',
          children: [
            _LabelledControl(
              label: 'FFT window',
              description: 'Window function applied before the transform',
              child: SegmentedControl<WindowFunction>(
                selected: spec.window,
                onSelect: (w) => player.setSpectrum(spec.copyWith(window: w)),
                options: const [
                  SegmentOption(WindowFunction.hann, 'Hann'),
                  SegmentOption(WindowFunction.blackmanHarris, 'Blackman'),
                  SegmentOption(WindowFunction.rectangular, 'Rect'),
                ],
              ),
            ),
            _LabelledControl(
              label: 'FFT size',
              description: 'Samples per frame; higher resolves finer detail',
              child: SegmentedControl<int>(
                selected: spec.fftSize,
                onSelect: (s) => player.setSpectrum(spec.copyWith(fftSize: s)),
                options: const [
                  SegmentOption(512, '512'),
                  SegmentOption(1024, '1024'),
                  SegmentOption(2048, '2048'),
                  SegmentOption(4096, '4096'),
                ],
              ),
            ),
            SliderRow(
              label: 'Bands',
              description: 'Number of bars drawn in the spectrum',
              value: spec.bandCount.toDouble(),
              min: 16,
              max: 128,
              divisions: 112,
              format: (x) => x.round().toString(),
              onChanged: (x) =>
                  player.setSpectrum(spec.copyWith(bandCount: x.round())),
            ),
          ],
        );
      },
    );
  }
}

// ---- Cover art ------------------------------------------------------

class _CoverArtGroup extends StatelessWidget {
  final Player player;
  const _CoverArtGroup(this.player);

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      label: 'Cover art',
      children: [
        Live<Cover>(
          stream: player.stream.coverArtAuto,
          initial: player.state.coverArtAuto,
          builder: (context, v) => _LabelledControl(
            label: 'Load external art',
            description: 'Look for cover images next to the audio file',
            child: SegmentedControl<Cover>(
              selected: v,
              onSelect: player.setCoverArtAuto,
              options: const [
                SegmentOption(Cover.no, 'Off'),
                SegmentOption(Cover.exact, 'Exact'),
                SegmentOption(Cover.fuzzy, 'Fuzzy'),
                SegmentOption(Cover.all, 'All'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---- About ----------------------------------------------------------

class _AboutGroup extends StatelessWidget {
  final Player player;
  const _AboutGroup(this.player);

  @override
  Widget build(BuildContext context) {
    final mpv = player.state.mpvVersion;
    final ffmpeg = player.state.ffmpegVersion;
    return SettingsGroup(
      label: 'About',
      children: [
        const InfoRow(label: 'App', value: 'MPV Studio'),
        InfoRow(label: 'Engine', value: mpv.isEmpty ? '-' : mpv),
        InfoRow(label: 'FFmpeg', value: ffmpeg.isEmpty ? '-' : ffmpeg),
      ],
    );
  }
}

// ---- Shared ---------------------------------------------------------

/// A settings tile whose interaction is a full-width control beneath the
/// title (segmented pickers) — same rhythm as the slider/dropdown tiles.
class _LabelledControl extends StatelessWidget {
  final String label;
  final String? description;
  final Widget child;
  const _LabelledControl({
    required this.label,
    required this.child,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SettingTile(title: label, description: description, below: child);
  }
}
