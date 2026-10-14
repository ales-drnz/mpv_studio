import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/effects/widgets/rack_parts.dart';
import 'package:mpv_studio/features/stream/widgets/choice_row.dart';
import 'package:mpv_studio/ui/palette.dart';
import 'package:mpv_studio/ui/widgets/controls.dart';

import '../support/layout_harness.dart';

/// Pills that hide their children from screen readers (excludeSemantics)
/// must carry the tap themselves, or a screen reader cannot press them.
void main() {
  testWidgets('pills are pressable by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = <String>[];
    await pumpStudio(
      tester,
      Scaffold(
        body: Column(
          children: [
            SegmentedControl<int>(
              options: const [SegmentOption(0, 'Off'), SegmentOption(1, 'On')],
              selected: 0,
              onSelect: (v) => taps.add('segment $v'),
            ),
            ChoiceRow<int>(
              label: 'Chunk size',
              choices: const [Choice(0, 'None'), Choice(1, '1 MiB')],
              selected: 0,
              onSelected: (v) => taps.add('choice $v'),
            ),
            TileButton(label: 'Choose', onPressed: () => taps.add('tile')),
            RackHeaderButton(
              icon: Icons.add_rounded,
              label: 'Add stage',
              tooltip: 'Add a stage to the chain',
              onTap: () => taps.add('rack'),
            ),
          ],
        ),
      ),
    );
    for (final label in ['On', '1 MiB', 'Choose', 'Add stage']) {
      final node = find.semantics.byLabel(label);
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        // isSemantics replaces it from Flutter 3.40; the app still supports 3.38.
        // ignore: deprecated_member_use
        containsSemantics(isButton: true, hasTapAction: true),
        reason: label,
      );
      tester.semantics.tap(node);
    }
    expect(taps, ['segment 1', 'choice 1', 'tile', 'rack']);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Off')),
      // isSemantics replaces it from Flutter 3.40; the app still supports 3.38.
      // ignore: deprecated_member_use
      containsSemantics(isSelected: true, hasSelectedState: true),
    );
    handle.dispose();
  });

  for (final palette in [Palette.light, Palette.dark]) {
    testWidgets('the picked choice pill takes the accent fill '
        '(${palette.brightness.name})', (tester) async {
      await pumpStudio(
        tester,
        Scaffold(
          body: ChoiceRow<int>(
            label: 'Mode',
            choices: const [Choice(0, 'Direct'), Choice(1, 'Transcode')],
            selected: 1,
            onSelected: (_) {},
          ),
        ),
        palette: palette,
      );
      Color fill(String label) {
        final ink = tester.widget<Ink>(
          find.ancestor(of: find.text(label), matching: find.byType(Ink)),
        );
        return (ink.decoration! as ShapeDecoration).color!;
      }

      Color? ink(String label) =>
          tester.widget<Text>(find.text(label)).style?.color;
      expect(fill('Transcode'), palette.accent);
      expect(ink('Transcode'), palette.onAccent);
      expect(fill('Direct'), palette.surface3);
      expect(ink('Direct'), palette.fg);
    });
  }

  test('no excluding Semantics drops the tap of the InkWell under it', () {
    final offences = <String>[];
    final semantics = RegExp(r'Semantics\(');
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final m in semantics.allMatches(source)) {
        final rest = source.substring(
          m.end,
          (m.end + 1200).clamp(0, source.length),
        );
        final child = rest.indexOf('child:');
        if (child < 0) continue;
        final args = rest.substring(0, child);
        if (!args.contains('excludeSemantics: true')) continue;
        if (args.contains('onTap')) continue;
        // The widget under it: the next 500 characters.
        final under = rest.substring(
          child,
          (child + 500).clamp(0, rest.length),
        );
        if (RegExp(r'InkWell\(\s*onTap:').hasMatch(under)) {
          final line = source.substring(0, m.start).split('\n').length;
          offences.add('${file.path}:$line');
        }
      }
    }
    expect(offences, isEmpty, reason: offences.join('\n'));
  });
}
