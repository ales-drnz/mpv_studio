import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' show LogLevel;

import '../../studio/studio_log.dart';
import 'media_server.dart';

/// App-level store of favourite (like) state for media-server tracks, shared
/// by the song lists (the star button) and the [PlaybackReporter] (the OS
/// lock-screen like command). Holds optimistic overrides keyed by
/// `"<kind>:<trackId>"` so a toggle from either surface reflects in the other
/// without a refetch, and writes through to the server.
class FavoritesController extends ChangeNotifier {
  FavoritesController(this._servers);

  final Map<ServerKind, MediaServer> _servers;
  final Map<String, bool> _overrides = {};

  /// The latest write per key: a failure rolls back only its own toggle,
  /// never a newer one made while it was in flight.
  final Map<String, int> _writes = {};

  static String _key(ServerKind kind, String id) => '${kind.name}:$id';

  /// The favourite state for a track if it's been toggled this session,
  /// otherwise [fallback] (the value the server returned for the list).
  bool resolved(ServerKind kind, String id, bool fallback) =>
      _overrides[_key(kind, id)] ?? fallback;

  /// Sets the favourite state for [id] on [kind]: shows it at once
  /// (optimistic), then writes it to the server. When the server refuses,
  /// the previous state comes back (unless a newer toggle came since) and
  /// this returns false; it never throws.
  Future<bool> setFavorite(ServerKind kind, String id, bool value) async {
    final key = _key(kind, id);
    final had = _overrides.containsKey(key);
    final before = _overrides[key];
    final write = _writes[key] = (_writes[key] ?? 0) + 1;
    _overrides[key] = value;
    notifyListeners();
    try {
      await _servers[kind]?.setFavorite(id, value);
      return true;
    } catch (e) {
      StudioLog.write(
        'FavoritesController: ${kind.name} refused $id: $e',
        level: LogLevel.warn,
      );
      if (_writes[key] != write) return false;
      if (had) {
        _overrides[key] = before!;
      } else {
        _overrides.remove(key);
      }
      notifyListeners();
      return false;
    }
  }
}
