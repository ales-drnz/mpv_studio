import 'package:flutter/foundation.dart';

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

  static String _key(ServerKind kind, String id) => '${kind.name}:$id';

  /// The favourite state for a track if it's been toggled this session,
  /// otherwise [fallback] (the value the server returned for the list).
  bool resolved(ServerKind kind, String id, bool fallback) =>
      _overrides[_key(kind, id)] ?? fallback;

  /// Sets the favourite state for [id] on [kind]: shows it at once
  /// (optimistic), then writes it to the server. When the server refuses,
  /// the previous state comes back and this returns false; it never
  /// throws.
  Future<bool> setFavorite(ServerKind kind, String id, bool value) async {
    final key = _key(kind, id);
    final had = _overrides.containsKey(key);
    final before = _overrides[key];
    _overrides[key] = value;
    notifyListeners();
    try {
      await _servers[kind]?.setFavorite(id, value);
      return true;
    } catch (e) {
      debugPrint('FavoritesController: ${kind.name} refused $id: $e');
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
