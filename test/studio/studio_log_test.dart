import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/console/console_log.dart';
import 'package:mpv_studio/studio/studio_log.dart';

void main() {
  test('lines reach the attached Console log until it is detached', () {
    final log = ConsoleLog();
    StudioLog.attach(log);
    StudioLog.write('first', level: LogLevel.warn);
    StudioLog.detach(log);
    StudioLog.write('second');
    expect(log.backlog.map((e) => (e.prefix, e.level, e.text)), [
      ('studio', LogLevel.warn, 'first'),
    ]);
  });

  test('redactUri drops the query and the credentials', () {
    expect(
      redactUri('https://pms.test:32400/a/b.mp3?X-Plex-Token=secret&x=1'),
      'https://pms.test:32400/a/b.mp3',
    );
    expect(
      redactUri('smb2://user:pw@nas/share/a.flac'),
      'smb2://nas/share/a.flac',
    );
    expect(redactUri('/music/a.flac'), '/music/a.flac');
  });
}
