import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/tokens.dart';
import 'sections.dart';
import 'shell_frame.dart';

/// The navigation behaviour of the app around the routed section bodies
/// ([navigationShell]): section switching, the re-tap of the active
/// section, the system back button, and the root [Scaffold] that hosts
/// SnackBars. The chrome itself is [ShellFrame].
///
/// It needs no player, so tests run it with any [miniPlayer].
class StudioShell extends StatefulWidget {
  const StudioShell({
    super.key,
    required this.navigationShell,
    this.miniPlayer,
  });

  final StatefulNavigationShell navigationShell;

  /// Builds the mini-player, shown on every section but Playback.
  final MiniPlayerBuilder? miniPlayer;

  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  StatefulNavigationShell get _shell => widget.navigationShell;

  Section get _section => Section.values[_shell.currentIndex];

  NavigatorState? _branchNavigator(int index) =>
      _shell.route.branches[index].navigatorKey.currentState;

  Future<void> _select(Section section) async {
    if (section.index == _shell.currentIndex) {
      // Re-tapping the active section acts as Back within it: it closes the
      // branch's pushed detail (a route, or a TwoPane detail) if any, else
      // resets the branch to its first location.
      final nav = _branchNavigator(section.index);
      if (nav != null && await nav.maybePop()) return;
      _shell.goBranch(section.index, initialLocation: true);
      return;
    }
    _shell.goBranch(section.index);
  }

  /// The system back (Android back button, the predictive back gesture):
  /// close a sheet or dialog, else close the section's detail, else go
  /// back to Playback, else let the system leave the app.
  Future<bool> _onBack() async {
    final root = Navigator.maybeOf(context, rootNavigator: true);
    if (root != null && root.canPop()) {
      await root.maybePop();
      return true;
    }
    final branch = _branchNavigator(_shell.currentIndex);
    if (branch != null && await branch.maybePop()) return true;
    if (_section != Section.nowPlaying) {
      _shell.goBranch(Section.nowPlaying.index);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    final mini = widget.miniPlayer;
    return BackButtonListener(
      onBackButtonPressed: _onBack,
      // A root Scaffold gives ScaffoldMessenger a surface to host SnackBars
      // on (the shells themselves are custom, not Scaffolds). The shells
      // handle the soft keyboard themselves, so it must not resize.
      child: Scaffold(
        backgroundColor: Tokens.bg,
        resizeToAvoidBottomInset: false,
        body: ShellFrame(
          section: section,
          onSelect: _select,
          body: _shell,
          // Playback already shows the full transport.
          miniPlayer: section == Section.nowPlaying ? null : mini,
        ),
      ),
    );
  }
}
