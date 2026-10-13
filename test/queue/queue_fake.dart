import 'dart:async';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/queue/queue_details.dart';

import '../support/fake_player.dart';

/// A [FakePlayer] whose queue commands act on its playlist, with mpv's
/// `playlist-move` meaning (the entry lands before the target), and which
/// records the raw commands, hooks and log level the Console uses.
class QueueFakePlayer extends FakePlayer {
  QueueFakePlayer([super.initial]);

  late final QueueFakeStream _queueStream = QueueFakeStream(this);

  final endFile = StreamController<MpvFileEndedEvent>.broadcast(sync: true);
  final errors = StreamController<PlayerError>.broadcast(sync: true);
  final loaded = StreamController<void>.broadcast(sync: true);

  /// What [nextPlaylist] and [previousPlaylist] answer.
  bool hasOtherPlaylist = false;

  @override
  PlayerStream get stream => _queueStream;

  List<Media> get items => state.playlist.items;

  void _set(List<Media> items, int index) => emit(
    (s) =>
        s.copyWith(playlist: Playlist(List.unmodifiable(items), index: index)),
  );

  @override
  Future<void> open(Media media, {bool? play}) async {
    calls.add('open ${media.uri} play=$play');
    _set([media], 0);
    if (play ?? false) emit((s) => s.copyWith(playWhenReady: true));
  }

  @override
  Future<void> openAll(List<Media> medias, {bool? play, int index = 0}) async {
    calls.add('openAll ${medias.length} play=$play');
    _set(medias, index);
    if (play ?? false) emit((s) => s.copyWith(playWhenReady: true));
  }

  @override
  Future<void> openPlaylistFile(Media playlist, {bool? play}) async {
    calls.add('openPlaylistFile ${playlist.uri} play=$play');
    if (play ?? false) emit((s) => s.copyWith(playWhenReady: true));
  }

  @override
  Future<void> add(Media media) async {
    calls.add('add ${media.uri}');
    final index = state.playlist.index < 0 && items.isEmpty
        ? -1
        : state.playlist.index;
    _set([...items, media], index);
  }

  @override
  Future<void> remove(int index) async {
    if (index < 0 || index >= items.length) {
      throw RangeError.index(index, items, 'index');
    }
    calls.add('remove $index');
    final next = [...items]..removeAt(index);
    var current = state.playlist.index;
    if (index < current) current--;
    if (current >= next.length) current = next.length - 1;
    _set(next, current);
  }

  @override
  Future<void> move(int from, int to) async {
    calls.add('move $from $to');
    final current = state.playlist.index >= 0
        ? items[state.playlist.index]
        : null;
    final next = [...items];
    final m = next.removeAt(from);
    next.insert(to > from ? to - 1 : to, m);
    _set(next, current == null ? -1 : next.indexOf(current));
  }

  @override
  Future<void> jump(int index) async {
    if (index < 0 || index >= items.length) {
      throw RangeError.index(index, items, 'index');
    }
    calls.add('jump $index');
    _set(items, index);
    emit((s) => s.copyWith(playWhenReady: true));
  }

  @override
  Future<void> replace(int index, Media media) async {
    calls.add('replace $index ${media.uri}');
    _set([...items]..[index] = media, state.playlist.index);
  }

  @override
  Future<void> clearPlaylist() async {
    calls.add('clearPlaylist');
    _set(const [], -1);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    emit((s) => s.copyWith(playWhenReady: false));
  }

  @override
  Future<bool> next({bool force = false}) async {
    calls.add('next force=$force');
    final i = state.playlist.index;
    if (i + 1 >= items.length) return false;
    _set(items, i + 1);
    return true;
  }

  @override
  Future<bool> previous({bool force = false}) async {
    calls.add('previous force=$force');
    final i = state.playlist.index;
    if (i <= 0) return false;
    _set(items, i - 1);
    return true;
  }

  @override
  Future<bool> nextPlaylist() async {
    calls.add('nextPlaylist');
    return hasOtherPlaylist;
  }

  @override
  Future<bool> previousPlaylist() async {
    calls.add('previousPlaylist');
    return hasOtherPlaylist;
  }

  /// Raw commands sent, as their joined arguments.
  final List<List<String>> rawCommands = [];

  /// What [getRawProperty] answers, by name.
  final Map<String, String> rawProperties = {};

  /// What [getRawPropertyNode] answers, by name.
  final Map<String, Object?> nodes = {};

  @override
  Future<void> sendRawCommand(List<String> args) async {
    rawCommands.add(args);
    calls.add('raw ${args.join(' ')}');
  }

  @override
  Future<String?> getRawProperty(String name) async => rawProperties[name];

  @override
  Future<Object?> getRawPropertyNode(String name) async => nodes[name];

  @override
  Future<void> setRawProperty(String name, String value) async {
    calls.add('setRaw $name $value');
    rawProperties[name] = value;
  }

  final hooks = StreamController<MpvHookEvent>.broadcast(sync: true);
  final log = StreamController<MpvLogEntry>.broadcast(sync: true);
  final List<Hook> registeredHooks = [];
  final List<int> continuedHooks = [];

  /// The timeout of each registered hook.
  final Map<Hook, Duration?> hookTimeouts = {};

  /// Hooks whose registration throws.
  final Set<Hook> failingHooks = {};

  @override
  Future<void> registerHook(
    Hook hook, {
    int priority = 0,
    Duration? timeout,
  }) async {
    if (failingHooks.contains(hook)) {
      throw const MpvCommandException(
        name: 'hook_add',
        code: -12,
        message: 'refused',
      );
    }
    registeredHooks.add(hook);
    hookTimeouts[hook] = timeout;
  }

  @override
  Future<void> continueHook(int id) async => continuedHooks.add(id);

  LogLevel? logLevel;

  @override
  void setLogLevel(LogLevel level) => logLevel = level;

  /// A [QueueDetails] on this player's streams.
  QueueDetails details() => QueueDetails.of(this);
}

class QueueFakeStream extends FakePlayerStream {
  QueueFakeStream(this._q) : super(_q);

  final QueueFakePlayer _q;

  @override
  Stream<String> get playlistPath => _q.watch((p) => p.state.playlistPath);
  @override
  Stream<MpvFileEndedEvent> get endFile => _q.endFile.stream;
  @override
  Stream<PlayerError> get error => _q.errors.stream;
  @override
  Stream<void> get seekCompleted => _q.loaded.stream;
  @override
  Stream<MpvHookEvent> get hook => _q.hooks.stream;
  @override
  Stream<MpvLogEntry> get log => _q.log.stream;
  @override
  Stream<MpvLogEntry> get internalLog => const Stream.empty();
}
