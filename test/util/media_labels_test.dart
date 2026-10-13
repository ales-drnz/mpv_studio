import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/util/media_labels.dart';

void main() {
  group('nameFromUri', () {
    test('a local path gives the file name without extension', () {
      expect(nameFromUri('/music/Artist/01 Song.flac'), '01 Song');
      expect(nameFromUri(r'C:\Music\Song.mp3'), 'Song');
      expect(nameFromUri('file:///music/My%20Song.flac'), 'My Song');
    });

    test('a URL gives its last decoded path segment', () {
      expect(
        nameFromUri('https://example.com/radio/Jazz%20FM.mp3?token=abc'),
        'Jazz FM.mp3',
      );
      expect(nameFromUri('https://example.com/live/'), 'live');
    });

    test('a URL without a path gives its host, never the credentials', () {
      expect(
        nameFromUri('http://user:pw@stream.example.com:8000'),
        'stream.example.com',
      );
      expect(nameFromUri('smb2://user:pw@nas/share/a%20b.flac'), 'a b.flac');
    });
  });

  group('originOf', () {
    test('reads the server extra first', () {
      expect(
        originOf(const Media('https://jf/a', extras: {'server': 'jellyfin'})),
        MediaOrigin.jellyfin,
      );
      expect(originOf(const Media('plex-transcode://mpv-1')), MediaOrigin.plex);
      expect(
        originOf(const Media('https://pms/a', extras: {'server': 'plex'})),
        MediaOrigin.plex,
      );
    });

    test('falls back to the URI scheme', () {
      expect(originOf(const Media('/music/a.flac')), MediaOrigin.file);
      expect(originOf(const Media(r'C:\a.flac')), MediaOrigin.file);
      expect(originOf(const Media('file:///a.flac')), MediaOrigin.file);
      expect(originOf(const Media('smb2://nas/a.flac')), MediaOrigin.smb);
      expect(originOf(const Media('https://example.com/a')), MediaOrigin.http);
    });
  });

  test('titleOf prefers the title extra', () {
    expect(titleOf(const Media('/a/b.flac', extras: {'title': ' T '})), 'T');
    expect(titleOf(const Media('/a/b.flac', extras: {'title': ''})), 'b');
  });

  test('shareableLocation drops credentials and server tokens', () {
    expect(shareableLocation(const Media('/a/b c.flac')), '/a/b c.flac');
    expect(
      shareableLocation(const Media('http://u:p@h:8000/a%20b.mp3?x=1')),
      'http://h:8000/a%20b.mp3?x=1',
    );
    expect(
      shareableLocation(
        const Media(
          'https://jf/Audio/1/stream?api_key=k',
          extras: {'server': 'jellyfin'},
        ),
      ),
      'https://jf/Audio/1/stream',
    );
  });

  test('every source has one label', () {
    expect(MediaOrigin.values.map((o) => o.label), [
      'Local file',
      'Web stream',
      'Samba share',
      'Jellyfin',
      'Plex',
    ]);
  });
}
