import 'package:flutter/material.dart';

import '../../tokens.dart';
import 'control_metrics.dart';

/// One selectable option in a [SegmentedControl].
class SegmentOption<T> {
  final T value;
  final String label;

  /// The longer name read by screen readers and shown on hover, when the
  /// [label] is an abbreviation.
  final String? tooltip;

  const SegmentOption(this.value, this.label, {this.tooltip});
}

/// A flat rounded pill of mutually-exclusive options. Used for short enum
/// picks (loop, gapless, cache mode, normalization, FFT window).
///
/// By default the segments share the width equally ([expand] `true`); set
/// [expand] `false` for a compact pill that hugs its content, e.g. when it
/// sits inline in a toolbar next to other controls. On touch it is a full
/// tap target tall.
class SegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final bool expand;

  /// When false the options are dimmed and inert.
  final bool enabled;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.expand = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget segment(SegmentOption<T> o) => _Segment(
      label: o.label,
      tooltip: o.tooltip,
      active: o.value == selected,
      onTap: enabled ? () => onSelect(o.value) : null,
      hugContent: !expand,
    );
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: controlHeightOf(context),
        decoration: ShapeDecoration(
          color: Tokens.surface2,
          shape: Tokens.shape(Tokens.rSm),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (final o in options)
              if (expand) Expanded(child: segment(o)) else segment(o),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final String? tooltip;
  final bool active;
  final VoidCallback? onTap;

  /// Adds lateral padding so the segment reads well when it sizes to its
  /// label instead of filling an equal share of the row.
  final bool hugContent;

  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
    this.tooltip,
    this.hugContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final segment = Semantics(
      button: true,
      selected: active,
      inMutuallyExclusiveGroup: true,
      label: tooltip ?? label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.shape(Tokens.rSm - 2),
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: hugContent ? Tokens.s8 : Tokens.s2,
            ),
            decoration: ShapeDecoration(
              color: active ? Tokens.accent : Colors.transparent,
              shape: Tokens.shape(Tokens.rSm - 2),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? Tokens.onAccent : Tokens.fgDim,
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return segment;
    return Tooltip(message: tooltip!, child: segment);
  }
}
