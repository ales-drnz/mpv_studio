import 'package:flutter/material.dart';

import '../tokens.dart';

/// The flat in-page navigation header shown atop any pushed detail or
/// list screen: a back chevron + title, with the whole row tappable.
///
/// Shared so every grid→detail view and full-page list (e.g. the effects
/// catalog category screen) uses the *identical* bar — same height, glyph,
/// and title type — instead of a one-off Material [AppBar].
class BackBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const BackBar({super.key, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
            child: Row(
              children: [
                const Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: Tokens.fgDim,
                ),
                const SizedBox(width: Tokens.s4),
                Text(title, style: Tokens.heading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
