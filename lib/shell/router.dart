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

/// Builds the app router. One [StatefulShellBranch] per [Section], each
/// with its own navigator (the shell reaches it to pop a pushed detail);
/// every branch stays mounted inside a keep-alive [IndexedStack], so
/// player subscriptions and the Now Playing visualizers survive section
/// switches. Switching sections is deliberately instant (no transition):
/// the shared fade and slide is for in-page navigation only.
///
/// [shell] and [page] default to the real [AppShell] and pages; tests
/// swap in a player-free shell and placeholder pages.
GoRouter createAppRouter({
  Widget Function(StatefulNavigationShell navigationShell)? shell,
  Widget Function(Section section)? page,
}) {
  final buildShell =
      shell ?? (navigationShell) => AppShell(navigationShell: navigationShell);
  final buildPage = page;
  return GoRouter(
    initialLocation: Section.nowPlaying.path,
    routes: [
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            buildShell(navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            IndexedStack(
              index: navigationShell.currentIndex,
              sizing: StackFit.expand,
              children: children,
            ),
        branches: [
          for (final section in Section.values)
            StatefulShellBranch(
              navigatorKey: GlobalKey<NavigatorState>(debugLabel: section.name),
              routes: [
                GoRoute(
                  path: section.path,
                  builder: (context, state) =>
                      buildPage?.call(section) ?? _pageFor(section, state),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

/// The page of [section]. [state] carries the route's parameters, such as
/// the Stream tab to open (`/stream?tab=plex`); each navigation brings a
/// new state, which is how the live Stream page tells a new request apart.
Widget _pageFor(Section section, GoRouterState state) {
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
      return StreamPage(
        initialTab: StreamTab.byName(state.uri.queryParameters['tab']),
        tabRequest: state,
      );
    case Section.settings:
      return const SettingsPage();
    case Section.console:
      return const ConsolePage();
  }
}
