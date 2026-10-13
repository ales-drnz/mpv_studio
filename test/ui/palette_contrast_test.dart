import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/palette.dart';

/// The WCAG contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The tonal steps must stay apart in both themes, or fields, tonal
/// circles and the stage panel vanish into what they sit on.
void main() {
  for (final (name, p) in [('dark', Palette.dark), ('light', Palette.light)]) {
    group('$name palette', () {
      test('fields read on the stage, the cards and the chrome', () {
        expect(contrast(p.surface3, p.bg), greaterThanOrEqualTo(1.2));
        expect(contrast(p.surface3, p.surface), greaterThanOrEqualTo(1.14));
        expect(contrast(p.surface3, p.surface2), greaterThanOrEqualTo(1.2));
      });

      test('tonal fills read on the chrome and the stage', () {
        expect(contrast(p.tonal, p.surface2), greaterThanOrEqualTo(1.2));
        expect(contrast(p.tonal, p.bg), greaterThanOrEqualTo(1.2));
      });

      test('the ring grey selection reads on a field', () {
        expect(
          contrast(p.accentContainer, p.surface3),
          greaterThanOrEqualTo(1.2),
        );
      });

      test('the stage panel reads on the chrome', () {
        expect(contrast(p.bg, p.surface2), greaterThanOrEqualTo(1.15));
      });

      test('hints read on fields', () {
        expect(contrast(p.fgFaint, p.surface3), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onTonal, p.tonal), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
