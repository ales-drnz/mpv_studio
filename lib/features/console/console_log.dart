import 'dart:async';
import 'dart:collection';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Always-on capture of the engine and library log, started at app launch.
///
/// The Console page (and its `player.stream.log` subscriptions) is built
/// lazily by the shell's keep-alive `IndexedStack`, only when you first
/// open the Console section. Without this service every log line emitted
/// before that first visit (mpv/ffmpeg init, the `ao=help` driver scan, the
/// Plex source resolver, the first file load…) would be lost, because the log
/// streams are live broadcasts with no replay.
///
/// This buffers the most recent [maxLines] entries from `player.stream.log`
/// and `player.stream.internalLog` from boot, and re-broadcasts each new
/// entry so the live Console appends it. The Console seeds itself from
/// [backlog] on open, then follows [entries].
class ConsoleLog {
  ConsoleLog({this.maxLines = 2000});

  /// Backlog cap, matches the Console's own scrollback limit.
  final int maxLines;

  final Queue<MpvLogEntry> _buffer = Queue<MpvLogEntry>();
  final StreamController<MpvLogEntry> _controller =
      StreamController<MpvLogEntry>.broadcast();
  final List<StreamSubscription<MpvLogEntry>> _subs = [];

  /// A snapshot of the buffered backlog, oldest first.
  List<MpvLogEntry> get backlog => List.unmodifiable(_buffer);

  /// New entries as they arrive. Does not replay the backlog, pair it with
  /// [backlog] when seeding a fresh view.
  Stream<MpvLogEntry> get entries => _controller.stream;

  /// Begin capturing from [player]. Call once, as early as possible after
  /// the player is created so the earliest startup logs are retained.
  void attach(PlayerApi player) {
    if (_subs.isNotEmpty) return; // already attached
    for (final s in [player.stream.log, player.stream.internalLog]) {
      _subs.add(s.listen(_onEntry));
    }
  }

  /// Appends a line the app logs itself (a refused setting, an uncaught
  /// error) to the backlog and the live Console.
  void add(MpvLogEntry entry) => _onEntry(entry);

  void _onEntry(MpvLogEntry entry) {
    _buffer.addLast(entry);
    while (_buffer.length > maxLines) {
      _buffer.removeFirst();
    }
    if (!_controller.isClosed) _controller.add(entry);
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _controller.close();
  }
}
