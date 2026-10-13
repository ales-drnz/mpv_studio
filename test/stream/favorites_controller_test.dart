import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/stream/favorites_controller.dart';
import 'package:mpv_studio/features/stream/media_server.dart';

import 'stream_fakes.dart';

/// A server whose favourite writes wait for the test.
class _SlowServer extends FakeServer {
  final writes = <Completer<void>>[];

  @override
  Future<void> setFavorite(String trackId, bool isFavorite) {
    final c = Completer<void>();
    writes.add(c);
    return c.future;
  }
}

void main() {
  test('a refused toggle rolls back', () async {
    final server = _SlowServer();
    final favs = FavoritesController({ServerKind.jellyfin: server});
    final done = favs.setFavorite(ServerKind.jellyfin, 't', true);
    expect(favs.resolved(ServerKind.jellyfin, 't', false), isTrue);
    server.writes.single.completeError(Exception('500'));
    expect(await done, isFalse);
    expect(favs.resolved(ServerKind.jellyfin, 't', false), isFalse);
  });

  test('a late failure does not undo a newer toggle', () async {
    final server = _SlowServer();
    final favs = FavoritesController({ServerKind.jellyfin: server});
    final first = favs.setFavorite(ServerKind.jellyfin, 't', true);
    final second = favs.setFavorite(ServerKind.jellyfin, 't', false);
    server.writes[1].complete();
    expect(await second, isTrue);
    server.writes[0].completeError(Exception('timeout'));
    expect(await first, isFalse);
    expect(favs.resolved(ServerKind.jellyfin, 't', true), isFalse);
  });
}
