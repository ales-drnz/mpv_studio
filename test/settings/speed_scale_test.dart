import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/widgets/controls.dart';

import 'settings_page_test.dart' show drain, pumpSettings;

/// Speed and pitch at 1x sit in the middle of their tracks.
void main() {
  testWidgets('Speed and Pitch are on log tracks', (tester) async {
    await pumpSettings(tester);
    for (final label in ['Speed', 'Pitch']) {
      final row = tester.widget<SliderRow>(
        find.byWidgetPredicate((w) => w is SliderRow && w.label == label),
      );
      expect(row.scale, SliderScale.log, reason: label);
    }
    await drain(tester);
  });
}
