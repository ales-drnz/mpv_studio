import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../ui/tokens.dart';
import 'sections.dart';
import 'shell_frame.dart';
import 'snack_clearance.dart';

/// The navigation behaviour of the app around the routed section bodies
/// ([navigationShell]): section switching (also Ctrl+1 to Ctrl+7, which
/// put the focus in the page), the re-tap of the active section, the
/// system back button and Escape, and the root [Scaffold] that hosts
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

  /// The section body's focus: a section switch puts the focus here, so
  /// Tab goes on into the page and the page's own keys (Ctrl+F) work.
  final _page = FocusNode(debugLabel: 'section page', skipTraversal: true);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  /// Puts the focus in the section body once the switch is built.
  void _focusPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _page.requestFocus();
    });
  }

  /// Ctrl+1 to Ctrl+7 (Cmd on macOS) open the sections in order; Escape
  /// closes the open section's detail when nothing below took it.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape &&
        !keys.isControlPressed &&
        !keys.isMetaPressed &&
        !keys.isAltPressed &&
        !keys.isShiftPressed) {
      _branchNavigator(_shell.currentIndex)?.maybePop();
      return KeyEventResult.handled;
    }
    if ((keys.isControlPressed || keys.isMetaPressed) &&
        !keys.isAltPressed &&
        !keys.isShiftPressed) {
      final index = _digits.indexOf(key);
      if (index >= 0 && index < Section.values.length) {
        _select(Section.values[index]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
  ];

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
    _focusPage();
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
    // Android's predictive back only reaches the app when the framework
    // has told the system it handles back; otherwise the system closes the
    // app at once. Off Playback the shell always handles it (back goes to
    // Playback), so this scope blocks the pop there, which is what reports
    // it. Sheets and pushed details report themselves.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: PopScope(
        canPop: section == Section.nowPlaying,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: BackButtonListener(
          onBackButtonPressed: _onBack,
          // A root Scaffold gives ScaffoldMessenger a surface to host SnackBars
          // on (the shells themselves are custom, not Scaffolds). The shells
          // handle the soft keyboard themselves, so it must not resize. The
          // clearance host floats the SnackBars above the shell chrome.
          child: SnackClearanceHost(
            child: Scaffold(
              backgroundColor: Tokens.bg,
              resizeToAvoidBottomInset: false,
              body: ShellFrame(
                section: section,
                onSelect: _select,
                body: Focus(focusNode: _page, child: _shell),
                // Playback already shows the full transport.
                miniPlayer: section == Section.nowPlaying ? null : mini,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
