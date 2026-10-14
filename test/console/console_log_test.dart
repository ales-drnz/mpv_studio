import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/console/console_log.dart';

void main() {
  test('the Console never shows credentials from a URL', () async {
    final log = ConsoleLog();
    addTearDown(log.dispose);
    final live = log.entries.first;
    log.add(
      const MpvLogEntry(
        prefix: 'cplayer',
        level: LogLevel.info,
        text: 'Playing: smb2://alex:secret@nas/Music/a.flac',
      ),
    );
    expect(log.backlog.single.text, 'Playing: smb2://nas/Music/a.flac');
    expect(log.backlog.single.prefix, 'cplayer');
    expect((await live).text, isNot(contains('secret')));
  });

  test('the Console never shows a server token', () async {
    final log = ConsoleLog();
    addTearDown(log.dispose);
    log.add(
      const MpvLogEntry(
        prefix: 'stream',
        level: LogLevel.error,
        text:
            'Failed to open https://jf.test/Audio/1/universal?ApiKey=k1 and '
            'https://pms.test/a.mp3?X-Plex-Token=k2',
      ),
    );
    final text = log.backlog.single.text;
    expect(text, isNot(contains('k1')));
    expect(text, isNot(contains('k2')));
    expect(text, contains('ApiKey=REDACTED'));
    expect(text, contains('X-Plex-Token=REDACTED'));
  });
}
