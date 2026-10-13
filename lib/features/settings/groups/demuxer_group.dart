import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/app_settings.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';

/// Demuxer cache tuning, the on-disk cache directory (build-time), and the
/// live demuxer / cache status. Sizes are exposed in MiB; the engine stores
/// raw bytes.
class DemuxerGroup extends StatefulWidget {
  final Player player;
  final AppSettings settings;
  const DemuxerGroup(this.player, this.settings, {super.key});

  @override
  State<DemuxerGroup> createState() => _DemuxerGroupState();
}

class _DemuxerGroupState extends State<DemuxerGroup> {
  static const _mib = 1024 * 1024;

  Player get player => widget.player;
  AppSettings get settings => widget.settings;

  late String _cacheDir = settings.demuxerCacheDir;

  Future<void> _pickCacheDir() async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    setState(() => _cacheDir = dir);
    settings.recordDemuxerCacheDir(dir);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Demuxer performance',
          children: [
            Live<DemuxerSettings>(
              stream: player.stream.demuxer,
              initial: player.state.demuxer,
              builder: (context, d) => SliderRow(
                label: 'Max cache size',
                description: 'Memory the demuxer may use to read ahead',
                value: d.maxBytes / _mib,
                min: 1,
                max: 2048,
                resetTo: 150,
                format: (x) => '${x.round()} MiB',
                onChanged: (x) =>
                    player.setDemuxer(d.copyWith(maxBytes: (x * _mib).round())),
              ),
            ),
            // mpv's demuxer-readahead-secs is fractional seconds, so the field
            // is a Duration. The slider scrubs whole seconds.
            Live<DemuxerSettings>(
              stream: player.stream.demuxer,
              initial: player.state.demuxer,
              builder: (context, d) => SliderRow(
                label: 'Readahead',
                description: 'How far ahead of playback the demuxer reads',
                value: d.readahead.inMilliseconds / 1000.0,
                min: 0,
                max: 600,
                resetTo: 1,
                format: (x) => '${x.round()} s',
                onChanged: (x) => player.setDemuxer(
                  d.copyWith(
                    readahead: Duration(milliseconds: (x * 1000).round()),
                  ),
                ),
              ),
            ),
            Live<DemuxerSettings>(
              stream: player.stream.demuxer,
              initial: player.state.demuxer,
              builder: (context, d) => SliderRow(
                label: 'Seekback pool',
                description: 'Recent audio kept so seeking back is instant',
                value: d.maxBackBytes / _mib,
                min: 0,
                max: 1024,
                resetTo: 50,
                format: (x) => '${x.round()} MiB',
                onChanged: (x) => player.setDemuxer(
                  d.copyWith(maxBackBytes: (x * _mib).round()),
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'On-disk cache (applied on next launch)',
          children: [
            SettingTile(
              title: 'Cache directory',
              description: _cacheDir.isEmpty
                  ? 'mpv default (often not writable on mobile)'
                  : _cacheDir,
              trailing: GestureDetector(
                onTap: _pickCacheDir,
                child: const ValueBadge('Choose…', color: Tokens.accent),
              ),
            ),
          ],
        ),
        SettingsGroup(
          label: 'Demuxer status',
          children: [
            Live<String>(
              stream: player.stream.currentDemuxer,
              initial: player.state.currentDemuxer,
              builder: (context, v) =>
                  InfoRow(label: 'Current demuxer', value: v.isEmpty ? '-' : v),
            ),
            Live<Duration>(
              stream: player.stream.bufferDuration,
              initial: player.state.bufferDuration,
              builder: (context, v) => InfoRow(
                label: 'Cache ahead',
                value: '${(v.inMicroseconds / 1e6).toStringAsFixed(2)} s',
              ),
            ),
            StreamBuilder<bool>(
              stream: player.stream.demuxerIdle,
              builder: (context, snap) => InfoRow(
                label: 'Idle',
                value: (snap.data ?? true) ? 'yes' : 'no',
              ),
            ),
            Live<bool>(
              stream: player.stream.demuxerViaNetwork,
              initial: player.state.demuxerViaNetwork,
              builder: (context, v) =>
                  InfoRow(label: 'Via network', value: v ? 'yes' : 'no'),
            ),
            Live<Duration>(
              stream: player.stream.demuxerStartTime,
              initial: player.state.demuxerStartTime,
              builder: (context, v) => InfoRow(
                label: 'Start time',
                value: '${(v.inMicroseconds / 1e6).toStringAsFixed(3)} s',
              ),
            ),
          ],
        ),
        // Structured cache-state snapshot for streaming sources (empty for
        // directly-seekable local files).
        Live<DemuxerCacheState>(
          stream: player.stream.demuxerCacheState,
          initial: player.state.demuxerCacheState,
          builder: (context, cache) => SettingsGroup(
            label: 'Network cache state',
            children: [
              InfoRow(
                label: 'Buffered ranges',
                value: cache.seekableRanges.isEmpty
                    ? '-'
                    : cache.seekableRanges
                          .map((r) => '${_fmt(r.start)}–${_fmt(r.end)}')
                          .join(', '),
              ),
              InfoRow(
                label: 'Raw input rate',
                value: cache.rawInputRate == null
                    ? '-'
                    : '${(cache.rawInputRate! / 1024).toStringAsFixed(1)} KiB/s',
              ),
              InfoRow(
                label: 'Cached at ends',
                value:
                    'EOF ${cache.eofCached ? 'yes' : 'no'}, '
                    'BOF ${cache.bofCached ? 'yes' : 'no'}',
              ),
              InfoRow(label: 'Underrun', value: cache.underrun ? 'yes' : 'no'),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}
