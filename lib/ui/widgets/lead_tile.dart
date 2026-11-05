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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// The text colour, for a row on a selection fill; null for the
  /// theme's.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: Tokens.leadSize,
            height: Tokens.leadSize,
            decoration: ShapeDecoration(
              color: Tokens.surface3,
              shape: const CircleBorder(),
            ),
            child: Icon(icon, size: Tokens.iconMd, color: Tokens.fg),
          ),
        ),
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
