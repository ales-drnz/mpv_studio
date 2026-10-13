import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../engine_format.dart';
import '../engine_snapshot.dart';
import 'engine_parts.dart';

/// The audio output: its lifecycle, driver and device, and the format
/// coming out of the decoder next to the one sent to the device.
class OutputView extends StatelessWidget {
  final EngineSnapshot snapshot;
  const OutputView({super.key, required this.snapshot});

  static Color colorOf(AudioOutputState s) => switch (s) {
    AudioOutputState.closed => Tokens.fgFaint,
    AudioOutputState.initializing => Tokens.amber,
    AudioOutputState.active => Tokens.green,
    AudioOutputState.failed => Tokens.red,
  };

  @override
  Widget build(BuildContext context) {
    final s = snapshot.state;
    final out = s.audioOutputState;
    final driver = s.currentAo.isNotEmpty
        ? s.currentAo
        : (s.audioDriver.isEmpty ? 'auto' : s.audioDriver);
    final device = s.audioDevice.description.isNotEmpty
        ? s.audioDevice.description
        : s.audioDevice.name;

    return EngineCard(
      title: 'Audio output',
      trailing: StatePill(
        EngineFormat.outputState(out),
        color: colorOf(out),
        strong: out != AudioOutputState.closed,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReadoutGrid(
            minCellWidth: 140,
            children: [Readout('Driver', driver), Readout('Device', device)],
          ),
          const SizedBox(height: Tokens.s16),
          LayoutBuilder(
            builder: (context, c) {
              final input = _ParamsColumn(
                title: 'From the decoder',
                params: s.audioParams,
              );
              final output = _ParamsColumn(
                title: 'To the device',
                params: s.audioOutParams,
              );
              // Side by side when two format boxes fit, else stacked.
              final columns = ResponsiveGrid.columnsFor(
                c.maxWidth,
                minTileWidth: 150,
                spacing: Tokens.s32,
                maxColumns: 2,
              );
              if (columns < 2) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: Tokens.s8),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 16,
                        color: Tokens.fgFaint,
                      ),
                    ),
                    output,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: input),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Tokens.s8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Tokens.fgFaint,
                    ),
                  ),
                  Expanded(child: output),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ParamsColumn extends StatelessWidget {
  final String title;
  final AudioParams params;
  const _ParamsColumn({required this.title, required this.params});

  @override
  Widget build(BuildContext context) {
    final p = EngineFormat.params(params);
    return Container(
      padding: const EdgeInsets.all(Tokens.s16),
      decoration: ShapeDecoration(
        color: Tokens.surface3,
        shape: Tokens.shape(Tokens.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Tokens.label.copyWith(
              color: Tokens.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Tokens.s8),
          _line('codec', p.codec),
          _line('format', p.format),
          _line('rate', p.rate),
          _line('channels', p.channels),
        ],
      ),
    );
  }

  static Widget _line(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.s4),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(k, style: Tokens.numeric.copyWith(color: Tokens.fgFaint)),
        ),
        Expanded(
          child: Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tokens.numeric.copyWith(color: Tokens.fg),
          ),
        ),
      ],
    ),
  );
}
