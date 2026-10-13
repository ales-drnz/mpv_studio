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
}
