import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_marks.dart';

/// A flag 16 wide (24 for the merged one) and 16 high.
Size _measure(String label) => Size(label.length == 1 ? 16 : 24, 16);

List<(String, Rect)> _flags(double? xa, double? xb, {double width = 400}) =>
    abLoopFlags(xa: xa, xb: xb, width: width, top: 0, measure: _measure);

void main() {
  test('A and B far apart hang outward from the loop', () {
    final flags = _flags(100, 300);
    expect(flags.map((f) => f.$1), ['A', 'B']);
    final a = flags[0].$2;
    final b = flags[1].$2;
    expect(a.right, lessThanOrEqualTo(100));
    expect(b.left, greaterThanOrEqualTo(300));
  });

  test('A and B close together do not overlap', () {
    for (final gap in [0.0, 1.0, 4.0, 10.0, 20.0, 40.0]) {
      final flags = _flags(200, 200 + gap);
      if (flags.length == 2) {
        expect(flags[0].$2.overlaps(flags[1].$2), isFalse, reason: '$gap');
      } else {
        expect(flags.single.$1, 'A-B');
      }
    }
  });

  test('close points at the edges merge into one flag inside the meter', () {
    for (final (xa, xb) in [(0.0, 3.0), (397.0, 400.0)]) {
      final flags = _flags(xa, xb);
      for (var i = 0; i < flags.length; i++) {
        final r = flags[i].$2;
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(400));
        for (var j = i + 1; j < flags.length; j++) {
          expect(r.overlaps(flags[j].$2), isFalse);
        }
      }
    }
    expect(_flags(0, 3).single.$1, 'A-B');
  });

  test('a single point keeps its flag on screen', () {
    expect(_flags(0, null).single.$2.left, greaterThanOrEqualTo(0));
    expect(_flags(null, 400).single.$2.right, lessThanOrEqualTo(400));
    expect(_flags(-5, null), isEmpty);
  });
}
