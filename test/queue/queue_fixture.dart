import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/queue/queue_details.dart';
import 'package:mpv_studio/features/queue/queue_page.dart';
import 'package:mpv_studio/studio/playback_issues.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../support/layout_harness.dart';
import 'queue_fake.dart';

const localSong = Media(
  '/music/Bill Evans/Peace Piece.flac',
  extras: {'title': 'Peace Piece'},
);
const webSong = Media('https://music.example.test/kind-of-blue/so-what.mp3');
const serverSong = Media(
  'https://jf.example.test/Audio/42/stream?api_key=secret',
  extras: {
    'title': 'Blue in Green',
    'artist': 'Bill Evans Trio',
    'server': 'jellyfin',
    'durationMs': 337000,
  },
);

/// A queue of three: a local file, the current web stream (tagged) and a
/// server track whose last play failed. [settle] lets the streams deliver
/// (`tester.pump` in a widget test).
Future<(QueueFakePlayer, QueueDetails)> threeEntries(
  Future<void> Function() settle,
) async {
  final player = QueueFakePlayer(
    const PlayerState(
      playlist: Playlist([localSong, webSong, serverSong], index: 2),
    ),
  );
  final details = player.details();
  addTearDown(details.dispose);
  await settle();
  player.endFile.add(
    const MpvFileEndedEvent(
      reason: MpvEndFileReason.error,
      error: MpvError.mpvErrorLoadingFailed,
    ),
  );
  player.emit(
    (s) => s.copyWith(
      playlist: const Playlist([localSong, webSong, serverSong], index: 1),
      metadata: const {
        'title': 'So What',
        'artist': 'Miles Davis',
        'album': 'Kind of Blue',
      },
      duration: const Duration(minutes: 9, seconds: 22),
    ),
  );
  await settle();
  player.loaded.add(null);
  await settle();
  return (player, details);
}

/// An empty queue.
(QueueFakePlayer, QueueDetails) emptyQueue() {
  final player = QueueFakePlayer();
  final details = player.details();
  addTearDown(details.dispose);
  return (player, details);
}

/// Pumps the Queue on [player] inside a Scaffold (for the toasts).
Future<void> pumpQueue(
  WidgetTester tester,
  QueueFakePlayer player,
  QueueDetails details, {
  Size size = const Size(1440, 900),
  InputMode input = InputMode.pointer,
  Palette palette = Palette.dark,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  List<String> picked = const [],
}) async {
  await pumpStudio(
    tester,
    Scaffold(
      body: QueueView(
        player: player,
        guard: unguarded,
        details: details,
        pickFiles: () async => picked,
        pickFolder: () async => picked,
        pickPlaylist: () async => picked.isEmpty ? null : picked.first,
      ),
    ),
    size: size,
    input: input,
    palette: palette,
    textScale: textScale,
    padding: padding,
  );
}
