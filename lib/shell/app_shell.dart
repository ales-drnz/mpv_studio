import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/queue/queue_controller.dart';
import '../studio/player_scope.dart';
import '../ui/layout/layout.dart';
import 'file_drop_host.dart';
import 'mini_player.dart';
import 'playback_notice_host.dart';
import 'playback_shortcuts.dart';
import 'sections.dart';
import 'studio_shell.dart';
import 'ui_memory.dart';

/// Root chrome of the running app: the [StudioShell] around the routed
/// section bodies (carried by [navigationShell]), wired to the player. It
/// adds the mini-player, the keyboard shortcuts on pointer devices, and
/// readable playback errors as SnackBars ([PlaybackNoticeHost]), and takes
/// files dropped anywhere on the window into the queue ([FileDropHost]). The
/// bodies live in a single keep-alive IndexedStack built by the router, so
/// player subscriptions (and the Now Playing visualizers) survive section
/// switches.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final section = Section.values[navigationShell.currentIndex];
    // The next launch opens where this one was left.
    UiMemory.keep(context, 'section', section.name);
    final player = PlayerScope.of(context);
    final rack = PlayerScope.rackOf(context);
    final issues = PlayerScope.issuesOf(context);
    final guard = issues.guard;
    return PlaybackNoticeHost(
      consoleVisible: section == Section.console,
      onShowLog: () => navigationShell.goBranch(Section.console.index),
      child: PlaybackShortcuts(
        player: player,
        enabled: context.layout.isPointer,
        guard: guard,
        child: FileDropHost(
          onDrop: (paths) async {
            final queue = QueueController(
              player: player,
              guard: guard,
              notify: issues.notify,
            );
            try {
              await queue.addDropped(paths);
            } catch (e) {
              issues.notify(
                'Could not add what was dropped: $e',
                isError: true,
              );
            } finally {
              queue.dispose();
            }
          },
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
      ),
    );
  }
}
