import 'package:flutter/foundation.dart';
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
    return ErrorCountBadge(count: issues.unseenLogErrors, child: child);
  }
}

/// A red badge with [count] on [child] while it is above zero.
class ErrorCountBadge extends StatelessWidget {
  const ErrorCountBadge({super.key, required this.count, required this.child});

  final ValueListenable<int> count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: count,
      child: child,
      // The number in the theme's badge ink (onAccent, 6.5:1 on the red
      // in both themes), and said as a sentence to screen readers.
      builder: (context, count, child) => Semantics(
        label: count > 0 ? '$count unseen errors' : null,
        child: Badge(
          isLabelVisible: count > 0,
          label: ExcludeSemantics(child: Text(count > 99 ? '99+' : '$count')),
          backgroundColor: Tokens.red,
          textColor: Tokens.onAccent,
          child: child,
        ),
      ),
    );
  }
}
