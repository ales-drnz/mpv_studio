import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/layout_scope.dart';
import '../tokens.dart';

/// How much a [RoundIconButton] stands out: the shape contrast of the
/// design language.
enum RoundTone {
  /// A bare icon in a circular hit area (tertiary actions).
  plain,

  /// A tonal circle ([Tokens.tonal]) behind the icon (secondary
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
/// and off switch. [color] tints the icon of a [RoundTone.plain] or
/// [RoundTone.tonal] button, for one that shows a state in its tint.
/// [selected] marks a button that is the selected one of a set or a
/// toggle shown as selected (a favourite): it gets the same fill as
/// [active] and says "selected" to screen readers. [onContainer] draws
/// it for a surface already in the secondary selection fill (the current
/// row): the icon in [Tokens.onAccentContainer], a hover wash of that
/// tone, and no fill of its own.
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
    this.color,
    this.selected,
    this.onContainer = false,
    this.badge,
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
  final Color? color;

  /// Selected (a set's current one, or a toggle shown as selected); null
  /// for a button with no selected state.
  final bool? selected;

  /// Whether the button sits on the secondary selection fill.
  final bool onContainer;

  /// A short count on the icon (the number of options set); null for
  /// none.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final minTap = context.layout.minTap;
    final d = math.max(diameter ?? minTap, minTap);
    final enabled = onTap != null;
    final on = active || (selected ?? false);
    final (Color fill, Color color) = switch (tone) {
      _ when onContainer => (
        Colors.transparent,
        enabled
            ? Tokens.onAccentContainer
            : Tokens.onAccentContainer.withValues(alpha: 0.5),
      ),
      _ when on => (Tokens.accentContainer, Tokens.onAccentContainer),
      RoundTone.primary => (
        enabled ? Tokens.accent : Tokens.surface4,
        enabled ? Tokens.onAccent : Tokens.fgFaint,
      ),
      RoundTone.tonal => (
        Tokens.tonal,
        enabled ? this.color ?? Tokens.onTonal : Tokens.fgFaint,
      ),
      RoundTone.plain => (
        Colors.transparent,
        enabled ? this.color ?? Tokens.fg : Tokens.fgFaint,
      ),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: toggled,
      selected: selected,
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
              hoverColor: onContainer
                  ? Tokens.onAccentContainer.withValues(alpha: 0.10)
                  : null,
              child: Center(
                child: Badge(
                  isLabelVisible: badge != null,
                  label: badge == null ? null : Text(badge!),
                  backgroundColor: Tokens.accent,
                  textColor: Tokens.onAccent,
                  child: Icon(icon, size: size, color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
