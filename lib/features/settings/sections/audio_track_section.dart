import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../util/reactive.dart';
import '../setting_anchor.dart';
import '../settings_catalog.dart';
import '../settings_scope.dart';
import 'anchored_rows.dart';

/// The audio track (`aid`) of the current file: the file's tracks plus the
/// two picks mpv understands, automatic and none; external audio files
/// added, rescanned or removed as extra tracks.
class AudioTrackSection extends StatelessWidget {
  const AudioTrackSection({super.key});

  // Values of the two picks that are not a track id.
  static const _auto = -1;
  static const _none = -2;

  static Future<void> _addExternal(SettingsScope scope) async {
    const group = XTypeGroup(
      label: 'Audio',
      extensions: ['mka', 'mp3', 'm4a', 'aac', 'flac', 'opus', 'ogg', 'wav'],
      uniformTypeIdentifiers: ['public.audio'],
    );
    final XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: const [group]);
    } on Object catch (e) {
      debugPrint('File picker unavailable: $e');
      return;
    }
    if (file == null) return;
    await scope.guard(
      () => scope.player.addAudioTrack(Media(file!.path), select: true),
    );
  }

  static String _label(MpvTrack t) {
    final lang = t.lang != null ? ' [${t.lang}]' : '';
    final ext = t.external ? ', external' : '';
    return t.title?.isNotEmpty == true
        ? '${t.id}: ${t.title}$lang$ext'
        : '${t.id}$lang$ext';
  }

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final p = scope.player;
    return Live<List<MpvTrack>>(
      stream: p.stream.tracks,
      initial: p.state.tracks,
      builder: (context, tracks) => Live<MpvTrack?>(
        stream: p.stream.currentAudioTrack,
        initial: p.state.currentAudioTrack,
        builder: (context, current) {
          final audio = [
            for (final t in tracks)
              if (t.type == 'audio' && !t.image && !t.albumArt) t,
          ];
          final items = <DropdownMenuItem<int>>[
            const DropdownMenuItem(value: _auto, child: Text('Automatic')),
            const DropdownMenuItem(value: _none, child: Text('No audio')),
            for (final t in audio)
              DropdownMenuItem(value: t.id, child: Text(_label(t))),
          ];
          final id = current?.id;
          final selected = items.any((i) => i.value == id) ? id : _auto;
          return SettingsGroup(
            label: SettingsSections.audioTrack,
            children: [
              anchoredDropdown<int>(
                scope,
                SettingsCatalog.audioTrack,
                value: selected,
                items: items,
                set: (v) => p.setAudioTrack(switch (v) {
                  _auto => Track.auto,
                  _none => Track.off,
                  _ => Track.id(v),
                }),
              ),
              InfoRow(
                label: 'Playing',
                value: current == null
                    ? 'no audio'
                    : 'track ${current.id}'
                          '${current.lang != null ? ' (${current.lang})' : ''}'
                          '${current.external ? ', external file' : ''}',
              ),
              if (current?.codecProfile case final profile?)
                InfoRow(label: 'Codec profile', value: profile),
              SettingAnchor(
                entry: SettingsCatalog.addExternal,
                child: SettingTile(
                  title: SettingsCatalog.addExternal.title,
                  description: SettingsCatalog.addExternal.description,
                  trailing: TileButton(
                    label: 'Add',
                    accent: true,
                    tooltip: 'Add an external audio file',
                    onPressed: () => _addExternal(scope),
                  ),
                ),
              ),
              SettingAnchor(
                entry: SettingsCatalog.rescanExternal,
                child: SettingTile(
                  title: SettingsCatalog.rescanExternal.title,
                  description: SettingsCatalog.rescanExternal.description,
                  trailing: TileButton(
                    label: 'Rescan',
                    tooltip: 'Rescan external audio files',
                    onPressed: () => scope.run(p.rescanExternalFiles),
                  ),
                ),
              ),
              if (current != null && current.external)
                SettingTile(
                  title: 'Remove this external track',
                  description: current.externalFilename,
                  trailing: TileButton(
                    label: 'Remove',
                    tooltip: 'Remove the external audio track',
                    onPressed: () => scope.run(
                      () => p.removeAudioTrack(Track.id(current.id)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
