import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/studio/playback_issues.dart';

class _Harness {
  final errors = StreamController<PlayerError>.broadcast();
  final endFile = StreamController<MpvFileEndedEvent>.broadcast();
  final playlist = StreamController<Playlist>.broadcast();
  final loaded = StreamController<void>.broadcast();
  late final issues = PlaybackIssues(
    errors: errors.stream,
    endFile: endFile.stream,
    playlist: playlist.stream,
    loaded: loaded.stream,
  );
  final notices = <PlaybackNotice>[];

  _Harness() {
    issues.notices.listen(notices.add);
  }

  /// mpv's order for a failed load: the end of the file, then its error.
  Future<void> fail(int code) async {
    endFile.add(MpvFileEndedEvent(reason: MpvEndFileReason.error, error: code));
    errors.add(
      EndFileError(
        reason: MpvEndFileReason.error,
        code: code,
        message: 'loading failed',
      ),
    );
    await pumpEventQueue();
  }

  Future<void> logError() async {
    errors.add(
      const LogError(
        prefix: 'ffmpeg',
        level: LogLevel.error,
        text: 'Invalid data found when processing input',
      ),
    );
    await pumpEventQueue();
  }

  void dispose() => issues.dispose();
}

const _a = Media('/music/a.flac', extras: {'title': 'Alpha'});
const _b = Media('/music/b.flac', extras: {'title': 'Beta'});

void main() {
  late _Harness h;
  setUp(() => h = _Harness());
  tearDown(() => h.dispose());

  test('a failed load becomes one readable notice naming the track', () async {
    h.playlist.add(const Playlist([_a, _b], index: 1));
    await pumpEventQueue();
    await h.fail(MpvError.mpvErrorLoadingFailed);
    expect(h.notices.map((n) => n.message), [
      'Could not open "Beta". Check the file or the connection.',
    ]);
  });

  test('log errors raise the badge instead of a toast', () async {
    await h.logError();
    await h.logError();
    expect(h.notices, isEmpty);
    expect(h.issues.unseenLogErrors.value, 2);

    h.issues.consoleVisible = true;
    expect(h.issues.unseenLogErrors.value, 0);
    await h.logError();
    expect(h.issues.unseenLogErrors.value, 0);

    h.issues.consoleVisible = false;
    await h.logError();
    expect(h.issues.unseenLogErrors.value, 1);
  });

  test(
    'the failed entry is marked until it loads or leaves the queue',
    () async {
      h.playlist.add(const Playlist([_a, _b], index: 0));
      await pumpEventQueue();
      await h.fail(MpvError.mpvErrorLoadingFailed);
      expect(h.issues.failed.value, {_a});

      // mpv moves on; the next entry loads fine, the mark stays on _a.
      h.playlist.add(const Playlist([_a, _b], index: 1));
      h.loaded.add(null);
      await pumpEventQueue();
      expect(h.issues.failed.value, {_a});

      // Back on _a, and this time it loads.
      h.playlist.add(const Playlist([_a, _b], index: 0));
      h.loaded.add(null);
      await pumpEventQueue();
      expect(h.issues.failed.value, isEmpty);

      await h.fail(MpvError.mpvErrorLoadingFailed);
      expect(h.issues.failed.value, {_a});
      h.playlist.add(const Playlist([_b], index: 0));
      await pumpEventQueue();
      expect(h.issues.failed.value, isEmpty);
    },
  );

  test('guard turns thrown player errors into notices', () async {
    final r1 = await h.issues.guard<Object?>(
      () => throw const MpvCommandException(
        name: 'seek',
        code: -12,
        message: 'property unavailable',
      ),
    );
    final r2 = await h.issues.guard<Object?>(
      () => throw RangeError.index(5, const [1], 'index'),
    );
    final r3 = await h.issues.guard<Object?>(
      () => throw const PlayerDisposedException(),
    );
    final ok = await h.issues.guard(() async => 42);
    await pumpEventQueue();
    expect(r1, isNull);
    expect(r2, isNull);
    expect(r3, isNull);
    expect(ok, 42);
    expect(h.notices.map((n) => n.message), [
      'mpv refused "seek": property unavailable.',
      'That queue entry is no longer there.',
    ]);
  });

  test('guard lets programming errors through', () async {
    expect(
      h.issues.guard<Object?>(() => throw ArgumentError('bad')),
      throwsArgumentError,
    );
  });

  group('describeEndFileError', () {
    EndFileError err(int code) => EndFileError(
      reason: MpvEndFileReason.error,
      code: code,
      message: 'mpv says no',
    );

    test('names the kind of failure', () {
      expect(
        describeEndFileError(
          err(MpvError.mpvErrorUnknownFormat),
          title: 'Song',
        ),
        'Could not play "Song": no playable audio found.',
      );
      expect(
        describeEndFileError(err(MpvError.mpvErrorAoInitFailed)),
        'The audio device could not be opened.',
      );
      expect(
        describeEndFileError(err(MpvError.mpvErrorLoadingFailed)),
        'Could not open the track. Check the file or the connection.',
      );
      expect(
        describeEndFileError(err(-999), title: 'Song'),
        'Playback of "Song" stopped: mpv says no.',
      );
    });
  });

  test('a source error never shows the full URI', () {
    final text = describeCallError(
      const SourceException(
        'smb2://user:secret@nas/share/My%20Song.flac',
        'unreadable',
      ),
    );
    expect(text, 'Could not open "My Song.flac": unreadable.');
    expect(text, isNot(contains('secret')));
  });
}
