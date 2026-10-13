import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The design language's hard rules, checked on the source: no squircle
/// anywhere, no raw colour outside the palette, no sharp or one-sided
/// corners. Colours come from `Tokens` (which reads the active `Palette`),
/// shapes from `Tokens.shape`, `Tokens.pill` and `CircleBorder`. `lib/ui`
/// owns the palette and the generated code is exempt.
void main() {
  final rules = <String, RegExp>{
    'a squircle (ContinuousRectangleBorder)': RegExp(
      r'ContinuousRectangleBorder',
    ),
    'the word squircle': RegExp('squircle', caseSensitive: false),
    'a raw colour literal (use Tokens)': RegExp(r'Color\(0x'),
    'a raw colour constructor (use Tokens)': RegExp(
      r'Color\.from(ARGB|RGBO)\(',
    ),
    'a Material colour (use Tokens; Colors.transparent is fine)': RegExp(
      r'Colors\.(?!transparent\b)\w+',
    ),
    'a one-sided or sharp corner (use Tokens.shape)': RegExp(
      r'BorderRadius\.(only|zero|vertical|horizontal)\b|Radius\.zero\b',
    ),
  };

  // Lines that may break a rule on purpose, as `path: rule`: the quick
  // editors' fade mask is drawn in black and transparent, not in colour.
  const allowed = <String>{
    'lib/features/effects/widgets/quick_editors.dart: '
        'a Material colour (use Tokens; Colors.transparent is fine)',
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
      final path = file.path.replaceAll(r'\', '/');
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final MapEntry(key: name, value: rule) in rules.entries) {
          if (rule.hasMatch(lines[i]) && !allowed.contains('$path: $name')) {
            offences.add('$path:${i + 1}: $name');
          }
        }
        // A BoxDecoration is a sharp rectangle unless it rounds or is a
        // circle (within its next few lines).
        if (lines[i].contains('BoxDecoration(')) {
          final decoration = lines.skip(i).take(6).join(' ');
          if (!decoration.contains('BoxShape.circle') &&
              !decoration.contains('borderRadius:')) {
            offences.add('$path:${i + 1}: a sharp BoxDecoration');
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
