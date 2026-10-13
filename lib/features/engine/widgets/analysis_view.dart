import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';
import '../engine_snapshot.dart';
import 'engine_parts.dart';

/// Where the waveform analysis of the current track stands.
enum WaveformPhase {
  waiting('waiting'),
  decoding('decoding'),
  progressive('progressive'),
  live('live window'),
  ready('ready');

  const WaveformPhase(this.label);
  final String label;

  static WaveformPhase of(WaveformData? w) {
    if (w == null) return WaveformPhase.waiting;
    if (w.live) return WaveformPhase.live;
    if (w.decoding) return WaveformPhase.decoding;
    if (w.filled.contains(0)) return WaveformPhase.progressive;
    return WaveformPhase.ready;
  }
}

/// The analysis of the current track, drawn like the `analysis_cache_feed`
/// diagram: the waveform bins filled so far over a flat baseline, and the
/// loudness scan that reads the same decode.
class AnalysisView extends StatelessWidget {
  final EngineSnapshot snapshot;
  const AnalysisView({super.key, required this.snapshot});

  static Color _phaseColor(WaveformPhase p) => switch (p) {
        WaveformPhase.waiting => Tokens.fgFaint,
        WaveformPhase.decoding => Tokens.accent,
        WaveformPhase.progressive => Tokens.amber,
        WaveformPhase.live => Tokens.accent,
        WaveformPhase.ready => Tokens.green,
      };

  static Color _scanColor(LoudnessScanState? s) => switch (s) {
        null || LoudnessScanState.idle => Tokens.fgFaint,
        LoudnessScanState.scanning => Tokens.accent,
        LoudnessScanState.ready => Tokens.green,
        LoudnessScanState.failed => Tokens.red,
        LoudnessScanState.unavailable => Tokens.amber,
      };

  static String _num(double? v, String unit) =>
      v == null || !v.isFinite ? 'n/a' : '${v.toStringAsFixed(1)} $unit';

  @override
  Widget build(BuildContext context) {
    final wave = snapshot.waveform;
    final phase = WaveformPhase.of(wave);
    final coverage = _coverage(wave);
    final scan = snapshot.loudnessScan;
    final scanState = scan?.state;

    return EngineCard(
      title: 'Analysis',
      caption: 'Waveform and loudness scan of the current track. '
          'Watching this panel starts the scan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Waveform', style: Tokens.label),
              const Spacer(),
              if (coverage != null)
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.s8),
                  child: Text(
                    '${(coverage * 100).round()}%',
                    style: Tokens.numeric,
                  ),
                ),
              StatePill(
                phase.label,
                color: _phaseColor(phase),
                strong: phase != WaveformPhase.waiting,
              ),
            ],
          ),
          const SizedBox(height: Tokens.s8),
          Semantics(
            label: 'Waveform ${phase.label}',
            excludeSemantics: true,
            child: SizedBox(
              height: 56,
              child: CustomPaint(
                painter: WaveformFillPainter(
                  wave: wave,
                  position: secondsOf(snapshot.state.position),
                ),
              ),
            ),
          ),
          const SizedBox(height: Tokens.s16),
          Row(
            children: [
              Text('Loudness scan', style: Tokens.label),
              const Spacer(),
              if (scanState == LoudnessScanState.scanning &&
                  scan?.progress != null)
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.s8),
                  child: Text(
                    '${(scan!.progress! * 100).round()}%',
                    style: Tokens.numeric,
                  ),
                ),
              StatePill(
                scanState?.mpvValue ?? 'waiting',
                color: _scanColor(scanState),
                strong:
                    scanState != null && scanState != LoudnessScanState.idle,
              ),
            ],
          ),
          const SizedBox(height: Tokens.s8),
          ThinBar(
            fraction: switch (scanState) {
              LoudnessScanState.ready => 1,
              LoudnessScanState.scanning => scan?.progress ?? 0,
              _ => 0,
            },
            color: _scanColor(scanState),
            height: 4,
          ),
          const SizedBox(height: Tokens.s12),
          ReadoutGrid(
            minCellWidth: 100,
            children: [
              Readout('Integrated', _num(scan?.integrated, 'LUFS')),
              Readout('Range', _num(scan?.range, 'LU')),
              Readout('True peak', _num(scan?.truePeak, 'dBTP')),
              Readout('Sample peak', _num(scan?.samplePeak, 'dBFS')),
            ],
          ),
        ],
      ),
    );
  }

  /// Share of bins decoded so far, or `null` once there is nothing to wait
  /// for.
  static double? _coverage(WaveformData? w) {
    if (w == null || w.live) return null;
    final d = w.decodeFraction;
    if (d != null) return d;
    if (w.bins == 0) return null;
    var filled = 0;
    for (final f in w.filled) {
      if (f == 1) filled++;
    }
    return filled == w.bins ? null : filled / w.bins;
  }
}

/// The waveform as bins filled so far (RMS body, peak outline) and a
/// dashed baseline where [WaveformData.filled] is 0.
class WaveformFillPainter extends CustomPainter {
  final WaveformData? wave;
  final double position;

  WaveformFillPainter({required this.wave, required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final half = mid - 2;
    final base = Paint()
      ..color = Tokens.line2
      ..strokeWidth = 1;
    final w = wave;
    if (w == null || w.bins == 0) {
      _dashedBaseline(canvas, 0, size.width, mid, base);
      return;
    }

    const step = 3.0;
    final peak = Paint()
      ..color = Tokens.accentDim
      ..strokeWidth = 2;
    final body = Paint()
      ..color = Tokens.accent
      ..strokeWidth = 2;
    double? gapFrom;
    for (var x = step / 2; x < size.width; x += step) {
      final i = (x / size.width * w.bins).floor().clamp(0, w.bins - 1);
      if (w.filled[i] == 0) {
        gapFrom ??= x - step / 2;
        continue;
      }
      if (gapFrom != null) {
        _dashedBaseline(canvas, gapFrom, x - step / 2, mid, base);
        gapFrom = null;
      }
      final hi = w.max[i].clamp(-1.0, 1.0), lo = w.min[i].clamp(-1.0, 1.0);
      canvas.drawLine(
        Offset(x, mid - math.max(hi * half, 1)),
        Offset(x, mid - math.min(lo * half, -1)),
        peak,
      );
      final rms = w.rms?[i];
      if (rms != null) {
        final r = math.max(rms.clamp(0.0, 1.0) * half, 1.0);
        canvas.drawLine(Offset(x, mid - r), Offset(x, mid + r), body);
      }
    }
    if (gapFrom != null) {
      _dashedBaseline(canvas, gapFrom, size.width, mid, base);
    }

    // Playhead on the waveform axis.
    final span = w.duration.inMicroseconds / 1e6;
    if (span > 0) {
      final f = (position - w.start.inMicroseconds / 1e6) / span;
      if (f >= 0 && f <= 1) {
        final px = f * size.width;
        canvas.drawLine(
          Offset(px, 0),
          Offset(px, size.height),
          Paint()
            ..color = Tokens.fg
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  static void _dashedBaseline(
    Canvas canvas,
    double from,
    double to,
    double y,
    Paint p,
  ) {
    for (var x = from; x < to; x += 6) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, to), y), p);
    }
  }

  @override
  bool shouldRepaint(WaveformFillPainter old) =>
      old.wave != wave || old.position != position;
}
