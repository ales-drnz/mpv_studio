import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../studio/player_scope.dart';
import '../ui/tokens.dart';
import 'desktop_shell.dart';
import 'mini_player.dart';
import 'mobile_shell.dart';
import 'playback_notice_host.dart';
import 'playback_shortcuts.dart';
import 'router.dart';
import 'sections.dart';

/// Root chrome. Wraps the routed section bodies (carried by
/// [navigationShell]) in the desktop or mobile shell depending on width, and
/// surfaces readable playback errors as SnackBars ([PlaybackNoticeHost]). The bodies themselves live in a
/// single keep-alive IndexedStack built by the router, so player
/// subscriptions (and the Now Playing visualizers) survive section switches.
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  void _select(Section section) {
    final shell = widget.navigationShell;
    if (section.index == shell.currentIndex) {
      // Re-tapping the active icon acts as Back: pop this branch's own pushed
      // detail (e.g. an opened settings category) if there is one. These are
      // raw Navigator.push routes that go_router doesn't track, so goBranch
      // alone wouldn't clear them.
      final nav = branchNavigatorKeys[section.index].currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
        return;
      }
      // Already at the branch root — reset it to its initial location.
      shell.goBranch(section.index, initialLocation: true);
      return;
    }
    shell.goBranch(section.index);
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final section = Section.values[navigationShell.currentIndex];
    final player = PlayerScope.of(context);
    final guard = PlayerScope.issuesOf(context).guard;
    // The mini-player rides along everywhere but Playback, which already
    // shows the full transport.
    Widget? mini(bool compact) => section == Section.nowPlaying
        ? null
        : MiniPlayer(
            player: player,
            rack: PlayerScope.rackOf(context),
            compact: compact,
            guard: guard,
            onOpen: () => _select(Section.nowPlaying),
          );

    // A root Scaffold gives ScaffoldMessenger a surface to host SnackBars on
    // (the shells themselves are custom, not Scaffolds).
    final scaffold = Scaffold(
      backgroundColor: Tokens.bg,
      // The bottom tab bar must stay pinned when the soft keyboard opens — the
      // mobile shell lifts only the body content above the keyboard itself
      // (see [MobileShell]). Letting the Scaffold resize would push the bar up.
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= Tokens.desktopBreakpoint;
          return PlaybackShortcuts(
            player: player,
            enabled: desktop,
            guard: guard,
            child: desktop
                ? DesktopShell(
                    section: section,
                    onSelect: _select,
                    body: navigationShell,
                    miniPlayer: mini(false),
                  )
                : MobileShell(
                    section: section,
                    onSelect: _select,
                    body: navigationShell,
                    miniPlayer: mini(true),
                  ),
          );
        },
      ),
    );
    return PlaybackNoticeHost(
      consoleVisible: section == Section.console,
      onShowLog: () => navigationShell.goBranch(Section.console.index),
      child: scaffold,
    );
  }
}
