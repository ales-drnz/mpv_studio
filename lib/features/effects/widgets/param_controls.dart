import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../generated/filter_catalog.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';

/// Writes a new value of a stage. `live` marks a control that moves
/// continuously (a slider drag), which the rack throttles.
typedef StageChange = void Function(AudioEffect next, {bool live});

/// The app control for one [ParamSpec] of [stage]: the single place that
/// maps a logical parameter to a widget, for any filter.
///
/// Sliders write live while dragged and [onEnd] on release; switches and
/// menus write at once; text writes on submit, since a half typed value
/// would only make mpv refuse the chain.
Widget buildParamControl(
  ParamSpec p,
  AudioEffect stage, {
  required StageChange onChange,
  required VoidCallback onEnd,
  bool enabled = true,
}) {
  switch (p) {
    case DoubleParam d:
      return SliderRow(
        label: d.name,
        value: d.get(stage).clamp(d.min, d.max),
        min: d.min,
        max: d.max,
        resetTo: d.def,
        enabled: enabled,
        format: _fmt,
        onChanged: (v) => onChange(d.set(stage, v), live: true),
        onChangeEnd: (_) => onEnd(),
      );
    case IntParam d:
      return SliderRow(
        label: d.name,
        value:
            d.get(stage).toDouble().clamp(d.min.toDouble(), d.max.toDouble()),
        min: d.min.toDouble(),
        max: d.max.toDouble(),
        divisions: (d.max - d.min) > 0 && (d.max - d.min) <= 64
            ? d.max - d.min
            : null,
        resetTo: d.def.toDouble(),
        enabled: enabled,
        format: (v) => v.round().toString(),
        onChanged: (v) {
          final n = v.round();
          if (n != d.get(stage)) onChange(d.set(stage, n), live: true);
        },
        onChangeEnd: (_) => onEnd(),
      );
    case BoolParam b:
      return SwitchRow(
        label: b.name,
        value: b.get(stage),
        enabled: enabled,
        onChanged: (v) => onChange(b.set(stage, v)),
      );
    case EnumParam en:
      return DropdownRow<Object>(
        label: en.name,
        value: en.get(stage),
        hint: 'default',
        items: [
          for (final o in en.options)
            DropdownMenuItem<Object>(value: o.value, child: Text(o.label)),
        ],
        onChanged: (v) {
          if (v != null) onChange(en.set(stage, v));
        },
      );
    case StringParam s:
      return SubmitTextRow(
        label: s.name,
        value: s.get(stage),
        enabled: enabled,
        onSubmit: (v) => onChange(s.set(stage, v)),
      );
  }
}

String _fmt(double v) {
  final a = v.abs();
  if (a >= 1000) return v.toStringAsFixed(0);
  if (a >= 100) return v.toStringAsFixed(1);
  if (a >= 0.01 || v == 0) return v.toStringAsFixed(2);
  return v.toStringAsExponential(1);
}

/// A monospace text field that writes on Enter or with its Apply button,
/// for values mpv parses as a whole: a filter option or a lavfi entry.
class SubmitTextRow extends StatefulWidget {
  final String label;
  final String? description;
  final String value;
  final String? hint;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String> onSubmit;

  const SubmitTextRow({
    super.key,
    required this.label,
    required this.value,
    required this.onSubmit,
    this.description,
    this.hint,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  State<SubmitTextRow> createState() => _SubmitTextRowState();
}

class _SubmitTextRowState extends State<SubmitTextRow> {
  late final TextEditingController _text =
      TextEditingController(text: widget.value);

  bool get _dirty => _text.text != widget.value;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(SubmitTextRow old) {
    super.didUpdateWidget(old);
    // Follow the stage (a rollback, a preset) unless the user is editing.
    if (old.value != widget.value && _text.text == old.value) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_dirty) widget.onSubmit(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final field = Container(
      constraints: const BoxConstraints(minHeight: Tokens.controlH),
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: widget.maxLines,
              onSubmitted: (_) => _submit(),
              style: Tokens.body.copyWith(
                fontFamily: Tokens.mono,
                color: widget.enabled ? Tokens.fg : Tokens.fgFaint,
              ),
              cursorColor: Tokens.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: Tokens.s8),
                hintText: widget.hint,
                hintStyle: Tokens.caption,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Apply',
            visualDensity: VisualDensity.compact,
            onPressed: widget.enabled && _dirty ? _submit : null,
            icon: Icon(
              Icons.check_rounded,
              size: 16,
              color: _dirty ? Tokens.accent : Tokens.fgFaint,
            ),
          ),
        ],
      ),
    );
    return SettingTile(
      title: widget.label,
      description: widget.description,
      enabled: widget.enabled,
      below: field,
    );
  }
}
