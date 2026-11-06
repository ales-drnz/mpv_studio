import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/playback_issues.dart';
import '../../util/media_import.dart';
import 'queue_snapshot.dart';

/// Picks files or a folder and hands back the paths, empty when cancelled.
typedef PathPicker = Future<List<String>> Function();

/// Picks a folder and hands back its path, null when cancelled.
typedef FolderPicker = Future<String?> Function();

/// Lists the audio files under a folder.
typedef FolderScanner = Future<List<String>> Function(String folder);

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
    this.pickFolder = pickFolderPath,
    this.scanFolder = scanAudioFolder,
    this.pickPlaylist = pickPlaylistFile,
    this.notify,
  });

  final PlayerApi player;
  final CallGuard guard;
  final PathPicker pickFiles;
  final FolderPicker pickFolder;
  final FolderScanner scanFolder;
  final PlaylistPicker pickPlaylist;

  /// Says why an add did nothing (no audio, a picker that failed).
  final void Function(String message)? notify;

  /// Whether a folder is being searched for audio files.
  ValueListenable<bool> get looking => _lookingFor;
  final _lookingFor = ValueNotifier<bool>(false);

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

  Future<void> addFiles() async {
    final paths = await _pick(pickFiles);
    if (paths != null) await enqueue(paths);
  }

  /// Queues the audio files of a picked folder, searched without holding
  /// the UI up and shown as [looking] meanwhile.
  Future<void> addFolder() async {
    final dir = await _pick(pickFolder);
    if (dir == null) return;
    final paths = await _looking(() => scanFolder(dir));
    if (paths.isEmpty) {
      _notify('No audio files in this folder');
      return;
    }
    await enqueue(paths);
  }

  /// Queues what was dropped: audio files, and the audio files of folders.
  /// A drop with none says why.
  Future<void> addDropped(List<String> paths) async {
    if (paths.isEmpty) return;
    final audio = await _looking(() => resolveDroppedPaths(paths));
    if (audio.isNotEmpty) {
      // A drop can land on any section: say what it did, unless it
      // started playing.
      final appended = _items.isNotEmpty;
      final before = _items.length;
      await enqueue(audio);
      final added = _items.length - before;
      if (appended && added > 0) {
        _notify(
          added == 1
              ? 'Added to the queue'
              : '$added tracks added to the queue',
        );
      }
      return;
    }
    _notify(
      paths.any(isPlaylistPath)
          ? 'Playlists open with Load playlist'
          : 'No audio files in what was dropped',
    );
  }

  /// Runs a system picker, saying so when it cannot open; null then.
  Future<T?> _pick<T>(Future<T> Function() picker) async {
    try {
      return await picker();
    } on PlatformException catch (e) {
      _notify('Could not open the file picker: ${e.message ?? e.code}');
      return null;
    }
  }

  Future<T> _looking<T>(Future<T> Function() search) async {
    if (!_disposed) _lookingFor.value = true;
    try {
      return await search();
    } finally {
      if (!_disposed) _lookingFor.value = false;
    }
  }

  void _notify(String message) {
    if (!_disposed) notify?.call(message);
  }

  /// Loads a playlist file (.m3u, .m3u8, .pls, .cue) as the new queue: its
  /// entries are expanded by the engine (`openPlaylistFile`), unlike
  /// `open`, which would queue the playlist as one entry. Returns the
  /// queue it replaced, for an undo, or null when there was none.
  Future<QueueSnapshot?> loadPlaylist() async {
    final path = await _pick(pickPlaylist);
    if (path == null) return null;
    return _replacing(() => player.openPlaylistFile(Media(path), play: true));
  }

  /// Empties the queue and returns what it held, for an undo, or null
  /// when there was nothing or the call failed.
  Future<QueueSnapshot?> clear() => _replacing(player.clearPlaylist);

  /// Puts back a queue that [loadPlaylist] or [clear] replaced.
  Future<void> putBack(QueueSnapshot before) => before.restore(player, guard);

  Future<QueueSnapshot?> _replacing(Future<void> Function() action) async {
    final before = QueueSnapshot.of(player);
    final ok = await guard(() async {
      await action();
      return true;
    });
    return ok == true ? before : null;
  }

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

  /// The entries [removeForUndo] took since the last undo toast went,
  /// oldest first, so one Undo puts them all back.
  final _removals = <_Removal>[];

  /// Removes the entry at [index] and adds it to the removals one undo
  /// puts back. Returns how many there are now, or null when the call
  /// failed (the entry stays).
  Future<int?> removeForUndo(int index) async {
    final pl = player.state.playlist;
    final current = index == pl.index;
    final playing = player.state.playWhenReady;
    final media = await remove(index);
    if (media == null) return null;
    _removals.add(_Removal(media, index, current: current, playing: playing));
    return _removals.length;
  }

  /// Puts back every entry of [removeForUndo], newest first so each lands
  /// at its index again. The one that was current becomes current again.
  Future<void> undoRemovals() async {
    final removals = List.of(_removals.reversed);
    _removals.clear();
    for (final r in removals) {
      await restore(r.media, r.index);
      if (!r.current) continue;
      await guard(() async {
        await player.jump(r.index);
        if (!r.playing) await player.pause();
      });
    }
  }

  /// Drops the removals, once their undo is no longer offered.
  void forgetRemovals() => _removals.clear();

  /// Puts [media] back at [index] after a [remove].
  Future<void> restore(Media media, int index) => guard(() async {
    // The appended entry lands at the current length, unless the queue
    // changes elsewhere between the add and the move.
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
    _lookingFor.dispose();
  }
}

/// An entry [QueueController.removeForUndo] took out.
class _Removal {
  _Removal(
    this.media,
    this.index, {
    required this.current,
    required this.playing,
  });

  final Media media;
  final int index;

  /// Whether it was the current entry, and playback was on.
  final bool current;
  final bool playing;
}
