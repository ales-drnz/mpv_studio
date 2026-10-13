import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../audio/pcm_analysis.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import 'loudness_gauge.dart';

/// The live loudness meter next to what is known of the file: the EBU
/// R128 readings of the chain as it plays (`stream.loudnessMeter`, fed by
/// the meter stage the switch adds), the offline scan of the whole track
/// (`stream.loudnessScan`) and the gain the app's normalization applies.
class LoudnessPanel extends StatefulWidget {
  /// Whether the meter stage is in the chain and on.
  final bool meterOn;
  final ValueChanged<bool> onMeterChanged;

  /// The live readings: `player.stream.loudnessMeter`.
  final Stream<Loudness> readings;

  /// The file's scan, `null` until one lands.
  final LoudnessScan? scan;

  /// The app's volume normalization.
  final bool normalizationOn;
  final double appliedGainDb;
  final double targetLufs;

  /// Whether the chain is bypassed: the meter then reads the dry signal.
  final bool bypassed;

  const LoudnessPanel({
    super.key,
    required this.meterOn,
    required this.onMeterChanged,
    required this.readings,
    required this.scan,
    required this.normalizationOn,
    required this.appliedGainDb,
    required this.targetLufs,
    this.bypassed = false,
  });

  @override
  State<LoudnessPanel> createState() => _LoudnessPanelState();
}

class _LoudnessPanelState extends State<LoudnessPanel> {
  StreamSubscription<Loudness>? _sub;
  Loudness? _last;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LoudnessPanel old) {
    super.didUpdateWidget(old);
    if (old.meterOn != widget.meterOn || old.readings != widget.readings) {
      _sync();
    }
  }

  void _sync() {
    _sub?.cancel();
    _sub = null;
    _last = null;
    if (!widget.meterOn) return;
    _sub = widget.readings.listen((l) {
      if (mounted) setState(() => _last = l);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _last;
    return Container(
      padding: const EdgeInsets.all(Tokens.s16),
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchRow(
            label: 'Live meter',
            subtitle: widget.meterOn
                ? (widget.bypassed
                      ? 'Measuring the dry signal while bypassed'
                      : 'Measuring at the meter stage of the chain')
                : 'Adds a measuring stage at the end of the chain',
            value: widget.meterOn,
            onChanged: widget.onMeterChanged,
          ),
          const SizedBox(height: Tokens.s8),
          LoudnessGauge(
            reading: l,
            target: widget.normalizationOn ? widget.targetLufs : null,
            enabled: widget.meterOn,
          ),
          const SizedBox(height: Tokens.s12),
          LayoutBuilder(
            builder: (context, c) {
              final live = _Column(
                title: 'Live',
                rows: [
                  ('Momentary', _lufs(l?.momentary)),
                  ('Short-term', _lufs(l?.shortTerm)),
                  ('Integrated', _lufs(l?.integrated)),
                  ('Range', _lu(l?.range)),
                ],
              );
              final file = _Column(title: 'This file', rows: _scanRows());
              final norm = _Column(title: 'Normalization', rows: _normRows());
              if (WidthClass.of(c.maxWidth).below(WidthClass.medium)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    live,
                    const SizedBox(height: Tokens.s12),
                    file,
                    const SizedBox(height: Tokens.s12),
                    norm,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: live),
                  const SizedBox(width: Tokens.s16),
                  Expanded(child: file),
                  const SizedBox(width: Tokens.s16),
                  Expanded(child: norm),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<(String, String)> _scanRows() {
    final s = widget.scan;
    switch (s?.state) {
      case null:
      case LoudnessScanState.idle:
        return [('Scan', 'Waiting for a track')];
      case LoudnessScanState.scanning:
        final p = s!.progress;
        return [
          ('Scan', p == null ? 'Scanning' : 'Scanning ${(p * 100).round()}%'),
        ];
      case LoudnessScanState.unavailable:
        return [('Scan', 'Not measurable ahead')];
      case LoudnessScanState.failed:
        return [('Scan', 'Failed')];
      case LoudnessScanState.ready:
        final tp = s!.truePeak;
        return [
          ('Integrated', _lufs(s.integrated)),
          ('Range', _lu(s.range)),
          (
            'True peak',
            tp == null ? '--' : '${amplitudeToDb(tp).toStringAsFixed(1)} dBTP',
          ),
        ];
    }
  }

  List<(String, String)> _normRows() {
    if (!widget.normalizationOn) return [('Gain', 'Off')];
    final g = widget.appliedGainDb;
    return [
      ('Target', '${widget.targetLufs.toStringAsFixed(0)} LUFS'),
      ('Gain', '${g >= 0 ? '+' : ''}${g.toStringAsFixed(1)} dB'),
    ];
  }

  static String _lufs(double? v) =>
      v == null || v <= -70 ? '--' : '${v.toStringAsFixed(1)} LUFS';
  static String _lu(double? v) =>
      v == null ? '--' : '${v.toStringAsFixed(1)} LU';
}

class _Column extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _Column({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title.toUpperCase(), style: Tokens.caption),
        const SizedBox(height: Tokens.s4),
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(k, style: Tokens.label)),
                Text(v, style: Tokens.numeric),
              ],
            ),
          ),
      ],
    );
  }
}
