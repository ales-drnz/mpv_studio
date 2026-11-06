import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/queue/queue_controller.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

import 'queue_fake.dart';

void main() {
  late QueueFakePlayer player;
  late List<String> notices;

  setUp(() {
    player = QueueFakePlayer();
    notices = [];
  });

  QueueController queueWith({
    FolderPicker? pickFolder,
    FolderScanner? scanFolder,
    PathPicker? pickFiles,
  }) {
    final queue = QueueController(
      player: player,
      guard: unguarded,
      pickFiles: pickFiles ?? () async => const [],
      pickFolder: pickFolder ?? () async => '/music',
      scanFolder: scanFolder ?? (_) async => const [],
      notify: notices.add,
    );
    addTearDown(queue.dispose);
    return queue;
  }

  test('a folder without audio says so', () async {
    await queueWith().addFolder();
    expect(notices, ['No audio files in this folder']);
  });

  test('a cancelled folder picker says nothing', () async {
    await queueWith(pickFolder: () async => null).addFolder();
    expect(notices, isEmpty);
  });

  test('the scan is shown while it runs', () async {
    final scan = Completer<List<String>>();
    final queue = queueWith(scanFolder: (_) => scan.future);
    final adding = queue.addFolder();
    await Future<void>.delayed(Duration.zero);
    expect(queue.looking.value, isTrue);
    scan.complete(['/music/a.flac']);
    await adding;
    expect(queue.looking.value, isFalse);
    expect(player.items.single.uri, '/music/a.flac');
  });

  test('a picker that fails says so', () async {
    await queueWith(
      pickFiles: () async =>
          throw PlatformException(code: 'busy', message: 'Picker busy'),
    ).addFiles();
    expect(notices, ['Could not open the file picker: Picker busy']);
  });

  group('a drop', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('studio_drop'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('of a playlist points to Load playlist', () async {
      final list = File('${dir.path}/mix.m3u')..writeAsStringSync('a.flac');
      await queueWith().addDropped([list.path]);
      expect(notices, ['Playlists open with Load playlist']);
    });

    test('of nothing playable says so', () async {
      final note = File('${dir.path}/notes.txt')..writeAsStringSync('hi');
      await queueWith().addDropped([note.path]);
      expect(notices, ['No audio files in what was dropped']);
    });

    test('of a folder scans it', () async {
      Directory('${dir.path}/cd1').createSync();
      File('${dir.path}/cd1/b.flac').writeAsStringSync('');
      File('${dir.path}/a.mp3').writeAsStringSync('');
      await queueWith().addDropped([dir.path]);
      expect(player.items.map((m) => m.uri), [
        '${dir.path}/a.mp3',
        '${dir.path}/cd1/b.flac',
      ]);
      expect(notices, isEmpty);
    });

    test('on a queue says what it added', () async {
      player = QueueFakePlayer(
        const PlayerState(playlist: Playlist([Media('/x.flac')], index: 0)),
      );
      File('${dir.path}/a.mp3').writeAsStringSync('');
      File('${dir.path}/b.mp3').writeAsStringSync('');
      await queueWith().addDropped([dir.path]);
      expect(player.items, hasLength(3));
      expect(notices, ['2 tracks added to the queue']);
    });
  });
}
