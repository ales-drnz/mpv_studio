import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_painter.dart';

List<double> _ticks(double from, double to, {double step = 60}) =>
    rulerTicks(viewStart: from, viewEnd: to, step: step, start: 0, end: 292);

void main() {
  test('a tick before the view is left out', () {
    // Zoomed in from 1:58: the 1:00 tick is off screen, 2:00 is the first.
    expect(_ticks(118, 230), [120, 180]);
  });

  test('ticks on the view edges are kept', () {
    expect(_ticks(120, 240), [120, 180, 240]);
    expect(_ticks(119.9999999, 240.0000001), [120, 180, 240]);
  });

  test('the whole track starts at zero and stops at its end', () {
    expect(_ticks(0, 292), [0, 60, 120, 180, 240]);
  });

  test('ticks stay inside the timeline', () {
    expect(_ticks(-30, 400), [0, 60, 120, 180, 240]);
  });

  test('a view with no room or no step has no ticks', () {
    expect(_ticks(121, 179), isEmpty);
    expect(_ticks(0, 292, step: 0), isEmpty);
  });
}
