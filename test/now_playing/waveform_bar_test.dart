import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform_meter.dart';

void main() {
  test('without RMS the bar is the peaks only, as before', () {
    final bar = waveBar(lo: -0.5, hi: 0.5, rms: null, centreY: 50, maxHalf: 40);
    expect(bar.top, 30);
    expect(bar.bottom, 70);
    expect(bar.body, isNull);
  });

  test('the RMS body sits inside the peaks', () {
    final bar = waveBar(lo: -0.9, hi: 0.8, rms: 0.25, centreY: 50, maxHalf: 40);
    expect(bar.top, closeTo(18, 1e-9));
    expect(bar.bottom, closeTo(86, 1e-9));
    expect(bar.body!.top, 40);
    expect(bar.body!.bottom, 60);
  });

  test('an RMS above the peaks is clamped to them', () {
    final bar = waveBar(lo: -0.2, hi: 0.1, rms: 0.9, centreY: 50, maxHalf: 40);
    expect(bar.body!.top, bar.top);
    expect(bar.body!.bottom, bar.bottom);
  });

  test('a silent bin keeps a 1 px body and a 1 px bar', () {
    final bar = waveBar(lo: 0, hi: 0, rms: 0, centreY: 50, maxHalf: 40);
    expect(bar.bottom - bar.top, 1);
    expect(bar.body!.bottom - bar.body!.top, 1);
  });

  test('out of range input is clamped', () {
    final bar = waveBar(
      lo: -3,
      hi: 3,
      rms: double.nan,
      centreY: 50,
      maxHalf: 40,
    );
    expect(bar.top, 10);
    expect(bar.bottom, 90);
    expect(bar.body, isNull);
  });
}
