import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/studio/mpv_studio.dart';

void main() {
  test('a failed launch undoes every step, newest first', () async {
    final done = <String>[];
    await MpvStudio.undoAll([
      () => done.add('player'),
      () async => done.add('console'),
      () => throw StateError('settings already closed'),
      () => done.add('issues'),
    ]);
    expect(done, ['issues', 'console', 'player']);
  });
}
