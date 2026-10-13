import 'package:flutter/material.dart';

import '../layout/layout_scope.dart';
import '../tokens.dart';

/// A flat back row for a pushed screen: a back chevron and a title, with
/// the whole row tappable, at least a tap target tall. Pages built on
/// `PageFrame` get the same affordance from its `onBack` instead.
class BackBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const BackBar({super.key, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.layout.isTouch ? 48 : 44,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
            child: Row(
              children: [
                Icon(Icons.chevron_left_rounded, size: 22, color: Tokens.fgDim),
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
