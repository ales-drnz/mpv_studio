import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/chart_text.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/round_icon_button.dart';
import '../../../util/reactive.dart';
import '../playback_scope.dart';

/// Flat real-time spectrum drawn as a smooth curve (not bars). Subscribes
/// to `player.stream.fft` and renders one continuous accent line through
/// the perceptual bands, over a faint fill. Subscribing arms the
/// analyzer; it disarms on unmount.
///
/// The curve runs edge to edge and its baseline sits on the bottom edge,
/// so the Playback page lays it full bleed, out to the edges of the page:
/// silent, the line rests whole on the edge, and the fill under it meets
/// the edge. When there is room it names itself, marks 100 Hz, 1 kHz and
/// 10 kHz along its foot, and offers its settings; [inset] keeps those
/// inside the page when the curve bleeds past it. Paused, it dims.
class SpectrumCurve extends StatelessWidget {
  /// Fixed height, or null to fill the parent (e.g. inside an [Expanded]).
  final double? height;

  /// How far past the page the curve bleeds on each side.
  final double inset;
  const SpectrumCurve({super.key, this.height, this.inset = 0});

  /// The least height that shows the title, the marks and the settings.
  static const double labelledHeight = 96;

  /// The marks along the foot, in Hz.
  static const List<double> marks = [100, 1000, 10000];

  @override
  Widget build(BuildContext context) {
    final player = PlaybackScope.of(context).player;
    final scaler = chartTextScaler(context);
    final curve = Live<SpectrumSettings>(
      stream: player.stream.spectrum,
      initial: player.state.spectrum,
      builder: (context, spec) => StreamBuilder<FftFrame>(
        stream: player.stream.fft,
        builder: (context, snap) => CustomPaint(
          size: Size.infinite,
          painter: _CurvePainter(
            snap.data?.bands,
            Tokens.palette,
            low: spec.bandLowHz,
            high: spec.bandHighHz,
            inset: inset,
            scaler: scaler,
          ),
        ),
      ),
    );
    final paint = Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            image: true,
            label: 'Output spectrum, 20 Hz to 20 kHz',
            excludeSemantics: true,
            child: Live<bool>(
              stream: player.stream.playWhenReady,
              initial: player.state.playWhenReady,
              builder: (context, playing) => AnimatedOpacity(
                opacity: playing ? 1 : 0.4,
                duration: Tokens.motion(context, Tokens.motionMedium),
                child: curve,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: _ShowFrom(
            height: labelledHeight,
            child: Padding(
              padding: EdgeInsets.only(
                left: inset + Tokens.s16,
                right: inset + Tokens.s8,
                top: Tokens.s8,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Output spectrum',
                        style: Tokens.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    RoundIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: 'Spectrum settings',
                      size: Tokens.iconMd,
                      onTap: () => showSpectrumSettings(context, player),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (height == null) return SizedBox.expand(child: paint);
    return SizedBox(height: height, width: double.infinity, child: paint);
  }
}

/// The spectrum's look, beside the spectrum: how fast the bands rise and
/// fall, and the dB range they span. The window, the FFT size and the
/// band count stay in Settings.
Future<void> showSpectrumSettings(BuildContext context, PlayerApi player) =>
    showStudioDialog<void>(
      context,
      title: 'Spectrum',
      builder: (context) => Live<SpectrumSettings>(
        stream: player.stream.spectrum,
        initial: player.state.spectrum,
        builder: (context, spec) {
          String db(double v) => '${v.round()} dB';
          String share(double v) => v.toStringAsFixed(2);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderRow(
                label: 'Rise',
                description: 'How fast a band climbs to a louder value',
                value: spec.attackSmoothing,
                min: 0.05,
                max: 1,
                format: share,
                resetTo: const SpectrumSettings().attackSmoothing,
                onChanged: (v) =>
                    player.setSpectrum(spec.copyWith(attackSmoothing: v)),
              ),
              SliderRow(
                label: 'Fall',
                description: 'How fast it sinks back; low leaves an afterglow',
                value: spec.releaseSmoothing,
                min: 0.02,
                max: 1,
                format: share,
                resetTo: const SpectrumSettings().releaseSmoothing,
                onChanged: (v) =>
                    player.setSpectrum(spec.copyWith(releaseSmoothing: v)),
              ),
              SliderRow(
                label: 'Floor',
                description: 'The level drawn as silence',
                value: spec.minDb,
                min: -120,
                max: spec.maxDb - 10,
                step: 1,
                format: db,
                resetTo: const SpectrumSettings().minDb,
                onChanged: (v) => player.setSpectrum(spec.copyWith(minDb: v)),
              ),
              SliderRow(
                label: 'Ceiling',
                description: 'The level drawn at the top',
                value: spec.maxDb,
                min: spec.minDb + 10,
                max: 0,
                step: 1,
                format: db,
                resetTo: const SpectrumSettings().maxDb,
                onChanged: (v) => player.setSpectrum(spec.copyWith(maxDb: v)),
              ),
            ],
          );
        },
      ),
      actions: (context) => [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );

class _CurvePainter extends CustomPainter {
  final Float32List? bands;
  final Palette palette;
  final double low;
  final double high;
  final double inset;
  final TextScaler scaler;
  _CurvePainter(
    this.bands,
    this.palette, {
    required this.low,
    required this.high,
    required this.inset,
    required this.scaler,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final b = bands;
    final n = b?.length ?? 0;

    // Baseline always drawn so the visualizer reads even when silent: a
    // hairline lying on the bottom edge.
    final baseline = Paint()
      ..color = palette.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h - 0.5), Offset(w, h - 0.5), baseline);

    // The frequency marks: a short tick and its label just above the
    // foot, where the bands are log-spaced from [low] to [high].
    if (h >= SpectrumCurve.labelledHeight && high > low && low > 0) {
      final tick = Paint()
        ..color = palette.lineRef
        ..strokeWidth = 1;
      final labelH = chartLabelHeight(scaler: scaler);
      for (final f in SpectrumCurve.marks) {
        if (f <= low || f >= high) continue;
        final x = math.log(f / low) / math.log(high / low) * w;
        if (x < inset + Tokens.s16 || x > w - inset - Tokens.s16) continue;
        canvas.drawLine(Offset(x, h - Tokens.s8), Offset(x, h), tick);
        paintChartLabel(
          canvas,
          f >= 1000 ? '${(f / 1000).round()}k' : '${f.round()}',
          Offset(x, h - Tokens.s8 - labelH - Tokens.s4),
          palette.fgFaint,
          scaler: scaler,
          center: true,
        );
      }
    }

    if (b == null || n < 2) return;

    // Silence puts the 2 px line whole on the bottom edge, its centre
    // one pixel above it; full scale keeps it whole under the top.
    double yOf(int i) => h - 1 - b[i].clamp(0.0, 1.0) * (h - 2);
    double xOf(int i) => n == 1 ? w / 2 : (i / (n - 1)) * w;

    final top = Path()..moveTo(xOf(0), yOf(0));
    for (var i = 1; i < n; i++) {
      final x0 = xOf(i - 1), y0 = yOf(i - 1);
      final x1 = xOf(i), y1 = yOf(i);
      // Quadratic through the midpoint: smooths the band envelope.
      top.quadraticBezierTo(x0, y0, (x0 + x1) / 2, (y0 + y1) / 2);
    }
    top.lineTo(xOf(n - 1), yOf(n - 1));

    final fill = Path.from(top)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(fill, Paint()..color = palette.accentWash);

    canvas.drawPath(
      top,
      Paint()
        ..color = palette.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  // The stream hands over a fresh Float32List per frame, so identity tracks
  // new data. Repaint only then (or on a theme change), not on unrelated
  // parent rebuilds.
  bool shouldRepaint(_CurvePainter old) =>
      !identical(old.bands, bands) ||
      old.palette != palette ||
      old.low != low ||
      old.high != high ||
      old.inset != inset ||
      old.scaler != scaler;
}

/// Shows [child] only when it gets at least [height]; in a shorter slot
/// (the spectrum strip under a phone's transport) it takes no room and
/// paints nothing. Reports no intrinsic size, so the slot is sized by the
/// curve, not by what sits on it.
class _ShowFrom extends SingleChildRenderObjectWidget {
  const _ShowFrom({required this.height, super.child});

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShowFrom(height);

  @override
  void updateRenderObject(BuildContext context, _RenderShowFrom renderObject) {
    renderObject.height = height;
  }
}

class _RenderShowFrom extends RenderProxyBox {
  _RenderShowFrom(this._height);

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  bool _shown = false;

  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => 0;
  @override
  double computeMinIntrinsicHeight(double width) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  void performLayout() {
    _shown = constraints.maxHeight >= _height;
    final child = this.child;
    if (child != null) child.layout(constraints, parentUsesSize: true);
    size = _shown && child != null ? child.size : constraints.smallest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_shown) super.paint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _shown && super.hitTestChildren(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_shown) super.visitChildrenForSemantics(visitor);
  }
}
