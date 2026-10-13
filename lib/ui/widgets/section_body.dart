import 'package:flutter/material.dart';

import '../tokens.dart';
import 'controls.dart';
import 'section_header.dart';

/// A labelled group of settings rows inside a single tonal card (radius
/// [Tokens.rLg]). The label sits above the card, inset like the rows;
/// rows sit flush, separated only by their own vertical rhythm.
class SettingsGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const SettingsGroup({super.key, required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    // Each row carries its own horizontal padding and vertical rhythm; the
    // rows sit flush in the surface card with no separating lines.
    final rows = <Widget>[
      for (final child in children)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
          child: child,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(label),
          Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.symmetric(vertical: Tokens.s4),
            decoration: ShapeDecoration(
              color: Tokens.surface,
              shape: Tokens.shape(Tokens.rLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

/// A static title/value row for read-only info (About panel, stats).
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SettingTile(title: label, trailing: ValueBadge(value));
  }
}
