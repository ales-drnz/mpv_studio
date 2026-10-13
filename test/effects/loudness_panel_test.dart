import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/widgets/loudness_panel.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('shows live readings, the file scan and the applied gain',
      (tester) async {
    final readings = StreamController<Loudness>.broadcast();
    addTearDown(readings.close);
    bool? toggled;
    await tester.pumpWidget(host(LoudnessPanel(
      meterOn: true,
      onMeterChanged: (v) => toggled = v,
      readings: readings.stream,
      scan: const LoudnessScan(
        state: LoudnessScanState.ready,
        integrated: -9.4,
        range: 5.2,
        truePeak: 1.0,
      ),
      normalizationOn: true,
      appliedGainDb: -8.6,
      targetLufs: -18,
    )));
    expect(find.text('--'), findsNWidgets(4), reason: 'no reading yet');

    readings.add(const Loudness(
      momentary: -14.24,
      shortTerm: -15.0,
      integrated: -16.5,
      range: 6.0,
    ));
    await tester.pump();
    expect(find.text('-14.2 LUFS'), findsOneWidget);
    expect(find.text('-15.0 LUFS'), findsOneWidget);
    expect(find.text('-16.5 LUFS'), findsOneWidget);
    expect(find.text('6.0 LU'), findsOneWidget);

    expect(find.text('-9.4 LUFS'), findsOneWidget);
    expect(find.text('5.2 LU'), findsOneWidget);
    expect(find.text('0.0 dBTP'), findsOneWidget);
    expect(find.text('-18 LUFS'), findsOneWidget);
    expect(find.text('-8.6 dB'), findsOneWidget);

    await tester.tap(find.text('Live meter'));
    expect(toggled, isFalse);
  });

  testWidgets('the meter off drops the reading and says how to start it',
      (tester) async {
    final readings = StreamController<Loudness>.broadcast();
    addTearDown(readings.close);
    Widget panel(bool on) => host(LoudnessPanel(
          meterOn: on,
          onMeterChanged: (_) {},
          readings: readings.stream,
          scan: const LoudnessScan(
              state: LoudnessScanState.scanning, progress: 0.42),
          normalizationOn: false,
          appliedGainDb: 0,
          targetLufs: -18,
        ));
    await tester.pumpWidget(panel(true));
    readings.add(const Loudness(momentary: -20));
    await tester.pump();
    expect(find.text('-20.0 LUFS'), findsOneWidget);
    expect(readings.hasListener, isTrue);

    await tester.pumpWidget(panel(false));
    expect(find.text('-20.0 LUFS'), findsNothing);
    expect(readings.hasListener, isFalse, reason: 'no listener while off');
    expect(find.text('Adds a measuring stage at the end of the chain'),
        findsOneWidget);
    expect(find.text('Scanning 42%'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
  });
}
