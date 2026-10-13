import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/app_settings.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';

/// Streaming behaviour: keep the output alive between tracks and prefetch
/// the next playlist entry while the current one is still playing, plus the
/// build-time streaming knobs (force-seekable, HLS variant selection) that
/// are read when the engine starts.
class StreamingGroup extends StatefulWidget {
  final Player player;
  final AppSettings settings;
  const StreamingGroup(this.player, this.settings, {super.key});

  @override
  State<StreamingGroup> createState() => _StreamingGroupState();
}

class _StreamingGroupState extends State<StreamingGroup> {
  Player get player => widget.player;
  AppSettings get settings => widget.settings;

  late bool _forceSeekable = settings.forceSeekable;
  late HlsBitrate _hlsBitrate = settings.hlsBitrate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Streaming',
          children: [
            Live<bool>(
              stream: player.stream.audioStreamSilence,
              initial: player.state.audioStreamSilence,
              builder: (context, v) => SwitchRow(
                label: 'Stream silence',
                subtitle:
                    'Keep the device open by feeding silence between tracks',
                value: v,
                onChanged: (x) => unawaited(player.setAudioStreamSilence(x)),
              ),
            ),
            Live<bool>(
              stream: player.stream.prefetchPlaylist,
              initial: player.state.prefetchPlaylist,
              builder: (context, v) => SwitchRow(
                label: 'Prefetch next track',
                subtitle: 'Open the next playlist entry ahead of time',
                value: v,
                onChanged: player.setPrefetchPlaylist,
              ),
            ),
            StreamBuilder<PrefetchState>(
              stream: player.stream.prefetchState,
              builder: (context, snap) => InfoRow(
                label: 'Prefetch state',
                value: (snap.data ?? PrefetchState.idle).name,
              ),
            ),
            StreamBuilder<Duration>(
              stream: player.stream.prefetchCacheDuration,
              builder: (context, snap) {
                final d = snap.data ?? Duration.zero;
                return InfoRow(
                  label: 'Prefetched ahead',
                  value: '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s',
                );
              },
            ),
          ],
        ),
        SettingsGroup(
          label: 'Stream open (applied on next launch)',
          children: [
            SwitchRow(
              label: 'Force seekable',
              subtitle:
                  'Allow in-cache seeking on streams mpv reports as non-seekable '
                  '(direct HTTP or HLS audio)',
              value: _forceSeekable,
              onChanged: (v) {
                setState(() => _forceSeekable = v);
                settings.recordForceSeekable(v);
              },
            ),
            SettingTile(
              title: 'HLS variant',
              description:
                  'Which rendition to pick from an adaptive HLS playlist',
              below: SegmentedControl<HlsBitrate>(
                selected: _hlsBitrate,
                options: const [
                  SegmentOption(HlsBitrate.no, 'Off'),
                  SegmentOption(HlsBitrate.min, 'Min'),
                  SegmentOption(HlsBitrate.max, 'Max'),
                ],
                onSelect: (v) {
                  setState(() => _hlsBitrate = v);
                  settings.recordHlsBitrate(v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
