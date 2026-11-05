import 'package:flutter/material.dart';

import '../tokens.dart';

/// A state that is read, not set: a dot and a label, with no fill, so it
/// never looks like a button. A lit dot is solid in [color]; an unlit one
/// ([on] false) is a ring at 3:1, so the state reads without colour.
class StatePill extends StatelessWidget {
  const StatePill(
    this.label, {
    super.key,
    this.on = true,
    this.color,
    this.tooltip,
  });

  final String label;
  final bool on;

  /// The lit dot's colour; the accent by default.
  final Color? color;

  /// What the state is (an engine property name, say).
  final String? tooltip;

  /// The dot's diameter.
  static const double dot = 8;

  @override
  Widget build(BuildContext context) {
    final pill = Semantics(
      label: '$label, ${on ? 'on' : 'off'}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot,
            height: dot,
            decoration: ShapeDecoration(
              color: on ? color ?? Tokens.accent : Colors.transparent,
              shape: CircleBorder(
                side: on
                    ? BorderSide.none
                    : BorderSide(color: Tokens.trackOff, width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: Tokens.s8),
          Flexible(
            child: Text(
              label,
              style: Tokens.label.copyWith(
                color: on ? Tokens.fg : Tokens.fgDim,
              ),
            ),
          ),
        ],
      ),
    );
    if (tooltip == null) return pill;
    return Tooltip(message: tooltip!, child: pill);
  }
}
