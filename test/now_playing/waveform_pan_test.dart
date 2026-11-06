import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/now_playing/widgets/waveform/waveform_pan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a trackpad pinch zooms by the change of its scale', () {
    final zooms = <double>[];
    final pan = WaveformPan(
      onPan: (_) => true,
      canPan: () => true,
      onZoom: zooms.add,
    )..start();
    pan.update(const PointerPanZoomUpdateEvent(scale: 2));
    pan.update(const PointerPanZoomUpdateEvent(scale: 4));
    expect(zooms, [0.5, 0.5]);
  });

  testWidgets('Ctrl with the wheel zooms instead of panning', (tester) async {
    final zooms = <double>[];
    final pans = <double>[];
    final pan = WaveformPan(
      onPan: (p) {
        pans.add(p);
        return true;
      },
      canPan: () => true,
      onZoom: zooms.add,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    pan.signal(const PointerScrollEvent(scrollDelta: Offset(0, -40)));
    GestureBinding.instance.pointerSignalResolver.resolve(
      const PointerScrollEvent(scrollDelta: Offset(0, -40)),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(zooms, hasLength(1));
    expect(zooms.single, lessThan(1), reason: 'the wheel away zooms in');
    expect(pans, isEmpty);
  });

  testWidgets('with reduced motion a release does not coast', (tester) async {
    final pans = <double>[];
    final pan = WaveformPan(
      onPan: (p) {
        pans.add(p);
        return true;
      },
      canPan: () => true,
      still: () => true,
    )..start();
    pan.update(
      const PointerPanZoomUpdateEvent(
        timeStamp: Duration(milliseconds: 0),
        panDelta: Offset(-30, 0),
      ),
    );
    pan.update(
      const PointerPanZoomUpdateEvent(
        timeStamp: Duration(milliseconds: 16),
        panDelta: Offset(-30, 0),
      ),
    );
    final moved = pans.length;
    pan.end();
    await tester.pump(const Duration(milliseconds: 200));
    expect(pans, hasLength(moved));
    pan.stop();
  });
}
