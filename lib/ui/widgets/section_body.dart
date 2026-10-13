import 'package:flutter/material.dart';

import '../layout/layout_scope.dart';
import '../tokens.dart';
import 'controls.dart';
import 'section_header.dart';

/// Standard scrollable body for a section: a column with the window
/// class's page padding (`context.layout.pagePadding`) unless [padding] is
/// given. It fills the full stage width; pages that want a readable width
/// cap use `PageFrame` instead.
class SectionBody extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;

  const SectionBody({
    super.key,
    required this.children,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding ?? context.layout.pagePadding,
      child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
    );
  }
}

/// A labelled group of settings rows inside a single flat card. The
/// label sits above the card in caption type; rows sit flush, separated
/// only by their own vertical rhythm.
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
            decoration: ShapeDecoration(
              color: Tokens.surface,
              shape: Tokens.squircle(Tokens.rMd),
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
