import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/console/console_log.dart';
import 'package:mpv_studio/features/console/console_page.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../queue/queue_fake.dart';
import '../support/layout_harness.dart';

/// A player whose log already holds a few lines of every level.
QueueFakePlayer consolePlayer() {
  final player = QueueFakePlayer();
  player.rawProperties['property-list'] = 'volume,pause,playlist-pos';
  player.rawProperties['options'] = 'volume,audio-device';
  player.rawProperties['option-info/mute/type'] = 'Flag';
  return player;
}

ConsoleLog consoleLog(QueueFakePlayer player) {
  final log = ConsoleLog()..attach(player);
  addTearDown(log.dispose);
  const lines = [
    (
      LogLevel.info,
      'cplayer',
      'mpv v0.41.0 Copyright 2000-2025 mpv/MPlayer/mplayer2 projects',
    ),
    (LogLevel.info, 'ao', 'Audio device: pipewire'),
    (LogLevel.warn, 'ffmpeg', 'mp3float: Header missing'),
    (LogLevel.error, 'stream', 'Failed to open https://example.test/gone.mp3.'),
    (LogLevel.v, 'demux', 'Detected file format: mp3'),
    (LogLevel.info, 'mpv_audio_kit', 'resolver: kept the URL'),
  ];
  for (final (level, prefix, text) in lines) {
    player.log.add(MpvLogEntry(prefix: prefix, level: level, text: text));
  }
  return log;
}

Future<void> pumpConsole(
  WidgetTester tester,
  QueueFakePlayer player,
  ConsoleLog log, {
  Size size = const Size(1440, 900),
  InputMode input = InputMode.pointer,
  Palette palette = Palette.dark,
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  await pumpStudio(
    tester,
    Scaffold(
      body: ConsoleView(player: player, log: log),
    ),
    size: size,
    input: input,
    palette: palette,
    textScale: textScale,
    padding: padding,
  );
}
