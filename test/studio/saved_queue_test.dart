import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/studio/app_settings.dart';
import 'package:mpv_studio/studio/saved_queue.dart';
import 'package:mpv_studio/studio/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../queue/queue_fake.dart';

const _file = Media('/music/Kveld.flac', extras: {'title': 'Kveld'});
const _radio = Media(
  'https://radio.test/live',
  extras: {'title': 'Night', 'durationMs': 0},
  httpHeaders: {'Icy-MetaData': '1'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the queue is kept and comes back paused on the same entry', () async {
    final settings = await AppSettings.load();
    final player = QueueFakePlayer();
    settings.watchQueue(player);
    player.emit(
      (s) => s.copyWith(playlist: const Playlist([_file, _radio], index: 1)),
    );
    await pumpEventQueue();
    await settings.dispose();

    final again = await AppSettings.load();
    final next = QueueFakePlayer();
    await again.restoreQueue(next);
    expect(next.items, [_file, _radio]);
    expect(next.state.playback.playlist.index, 1);
    expect(next.state.playback.playWhenReady, isFalse);
    await again.dispose();
  });

  test('entries with secrets in the address or live sources stay out', () {
    final kept = encodeQueue(
      const Playlist([
        Media('smb://anna:secret@nas/music/a.flac'),
        Media('mak-pcm://4'),
        Media('blob:https://studio.test/abc'),
        _file,
      ], index: 3),
    );
    expect(decodeQueue(kept)?.items, [_file]);
    expect(decodeQueue(kept)?.index, 0);
  });

  test('the places in the app are kept', () async {
    final settings = await AppSettings.load();
    settings
      ..recordUiValue('section', 'console')
      ..recordUiValue('sidebarCollapsed', true)
      ..recordUiValue('meterHeight', 212.0);
    await settings.dispose();
    final again = await AppSettings.load();
    expect(again.uiValue<String>('section'), 'console');
    expect(again.uiValue<bool>('sidebarCollapsed'), isTrue);
    expect(again.uiValue<double>('meterHeight'), 212.0);
    expect(again.uiValue<String>('nothing'), isNull);
    await again.dispose();
  });

  test('a save asked for now does not wait for the debounce', () async {
    final settings = await AppSettings.load();
    settings.recordUiValue('section', 'queue');
    await settings.saveNow();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SettingsStore.key), contains('"queue"'));
    await settings.dispose();
  });

  test('an entry keeps its options, not its secrets', () {
    const radio = Media(
      'https://radio.test/live',
      extras: {
        'title': 'Night',
        'cover': {'w': 300},
      },
      httpHeaders: {
        'Icy-MetaData': '1',
        'Authorization': 'Bearer secret',
        'Cookie': 'session=secret',
      },
      streamLavfOptions: {'reconnect_streamed': '1'},
      demuxerLavfOptions: {'probesize': '2048'},
      httpChunkSize: 65536,
      start: Duration(seconds: 5),
      end: Duration(minutes: 3),
      waveformDurationHint: Duration(minutes: 4),
    );
    final back = decodeQueue(
      encodeQueue(const Playlist([radio])),
    )!.items.single;
    expect(back.streamLavfOptions, {'reconnect_streamed': '1'});
    expect(back.demuxerLavfOptions, {'probesize': '2048'});
    expect(back.httpChunkSize, 65536);
    expect(back.start, const Duration(seconds: 5));
    expect(back.end, const Duration(minutes: 3));
    expect(back.waveformDurationHint, const Duration(minutes: 4));
    expect(back.extras?['cover'], {'w': 300});
    expect(back.httpHeaders, {'Icy-MetaData': '1'});
  });

  test('server tracks stay out: they carry the session', () {
    final kept = encodeQueue(
      const Playlist([
        Media(
          'https://jf.test/Audio/1/stream?ApiKey=t',
          extras: {'server': 'jellyfin'},
        ),
        Media(
          'plex-transcode://7',
          extras: {
            'plexSession': {'id': 'x'},
          },
        ),
        _file,
      ]),
    );
    expect(decodeQueue(kept)?.items, [_file]);
  });

  test('the same entry twice comes back on the copy that was current', () {
    final kept = encodeQueue(const Playlist([_file, _radio, _file], index: 2));
    expect(decodeQueue(kept)?.index, 2);
  });

  test('with Resume off the queue is not kept', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    settings.recordResumePlayback(false);
    final player = QueueFakePlayer();
    settings.watchQueue(player);
    player.emit((s) => s.copyWith(playlist: const Playlist([_file], index: 0)));
    await pumpEventQueue();
    await settings.dispose();
    final again = await AppSettings.load();
    final next = QueueFakePlayer();
    await again.restoreQueue(next);
    expect(next.items, isEmpty);
    await again.dispose();
  });
}
