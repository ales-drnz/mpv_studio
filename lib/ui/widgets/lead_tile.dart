import 'package:flutter/material.dart';

import '../tokens.dart';

/// The content of a row led by an icon in a circle: a settings group, an
/// onboarding choice. The row's own fill, tap and padding stay with the
/// caller; this is the one layout of the circle, the two lines and the
/// [trailing] widget.
class LeadTile extends StatelessWidget {
  const LeadTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.color,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// The text colour, for a row on a selection fill; null for the
  /// theme's.
  final Color? color;

  /// The row is on the selection fill: the circle inverts, so it reads as
  /// a mark rather than a hole in the fill.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LeadCircle(icon: icon, selected: selected),
        const SizedBox(width: Tokens.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Tokens.heading.copyWith(color: color)),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: Tokens.s4),
                Text(
                  subtitle,
                  style: Tokens.label.copyWith(color: color ?? Tokens.fgDim),
                ),
              ],
            ],
          ),
        ),
        if (trailing case final trailing?) ...[
          const SizedBox(width: Tokens.s8),
          trailing,
        ],
      ],
    );
  }
}

/// The icon in a circle that leads a [LeadTile] or a header (a sign-in
/// form): [Tokens.leadSize] across by default, the field tone with the
/// icon in [Tokens.fg], inverted on a selection fill.
class LeadCircle extends StatelessWidget {
  const LeadCircle({
    super.key,
    required this.icon,
    this.size = Tokens.leadSize,
    this.selected = false,
  });

  final IconData icon;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: selected ? Tokens.onAccentContainer : Tokens.surface3,
          shape: const CircleBorder(),
        ),
        child: Icon(
          icon,
          size: size > Tokens.leadSize ? Tokens.iconLg : Tokens.iconMd,
          color: selected ? Tokens.accentContainer : Tokens.fg,
        ),
      ),
    );
  }
}
