import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';
import 'graphic_height.dart';

/// The 18 fixed bands of ffmpeg's `superequalizer`, in order. The key is
/// the raw ffmpeg option name (digit-prefixed, so it lives in the
/// settings `params` map); the label is the band's centre frequency.
const List<({String key, String label})> kEqBands = [
  (key: '1b', label: '65'),
  (key: '2b', label: '92'),
  (key: '3b', label: '131'),
  (key: '4b', label: '185'),
  (key: '5b', label: '262'),
  (key: '6b', label: '370'),
  (key: '7b', label: '523'),
  (key: '8b', label: '740'),
  (key: '9b', label: '1k'),
  (key: '10b', label: '1.5k'),
  (key: '11b', label: '2.1k'),
  (key: '12b', label: '3k'),
  (key: '13b', label: '4.2k'),
  (key: '14b', label: '5.9k'),
  (key: '15b', label: '8.4k'),
  (key: '16b', label: '12k'),
  (key: '17b', label: '17k'),
  (key: '18b', label: '20k'),
];

/// EQ band gains are presented in dB (±[kEqMaxDb]) but `superequalizer`
/// takes a linear multiplier (1.0 = flat). These convert between the
/// two; 0 dB ⇒ 1.0.
const double kEqMaxDb = 12;
double eqLinearToDb(double linear) =>
    linear <= 0 ? -kEqMaxDb : 20 * (math.log(linear) / math.ln10);
double eqDbToLinear(double db) => math.pow(10, db / 20).toDouble();

/// An interactive 18-band graphic EQ rendered as a single continuous
/// curve over a dB grid — the band gains are the control points of a
/// Catmull-Rom spline. Drag anywhere to shape the nearest band; sweep
/// horizontally to paint a contour across several bands at once. Double-
/// tap flattens the touched band back to 0 dB.
///
/// Flat-design throughout: a faint lattice, an accent curve over a
/// bipolar wash that grows up for boosts and down for cuts from the
/// 0 dB centre line, and small node dots that brighten on the band the
/// pointer is riding.
class Equalizer extends StatefulWidget {
  /// Current gain per band key, in dB. Missing keys read as 0 dB.
  final Map<String, double> bandsDb;
  final void Function(String key, double db) onChanged;
  final VoidCallback onChangeEnd;
  final bool enabled;

  const Equalizer({
    super.key,
    required this.bandsDb,
    required this.onChanged,
    required this.onChangeEnd,
    this.enabled = true,
  });

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> {
  /// Index of the band the pointer is currently shaping, for highlight.
  int? _active;

  // Plot insets: a slim right gutter for the dB scale, a bottom gutter
  // for the frequency labels. The curve lives inside what's left.
  static const double _rightGutter = 26;
  static const double _bottomGutter = 16;
  static const double _topPad = 8;

  Rect _plot(Size s) => Rect.fromLTRB(
    2,
    _topPad,
    s.width - _rightGutter,
    s.height - _bottomGutter,
  );

  /// Maps a pointer position to (band index, dB) and pushes the change.
  void _shapeAt(Offset local, Size size) {
    final plot = _plot(size);
    if (plot.width <= 0) return;
    final n = kEqBands.length;
    final t = ((local.dx - plot.left) / plot.width).clamp(0.0, 1.0);
    final i = (t * (n - 1)).round().clamp(0, n - 1);
    final yt = ((local.dy - plot.top) / plot.height).clamp(0.0, 1.0);
    final db = (kEqMaxDb - yt * 2 * kEqMaxDb).clamp(-kEqMaxDb, kEqMaxDb);
    if (_active != i) setState(() => _active = i);
    widget.onChanged(kEqBands[i].key, db.toDouble());
  }

  int _nearestBand(Offset local, Size size) {
    final plot = _plot(size);
    final n = kEqBands.length;
    final t = ((local.dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (t * (n - 1)).round().clamp(0, n - 1);
  }

  /// The bands away from 0 dB, for screen readers.
  String _describe() {
    final moved = [
      for (final b in kEqBands)
        if ((widget.bandsDb[b.key] ?? 0).abs() >= 0.5)
          '${_hz(b.label)} ${_signed(widget.bandsDb[b.key]!)} dB',
    ];
    return moved.isEmpty ? 'Flat' : moved.join(', ');
  }

  /// A band label (`92`, `1.5k`) with its unit (`92 Hz`, `1.5 kHz`).
  static String _hz(String label) => label.endsWith('k')
      ? '${label.substring(0, label.length - 1)} kHz'
      : '$label Hz';

  static String _signed(double db) =>
      '${db > 0 ? '+' : ''}${db.toStringAsFixed(1)}';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Taller on wide editors so the curve keeps its shape.
        final height = graphicHeight(
          context,
          c.maxWidth,
          ratio: 0.32,
          min: 168,
          max: 260,
        );
        final size = Size(c.maxWidth, height);
        return Semantics(
          label: '18-band equalizer curve',
          value: _describe(),
          hint: 'Each band is also a slider under All parameters',
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: widget.enabled
                  ? (d) => _shapeAt(d.localPosition, size)
                  : null,
              onPanUpdate: widget.enabled
                  ? (d) => _shapeAt(d.localPosition, size)
                  : null,
              onPanEnd: widget.enabled
                  ? (_) {
                      setState(() => _active = null);
                      widget.onChangeEnd();
                    }
                  : null,
              onTapDown: widget.enabled
                  ? (d) => setState(
                      () => _active = _nearestBand(d.localPosition, size),
                    )
                  : null,
              onTapUp: widget.enabled ? (_) => widget.onChangeEnd() : null,
              onDoubleTapDown: widget.enabled
                  ? (d) {
                      final i = _nearestBand(d.localPosition, size);
                      widget.onChanged(kEqBands[i].key, 0);
                      widget.onChangeEnd();
                    }
                  : null,
              child: CustomPaint(
                size: size,
                painter: _EqPainter(
                  bandsDb: widget.bandsDb,
                  active: _active,
                  enabled: widget.enabled,
                  plot: _plot,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EqPainter extends CustomPainter {
  final Map<String, double> bandsDb;
  final int? active;
  final bool enabled;
  final Rect Function(Size) plot;

  _EqPainter({
    required this.bandsDb,
    required this.active,
    required this.enabled,
    required this.plot,
  });

  static const _gridDb = [12.0, 6.0, 0.0, -6.0, -12.0];

  @override
  void paint(Canvas canvas, Size size) {
    final r = plot(size);
    if (r.width <= 0 || r.height <= 0) return;
    final n = kEqBands.length;

    final accent = enabled ? Tokens.accent : Tokens.fgFaint;

    double yOfDb(double db) =>
        r.top + (1 - (db + kEqMaxDb) / (2 * kEqMaxDb)) * r.height;
    double xOfBand(int i) => r.left + (i / (n - 1)) * r.width;

    // ── Grid lattice ────────────────────────────────────────────────
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final db in _gridDb) {
      final y = yOfDb(db);
      gridPaint.color = db == 0 ? Tokens.line2 : Tokens.line;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), gridPaint);
      // dB scale label in the right gutter.
      paintChartLabel(
        canvas,
        db == 0 ? '0' : '${db > 0 ? '+' : ''}${db.toInt()}',
        Offset(r.right + 4, y - 6),
        Tokens.fgFaint,
      );
    }

    // ── Band gains → curve points ───────────────────────────────────
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          xOfBand(i),
          yOfDb((bandsDb[kEqBands[i].key] ?? 0).clamp(-kEqMaxDb, kEqMaxDb)),
        ),
    ];

    final curve = _catmullRom(pts);

    // Bipolar fill: close the curve along the 0 dB centre line so boosts
    // wash upward and cuts wash downward from the middle.
    final zeroY = yOfDb(0);
    final fill = Path.from(curve)
      ..lineTo(r.right, zeroY)
      ..lineTo(r.left, zeroY)
      ..close();
    canvas.save();
    canvas.clipRect(r.inflate(1));
    canvas.drawPath(
      fill,
      Paint()..color = enabled ? Tokens.accentWash : Tokens.surface3,
    );
    canvas.restore();

    // Curve stroke.
    canvas.drawPath(
      curve,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );

    // ── Nodes + frequency labels ────────────────────────────────────
    // On narrow canvases, thin the labels so they don't collide.
    final labelStep = r.width / n < 26 ? 2 : 1;
    for (var i = 0; i < n; i++) {
      final p = pts[i];
      final isActive = i == active;
      canvas.drawCircle(
        p,
        isActive ? 4.5 : 2.6,
        Paint()..color = isActive ? accent : Tokens.surface,
      );
      canvas.drawCircle(
        p,
        isActive ? 4.5 : 2.6,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 0 : 1.4
          ..isAntiAlias = true,
      );
      if (i % labelStep == 0) {
        paintChartLabel(
          canvas,
          kEqBands[i].label,
          Offset(p.dx, r.bottom + 3),
          isActive ? accent : Tokens.fgFaint,
          center: true,
        );
      }
    }
  }

  /// Builds a smooth open Catmull-Rom spline through [pts] as a cubic
  /// Bézier path — the band dots become the spline's interpolation
  /// points, so the curve passes exactly through each gain.
  Path _catmullRom(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i == 0 ? 0 : i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 >= pts.length ? pts.length - 1 : i + 2];
      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_EqPainter old) =>
      old.active != active ||
      old.enabled != enabled ||
      !_mapEq(old.bandsDb, bandsDb);

  static bool _mapEq(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
