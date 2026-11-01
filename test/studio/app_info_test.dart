import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/studio/app_info.dart';

void main() {
  test('appVersion is the version of pubspec.yaml', () {
    final version = RegExp(
      r'^version: (\S+)$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())?.group(1);
    expect(version, isNotNull);
    expect(appVersion, version!.split('+').first);
  });
}
