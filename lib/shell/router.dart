import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/console/console_page.dart';
import '../features/effects/effects_page.dart';
import '../features/engine/engine_page.dart';
import '../features/now_playing/now_playing_page.dart';
import '../features/queue/queue_page.dart';
import '../features/settings/settings_page.dart';
import '../features/stream/stream_page.dart';
import 'app_shell.dart';
import 'sections.dart';

/// One navigator key per section branch. They let the shell pop a branch's
/// own pushed detail (e.g. a settings category opened with `Navigator.push`)
/// when its tab/sidebar icon is tapped again — "tap the active icon to go
/// back". Top-level and stable so the keys survive rebuilds.
final List<GlobalKey<NavigatorState>> branchNavigatorKeys = [
  for (final _ in Section.values) GlobalKey<NavigatorState>(),
];

/// Builds the app router. One [StatefulShellBranch] per [Section]; every
/// branch stays mounted inside a keep-alive [IndexedStack], so player
/// subscriptions and the Now Playing visualizers survive section switches.
/// Switching sections from the sidebar is deliberately instant (no
/// transition) — the shared fade+slide is for in-page navigation only.
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: Section.nowPlaying.path,
    routes: [
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            IndexedStack(
          index: navigationShell.currentIndex,
          sizing: StackFit.expand,
          children: children,
        ),
        branches: [
          for (final section in Section.values)
            StatefulShellBranch(
              navigatorKey: branchNavigatorKeys[section.index],
              routes: [
                GoRoute(
                  path: section.path,
                  builder: (context, state) => _pageFor(section),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

Widget _pageFor(Section section) {
  switch (section) {
    case Section.nowPlaying:
      return const NowPlayingPage();
    case Section.queue:
      return const QueuePage();
    case Section.effects:
      return const EffectsPage();
    case Section.engine:
      return const EnginePage();
    case Section.stream:
      return const StreamPage();
    case Section.settings:
      return const SettingsPage();
    case Section.console:
      return const ConsolePage();
  }
}
