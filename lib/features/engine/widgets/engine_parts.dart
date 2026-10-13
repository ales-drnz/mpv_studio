import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';

/// One panel of the Engine view: a caption title with an optional trailing
/// readout over a flat squircle card.
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
      padding: const EdgeInsets.fromLTRB(
        Tokens.s16,
        Tokens.s12,
        Tokens.s16,
        Tokens.s16,
      ),
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: Tokens.caption.copyWith(
                    color: Tokens.fgDim,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: Tokens.s2),
            Text(caption!, style: Tokens.caption),
          ],
          const SizedBox(height: Tokens.s12),
          child,
        ],
      ),
    );
  }
}

/// A small status light with its label: lit in [color] when [on].
class Spy extends StatelessWidget {
  final String label;
  final bool on;
  final Color color;

  const Spy({
    super.key,
    required this.label,
    required this.on,
    this.color = Tokens.green,
  });

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? color : Tokens.surface3,
              border: Border.all(color: on ? color : Tokens.line2),
            ),
          ),
          const SizedBox(width: Tokens.s6),
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

/// A filled squircle chip naming a state, tinted by [color].
class StatePill extends StatelessWidget {
  final String text;
  final Color color;
  final bool strong;

  const StatePill(this.text,
      {super.key, required this.color, this.strong = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s8, vertical: 3),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: strong ? 0.18 : 0.08),
        shape: Tokens.squircle(Tokens.rSm),
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
        const SizedBox(height: Tokens.s2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Tokens.numeric.copyWith(
            color: color ?? Tokens.fg,
            fontSize: 12.5,
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
        final perRow =
            (c.maxWidth / minCellWidth).floor().clamp(1, children.length);
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

/// A thin rounded progress track, filled to [fraction] in [color].
class ThinBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;

  const ThinBar({
    super.key,
    required this.fraction,
    this.color = Tokens.accent,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Tokens.surface3),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
