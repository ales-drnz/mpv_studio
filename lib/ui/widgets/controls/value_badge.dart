import 'package:flutter/material.dart';

import '../../layout/layout_scope.dart';
import '../../tokens.dart';

/// A read-only value, set in a small squircle chip and aligned flush to the
/// trailing edge. The single way settings values are shown.
class ValueBadge extends StatelessWidget {
  final String text;
  final Color? color;
  const ValueBadge(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s8, vertical: 4),
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: Tokens.numeric.copyWith(color: color ?? Tokens.fgDim),
      ),
    );
  }
}

/// A small text button in the badge style, for the trailing action of a
/// settings row ("Choose", "Save", "Clear"). At least one tap target tall
/// on touch; [accent] marks the primary action.
class TileButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool accent;

  /// The longer description read by screen readers and shown on hover;
  /// defaults to [label].
  final String? tooltip;

  const TileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.accent = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? Tokens.fgFaint
        : accent
        ? Tokens.accent
        : Tokens.fgDim;
    final button = Semantics(
      button: true,
      enabled: enabled,
      label: tooltip ?? label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: Tokens.squircle(Tokens.rSm),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: context.layout.minTap,
              minWidth: context.layout.minTap,
            ),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.s12,
                  vertical: Tokens.s6,
                ),
                decoration: ShapeDecoration(
                  color: Tokens.surface2,
                  shape: Tokens.squircle(Tokens.rSm),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tokens.label.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
