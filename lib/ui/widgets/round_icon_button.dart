import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/layout_scope.dart';
import '../tokens.dart';

/// How much a [RoundIconButton] stands out: the shape contrast of the
/// design language.
enum RoundTone {
  /// A bare icon in a circular hit area (tertiary actions).
  plain,

  /// A tonal circle ([Tokens.surface3]) behind the icon (secondary
  /// actions: previous and next, shell tools).
  tonal,

  /// A solid accent circle with [Tokens.onAccent] content (the one
  /// primary action of a view, such as play).
  primary,
}

/// The app's circular icon button: a full circle of [diameter] (never
/// less than the tap target), a tooltip, and screen reader semantics.
/// [active] marks a toggle that is on: it gets the secondary selection
/// fill ([Tokens.accentContainer]) whatever its [tone]. [label] names it
/// for screen readers when the tooltip says more; [toggled] marks an on
/// and off switch.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.onLongPress,
    this.tone = RoundTone.plain,
    this.size = 24,
    this.diameter,
    this.active = false,
    this.label,
    this.toggled,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final RoundTone tone;

  /// The icon size.
  final double size;

  /// The circle's diameter; defaults to (and is at least) the tap target.
  final double? diameter;
  final bool active;
  final String? label;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final minTap = context.layout.minTap;
    final d = math.max(diameter ?? minTap, minTap);
    final enabled = onTap != null;
    final (Color fill, Color color) = switch (tone) {
      _ when active => (Tokens.accentContainer, Tokens.onAccentContainer),
      RoundTone.primary => (
        enabled ? Tokens.accent : Tokens.surface4,
        enabled ? Tokens.onAccent : Tokens.fgFaint,
      ),
      RoundTone.tonal => (
        Tokens.surface3,
        enabled ? Tokens.fg : Tokens.fgFaint,
      ),
      RoundTone.plain => (
        Colors.transparent,
        enabled ? Tokens.fg : Tokens.fgFaint,
      ),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: toggled,
      label: label ?? tooltip,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: d,
          height: d,
          decoration: ShapeDecoration(color: fill, shape: const CircleBorder()),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              customBorder: const CircleBorder(),
              child: Center(
                child: Icon(icon, size: size, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
