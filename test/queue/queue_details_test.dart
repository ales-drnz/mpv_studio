import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/queue/queue_details.dart';
import 'package:mpv_studio/util/media_labels.dart';

const _url = Media('https://radio.example.com/live/Night%20Radio.mp3');
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
  final endFile = StreamController<MpvFileEndedEvent>.broadcast();
  final errors = StreamController<PlayerError>.broadcast();
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
      endFile: endFile.stream,
      errors: errors.stream,
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

  Future<void> end(MpvEndFileReason reason, {int error = 0}) async {
    endFile.add(MpvFileEndedEvent(reason: reason, error: error));
    await pumpEventQueue();
  }

  EntryOutcome? outcome(Media m) => details.outcomes.value[m];

  QueueRowInfo row(Media m) => QueueRowInfo.of(m, details.details.value[m]);
}

void main() {
  late _Harness h;
  setUp(() => h = _Harness());
  tearDown(() => h.details.dispose());

  test('before loading, a URL is named after its last path segment', () {
    final row = h.row(_url);
    expect(row.title, 'Night Radio.mp3');
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
    h.mediaTitle = 'Night Radio.mp3'; // mpv's file name fallback: ignored
    await h.load();
    expect(h.row(_url).title, 'Night Radio.mp3');

    // A radio stream announcing its song.
    h.mediaTitle = 'Juniper Avenue, Departures';
    h.metadataChanged.add(null);
    await pumpEventQueue();
    expect(h.row(_url).title, 'Juniper Avenue, Departures');
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

  group('one labelling path for every row', () {
    // The Stream page queues a URL with a placeholder artist; a playlist
    // file or the Console queues the same source bare.
    const placeholder = Media(
      'https://radio.example.com/live/a.mp3',
      extras: {'artist': 'Stream'},
    );
    const bare = Media('https://radio.example.com/live/b.mp3');

    test('the same HTTP source reads "Web stream" on every row', () async {
      await h.play([placeholder, bare], 0);
      h.metadata = {'title': 'Departures', 'artist': 'Juniper Avenue'};
      await h.load();
      expect(h.row(placeholder).origin.label, 'Web stream');
      expect(h.row(bare).origin.label, 'Web stream');
      expect(h.row(placeholder).subtitle, 'Juniper Avenue · Web stream');
      expect(h.row(bare).subtitle, 'Web stream');
    });

    test('the tagged artist wins over the extras on the current row', () async {
      // The current row showed the placeholder, the mini-player the tag.
      await h.play([placeholder, bare], 0);
      h.metadata = {'ARTIST': 'Juniper Avenue', 'Album': 'Night Ferry'};
      await h.load();
      final row = h.row(placeholder);
      expect(row.artist, 'Juniper Avenue');
      expect(row.album, 'Night Ferry');
    });

    test('tags show on the row as soon as they change', () async {
      await h.play([bare], 0);
      await h.load();
      expect(h.row(bare).artist, isNull);
      h.metadata = {'artist': 'Late tag'};
      h.metadataChanged.add(null);
      await pumpEventQueue();
      expect(h.row(bare).artist, 'Late tag');
    });
  });

  group('outcomes', () {
    test('a track that plays to its end is played', () async {
      await h.play([_song, _url], 0);
      await h.load();
      expect(h.outcome(_song), isNull);
      // mpv may move the queue on before it reports the end.
      await h.play([_song, _url], 1);
      await h.end(MpvEndFileReason.eof);
      expect(h.outcome(_song)?.end, EntryEnd.ended);
      expect(h.outcome(_url), isNull);
    });

    test('a track left early is skipped', () async {
      await h.play([_song, _url], 0);
      await h.load();
      await h.play([_song, _url], 1);
      await h.end(MpvEndFileReason.stop);
      expect(h.outcome(_song)?.end, EntryEnd.stopped);
      expect(h.outcome(_song)?.reason, 'Skipped');
    });

    test('a track that cannot open fails with the reason', () async {
      await h.play([_song, _url], 1);
      await h.end(
        MpvEndFileReason.error,
        error: MpvError.mpvErrorLoadingFailed,
      );
      h.errors.add(
        const EndFileError(
          reason: MpvEndFileReason.error,
          code: MpvError.mpvErrorLoadingFailed,
          message: 'loading failed',
        ),
      );
      await pumpEventQueue();
      final o = h.outcome(_url)!;
      expect(o.end, EntryEnd.failed);
      expect(o.message, 'loading failed');
      expect(o.reason, 'Could not open the file or stream');
    });

    test('playing again clears the outcome', () async {
      await h.play([_song], 0);
      await h.end(MpvEndFileReason.error, error: -17);
      expect(h.outcome(_song)?.reason, 'No playable audio found');
      await h.load();
      expect(h.outcome(_song), isNull);
    });

    test('quit and redirect are not outcomes', () async {
      await h.play([_song], 0);
      await h.load();
      await h.end(MpvEndFileReason.redirect);
      await h.end(MpvEndFileReason.quit);
      expect(h.details.outcomes.value, isEmpty);
    });
  });
}
