import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/playback_issues.dart';
import '../../util/media_import.dart';

/// Picks files or a folder and hands back the paths, empty when cancelled.
typedef PathPicker = Future<List<String>> Function();

/// Picks one playlist file, null when cancelled.
typedef PlaylistPicker = Future<String?> Function();

/// Opens the system picker for one playlist file.
Future<String?> pickPlaylistFile() async {
  const group = XTypeGroup(
    label: 'playlist',
    extensions: ['m3u', 'm3u8', 'pls', 'cue'],
    // iOS filters by UTI, not extension, and rejects an extension-only group
    // outright. Playlists are plain text; m3u carries its own system type.
    uniformTypeIdentifiers: ['public.m3u-playlist', 'public.text'],
  );
  final file = await openFile(acceptedTypeGroups: const [group]);
  return file?.path;
}

/// The queue operations behind the Queue page. Every player call goes
/// through [guard], so a failure becomes a toast and never escapes.
///
/// Indices are the queue's own. Moves take the final position of the
/// entry, which this class turns into mpv's `playlist-move` target (the
/// entry it lands before).
class QueueController {
  QueueController({
    required this.player,
    required this.guard,
    this.pickFiles = pickAudioFiles,
    this.pickFolder = pickAudioFolder,
    this.pickPlaylist = pickPlaylistFile,
  });

  final PlayerApi player;
  final CallGuard guard;
  final PathPicker pickFiles;
  final PathPicker pickFolder;
  final PlaylistPicker pickPlaylist;

  /// How many picked files are still being added to the queue.
  ValueListenable<int> get adding => _adding;
  final _adding = ValueNotifier<int>(0);
  bool _disposed = false;

  /// Sets [adding], unless the controller was disposed mid-add (the
  /// player changed under the page).
  void _setAdding(int value) {
    if (!_disposed) _adding.value = value;
  }

  List<Media> get _items => player.state.playlist.items;

  static Media mediaFor(String path) =>
      Media(path, extras: {'title': baseNameNoExt(path)});

  /// Queues the files at [paths]: they become the queue and start playing
  /// when it is empty, else they are appended.
  Future<void> enqueue(List<String> paths) async {
    if (paths.isEmpty) return;
    _setAdding(_adding.value + paths.length);
    try {
      final medias = [for (final p in paths) mediaFor(p)];
      if (_items.isEmpty) {
        await guard(() => player.openAll(medias, play: true));
        return;
      }
      for (final m in medias) {
        final ok = await guard(() async {
          await player.add(m);
          return true;
        });
        _setAdding(_adding.value - 1);
        if (ok == null) break;
      }
    } finally {
      _setAdding(0);
    }
  }

  Future<void> addFiles() async => enqueue(await pickFiles());

  Future<void> addFolder() async => enqueue(await pickFolder());

  /// Loads a playlist file (.m3u, .m3u8, .pls, .cue) as the new queue: its
  /// entries are expanded by the engine (`openPlaylistFile`), unlike
  /// `open`, which would queue the playlist as one entry.
  Future<void> loadPlaylist() async {
    final path = await pickPlaylist();
    if (path == null) return;
    await guard(() => player.openPlaylistFile(Media(path), play: true));
  }

  Future<void> clear() => guard(player.clearPlaylist);

  Future<void> play(int index) => guard(() => player.jump(index));

  /// Removes the entry at [index] and returns it, or null when the call
  /// failed (the entry stays).
  Future<Media?> remove(int index) async {
    if (index < 0 || index >= _items.length) return null;
    final media = _items[index];
    final ok = await guard(() async {
      await player.remove(index);
      return true;
    });
    return ok == null ? null : media;
  }

  /// Puts [media] back at [index] after a [remove].
  Future<void> restore(Media media, int index) => guard(() async {
    // The appended entry lands at the current length.
    final last = _items.length;
    await player.add(media);
    if (index < last) await player.move(last, index);
  });

  /// Moves the entry at [from] so that it ends up at index [to].
  Future<void> move(int from, int to) {
    if (from == to) return Future.value();
    // playlist-move puts the entry before the one now at the target.
    return guard(() => player.move(from, to > from ? to + 1 : to));
  }

  /// Moves the entry at [index] right after the current one.
  Future<void> playNext(int index) {
    final current = player.state.playlist.index;
    if (current < 0 || index == current || index == current + 1) {
      return Future.value();
    }
    return guard(() => player.move(index, current + 1));
  }

  Future<void> moveToTop(int index) => move(index, 0);

  Future<void> moveToBottom(int index) => move(index, _items.length - 1);

  /// Swaps the entry at [index] for a picked file. Gapless when [index] is
  /// the current entry.
  Future<void> replace(int index) async {
    final paths = await pickFiles();
    if (paths.isEmpty) return;
    await guard(() => player.replace(index, mediaFor(paths.first)));
  }

  /// Goes to the next source playlist: true when there was one, false when
  /// there was none, null when the call failed.
  Future<bool?> nextPlaylist() => guard(player.nextPlaylist);

  /// The reverse of [nextPlaylist].
  Future<bool?> previousPlaylist() => guard(player.previousPlaylist);

  void dispose() {
    _disposed = true;
    _adding.dispose();
  }
}
