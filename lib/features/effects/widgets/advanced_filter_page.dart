import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../generated/filter_catalog.dart';
import '../../../studio/player_scope.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/back_bar.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../effects_chain.dart';

/// The dedicated editor for one **advanced** (required-param) filter —
/// `chorus`, `pan`, `channelmap`, `aeval`, `arnndn`. These can't be safely
/// bulk-toggled (a bare construction fails to init in mpv), so each gets its
/// own page where the user picks a curated [FilterPreset], types a custom
/// value, or (for `arnndn`) selects a model file. The filter is only ever
/// enabled once it holds valid values, so it can never enter the `af` chain
/// in a broken state. Driven entirely by the logical [FilterDescriptor].
class AdvancedFilterPage extends StatefulWidget {
  final FilterDescriptor spec;
  const AdvancedFilterPage({super.key, required this.spec});

  @override
  State<AdvancedFilterPage> createState() => _AdvancedFilterPageState();
}

class _AdvancedFilterPageState extends State<AdvancedFilterPage> {
  late final Player _player = PlayerScope.of(context);

  /// Buffered custom edits, keyed by ffmpeg option name. Merged over the live
  /// values on Apply, so editing one field never clears the others.
  final Map<String, String> _pending = {};

  FilterDescriptor get _spec => widget.spec;

  /// The mandatory free-form params (one custom field each).
  List<StringParam> get _strParams =>
      _spec.params.whereType<StringParam>().where((p) => p.required).toList();

  bool _valid(Map<String, String> values) =>
      _strParams.every((p) => (values[p.name] ?? '').trim().isNotEmpty);

  Map<String, String> _merged(List<AudioEffect> fx) => {
        for (final p in _strParams) p.name: p.get(_spec.stageIn(fx)),
        ..._pending,
      };

  void _apply(List<AudioEffect> fx,
      {required bool enabled, Map<String, String>? values}) {
    final v = values ?? _merged(fx);
    _player.updateAudioEffects((chain) => _spec.edit(chain, (e) {
          var next = e;
          for (final p in _strParams) {
            final val = v[p.name];
            if (val != null) next = p.set(next, val);
          }
          return _spec.setEnabled(next, enabled);
        }));
  }

  /// Copies a bundled asset (e.g. `assets/models/general.rnnn`) to a stable
  /// temp file the engine can open, returning its filesystem path.
  Future<String> _materializeAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final name = assetPath.split('/').last;
    final dir = Directory('${Directory.systemTemp.path}/mpv_studio_models');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  Future<void> _applyPreset(List<AudioEffect> fx, FilterPreset preset) async {
    var values = preset.values;
    final fp = _spec.fileParam;
    // A file-backed preset points at a bundled asset — materialize it first.
    if (_spec.fileBacked && fp != null && preset.values[fp] != null) {
      values = {fp: await _materializeAsset(preset.values[fp]!)};
    }
    if (!mounted) return;
    setState(() => _pending
      ..clear()
      ..addAll(values));
    _apply(fx, enabled: true, values: values);
  }

  Future<void> _pickFile(List<AudioEffect> fx) async {
    final fp = _spec.fileParam;
    if (fp == null) return;
    final file = await openFile();
    if (file == null || !mounted) return;
    setState(() => _pending[fp] = file.path);
    _apply(fx, enabled: true, values: {fp: file.path});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            BackBar(
              title: _spec.title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: StreamBuilder<List<AudioEffect>>(
                stream: _player.stream.audioEffects,
                initialData: _player.state.audioEffects,
                builder: (context, snap) => _body(snap.data!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(List<AudioEffect> fx) {
    final enabled = _spec.isEnabled(fx);
    final canEnable = _valid(_merged(fx));

    return SectionBody(
      children: [
        // ── Bypass ──────────────────────────────────────────────────────
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
          child: SwitchRow(
            label: 'Effect',
            subtitle: _spec.wire,
            value: enabled,
            enabled: canEnable || enabled,
            onChanged: (on) {
              if (on && !_valid(_merged(fx))) {
                if (_spec.presets.isNotEmpty) _applyPreset(fx, _spec.presets.first);
                return;
              }
              _apply(fx, enabled: on, values: _merged(fx));
            },
          ),
        ),

        // ── Presets ─────────────────────────────────────────────────────
        if (_spec.presets.isNotEmpty)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Presets', style: Tokens.heading),
                const SizedBox(height: 2),
                Text(
                  _spec.fileBacked
                      ? 'Bundled noise-reduction models'
                      : 'One-tap valid starting points',
                  style: Tokens.caption,
                ),
                const SizedBox(height: Tokens.s12),
                Wrap(
                  spacing: Tokens.s8,
                  runSpacing: Tokens.s8,
                  children: [
                    for (final preset in _spec.presets)
                      _PresetChip(
                        label: preset.name,
                        active: _presetActive(fx, preset, enabled),
                        onTap: () => _applyPreset(fx, preset),
                      ),
                  ],
                ),
              ],
            ),
          ),

        // ── Custom: inline value(s) ─────────────────────────────────────
        if (!_spec.fileBacked)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Custom', style: Tokens.heading),
                ),
                for (final p in _strParams)
                  TextRow(
                    label: p.name,
                    value: _pending[p.name] ?? p.get(_spec.stageIn(fx)),
                    hint: _spec.presets.isNotEmpty
                        ? 'e.g. ${_spec.presets.first.values[p.name] ?? ''}'
                        : null,
                    onChanged: (v) => _pending[p.name] = v,
                  ),
                const SizedBox(height: Tokens.s4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _valid(_merged(fx))
                        ? () => _apply(fx, enabled: true, values: _merged(fx))
                        : null,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Apply'),
                    style: TextButton.styleFrom(
                      foregroundColor: Tokens.accent,
                      textStyle: Tokens.label,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Custom: your own model file (arnndn) ────────────────────────
        if (_spec.fileBacked)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Custom', style: Tokens.heading),
                const SizedBox(height: 2),
                const Text('Use your own model file', style: Tokens.caption),
                const SizedBox(height: Tokens.s8),
                ValueBadge(_currentFileName(fx)),
                const SizedBox(height: Tokens.s12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _pickFile(fx),
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Choose file…'),
                    style: TextButton.styleFrom(
                      foregroundColor: Tokens.accent,
                      textStyle: Tokens.label,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _currentFileName(List<AudioEffect> fx) {
    final fp = _spec.fileParam;
    if (fp == null) return '';
    final p = _strParams.firstWhere((p) => p.name == fp);
    final cur = p.get(_spec.stageIn(fx));
    return cur.isEmpty ? 'No file selected' : cur.split('/').last;
  }

  /// Whether [preset] is the active selection. For file-backed presets the
  /// live value is a materialized temp path, so compare basenames.
  bool _presetActive(List<AudioEffect> fx, FilterPreset preset, bool enabled) {
    if (!enabled) return false;
    if (_spec.fileBacked) {
      final fp = _spec.fileParam;
      if (fp == null) return false;
      final cur =
          _strParams.firstWhere((p) => p.name == fp).get(_spec.stageIn(fx));
      final want = preset.values[fp] ?? '';
      return cur.isNotEmpty && cur.split('/').last == want.split('/').last;
    }
    return preset.values.entries.every((e) {
      final p = _strParams.where((p) => p.name == e.key);
      return p.isNotEmpty && p.first.get(_spec.stageIn(fx)) == e.value;
    });
  }
}

/// A flat bordered surface card framing one block of the editor.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(Tokens.s16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.s12),
      padding: padding,
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      child: child,
    );
  }
}

/// A tappable preset pill — accent-filled when it's the active selection.
class _PresetChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: Tokens.squircle(Tokens.rSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Tokens.s12, vertical: Tokens.s8),
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
