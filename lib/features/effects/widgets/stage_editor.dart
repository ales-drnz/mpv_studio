import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';
import '../rack_catalog.dart';
import '../rack_controller.dart';
import '../rack_environment.dart';
import 'featured_editors.dart';
import 'param_controls.dart';
import 'stage_editor_parts.dart';
import 'stage_meters.dart';

/// The open body of one stage: its before and after meters, then the
/// editor that fits it (a featured graphic editor, presets and text
/// options for the filters that need them, the raw entry, or one control
/// per parameter), then a reset.
class StageEditor extends StatelessWidget {
  final RackController rack;
  final int id;

  const StageEditor({super.key, required this.rack, required this.id});

  @override
  Widget build(BuildContext context) {
    final stage = rack.chain.stage(id);
    if (stage == null) return const SizedBox.shrink();
    final e = stage.effect;
    final d = descriptorOf(e.filter);
    final instance = rack.chain.tapInstance(id);
    final granted = rack.tapGranted(id);

    void change(AudioEffect next, {bool live = false}) =>
        rack.edit(id, next, live: live);

    final children = <Widget>[];
    final filter = e.filter;
    if (filter != null && instance != null) {
      children.add(
        StageMeters(
          filter: filter,
          instance: instance,
          active: granted,
          idleText: !e.enabled
              ? 'Stage is off'
              : rack.bypass
              ? 'Chain bypassed'
              : rack.tapDenied(id)
              ? 'Meters paused: close a stage to see these'
              : 'Meters off',
        ),
      );
      children.add(const SizedBox(height: Tokens.s12));
    }

    if (e is RawAudioEffect) {
      children.add(
        SubmitTextRow(
          label: 'lavfi entry',
          description: 'Inserted as written. Enter or the check applies it.',
          value: e.entry,
          hint: 'lavfi-aecho=0.8:0.9:500:0.3',
          maxLines: 3,
          onSubmit: (v) => change(e.copyWith(entry: v)),
        ),
      );
    } else if (isMeterStage(e)) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
          child: Text(
            'Feeds the live loudness meter. It measures the audio at this '
            'point of the chain and leaves it unchanged.',
            style: Tokens.caption,
          ),
        ),
      );
    } else if (d != null) {
      final featured = FeaturedEditor.of(
        e,
        onChange: change,
        onEnd: rack.flush,
        tapInstance: instance ?? 0,
        live: granted,
        loudness: rack.meterOn
            ? RackEnvironment.maybeOf(context)?.loudness
            : null,
      );
      if (featured != null) {
        children
          ..add(featured.graphic)
          ..add(const SizedBox(height: Tokens.s8))
          ..addAll(featured.controls)
          ..add(AllParams(d: d, e: e, rack: rack, id: id));
      } else {
        if (d.presets.isNotEmpty) {
          children.add(PresetChips(d: d, e: e, rack: rack, id: id));
        }
        if (d.fileBacked) {
          children.add(ModelFilePicker(d: d, e: e, rack: rack, id: id));
        }
        for (final p in d.params) {
          if (d.fileBacked && p.name == d.fileParam) continue;
          children.add(
            buildParamControl(p, e, onChange: change, onEnd: rack.flush),
          );
        }
        if (d.params.isEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
              child: Text('No adjustable parameters.', style: Tokens.caption),
            ),
          );
        }
      }
      if (d.params.isNotEmpty) {
        children.add(
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => change(d.setEnabled(d.create(), e.enabled)),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: Tokens.fgDim,
                textStyle: Tokens.label,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
