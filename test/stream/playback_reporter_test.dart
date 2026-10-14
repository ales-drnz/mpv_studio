import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/favorites_controller.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/playback_reporter.dart';

import '../support/fake_player.dart';
import 'stream_fakes.dart';

/// A server that records its playback reports.
class _ReportingServer extends FakeServer {
  _ReportingServer(ServerKind kind) : super(kind: kind, connected: true);

  final reports = <String>[];

  @override
  Future<void> reportStart(String itemId) async => reports.add('start $itemId');

  @override
  Future<void> reportStopped(
    String itemId, {
    required Duration position,
  }) async => reports.add('stop $itemId ${position.inSeconds}');
}

class _Player extends FakePlayer {
  @override
  late final PlayerStream stream = _Stream(this);
}

class _Stream extends FakePlayerStream {
  _Stream(super.p);

  @override
  Stream<MediaSessionCommand> get mediaSessionCommands => const Stream.empty();
}

const _samba = Media('smb://nas/music/a.m4a');

Media _track(ServerKind kind, String id) =>
    Media('https://server/$id', extras: {'server': kind.name, 'serverId': id});

void main() {
  for (final kind in [ServerKind.plex, ServerKind.jellyfin]) {
    test('${kind.name} stops at the last position it reached', () async {
      final server = _ReportingServer(kind);
      final servers = {kind: server};
      final player = _Player();
      final reporter = PlaybackReporter(
        player,
        servers,
        FavoritesController(servers),
      )..start();

      player.emit(
        (s) => s.copyWith(
          playlist: Playlist([_track(kind, '3217'), _samba], index: 0),
          playing: true,
          playWhenReady: true,
        ),
      );
      await pumpEventQueue();
      player.emit((s) => s.copyWith(position: const Duration(seconds: 48)));
      await pumpEventQueue();

      // The user plays another track: the position resets before the
      // playlist moves on, then the next entry starts counting.
      player.emit((s) => s.copyWith(position: Duration.zero));
      await pumpEventQueue();
      player.emit(
        (s) => s.copyWith(
          playlist: Playlist([_track(kind, '3217'), _samba], index: 1),
          position: const Duration(seconds: 2),
        ),
      );
      await pumpEventQueue();

      await reporter.dispose();
      expect(server.reports, ['start 3217', 'stop 3217 48']);
    });
  }
}
