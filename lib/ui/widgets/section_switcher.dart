import 'package:flutter/material.dart';

/// The single transition shape used across the app's navigation: a gentle
/// fade plus a short horizontal slide. Shared by [SectionSwitcher] (an
/// in-page list to detail swap, as in `TwoPane`) and [fadeSlidePageRoute]
/// (pushed full-page routes), so every navigation reads the same.
const Duration kNavTransition = Duration(milliseconds: 220);
const Offset kNavSlideOffset = Offset(0.04, 0);

Widget _navTransition(Animation<double> animation, Widget child) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: kNavSlideOffset,
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

/// A pushed full-page route (over the shell) using the shared fade and
/// slide, so a push matches the in-page transitions.
Route<T> fadeSlidePageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: kNavTransition,
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) =>
        _navTransition(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child,
        ),
  );
}

/// Animates the in-page swap between a list and a detail drawn over it
/// (`TwoPane` on narrow windows) so the detail doesn't just snap in: the
/// flat equivalent of a push transition, without leaving the section's
/// shell.
///
/// The [child] must change its key when the view changes (e.g.
/// `KeyedSubtree(key: ValueKey(pushedIndex), …)`), otherwise there's
/// nothing for the switcher to cross-fade between.
class SectionSwitcher extends StatelessWidget {
  final Widget child;
  const SectionSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: kNavTransition,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => _navTransition(animation, child),
      // Full-bleed section bodies: let each child fill the stage instead of
      // the default centred layout, and keep the outgoing one beneath.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topLeft,
        children: [
          for (final c in previousChildren) Positioned.fill(child: c),
          ?currentChild,
        ],
      ),
      child: child,
    );
  }
}
