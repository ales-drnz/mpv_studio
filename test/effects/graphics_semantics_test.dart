import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/widgets/compressor_curve.dart';
import 'package:mpv_studio/features/effects/widgets/equalizer.dart';
import 'package:mpv_studio/features/effects/widgets/loudness_gauge.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('the equalizer names the bands it moves', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Equalizer(
        bandsDb: const {'1b': 3, '9b': -2},
        onChanged: (_, _) {},
        onChangeEnd: () {},
      ),
    );
    final node = tester.getSemantics(
      find.bySemanticsLabel('18-band equalizer curve'),
    );
    expect(node.value, '65 Hz +3.0 dB, 1 kHz -2.0 dB');
    handle.dispose();
  });

  testWidgets('the compressor curve reads out its settings', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const CompressorCurve(
        threshold: 0.125,
        ratio: 4,
        knee: 2.8,
        makeup: 1,
        enabled: true,
        live: false,
      ),
    );
    expect(find.bySemanticsLabel('Compressor transfer curve'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(CompressorCurve)).value,
      'threshold -18 dB, ratio 4.0 to 1, make-up 0 dB',
    );
    handle.dispose();
  });

  testWidgets('the loudness gauge reads out LUFS', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const LoudnessGauge(
        reading: Loudness(momentary: -14.24, shortTerm: -15, integrated: -16.5),
        target: -18,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Loudness gauge')).value,
      'momentary -14.2 LUFS, short-term -15.0 LUFS, '
      'integrated -16.5 LUFS, target -18 LUFS',
    );
    handle.dispose();
  });
}
