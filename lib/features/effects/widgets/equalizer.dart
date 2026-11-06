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
/// curve over a dB grid: the band gains are the control points of a
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

  // Plot insets: a right gutter for the dB scale and a bottom one for
  // the frequency labels, both measured at the reader's text size, and
  // the active node's radius on both sides so no node meets a label.
  // The curve lives inside what's left.
  static const double _topPad = 8;
  static const double nodeRadius = 4.5;

  /// The chart text scale of the last build, for the plot geometry.
  TextScaler _scaler = TextScaler.noScaling;

  Rect _plot(Size s) => Rect.fromLTRB(
    nodeRadius + 1,
    _topPad,
    s.width - nodeRadius - Tokens.s4 - chartLabelWidth('+12', scaler: _scaler),
    s.height - chartLabelHeight(scaler: _scaler) - Tokens.s4 - 2,
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
    _scaler = chartTextScaler(context);
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
                  scaler: _scaler,
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
  final TextScaler scaler;

  final Map<String, double> bandsDb;
  final int? active;
  final bool enabled;
  final Rect Function(Size) plot;

  _EqPainter({
    this.scaler = TextScaler.noScaling,
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
      gridPaint.color = db == 0 ? Tokens.lineRef : Tokens.line;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), gridPaint);
      // dB scale label in the right gutter.
      paintChartLabel(
        canvas,
        db == 0 ? '0' : '${db > 0 ? '+' : ''}${db.toInt()}',
        Offset(r.right + _EqualizerState.nodeRadius + Tokens.s4, y),
        Tokens.fgFaint,
        scaler: scaler,
        middle: true,
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
    canvas.drawPath(fill, Paint()..color = chartFill(enabled: enabled));
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
    // Thin the labels to every second or third band when the widest
    // would not clear its neighbour at the reader's text size.
    final widest = [
      for (final b in kEqBands) chartLabelWidth(b.label, scaler: scaler),
    ].reduce(math.max);
    final spacing = r.width / (n - 1);
    final labelStep = (spacing <= 0 ? n : ((widest + Tokens.s4) / spacing))
        .ceil()
        .clamp(1, n);
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
        // The outer labels stay inside the plot's width: the last one
        // would run into the dB scale.
        final label = kEqBands[i].label;
        final half = chartLabelWidth(label, scaler: scaler) / 2;
        final first = p.dx - half < 0;
        final last = p.dx + half > r.right;
        paintChartLabel(
          canvas,
          label,
          Offset(
            first
                ? 0
                : last
                ? r.right
                : p.dx,
            r.bottom + Tokens.s4 + 2,
          ),
          isActive ? accent : Tokens.fgFaint,
          center: !first && !last,
          end: last,
          scaler: scaler,
        );
      }
    }
  }

  /// Builds a smooth open Catmull-Rom spline through [pts] as a cubic
  /// Bézier path: the band dots become the spline's interpolation
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
      !_mapEq(old.bandsDb, bandsDb) ||
      old.scaler != scaler;

  static bool _mapEq(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
