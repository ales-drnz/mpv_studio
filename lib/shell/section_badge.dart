import 'package:flutter/material.dart';

import '../studio/player_scope.dart';
import '../ui/tokens.dart';
import 'sections.dart';

/// Puts the count of unseen mpv errors on the Console's navigation icon.
/// Any other section gets its [child] back untouched.
class SectionBadge extends StatelessWidget {
  const SectionBadge({super.key, required this.section, required this.child});

  final Section section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final issues = PlayerScope.maybeIssuesOf(context);
    if (section != Section.console || issues == null) return child;
    return ValueListenableBuilder<int>(
      valueListenable: issues.unseenLogErrors,
      child: child,
      builder: (context, count, child) => Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: Tokens.red,
        textColor: Tokens.fg,
        child: child,
      ),
    );
  }
}
