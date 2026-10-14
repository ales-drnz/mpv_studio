import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/settings/settings_scope.dart';
import 'package:mpv_studio/studio/app_settings.dart';
import 'package:mpv_studio/studio/loudness_normalizer.dart';
import 'package:mpv_studio/studio/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_player.dart';

/// A [FakePlayer] that accepts every call: setters are recorded in
/// [calls] as `name args name=value` and succeed, unless their name is in [refuse]
/// (they then throw an [MpvCommandException]). Streams it does not wire
/// stay silent, so widgets show the [state] they start from.
class StudioFakePlayer extends FakePlayer {
  StudioFakePlayer({
    PlayerState? initial,
    this.configuration = const PlayerConfiguration(),
  }) : super(initial);

  @override
  final PlayerConfiguration configuration;

  /// Member names whose call throws.
  final Set<String> refuse = {};

  /// mpv restarting playback (an entry opened), for `stream.seekCompleted`.
  final opened = StreamController<void>.broadcast(sync: true);

  /// The ends of entries, for `stream.endFile`.
  final ended = StreamController<MpvFileEndedEvent>.broadcast(sync: true);

  /// What `getRawProperty` answers, by name (null when absent). Reads
  /// are not recorded in [calls].
  final Map<String, String> rawProperties = {};

  @override
  late final PlayerStream stream = _StudioFakeStream(this);

  @override
  Future<String?> getRawProperty(String name) async => rawProperties[name];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = _name(invocation.memberName);
    calls.add(
      [
        name,
        ...invocation.positionalArguments.map((a) => '$a'),
        for (final e in invocation.namedArguments.entries)
          '${_name(e.key)}=${e.value}',
      ].join(' '),
    );
    if (refuse.contains(name)) {
      return Future<void>.error(
        MpvCommandException(name: name, code: -12, message: 'refused'),
      );
    }
    return Future<void>.value();
  }
}

class _StudioFakeStream extends FakePlayerStream {
  _StudioFakeStream(this._player) : super(_player);
  final StudioFakePlayer _player;

  @override
  Stream<void> get seekCompleted => _player.opened.stream;

  @override
  Stream<MpvFileEndedEvent> get endFile => _player.ended.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => const Stream<Never>.empty();
}

String _name(Symbol s) {
  final t = s.toString(); // Symbol("name")
  return t.substring(8, t.length - 2);
}

/// Fresh [AppSettings] on mock preferences holding [stored] (a settings
/// blob, as MPV Studio wrote it).
Future<AppSettings> loadSettings([Map<String, Object?>? stored]) async {
  SharedPreferences.setMockInitialValues({
    if (stored != null) SettingsStore.key: jsonEncode(stored),
  });
  return AppSettings.load();
}

/// The Settings services on fakes, with every notice collected.
class SettingsHarness {
  SettingsHarness._(this.player, this.settings, this.normalizer);

  static Future<SettingsHarness> create({
    Map<String, Object?>? stored,
    PlayerConfiguration configuration = const PlayerConfiguration(),
  }) async {
    final settings = await loadSettings(stored);
    final player = StudioFakePlayer(configuration: configuration);
    final normalizer = LoudnessNormalizer(player, settings)..restore();
    final h = SettingsHarness._(player, settings, normalizer);
    addTearDown(normalizer.dispose);
    return h;
  }

  final StudioFakePlayer player;
  final AppSettings settings;
  final LoudnessNormalizer normalizer;
  final List<Object> failures = [];
  int restarts = 0;
  int welcomes = 0;

  Future<T?> guard<T>(FutureOr<T> Function() call) async {
    try {
      return await call();
    } on Object catch (e) {
      failures.add(e);
      return null;
    }
  }

  /// [child] under a [SettingsScope] of these fakes.
  Widget wrap(Widget child) => SettingsScope(
    player: player,
    settings: settings,
    normalizer: normalizer,
    guard: guard,
    restart: () async => restarts++,
    showWelcome: (_) => welcomes++,
    child: child,
  );
}
