import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/ui/widgets/controls/slider_row.dart';

void main() {
  testWidgets('a drag ends on the dragged value, not a stale one', (
    tester,
  ) async {
    double? ended;
    // The parent never rebuilds with the new value, like one that updates
    // asynchronously.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: AppSlider(
                value: 0,
                min: 0,
                max: 100,
                onChanged: (_) {},
                onChangeEnd: (v) => ended = v,
              ),
            ),
          ),
        ),
      ),
    );
    final slider = tester.getRect(find.byType(AppSlider));
    await tester.dragFrom(
      Offset(slider.left + 20, slider.center.dy),
      const Offset(200, 0),
    );
    expect(ended, isNotNull);
    expect(ended, greaterThan(50));
  });
}
