import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';
import 'anchored_rows.dart';
import 'pickers.dart';

/// The network cache and its live state.
class CacheSection extends StatelessWidget {
  const CacheSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return Live<CacheSettings>(
      stream: p.stream.cache,
      initial: p.state.cache,
      builder: (context, cache) => SettingsGroup(
        label: SettingsSections.cache,
        children: [
          anchoredSegments(
            scope,
            SettingsCatalog.cacheMode,
            selected: cache.mode,
            set: (m) => p.setCache(cache.copyWith(mode: m)),
            options: const [
              SegmentOption(Cache.auto, 'Auto', tooltip: 'Automatic'),
              SegmentOption(Cache.yes, 'On'),
              SegmentOption(Cache.no, 'Off'),
            ],
          ),
          anchoredSlider(
            scope,
            SettingsCatalog.cacheDuration,
            value: cache.secs.inSeconds.toDouble(),
            min: 30,
            max: 7200,
            format: (x) => '${(x / 60).round()} min',
            set: (x) =>
                p.setCache(cache.copyWith(secs: Duration(seconds: x.round()))),
          ),
          anchoredSwitch(
            scope,
            SettingsCatalog.cacheOnDisk,
            value: cache.onDisk,
            set: (v) => p.setCache(cache.copyWith(onDisk: v)),
          ),
          anchoredSwitch(
            scope,
            SettingsCatalog.pauseOnBuffer,
            value: cache.pause,
            set: (v) => p.setCache(cache.copyWith(pause: v)),
          ),
          anchoredSwitch(
            scope,
            SettingsCatalog.prebuffer,
            value: cache.pauseInitial,
            set: (v) => p.setCache(cache.copyWith(pauseInitial: v)),
          ),
          anchoredSlider(
            scope,
            SettingsCatalog.bufferWait,
            value: cache.pauseWait.inMicroseconds / 1e6,
            min: 0.1,
            max: 60,
            resetTo: 1,
            enabled: cache.pause,
            format: (x) => '${x.toStringAsFixed(1)} s',
            set: (x) => p.setCache(
              cache.copyWith(
                pauseWait: Duration(microseconds: (x * 1e6).round()),
              ),
            ),
          ),
          Live<double>(
            stream: p.stream.cacheSpeed,
            initial: p.state.cacheSpeed,
            builder: (context, v) => InfoRow(
              label: 'Cache speed',
              value: '${(v / 1024).toStringAsFixed(1)} KiB/s',
            ),
          ),
          Live<int>(
            stream: p.stream.cacheBufferingState,
            initial: p.state.cacheBufferingState,
            builder: (context, v) =>
                InfoRow(label: 'Cache buffering', value: '$v%'),
          ),
          Live<double>(
            stream: p.stream.bufferingPercentage,
            initial: p.state.bufferingPercentage,
            builder: (context, v) => InfoRow(
              label: 'Buffer fill',
              value: '${v.toStringAsFixed(1)}%',
            ),
          ),
          Live<bool>(
            stream: p.stream.pausedForCache,
            initial: p.state.pausedForCache,
            builder: (context, v) =>
                InfoRow(label: 'Paused for cache', value: v ? 'yes' : 'no'),
          ),
        ],
      ),
    );
  }
}

/// The demuxer's read-ahead and its disk cache folder (read when the player
/// is created, so a change shows the restart banner), with its live state.
/// Sizes show in MiB; the engine stores bytes.
class DemuxerSection extends StatelessWidget {
  const DemuxerSection({super.key});

  static const _mib = 1024 * 1024;

  static String _time(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    final settings = scope.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Live<DemuxerSettings>(
          stream: p.stream.demuxer,
          initial: p.state.demuxer,
          builder: (context, d) => SettingsGroup(
            label: SettingsSections.demuxer,
            children: [
              anchoredSlider(
                scope,
                SettingsCatalog.readaheadMemory,
                value: d.maxBytes / _mib,
                min: 1,
                max: 2048,
                resetTo: 150,
                format: (x) => '${x.round()} MiB',
                set: (x) =>
                    p.setDemuxer(d.copyWith(maxBytes: (x * _mib).round())),
              ),
              // demuxer-readahead-secs is fractional; the slider scrubs
              // whole seconds.
              anchoredSlider(
                scope,
                SettingsCatalog.readaheadTime,
                value: d.readahead.inMilliseconds / 1000,
                min: 0,
                max: 600,
                resetTo: 1,
                format: (x) => '${x.round()} s',
                set: (x) => p.setDemuxer(
                  d.copyWith(
                    readahead: Duration(milliseconds: (x * 1000).round()),
                  ),
                ),
              ),
              anchoredSlider(
                scope,
                SettingsCatalog.seekback,
                value: d.maxBackBytes / _mib,
                min: 0,
                max: 1024,
                resetTo: 50,
                format: (x) => '${x.round()} MiB',
                set: (x) =>
                    p.setDemuxer(d.copyWith(maxBackBytes: (x * _mib).round())),
              ),
              ListenableBuilder(
                listenable: settings.changes,
                builder: (context, _) => anchoredPath(
                  SettingsCatalog.diskCacheFolder,
                  path: settings.demuxerCacheDir,
                  unset: 'The engine default, often not writable on mobile.',
                  pick: pickFolder,
                  onChanged: settings.recordDemuxerCacheDir,
                ),
              ),
            ],
          ),
        ),
        SettingsGroup(
          label: 'Demuxer status',
          children: [
            Live<String>(
              stream: p.stream.currentDemuxer,
              initial: p.state.currentDemuxer,
              builder: (context, v) =>
                  InfoRow(label: 'Current demuxer', value: v.isEmpty ? '-' : v),
            ),
            Live<Duration>(
              stream: p.stream.bufferDuration,
              initial: p.state.bufferDuration,
              builder: (context, v) => InfoRow(
                label: 'Cache ahead',
                value: '${(v.inMicroseconds / 1e6).toStringAsFixed(2)} s',
              ),
            ),
            Live<bool>(
              stream: p.stream.demuxerViaNetwork,
              initial: p.state.demuxerViaNetwork,
              builder: (context, v) =>
                  InfoRow(label: 'Via network', value: v ? 'yes' : 'no'),
            ),
            // Structured cache state for streams (empty for local files
            // that seek directly).
            Live<DemuxerCacheState>(
              stream: p.stream.demuxerCacheState,
              initial: p.state.demuxerCacheState,
              builder: (context, c) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InfoRow(
                    label: 'Buffered ranges',
                    value: c.seekableRanges.isEmpty
                        ? '-'
                        : [
                            for (final r in c.seekableRanges)
                              '${_time(r.start)} to ${_time(r.end)}',
                          ].join(', '),
                  ),
                  InfoRow(
                    label: 'Raw input rate',
                    value: c.rawInputRate == null
                        ? '-'
                        : '${(c.rawInputRate! / 1024).toStringAsFixed(1)} KiB/s',
                  ),
                  InfoRow(label: 'Underrun', value: c.underrun ? 'yes' : 'no'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Prefetch, force seeking (read when the player is created) and the HLS
/// variant, with the live prefetch state.
class StreamingSection extends StatelessWidget {
  const StreamingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    final settings = scope.settings;
    return SettingsGroup(
      label: SettingsSections.streaming,
      children: [
        Live<bool>(
          stream: p.stream.prefetchPlaylist,
          initial: p.state.prefetchPlaylist,
          builder: (context, v) => anchoredSwitch(
            scope,
            SettingsCatalog.prefetch,
            value: v,
            set: p.setPrefetchPlaylist,
          ),
        ),
        Live<PrefetchState>(
          stream: p.stream.prefetchState,
          initial: PrefetchState.idle,
          builder: (context, v) =>
              InfoRow(label: 'Prefetch state', value: v.name),
        ),
        ListenableBuilder(
          listenable: settings.changes,
          builder: (context, _) => SettingAnchor(
            entry: SettingsCatalog.forceSeeking,
            child: SwitchRow(
              label: SettingsCatalog.forceSeeking.title,
              subtitle: SettingsCatalog.forceSeeking.description,
              value: settings.forceSeekable,
              onChanged: settings.recordForceSeekable,
            ),
          ),
        ),
        Live<HlsBitrate>(
          stream: p.stream.hlsBitrate,
          initial: p.state.hlsBitrate,
          builder: (context, v) => anchoredSegments(
            scope,
            SettingsCatalog.hlsVariant,
            selected: v,
            set: p.setHlsBitrate,
            options: const [
              SegmentOption(
                HlsBitrate.no,
                'Off',
                tooltip: 'Do not pick by bitrate',
              ),
              SegmentOption(HlsBitrate.min, 'Lowest'),
              SegmentOption(HlsBitrate.max, 'Highest'),
            ],
          ),
        ),
      ],
    );
  }
}
