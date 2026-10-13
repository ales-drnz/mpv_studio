import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The design language's hard rules, checked on the source: no squircle
/// anywhere, and no raw colour literal outside the palette. Colours come
/// from `Tokens` (which reads the active `Palette`), shapes from
/// `Tokens.shape`, `Tokens.pill` and `CircleBorder`. `lib/ui` owns the
/// palette and the generated code is exempt.
void main() {
  final rules = <String, RegExp>{
    'a squircle (ContinuousRectangleBorder)': RegExp(
      r'ContinuousRectangleBorder',
    ),
    'the word squircle': RegExp('squircle', caseSensitive: false),
    'a raw colour literal (use Tokens)': RegExp(r'Color\(0x'),
  };

  test('lib follows the design rules', () {
    final offences = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final path = f.path.replaceAll(r'\', '/');
          return !path.startsWith('lib/ui/') &&
              !path.startsWith('lib/generated/');
        });
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final MapEntry(key: name, value: rule) in rules.entries) {
          if (rule.hasMatch(lines[i])) {
            offences.add('${file.path}:${i + 1}: $name');
          }
        }
      }
    }
    expect(offences, isEmpty, reason: offences.join('\n'));
  });

  test('lib/ui draws no squircle either', () {
    final offences = [
      for (final f
          in Directory('lib/ui')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')))
        if (f.readAsStringSync().contains('ContinuousRectangleBorder')) f.path,
    ];
    expect(offences, isEmpty, reason: offences.join('\n'));
  });
}
