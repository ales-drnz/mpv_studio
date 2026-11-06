import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../studio/player_scope.dart';
import 'mini_player.dart';
import 'playback_notice_host.dart';
import 'playback_shortcuts.dart';
import 'sections.dart';
import 'studio_shell.dart';

/// Root chrome of the running app: the [StudioShell] around the routed
/// section bodies (carried by [navigationShell]), wired to the player. It
/// adds the mini-player, the keyboard shortcuts (any device with keys), and
/// readable playback errors as SnackBars ([PlaybackNoticeHost]). The
/// bodies live in a single keep-alive IndexedStack built by the router, so
/// player subscriptions (and the Now Playing visualizers) survive section
/// switches.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final section = Section.values[navigationShell.currentIndex];
    final player = PlayerScope.of(context);
    final rack = PlayerScope.rackOf(context);
    final guard = PlayerScope.issuesOf(context).guard;
    return PlaybackNoticeHost(
      consoleVisible: section == Section.console,
      onShowLog: () => navigationShell.goBranch(Section.console.index),
      // The keys work wherever a keyboard sends them, a tablet's too; a
      // touch screen alone sends none.
      child: PlaybackShortcuts(
        player: player,
        guard: guard,
        rack: rack,
        child: StudioShell(
          navigationShell: navigationShell,
          miniPlayer: (context, variant) => MiniPlayer(
            player: player,
            rack: rack,
            variant: variant,
            guard: guard,
            onOpen: () => navigationShell.goBranch(Section.nowPlaying.index),
          ),
        ),
      ),
    );
  }
}
