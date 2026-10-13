import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/player_scope.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';

/// Audio track (`aid`) selector. Lists the file's audio tracks plus the
/// two synthetic picks mpv understands — `auto` and `no` — and lets the user
/// load or drop an external audio file as an extra selectable track.
class AudioTrackGroup extends StatelessWidget {
  final Player player;
  const AudioTrackGroup(this.player, {super.key});

  Future<void> _addExternal(BuildContext context) async {
    const group = XTypeGroup(
      label: 'audio',
      extensions: ['mka', 'mp3', 'm4a', 'aac', 'flac', 'opus', 'ogg', 'wav'],
    );
    final issues = PlayerScope.issuesOf(context);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    await issues.guard(
      () => player.addAudioTrack(Media(file.path), select: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MpvTrack>>(
      stream: player.stream.tracks,
      initialData: player.state.tracks,
      builder: (context, tracksSnap) {
        final audioTracks = (tracksSnap.data ?? const <MpvTrack>[])
            .where((t) => t.type == 'audio' && !t.image && !t.albumArt)
            .toList();
        return StreamBuilder<MpvTrack?>(
          stream: player.stream.currentAudioTrack,
          initialData: player.state.currentAudioTrack,
          builder: (context, currentSnap) {
            final current = currentSnap.data;
            final currentId = current?.id;

            final items = <DropdownMenuItem<int>>[
              const DropdownMenuItem(value: -1, child: Text('Auto')),
              const DropdownMenuItem(value: -2, child: Text('No audio')),
              for (final t in audioTracks)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(
                    _trackLabel(t),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ];
            final selected =
                items.any((i) => i.value == currentId) ? currentId : -1;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsGroup(
                  label: 'Audio track',
                  children: [
                    DropdownRow<int>(
                      label: 'Track',
                      description: 'Which audio track to play from the file',
                      value: selected,
                      items: items,
                      onChanged: (v) {
                        if (v == null) return;
                        final mode = switch (v) {
                          -1 => Track.auto,
                          -2 => Track.off,
                          _ => Track.id(v),
                        };
                        PlayerScope.issuesOf(context)
                            .guard(() => player.setAudioTrack(mode));
                      },
                    ),
                    InfoRow(
                      label: 'Active',
                      value: current == null
                          ? 'no audio'
                          : 'aid=${current.id}'
                              '${current.lang != null ? ' (${current.lang})' : ''}',
                    ),
                    if (current != null) ...[
                      InfoRow(
                        label: 'Source',
                        value: current.external ? 'external file' : 'container',
                      ),
                      if (current.externalFilename != null)
                        InfoRow(
                          label: 'File',
                          value: current.externalFilename!,
                        ),
                      if (current.codecProfile != null)
                        InfoRow(
                          label: 'Codec profile',
                          value: current.codecProfile!,
                        ),
                    ],
                  ],
                ),
                SettingsGroup(
                  label: 'External tracks',
                  children: [
                    SettingTile(
                      title: 'Add external audio file',
                      description:
                          'Load a separate dub or commentary as a selectable track',
                      trailing: GestureDetector(
                        onTap: () => _addExternal(context),
                        child: const ValueBadge('Add…', color: Tokens.accent),
                      ),
                    ),
                    if (current != null && current.external)
                      SettingTile(
                        title: 'Remove current external track',
                        description: 'Detach the loaded external audio file',
                        trailing: GestureDetector(
                          onTap: () => PlayerScope.issuesOf(context).guard(
                            () => player.removeAudioTrack(Track.id(current.id)),
                          ),
                          child: const ValueBadge('Remove'),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _trackLabel(MpvTrack t) {
    final lang = t.lang != null ? ' [${t.lang}]' : '';
    final ext = t.external ? ' ·ext' : '';
    return t.title?.isNotEmpty == true
        ? '${t.id}: ${t.title}$lang$ext'
        : '${t.id}$lang$ext';
  }
}
