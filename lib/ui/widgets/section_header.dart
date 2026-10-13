import 'package:flutter/material.dart';

import '../tokens.dart';

/// The app-wide label above a group of content, as written, in the
/// accent, inset by the card padding ([Tokens.s16]) so it lines up with
/// the rows of the card below. One widget so every group ("Featured",
/// "All effects", settings categories, stream groups, info-sheet
/// sections) reads identically.
class SectionHeader extends StatelessWidget {
  final String label;
  const SectionHeader(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.s16,
          Tokens.s8,
          Tokens.s16,
          Tokens.s8,
        ),
        child: Text(
          label,
          style: Tokens.label.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Tokens.accent,
          ),
        ),
      ),
    );
  }
}
