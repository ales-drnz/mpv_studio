import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../util/media_labels.dart';

/// Runs a player call for a control: [PlaybackIssues.guard] in the app,
/// so what the call throws becomes a toast. Completes with the call's
/// result, or null when it threw (e.g. the bool of `Player.next`).
typedef CallGuard = Future<T?> Function<T>(FutureOr<T> Function() call);

/// A [CallGuard] that only runs the call, for a control hosted without
/// the app around it (the widget tests).
Future<T?> unguarded<T>(FutureOr<T> Function() call) async => call();

/// One readable problem for the user, shown as a toast by the shell.
@immutable
class PlaybackNotice {
  const PlaybackNotice(this.message);

  final String message;

  @override
  String toString() => 'PlaybackNotice($message)';
}

/// Turns the engine's errors into what the app shows:
///
/// * a [PlaybackNotice] for a track that stopped on an error
///   ([EndFileError]) and for a player call that threw ([guard]);
/// * a count of mpv error lines ([LogError]) not yet seen in the Console,
///   for the badge on its navigation entry;
/// * the queue entries that failed to play, for their row in the Queue.
///
/// The raw lines stay in the Console log; nothing here shows them as toasts.
class PlaybackIssues {
  PlaybackIssues({
    required Stream<PlayerError> errors,
    required Stream<MpvFileEndedEvent> endFile,
    required Stream<Playlist> playlist,
    required Stream<void> loaded,
  }) {
    _subs = [
      playlist.listen(_onPlaylist),
      endFile.listen(_onEndFile),
      errors.listen(_onError),
      loaded.listen((_) => _onLoaded()),
    ];
  }

  /// Wires the service to [player]'s streams.
  factory PlaybackIssues.of(Player player) => PlaybackIssues(
    errors: player.stream.error,
    endFile: player.stream.endFile,
    playlist: player.stream.playlist,
    loaded: player.stream.seekCompleted,
  );

  late final List<StreamSubscription<Object?>> _subs;
  final _notices = StreamController<PlaybackNotice>.broadcast();

  /// Readable problems to show as toasts.
  Stream<PlaybackNotice> get notices => _notices.stream;

  /// mpv error lines logged since the Console was last open.
  ValueListenable<int> get unseenLogErrors => _unseenLogErrors;
  final _unseenLogErrors = ValueNotifier<int>(0);

  /// Queue entries whose last attempt to play ended on an error. An entry
  /// leaves the set once it loads, or once it leaves the queue.
  ValueListenable<Set<Media>> get failed => _failed;
  final _failed = ValueNotifier<Set<Media>>(const {});

  bool _consoleVisible = false;

  /// Whether the Console is on screen. While it is, mpv errors are seen as
  /// they arrive and the badge stays at zero.
  set consoleVisible(bool visible) {
    _consoleVisible = visible;
    if (visible) _unseenLogErrors.value = 0;
  }

  /// The entry mpv is on, as last reported by the playlist stream.
  Media? _current;

  /// The entry the latest error ended, until its [EndFileError] is shown.
  Media? _lastFailed;

  void _onPlaylist(Playlist pl) {
    _current = pl.index >= 0 && pl.index < pl.items.length
        ? pl.items[pl.index]
        : null;
    if (_failed.value.isEmpty) return;
    final kept = _failed.value.where(pl.items.contains).toSet();
    if (kept.length != _failed.value.length) _failed.value = kept;
  }

  void _onEndFile(MpvFileEndedEvent event) {
    if (event.reason != MpvEndFileReason.error) return;
    final entry = _current;
    _lastFailed = entry;
    if (entry != null && !_failed.value.contains(entry)) {
      _failed.value = {..._failed.value, entry};
    }
  }

  void _onLoaded() {
    final entry = _current;
    if (entry == null || !_failed.value.contains(entry)) return;
    _failed.value = {..._failed.value}..remove(entry);
  }

  void _onError(PlayerError error) {
    debugPrint('mpv error: ${error.message}');
    switch (error) {
      case EndFileError():
        final entry = _lastFailed;
        _lastFailed = null;
        _notices.add(
          PlaybackNotice(
            describeEndFileError(
              error,
              title: entry == null ? null : titleOf(entry),
            ),
          ),
        );
      case LogError():
        if (!_consoleVisible) _unseenLogErrors.value++;
    }
  }

  /// Runs a player [call] and turns what it throws into a notice: an
  /// [MpvCommandException], a [SourceException] or another
  /// [PlayerException], and a [RangeError] (a queue index that went away).
  /// Returns null when the call failed. A disposed player fails silently.
  Future<T?> guard<T>(FutureOr<T> Function() call) async {
    try {
      return await call();
    } on PlayerDisposedException {
      return null;
    } on PlayerException catch (e) {
      report(e);
      return null;
    } on RangeError catch (e) {
      report(e);
      return null;
    }
  }

  /// Shows [error] as a notice, for failures caught outside [guard].
  void report(Object error) {
    debugPrint('player call failed: $error');
    _notices.add(PlaybackNotice(describeCallError(error)));
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _notices.close();
    _unseenLogErrors.dispose();
    _failed.dispose();
  }
}

/// The toast text for a track that stopped on [error]. [title] names the
/// track when known.
String describeEndFileError(EndFileError error, {String? title}) {
  final track = title == null || title.isEmpty ? 'the track' : '"$title"';
  if (error.isAudioOutputError) {
    return 'The audio device could not be opened.';
  }
  if (error.isFormatError) {
    return 'Could not play $track: no playable audio found.';
  }
  if (error.isLoadingError) {
    return 'Could not open $track. Check the file or the connection.';
  }
  return 'Playback of $track stopped: ${_sentence(error.message)}';
}

/// The toast text for a player call that threw [error].
String describeCallError(Object error) => switch (error) {
  MpvCommandException(:final name, :final message) =>
    'mpv refused "$name": ${_sentence(message)}',
  SourceException(:final uri, :final message) =>
    'Could not open "${nameFromUri(uri)}": ${_sentence(message)}',
  PlayerInitException(:final message) =>
    'The audio engine did not start: ${_sentence(message)}',
  RangeError() => 'That queue entry is no longer there.',
  _ => 'Something went wrong: ${_sentence(error.toString())}',
};

/// [text] trimmed, with a final full stop.
String _sentence(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'unknown error.';
  return RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.';
}
