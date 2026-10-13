import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/audio/units.dart';

void main() {
  test('frequencies read in Hz, then kHz', () {
    expect(formatHz(120), '120 Hz');
    expect(formatHz(999.4), '999 Hz');
    expect(formatHz(1200), '1.2 kHz');
    expect(formatHz(3000), '3 kHz');
    expect(formatHz(12500), '12.5 kHz');
  });
}
