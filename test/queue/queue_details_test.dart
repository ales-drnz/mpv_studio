import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/queue/queue_details.dart';
import 'package:mpv_studio/util/media_labels.dart';

const _url = Media('https://radio.example.com/live/Jazz%20FM.mp3');
const _song = Media('/music/a.flac', extras: {'title': 'From extras'});
const _server = Media(
  'plex-transcode://mpv-1',
  extras: {
    'title': 'Server title',
    'artist': 'Server artist',
    'server': 'plex',
    'durationMs': 125000,
    'art': 'https://pms/art.jpg',
  },
);

class _Harness {
  final playlist = StreamController<Playlist>.broadcast();
  final loaded = StreamController<void>.broadcast();
  final metadataChanged = StreamController<Object?>.broadcast();
  Map<String, String> metadata = const {};
  String mediaTitle = '';
  Duration duration = Duration.zero;

  late final QueueDetails details;

  _Harness() {
    details = QueueDetails(
      playlist: playlist.stream,
      loaded: loaded.stream,
      changes: [metadataChanged.stream],
      snapshot: () =>
          (metadata: metadata, mediaTitle: mediaTitle, duration: duration),
    );
  }

  Future<void> play(List<Media> items, int index) async {
    playlist.add(Playlist(items, index: index));
    await pumpEventQueue();
  }

  Future<void> load() async {
    loaded.add(null);
    await pumpEventQueue();
  }

  QueueRowInfo row(Media m) => QueueRowInfo.of(m, details.details.value[m]);
}

void main() {
  late _Harness h;
  setUp(() => h = _Harness());
  tearDown(() => h.details.dispose());

  test('before loading, a URL is named after its last path segment', () {
    final row = h.row(_url);
    expect(row.title, 'Jazz FM.mp3');
    expect(row.artist, isNull);
    expect(row.origin, MediaOrigin.http);
    expect(row.duration, isNull);
  });

  test('server rows use their extras', () {
    final row = h.row(_server);
    expect(row.title, 'Server title');
    expect(row.artist, 'Server artist');
    expect(row.origin, MediaOrigin.plex);
    expect(row.duration, const Duration(seconds: 125));
    expect(row.artUrl, 'https://pms/art.jpg');
  });

  test('the tags replace the extras title once the track loads', () async {
    await h.play([_song, _url], 0);
    h.metadata = {'TITLE': 'Tagged', 'Artist': 'Someone'};
    h.duration = const Duration(minutes: 3);
    await h.load();
    final row = h.row(_song);
    expect(row.title, 'Tagged');
    expect(row.artist, 'Someone');
    expect(row.duration, const Duration(minutes: 3));
  });

  test('the media title names a stream without tags', () async {
    await h.play([_song, _url], 1);
    h.mediaTitle = 'Jazz FM.mp3'; // mpv's file name fallback: ignored
    await h.load();
    expect(h.row(_url).title, 'Jazz FM.mp3');

    // A radio stream announcing its song.
    h.mediaTitle = 'Miles Davis, So What';
    h.metadataChanged.add(null);
    await pumpEventQueue();
    expect(h.row(_url).title, 'Miles Davis, So What');
  });

  test('state left over from the previous track is not recorded', () async {
    await h.play([_song, _url], 0);
    h.metadata = {'title': 'Song A'};
    await h.load();

    // The queue moves on; the old tags are still in the state until the
    // next track loads, and a change event arrives in between.
    await h.play([_song, _url], 1);
    h.metadataChanged.add(null);
    await pumpEventQueue();
    expect(h.details.details.value.containsKey(_url), isFalse);
    expect(h.row(_song).title, 'Song A');
  });

  test('entries that leave the queue are forgotten', () async {
    await h.play([_song], 0);
    h.metadata = {'title': 'Song A'};
    await h.load();
    expect(h.details.details.value.keys, [_song]);
    await h.play([_url], 0);
    expect(h.details.details.value, isEmpty);
  });
}
