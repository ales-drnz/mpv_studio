/// A frequency as people read it: `120 Hz` below a kilohertz, then
/// `1.2 kHz`, `3 kHz`, `12 kHz` (a whole number of kilohertz loses its
/// decimal).
String formatHz(double hz) {
  if (hz < 1000) return '${hz.round()} Hz';
  final k = (hz / 100).round() / 10;
  return k == k.roundToDouble()
      ? '${k.round()} kHz'
      : '${k.toStringAsFixed(1)} kHz';
}
