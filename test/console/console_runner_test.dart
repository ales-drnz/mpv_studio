import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/console/console_runner.dart';
import 'package:mpv_studio/features/console/hook_monitor.dart';

import '../queue/queue_fake.dart';

const _a = Media('/a.flac');
const _b = Media('/b.flac');

void main() {
  late QueueFakePlayer player;
  late ConsoleRunner runner;

  setUp(() {
    player = QueueFakePlayer();
    runner = ConsoleRunner(player);
  });

  Future<List<String>> run(String line) async => [
    for (final r in await runner.run(line)) '${r.kind.name}: ${r.text}',
  ];

  group('transport commands go through the Player API', () {
    test('loadfile replace opens and plays', () async {
      expect(await run('loadfile https://x.test/a.mp3'), [
        'routed: via Player.open(play: true)',
      ]);
      expect(player.calls.last, 'open https://x.test/a.mp3 play=true');
      expect(player.state.playWhenReady, isTrue);
      expect(player.rawCommands, isEmpty);
    });

    test('loadfile append-play on an idle player plays the entry', () async {
      expect(await run('loadfile "/m/a b.flac" append-play'), [
        'routed: via Player.add(), Player.jump(0)',
      ]);
      expect(player.items.single.uri, '/m/a b.flac');
      expect(player.state.playWhenReady, isTrue);
    });

    test('loadfile append-play while playing only appends', () async {
      player.emit((s) => s.copyWith(playlist: const Playlist([_a], index: 0)));
      expect(await run('loadfile /b.flac append-play'), [
        'routed: via Player.add()',
      ]);
      expect(player.items.map((m) => m.uri), ['/a.flac', '/b.flac']);
    });

    test('loadfile insert-next and insert-at place the entry', () async {
      player.emit(
        (s) => s.copyWith(playlist: const Playlist([_a, _b], index: 0)),
      );
      await run('loadfile /c.flac insert-next');
      expect(player.items.map((m) => m.uri), ['/a.flac', '/c.flac', '/b.flac']);
      await run('loadfile /d.flac insert-at 0');
      expect(player.items.first.uri, '/d.flac');
      expect(await run('loadfile /e.flac insert-at'), [
        'error: insert-at needs an index',
      ]);
    });

    test('loadfile with options goes raw and syncs the intent', () async {
      expect(await run('loadfile /a.flac replace -1 start=10'), [
        'routed: via raw loadfile (with options), then Player.play()',
      ]);
      expect(player.rawCommands.single, [
        'loadfile',
        '/a.flac',
        'replace',
        '-1',
        'start=10',
      ]);
      expect(player.state.playWhenReady, isTrue);
    });

    test('loadlist replace opens the playlist file', () async {
      expect(await run('loadlist /l.m3u'), [
        'routed: via Player.openPlaylistFile(play: true)',
      ]);
      expect(await run('loadlist /l.m3u append-play'), [
        'routed: via raw loadlist, then Player.play()',
      ]);
    });

    test('pause, cycle pause and set pause', () async {
      await run('set pause no');
      expect(player.calls.last, 'play');
      await run('cycle pause');
      expect(player.calls.last, 'pause');
      await run('no-osd cycle pause');
      expect(player.calls.last, 'play');
      await run('pause');
      expect(player.calls.last, 'pause');
      expect(await run('set pause maybe'), [
        'error: pause takes yes, no or toggle',
      ]);
      expect(player.rawCommands, isEmpty);
    });

    test('stop and playlist navigation report the answer', () async {
      player.emit(
        (s) => s.copyWith(playlist: const Playlist([_a, _b], index: 1)),
      );
      expect(await run('playlist-next'), [
        'routed: via Player.next(force: false)',
        'output: No next entry',
      ]);
      expect(await run('playlist-prev'), [
        'routed: via Player.previous(force: false)',
      ]);
      expect(await run('playlist-play-index 1'), [
        'routed: via Player.jump(1)',
      ]);
      expect(await run('playlist-play-index none'), [
        'routed: via Player.stop()',
      ]);
      expect(await run('stop'), ['routed: via Player.stop()']);
      expect(await run('playlist-next-playlist'), [
        'routed: via Player.nextPlaylist()',
        'output: No next playlist',
      ]);
      expect(await run('playlist-play-index 9'), [startsWith('error:')]);
    });
  });

  group('other commands go raw', () {
    test('quoted arguments stay whole', () async {
      expect(await run('print-text "a b"'), ['output: ok']);
      expect(player.rawCommands.single, ['print-text', 'a b']);
    });

    test(r'print-text expands ${property}', () async {
      expect(await run(r'print-text "paused: ${pause}"'), [
        r'output: ok (sent as expand-properties print-text "paused: ${pause}")',
      ]);
      await run(r'raw print-text ${pause}');
      expect(player.rawCommands.last, ['raw', 'print-text', r'${pause}']);
      await run('seek 30');
      expect(player.rawCommands.last, ['seek', '30']);
    });

    test('an unterminated quote is reported, nothing is sent', () async {
      expect(await run('print-text "a'), ['error: Unterminated double quote']);
      expect(player.rawCommands, isEmpty);
    });
  });

  test('get, getnode and set', () async {
    player.rawProperties['volume'] = '80';
    player.nodes['track-list'] = [
      {'id': 1, 'type': 'audio'},
    ];
    expect(await run('get volume'), ['output: volume = 80']);
    expect(await run('get nothing'), ['output: nothing = <null>']);
    final node = await run('getnode track-list');
    expect(node.single, contains('"type": "audio"'));
    expect(await run('set volume "50"'), ['output: volume = 50']);
    expect(player.calls.last, 'setRaw volume 50');
  });

  test('help explains routing and quoting', () async {
    final help = (await run('help')).join('\n');
    expect(help, contains('Player API'));
    expect(help, contains('expand-properties'));
    expect(help, contains('"a b"'));
  });

  test('hooks on registers every hook and continues each event', () async {
    final events = <MpvHookEvent>[];
    expect((await run('hooks on')).single, startsWith('output: Reporting'));
    expect(player.registeredHooks, Hook.values);
    final sub = HookMonitor.of(player).events.listen(events.add);
    player.hooks.add(const MpvHookEvent(7, Hook.load));
    await pumpEventQueue();
    expect(player.continuedHooks, [7]);
    expect(events.single.hook, Hook.load);
    await run('hooks off');
    player.hooks.add(const MpvHookEvent(8, Hook.unload));
    await pumpEventQueue();
    expect(player.continuedHooks, [7, 8]);
    expect(events, hasLength(1));
    await sub.cancel();
  });
}
