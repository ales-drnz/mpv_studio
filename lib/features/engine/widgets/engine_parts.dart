import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';

/// One panel of the Engine view: a heading with an optional trailing state
/// pill over a tonal card.
class EngineCard extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget? trailing;
  final Widget child;

  const EngineCard({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.s16),
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.shape(Tokens.rLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: Tokens.heading),
                ),
              ),
              ?trailing,
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: Tokens.s4),
            Text(caption!, style: Tokens.label),
          ],
          const SizedBox(height: Tokens.s16),
          child,
        ],
      ),
    );
  }
}

/// A small status light with its label: lit in [color] (green by
/// default) when [on].
class Spy extends StatelessWidget {
  final String label;
  final bool on;
  final Color? color;

  const Spy({super.key, required this.label, required this.on, this.color});

  @override
  Widget build(BuildContext context) {
    final lit = color ?? Tokens.green;
    return Semantics(
      label: '$label ${on ? 'on' : 'off'}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 8,
            height: 8,
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: on ? lit : Tokens.surface4,
            ),
          ),
          const SizedBox(width: Tokens.s8),
          Text(
            label,
            style: Tokens.numeric.copyWith(
              color: on ? Tokens.fg : Tokens.fgFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill naming a state: [color] at 16% with the colour as text, or a
/// quiet tonal pill when not [strong].
class StatePill extends StatelessWidget {
  final String text;
  final Color color;
  final bool strong;

  const StatePill(
    this.text, {
    super.key,
    required this.color,
    this.strong = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.s12,
        vertical: Tokens.s4,
      ),
      decoration: ShapeDecoration(
        color: strong ? color.withValues(alpha: 0.16) : Tokens.surface3,
        shape: Tokens.pill,
      ),
      child: Text(
        text,
        style: Tokens.numeric.copyWith(
          color: strong ? color : Tokens.fgFaint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A caption over a monospace value, for the grids of readouts.
class Readout extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const Readout(this.label, this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Tokens.caption),
        const SizedBox(height: Tokens.s4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Tokens.numeric.copyWith(
            color: color ?? Tokens.fg,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// Lays [children] out in rows of equal-width cells, as many per row as
/// fit at [minCellWidth].
class ReadoutGrid extends StatelessWidget {
  final List<Widget> children;
  final double minCellWidth;

  const ReadoutGrid({
    super.key,
    required this.children,
    this.minCellWidth = 110,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final perRow = (c.maxWidth / minCellWidth).floor().clamp(
          1,
          children.length,
        );
        final cellWidth = c.maxWidth / perRow;
        return Wrap(
          runSpacing: Tokens.s12,
          children: [
            for (final child in children)
              SizedBox(width: cellWidth, child: child),
          ],
        );
      },
    );
  }
}

/// A thin pill progress track, filled to [fraction] in [color] (the
/// accent by default) over the inactive track tone.
class ThinBar extends StatelessWidget {
  final double fraction;
  final Color? color;
  final double height;

  const ThinBar({
    super.key,
    required this.fraction,
    this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const ShapeBorderClipper(shape: StadiumBorder()),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Tokens.surface4),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: color ?? Tokens.accent),
            ),
          ],
        ),
      ),
    );
  }
}
