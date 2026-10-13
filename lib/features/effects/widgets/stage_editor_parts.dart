import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../generated/filter_catalog.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../rack_controller.dart';
import '../stage_presets.dart';
import 'param_controls.dart';

/// Every parameter of a featured stage, folded under its graphic editor.
class AllParams extends StatefulWidget {
  final FilterDescriptor d;
  final AudioEffect e;
  final RackController rack;
  final int id;
  const AllParams({
    super.key,
    required this.d,
    required this.e,
    required this.rack,
    required this.id,
  });

  @override
  State<AllParams> createState() => _AllParamsState();
}

class _AllParamsState extends State<AllParams> {
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
class PresetChips extends StatelessWidget {
  final FilterDescriptor d;
  final AudioEffect e;
  final RackController rack;
  final int id;
  const PresetChips({
    super.key,
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
class ModelFilePicker extends StatelessWidget {
  final FilterDescriptor d;
  final AudioEffect e;
  final RackController rack;
  final int id;
  const ModelFilePicker({
    super.key,
    required this.d,
    required this.e,
    required this.rack,
    required this.id,
  });

  Future<void> _choose(StringParam p) async {
    final XFile? file;
    try {
      file = await openFile();
    } on Object catch (err) {
      rack.reportError('The file picker could not open: $err');
      return;
    }
    if (file == null) return;
    rack.edit(id, d.setEnabled(p.set(e, file.path), true));
  }

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
        onPressed: () => _choose(p),
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
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.pill,
          child: Ink(
            height: context.layout.minTap,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            decoration: ShapeDecoration(
              color: active ? Tokens.accentContainer : Tokens.surface3,
              shape: Tokens.pill,
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: Tokens.label.copyWith(
                  color: active ? Tokens.onAccentContainer : Tokens.fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
