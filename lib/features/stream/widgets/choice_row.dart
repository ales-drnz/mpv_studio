import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';

/// One option of a [ChoiceRow].
class Choice<T> {
  const Choice(this.value, this.label, {this.disabledReason});

  final T value;
  final String label;

  /// Why the option cannot be picked now (its tooltip); null when it can.
  final String? disabledReason;
}

/// A labelled row of single-select pills that wraps on narrow widths: the
/// picked one in the secondary selection fill, the others tonal.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.description,
  });

  final String label;

  /// A line under the label.
  final String? description;
  final List<Choice<T>> choices;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Tokens.body.copyWith(fontWeight: FontWeight.w500)),
        if (description != null) ...[
          const SizedBox(height: Tokens.s4),
          Text(
            description!,
            style: Tokens.label.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
        const SizedBox(height: Tokens.s8),
        Wrap(
          spacing: Tokens.s8,
          runSpacing: Tokens.s8,
          children: [
            for (final c in choices)
              _ChoicePill(
                choice: c,
                on: c.value == selected,
                onSelected: onSelected,
              ),
          ],
        ),
      ],
    );
  }
}

class _ChoicePill<T> extends StatelessWidget {
  const _ChoicePill({
    required this.choice,
    required this.on,
    required this.onSelected,
  });

  final Choice<T> choice;
  final bool on;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = choice.disabledReason == null;
    final pill = Semantics(
      button: true,
      selected: on,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      label: choice.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? () => onSelected(choice.value) : null,
          customBorder: Tokens.pill,
          child: Ink(
            height: controlHeightOf(context),
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            decoration: ShapeDecoration(
              color: on ? Tokens.accentContainer : Tokens.surface3,
              shape: Tokens.pill,
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                choice.label,
                maxLines: 1,
                style: Tokens.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: !enabled
                      ? Tokens.fgFaint
                      : on
                      ? Tokens.onAccentContainer
                      : Tokens.fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return enabled
        ? pill
        : Tooltip(message: choice.disabledReason!, child: pill);
  }
}
