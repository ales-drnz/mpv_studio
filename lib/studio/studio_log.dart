import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/console/console_log.dart';

/// Where the app's own diagnostics go: the Console log of the running
/// studio (as `studio` lines next to the engine's), and the debug console
/// in debug builds only. Before a studio runs, and in tests, a line only
/// reaches the debug console.
abstract final class StudioLog {
  static ConsoleLog? _sink;

  /// Sends the lines to [log] from now on (the running studio's).
  static void attach(ConsoleLog log) => _sink = log;

  /// Stops sending lines to [log], if it is the current one.
  static void detach(ConsoleLog log) {
    if (identical(_sink, log)) _sink = null;
  }

  /// Logs [text] at [level].
  static void write(String text, {LogLevel level = LogLevel.info}) {
    if (kDebugMode) debugPrint('studio: $text');
    _sink?.add(MpvLogEntry(prefix: 'studio', level: level, text: text));
  }
}

/// [uri] safe to log: no query (a Plex URL carries its token there) and no
/// user name or password.
String redactUri(String uri) {
  final parsed = Uri.tryParse(uri);
  if (parsed == null) {
    final q = uri.indexOf('?');
    return q < 0 ? uri : uri.substring(0, q);
  }
  return parsed
      .replace(userInfo: '', query: '')
      .toString()
      .replaceFirst(RegExp(r'\?$'), '');
}
