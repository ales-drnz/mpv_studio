import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../util/media_labels.dart';
import '../util/redact.dart';

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
  const PlaybackNotice(this.message, {this.isError = true});

  final String message;

  /// A problem (shown longer, with a way to the log) rather than plain
  /// information such as "End of queue".
  final bool isError;

  @override
  String toString() => 'PlaybackNotice($message${isError ? '' : ', info'})';
}

/// Turns the engine's errors into what the app shows:
///
/// * a [PlaybackNotice] for a track that stopped on an error
///   ([EndFileError]) and for a player call that threw ([guard]);
/// * a count of mpv error lines ([LogError]) not yet seen in the Console,
///   for the badge on its navigation entry;
/// * the queue entries that failed to play ([failed]), for the Playback
///   page's failed-track banner;
/// * app-level notices ([notify]), such as settings the player refused on
///   launch or an uncaught error.
///
/// Notices raised before the shell listens (during launch) are held and
/// delivered to the first listener. The raw lines stay in the Console log;
/// nothing here shows them as toasts.
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
  late final _notices = StreamController<PlaybackNotice>.broadcast(
    onListen: _deliverHeld,
  );

  /// Notices raised while nobody listened, the latest [_maxHeld].
  final List<PlaybackNotice> _held = [];
  static const _maxHeld = 8;

  void _deliverHeld() {
    final held = List.of(_held);
    _held.clear();
    held.forEach(_notices.add);
  }

  void _add(PlaybackNotice notice) {
    if (_notices.isClosed) return;
    if (_notices.hasListener) {
      _notices.add(notice);
    } else {
      _held.add(notice);
      if (_held.length > _maxHeld) _held.removeAt(0);
    }
  }

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
  /// they arrive and the badge stays at zero. Clearing the badge notifies
  /// its listeners: never set this while a frame builds.
  set consoleVisible(bool visible) {
    if (visible == _consoleVisible) return;
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
    if (_failed.value.isNotEmpty) {
      final kept = _failed.value.where(pl.items.contains).toSet();
      if (kept.length != _failed.value.length) _failed.value = kept;
    }
  }

  void _onEndFile(MpvFileEndedEvent event) {
    final entry = _current;
    if (event.reason != MpvEndFileReason.error) return;
    _lastFailed = entry;
    if (entry != null && !_failed.value.contains(entry)) {
      _failed.value = {..._failed.value, entry};
    }
  }

  void _onLoaded() {
    final entry = _current;
    if (entry == null) return;
    if (_failed.value.contains(entry)) {
      _failed.value = {..._failed.value}..remove(entry);
    }
  }

  void _onError(PlayerError error) {
    // mpv's message names the URL it failed on, server token included:
    // masked, and only in debug builds.
    if (kDebugMode) debugPrint('mpv error: ${redactSecrets(error.message)}');
    switch (error) {
      case EndFileError():
        final entry = _lastFailed;
        _lastFailed = null;
        _add(
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
    if (kDebugMode) {
      debugPrint('player call failed: ${redactSecrets('$error')}');
    }
    _add(PlaybackNotice(describeCallError(error)));
  }

  /// Shows [message] as a notice, as it is: plain information by default
  /// ("End of queue"), shown briefly; with [isError] a problem that is not
  /// a player call failing (settings refused on launch, an uncaught
  /// error), shown like the other errors.
  void notify(String message, {bool isError = false}) =>
      _add(PlaybackNotice(message, isError: isError));

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _held.clear();
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
