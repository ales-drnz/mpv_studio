import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../generated/filter_catalog.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../rack_catalog.dart';
import '../rack_controller.dart';
import 'featured_editors.dart';
import 'loudness_gauge.dart';
import 'param_controls.dart';
import 'stage_meters.dart';

/// Whether every mandatory text option of [e] has a value, so the stage
/// can be switched on without mpv refusing the chain.
bool stageReady(AudioEffect e) {
  final d = descriptorOf(e.filter);
  if (d == null) return e is! RawAudioEffect || e.entry.trim().isNotEmpty;
  return d.params
      .whereType<StringParam>()
      .where((p) => p.required)
      .every((p) => p.get(e).trim().isNotEmpty);
}

/// Copies a bundled asset (a noise model) to a temp file mpv can open.
Future<String> materializeAsset(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final dir = Directory('${Directory.systemTemp.path}/mpv_studio_models');
  await dir.create(recursive: true);
  final file = File('${dir.path}/${assetPath.split('/').last}');
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file.path;
}

/// Applies [preset] to stage [id] and switches it on.
Future<void> applyPreset(
  RackController rack,
  int id,
  FilterDescriptor d,
  FilterPreset preset,
) async {
  var values = preset.values;
  final fp = d.fileParam;
  if (d.fileBacked && fp != null && values[fp] != null) {
    values = {fp: await materializeAsset(values[fp]!)};
  }
  final stage = rack.chain.stage(id);
  if (stage == null) return;
  var e = stage.effect;
  for (final p in d.params.whereType<StringParam>()) {
    final v = values[p.name];
    if (v != null) e = p.set(e, v);
  }
  rack.edit(id, d.setEnabled(e, true));
}

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
          padding: EdgeInsets.symmetric(vertical: Tokens.s8),
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
      );
      if (featured != null) {
        Widget graphic = featured.graphic;
        if (e is LoudnormEffect) {
          // The target gauge with the live reading on it.
          final env = RackEnvironment.maybeOf(context);
          graphic = StreamBuilder<Loudness>(
            stream: rack.meterOn ? env?.loudness : null,
            builder: (context, snap) => LoudnessGauge(
              reading: snap.data,
              target: e.i,
              range: e.lra,
              truePeak: e.tp,
              enabled: e.enabled,
            ),
          );
        }
        children
          ..add(graphic)
          ..add(const SizedBox(height: Tokens.s8))
          ..addAll(featured.controls)
          ..add(_AllParams(d: d, e: e, rack: rack, id: id));
      } else {
        if (d.presets.isNotEmpty) {
          children.add(_Presets(d: d, e: e, rack: rack, id: id));
        }
        if (d.fileBacked) {
          children.add(_FilePicker(d: d, e: e, rack: rack, id: id));
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
              padding: EdgeInsets.symmetric(vertical: Tokens.s8),
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

/// Every parameter of a featured stage, folded under its graphic editor.
class _AllParams extends StatefulWidget {
  final FilterDescriptor d;
  final AudioEffect e;
  final RackController rack;
  final int id;
  const _AllParams({
    required this.d,
    required this.e,
    required this.rack,
    required this.id,
  });

  @override
  State<_AllParams> createState() => _AllParamsState();
}

class _AllParamsState extends State<_AllParams> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
              _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 16,
            ),
            label: Text(_open ? 'Fewer parameters' : 'All parameters'),
            style: TextButton.styleFrom(
              foregroundColor: Tokens.fgDim,
              textStyle: Tokens.label,
            ),
          ),
        ),
        if (_open)
          for (final p in widget.d.params)
            buildParamControl(
              p,
              widget.e,
              onChange: (next, {live = false}) =>
                  widget.rack.edit(widget.id, next, live: live),
              onEnd: widget.rack.flush,
            ),
      ],
    );
  }
}

/// The curated presets of a filter with mandatory options.
class _Presets extends StatelessWidget {
  final FilterDescriptor d;
  final AudioEffect e;
  final RackController rack;
  final int id;
  const _Presets({
    required this.d,
    required this.e,
    required this.rack,
    required this.id,
  });

  bool _active(FilterPreset preset) {
    if (!e.enabled) return false;
    return preset.values.entries.every((kv) {
      final p = d.params
          .whereType<StringParam>()
          .where((p) => p.name == kv.key)
          .firstOrNull;
      if (p == null) return false;
      final cur = p.get(e);
      // A file preset plays from a temp copy: compare file names.
      return d.fileBacked
          ? cur.split('/').last == kv.value.split('/').last
          : cur == kv.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.fileBacked ? 'Bundled models' : 'Presets',
            style: Tokens.label,
          ),
          const SizedBox(height: Tokens.s8),
          Wrap(
            spacing: Tokens.s8,
            runSpacing: Tokens.s8,
            children: [
              for (final preset in d.presets)
                _Chip(
                  label: preset.name,
                  active: _active(preset),
                  onTap: () => applyPreset(rack, id, d, preset),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A model file of the user's own, for a file-backed filter.
class _FilePicker extends StatelessWidget {
  final FilterDescriptor d;
  final AudioEffect e;
  final RackController rack;
  final int id;
  const _FilePicker({
    required this.d,
    required this.e,
    required this.rack,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    final p = d.params
        .whereType<StringParam>()
        .where((p) => p.name == d.fileParam)
        .firstOrNull;
    if (p == null) return const SizedBox.shrink();
    final cur = p.get(e);
    return SettingTile(
      title: 'Model file',
      description: cur.isEmpty ? 'No file selected' : cur.split('/').last,
      trailing: TextButton.icon(
        onPressed: () async {
          final file = await openFile();
          if (file == null) return;
          rack.edit(id, d.setEnabled(p.set(e, file.path), true));
        },
        icon: const Icon(Icons.folder_open_rounded, size: 16),
        label: const Text('Choose'),
        style: TextButton.styleFrom(
          foregroundColor: Tokens.accent,
          textStyle: Tokens.label,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: Tokens.squircle(Tokens.rSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.s12,
            vertical: Tokens.s8,
          ),
          decoration: ShapeDecoration(
            color: active ? Tokens.accent : Tokens.surface2,
            shape: Tokens.squircle(Tokens.rSm),
          ),
          child: Text(
            label,
            style: Tokens.label.copyWith(
              color: active ? Tokens.onAccent : Tokens.fgDim,
            ),
          ),
        ),
      ),
    );
  }
}
