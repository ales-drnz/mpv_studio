import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/signed_url_resolver.dart';

import '../stream/stream_fakes.dart';
import 'showcase_covers.dart';
import 'showcase_library.dart';
import 'showcase_player.dart';

/// A made-up media server over the showcase shelf: songs and albums
/// that search like the real servers (title, artist or album, any case),
/// covers at made-up URLs, and nothing on the network.
class ShowcaseServer extends FakeServer {
  ShowcaseServer(ServerKind kind, List<ShowcaseAlbum> shelf)
    : _host = kind == ServerKind.plex
          ? 'plex.example.test'
          : 'jellyfin.example.test',
      super(
        kind: kind,
        connected: true,
        tracks: [
          for (final a in shelf)
            for (final t in a.files) _track(kind, a, t),
        ],
        albums: [
          for (final a in shelf)
            ServerAlbum(
              id: _albumId(a),
              title: a.title,
              artist: a.artist,
              year: a.year,
              artUrl: artUrl(kind, a),
            ),
        ],
        albumTracks: {
          for (final a in shelf)
            _albumId(a): [for (final t in a.files) _track(kind, a, t)],
        },
      );

  final String _host;

  static String _albumId(ShowcaseAlbum a) =>
      a.title.toLowerCase().replaceAll(' ', '-');

  /// Where [album]'s cover is on a [kind] server.
  static String artUrl(ServerKind kind, ShowcaseAlbum album) =>
      'https://${kind.name}.example.test/art/${_albumId(album)}.png';

  static ServerTrack _track(
    ServerKind kind,
    ShowcaseAlbum a,
    ShowcaseTrack t,
  ) => ServerTrack(
    id: '${_albumId(a)}-${t.number}',
    title: t.title,
    artist: t.artist,
    album: t.album,
    duration: t.length,
    artUrl: artUrl(kind, a),
  );

  @override
  String get hostHint => _host;

  bool _matches(String query, List<String> fields) {
    final q = query.trim().toLowerCase();
    return q.isEmpty || fields.any((f) => f.toLowerCase().contains(q));
  }

  @override
  Future<LibraryPage<ServerTrack>> fetchTracks({
    required int startIndex,
    required int pageSize,
    String query = '',
  }) async {
    final hits = tracks
        .where((t) => _matches(query, [t.title, t.artist, t.album]))
        .toList();
    return LibraryPage(
      hits.skip(startIndex).take(pageSize).toList(),
      hits.length,
    );
  }

  @override
  Future<LibraryPage<ServerAlbum>> fetchAlbums({
    required int startIndex,
    required int pageSize,
    String query = '',
  }) async {
    final hits = albums
        .where((a) => _matches(query, [a.title, a.artist]))
        .toList();
    return LibraryPage(
      hits.skip(startIndex).take(pageSize).toList(),
      hits.length,
    );
  }

  @override
  String streamUrl(ServerTrack track, StreamOptions options) =>
      'https://$_host/audio/${track.id}/${options.mode.name}.m3u8';
}

/// Every cover of [shelf] on a [kind] server, by URL, painted.
Future<Map<String, Uint8List>> paintServerCovers(
  WidgetTester tester,
  ServerKind kind,
  List<ShowcaseAlbum> shelf,
) async {
  final covers = <String, Uint8List>{};
  await tester.runAsync(() async {
    for (final a in shelf) {
      covers[ShowcaseServer.artUrl(kind, a)] = await paintCover(a.cover);
    }
  });
  return covers;
}

/// A resolver whose log times follow [now] and whose call times are
/// fixed, so its log reads the same on every run.
SignedUrlResolver showcaseResolver(DateTime Function() now) =>
    SignedUrlResolver(
      clock: now,
      timer: (work) {
        work();
        return const Duration(microseconds: 300);
      },
    );

/// Plays signed links the way the app's player does: when a
/// `studio-signed://` entry opens, it asks [resolver] for a link, which
/// has expired, retries for a fresh one, then the fresh one is kept on
/// the next open, a moment apart each, so the log fills as it would.
class SignedPlayback {
  SignedPlayback(this.player, this.resolver);

  final ShowcasePlayer player;
  final SignedUrlResolver resolver;

  /// Opens [media] (a signed entry) and plays its resolver calls.
  void open(Media media) {
    final entry = media.uri;
    Timer(const Duration(milliseconds: 150), () async {
      final expired = await resolver.resolve(
        SourceResolveRequest(media: media, uri: entry, isRetry: false),
      );
      Timer(const Duration(milliseconds: 450), () async {
        final fresh = await resolver.resolve(
          SourceResolveRequest(media: media, uri: expired!, isRetry: true),
        );
        Timer(const Duration(milliseconds: 450), () {
          resolver.resolve(
            SourceResolveRequest(media: media, uri: fresh!, isRetry: false),
          );
        });
      });
    });
  }
}
