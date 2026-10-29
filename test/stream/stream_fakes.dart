import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/favorites_controller.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/samba/samba_login_store.dart';
import 'package:mpv_studio/features/stream/samba/samba_share.dart';
import 'package:mpv_studio/features/stream/samba/samba_tab.dart';
import 'package:mpv_studio/features/stream/signed_url_resolver.dart';
import 'package:mpv_studio/features/stream/stream_actions.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';
import 'package:mpv_studio/studio/playback_issues.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/fake_player.dart';
import '../support/layout_harness.dart';

/// A [FakePlayer] that also takes the load calls the Stream page makes and
/// records the [Media] they carry, applying them to the playlist.
class StreamPlayer extends FakePlayer {
  StreamPlayer([super.initial]);

  /// Every entry loaded, in call order.
  final List<Media> loaded = [];

  /// The resolver installed with [setSourceResolver].
  SourceResolver? resolver;

  late final _stream = StreamPlayerStream(this);

  @override
  PlayerStream get stream => _stream;

  void _setQueue(List<Media> items, int index) =>
      emit((s) => s.copyWith(playlist: Playlist(items, index: index)));

  @override
  Future<void> open(Media media, {bool? play}) async {
    calls.add('open');
    loaded.add(media);
    _setQueue([media], 0);
  }

  @override
  Future<void> openAll(List<Media> medias, {bool? play, int index = 0}) async {
    calls.add('openAll ${medias.length}');
    loaded.addAll(medias);
    _setQueue(List.of(medias), index);
  }

  @override
  Future<void> add(Media media) async {
    calls.add('add');
    loaded.add(media);
    final pl = state.playlist;
    _setQueue([...pl.items, media], pl.index);
  }

  @override
  Future<void> move(int from, int to) async {
    calls.add('move $from $to');
    final pl = state.playlist;
    final items = List.of(pl.items);
    final m = items.removeAt(from);
    items.insert(to > from ? to - 1 : to, m);
    _setQueue(items, pl.index);
  }

  @override
  Future<void> setChapter(int index) async => calls.add('setChapter $index');

  @override
  Future<void> setSourceResolver(
    SourceResolver? resolver, {
    Duration? timeout = const Duration(seconds: 15),
  }) async {
    calls.add('setSourceResolver');
    this.resolver = resolver;
  }
}

/// [FakePlayerStream] plus the chapters stream the Chapters tab reads.
class StreamPlayerStream extends FakePlayerStream {
  StreamPlayerStream(this._player) : super(_player);
  final StreamPlayer _player;

  @override
  Stream<List<Chapter>> get chapters => _player.watch((p) => p.state.chapters);
}

/// A media server with canned answers and no network.
class FakeServer extends MediaServer {
  FakeServer({
    this.kind = ServerKind.jellyfin,
    this.connected = false,
    this.tracks = const [],
    this.albums = const [],
    this.albumTracks = const {},
    this.connectError,
    this.fetchError,
  });

  @override
  final ServerKind kind;
  bool connected;
  final List<ServerTrack> tracks;
  final List<ServerAlbum> albums;
  final Map<String, List<ServerTrack>> albumTracks;

  /// Thrown by [connect]; null signs in.
  Object? connectError;

  /// Thrown by the fetches; null answers.
  Object? fetchError;

  final List<String> log = [];

  @override
  String get name => kind == ServerKind.plex ? 'Plex' : 'Jellyfin';

  @override
  bool get isConnected => connected;

  @override
  List<StreamProtocol> get protocols => kind == ServerKind.plex
      ? const [StreamProtocol.dash, StreamProtocol.hls]
      : const [StreamProtocol.hls];

  @override
  String get hostHint => '192.168.1.10:8096';

  @override
  Future<void> connect({
    required String host,
    required String username,
    required String password,
  }) async {
    log.add('connect $host $username');
    final e = connectError;
    if (e != null) throw e;
    connected = true;
  }

  @override
  Future<bool> tryRestore() async => connected;

  @override
  FailureKind classify(Object error) => switch (error) {
    FakeAuthError() => FailureKind.auth,
    _ => commonFailureKind(error) ?? FailureKind.other,
  };

  @override
  Future<void> logout() async {
    log.add('logout');
    connected = false;
  }

  @override
  Future<LibraryPage<ServerTrack>> fetchTracks({
    required int startIndex,
    required int pageSize,
    String query = '',
  }) async {
    final e = fetchError;
    if (e != null) throw e;
    final hits = tracks.where((t) => t.title.contains(query)).toList();
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
    final e = fetchError;
    if (e != null) throw e;
    return LibraryPage(
      albums.skip(startIndex).take(pageSize).toList(),
      albums.length,
    );
  }

  @override
  Future<List<ServerTrack>> fetchAlbumTracks(ServerAlbum album) async =>
      albumTracks[album.id] ?? const [];

  @override
  String streamUrl(ServerTrack track, StreamOptions options) {
    final e = streamError;
    if (e != null) throw e;
    return 'https://${kind.name}.test/${track.id}?mode=${options.mode.name}';
  }

  /// Thrown by [streamUrl]; null builds the URL.
  Object? streamError;

  @override
  Future<void> setFavorite(String trackId, bool isFavorite) async =>
      log.add('favorite $trackId $isFavorite');

  @override
  Future<void> reportStart(String itemId, {required Duration duration}) async {}

  @override
  Future<void> reportProgress(
    String itemId, {
    required Duration position,
    required Duration duration,
    required bool paused,
  }) async {}

  @override
  Future<void> reportStopped(
    String itemId, {
    required Duration position,
    required Duration duration,
  }) async {}
}

/// What a [FakeServer] throws for refused credentials.
class FakeAuthError implements Exception {
  @override
  String toString() => 'HTTP 401';
}

/// A share with a fixed folder tree: folder path to entries.
class FakeShare implements SambaShare {
  FakeShare(this.tree);

  final Map<String, List<SambaEntry>> tree;
  bool disconnected = false;

  /// Thrown by [disconnect]; null closes cleanly.
  Object? disconnectError;

  /// Listings that wait for their completer, by folder.
  final Map<String, Completer<void>> gates = {};

  @override
  Future<List<SambaEntry>> list(String path) async {
    await gates[path]?.future;
    return tree[path] ?? const [];
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    final e = disconnectError;
    if (e != null) throw e;
  }
}

/// A keychain in memory; [failing] makes every call throw, like Linux
/// without a running secret service.
class FakeSecretStore implements SecretStore {
  FakeSecretStore({this.failing = false});

  bool failing;
  final Map<String, String> values = {};

  void _check() {
    if (failing) throw Exception('no secret service');
  }

  @override
  Future<String?> read(String key) async {
    _check();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check();
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _check();
    values.remove(key);
  }
}

/// A login store with nothing saved that saves nothing, touching neither
/// the preferences nor the keychain.
class NoSambaLogin extends SambaLoginStore {
  NoSambaLogin() : super(secrets: FakeSecretStore());

  @override
  Future<SambaLogin?> load() async => null;

  @override
  Future<void> save(SambaLogin login) async {}

  @override
  Future<void> clear() async {}
}

/// [StreamActions] on [player], unguarded.
StreamActions actionsFor(PlayerApi player) =>
    StreamActions(player: player, guard: unguarded);

/// The Stream page on fakes, as [pumpStudio] hosts it, in a [Scaffold].
Widget streamView({
  required StreamPlayer player,
  FakeServer? jellyfin,
  FakeServer? plex,
  SignedUrlResolver? resolver,
  StreamTab tab = StreamTab.lab,
  Object? tabRequest,
  Widget? samba,
}) {
  final j = jellyfin ?? FakeServer();
  final p = plex ?? FakeServer(kind: ServerKind.plex);
  final actions = actionsFor(player);
  return Scaffold(
    body: StreamView(
      actions: actions,
      jellyfin: j,
      plex: p,
      favorites: FavoritesController({
        ServerKind.jellyfin: j,
        ServerKind.plex: p,
      }),
      resolver: resolver ?? SignedUrlResolver(),
      initialTab: tab,
      tabRequest: tabRequest,
      samba: samba ?? SambaTab(actions: actions, store: NoSambaLogin()),
    ),
  );
}

/// Pumps [child] at the named [size] with the size's input and insets.
Future<void> pumpAt(
  WidgetTester tester,
  Widget child,
  String size, {
  Palette palette = Palette.dark,
  double textScale = 1,
}) async {
  final s = studioSize(size);
  final input = inputFor(s);
  await pumpStudio(
    tester,
    child,
    size: s.size,
    input: input,
    palette: palette,
    textScale: textScale,
    padding: input == InputMode.touch ? phoneInsets(s.size) : EdgeInsets.zero,
  );
}
