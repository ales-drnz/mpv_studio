import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';

/// One option of a [ChoiceRow].
class Choice<T> {
  const Choice(this.value, this.label, {this.disabledReason});

  final T value;
  final String label;

  /// Why the option cannot be picked now (its tooltip); null when it can.
  final String? disabledReason;
}

/// A labelled row of single-select chips that wraps on narrow widths.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.choices,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<Choice<T>> choices;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Tokens.label.copyWith(color: Tokens.fg)),
        const SizedBox(height: Tokens.s8),
        Wrap(
          spacing: Tokens.s8,
          runSpacing: Tokens.s8,
          children: [for (final c in choices) _chip(c)],
        ),
      ],
    );
  }

  Widget _chip(Choice<T> c) {
    final on = c.value == selected;
    final enabled = c.disabledReason == null;
    final chip = ChoiceChip(
      label: Text(c.label),
      selected: on,
      showCheckmark: false,
      selectedColor: Tokens.accentWash,
      backgroundColor: Tokens.surface2,
      disabledColor: Tokens.surface2,
      side: BorderSide(color: on ? Tokens.accent : Tokens.line2),
      labelStyle: Tokens.label.copyWith(
        color: !enabled
            ? Tokens.fgFaint
            : on
            ? Tokens.accent
            : Tokens.fg,
      ),
      onSelected: enabled ? (_) => onSelected(c.value) : null,
    );
    return enabled ? chip : Tooltip(message: c.disabledReason!, child: chip);
  }
}
