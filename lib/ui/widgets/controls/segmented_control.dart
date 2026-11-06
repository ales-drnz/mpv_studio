import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../layout/layout_scope.dart';
import '../../tokens.dart';
import '../focus_ring.dart';
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

/// A flat pill of mutually-exclusive options. Used for short enum
/// picks (loop, gapless, cache mode, normalization, FFT window).
///
/// By default the segments share the width equally ([expand] `true`), up
/// to [maxExpandedWidth] from a medium window on, where a pill across a
/// whole card would only stretch three words apart; set [expand] `false`
/// for a compact pill that hugs its content, e.g. when it sits inline in
/// a toolbar next to other controls. On touch it is a full tap target
/// tall.
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

  /// The widest an expanded control grows outside a phone.
  static const double maxExpandedWidth = 360;

  @override
  Widget build(BuildContext context) {
    final pill = _pill(context);
    if (!expand || context.layout.isCompact) return pill;
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth <= maxExpandedWidth
          ? pill
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(width: maxExpandedWidth, child: pill),
            ),
    );
  }

  Widget _pill(BuildContext context) {
    Widget segment(SegmentOption<T> o) => _Segment(
      index: options.indexOf(o),
      label: o.label,
      tooltip: o.tooltip,
      active: o.value == selected,
      onTap: enabled ? () => onSelect(o.value) : null,
      hugContent: !expand,
    );
    // Left and Right move the pick, like a radio group, and stay here
    // instead of seeking the playback.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (!enabled || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
          return KeyEventResult.ignored;
        }
        final step = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowLeft => -1,
          LogicalKeyboardKey.arrowRight => 1,
          _ => 0,
        };
        if (step == 0) return KeyEventResult.ignored;
        // From the segment that has the focus, which Tab may have put on
        // one that is not picked.
        final focused = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<_Segment>();
        final at =
            focused?.index ?? options.indexWhere((o) => o.value == selected);
        final next = at + step;
        if (at >= 0 && next >= 0 && next < options.length) {
          onSelect(options[next].value);
          FocusManager.instance.primaryFocus?.focusInDirection(
            step < 0 ? TraversalDirection.left : TraversalDirection.right,
          );
        }
        return KeyEventResult.handled;
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: controlHeightOf(context),
          decoration: ShapeDecoration(
            color: Tokens.surface3,
            shape: Tokens.pill,
          ),
          padding: const EdgeInsets.all(Tokens.s4),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (final o in options)
                if (expand) Expanded(child: segment(o)) else segment(o),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  /// Its place among the options.
  final int index;
  final String label;
  final String? tooltip;
  final bool active;
  final VoidCallback? onTap;

  /// Adds lateral padding so the segment reads well when it sizes to its
  /// label instead of filling an equal share of the row.
  final bool hugContent;

  const _Segment({
    required this.index,
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
      // The visible label first, so a spoken name holds what shows.
      label: tooltip == null ? label : '$label, $tooltip',
      excludeSemantics: true,
      onTap: onTap,
      child: FocusRing(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: Tokens.pill,
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: hugContent ? Tokens.s12 : Tokens.s4,
              ),
              decoration: ShapeDecoration(
                color: active ? Tokens.accent : Colors.transparent,
                shape: Tokens.pill,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tokens.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Tokens.onAccent : Tokens.fgDim,
                ),
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
