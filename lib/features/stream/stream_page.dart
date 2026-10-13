import 'package:flutter/material.dart';

import '../../studio/player_scope.dart';
import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import 'chapters_tab.dart';
import 'favorites_controller.dart';
import 'lab_tab.dart';
import 'library/server_library_tab.dart';
import 'media_server.dart';
import 'resolver_tab.dart';
import 'samba/samba_tab.dart';
import 'signed_url_resolver.dart';
import 'stream_actions.dart';
import 'widgets/stream_tab_scope.dart';

/// The tabs of the Stream page, in order.
enum StreamTab {
  lab('Lab'),
  chapters('Chapters'),
  resolver('Resolver'),
  jellyfin('Jellyfin'),
  plex('Plex'),
  samba('Samba');

  final String label;
  const StreamTab(this.label);
}

/// The Stream section: network sources, one tab each. **Lab** plays the
/// reference streams and any URL with its own HTTP options; **Chapters**
/// streams with embedded chapters; **Resolver** shows a source resolver
/// renewing links that expire; **Jellyfin** and **Plex** sign in to a
/// server and browse its songs and albums; **Samba** walks an SMB share.
///
/// Reads the player, the servers and the favourites from the app's
/// [PlayerScope]; [StreamView] is the page itself.
class StreamPage extends StatelessWidget {
  const StreamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final issues = PlayerScope.issuesOf(context);
    return StreamView(
      actions: StreamActions(
        player: PlayerScope.of(context),
        guard: issues.guard,
      ),
      // The servers live at app scope, so their sessions and the playback
      // reporting outlive this page.
      jellyfin: PlayerScope.serverOf(context, ServerKind.jellyfin),
      plex: PlayerScope.serverOf(context, ServerKind.plex),
      favorites: PlayerScope.favoritesOf(context),
      resolver: SignedUrlResolver.shared,
    );
  }
}

/// The Stream page on explicit services: the header, the tab row and the
/// tabs, every tab kept alive so a sign-in, a search or an open folder
/// survives a switch.
class StreamView extends StatefulWidget {
  const StreamView({
    super.key,
    required this.actions,
    required this.jellyfin,
    required this.plex,
    required this.favorites,
    required this.resolver,
    this.initialTab = StreamTab.lab,
    this.samba,
  });

  final StreamActions actions;
  final MediaServer jellyfin;
  final MediaServer plex;
  final FavoritesController favorites;
  final SignedUrlResolver resolver;
  final StreamTab initialTab;

  /// The Samba tab; the real one when null (tests pass one on a fake
  /// share).
  final Widget? samba;

  @override
  State<StreamView> createState() => _StreamViewState();
}

class _StreamViewState extends State<StreamView>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: StreamTab.values.length,
    initialIndex: widget.initialTab.index,
    vsync: this,
  )..addListener(_onTab);

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _body(StreamTab tab) => switch (tab) {
    StreamTab.lab => LabTab(actions: widget.actions),
    StreamTab.chapters => ChaptersTab(actions: widget.actions),
    StreamTab.resolver => ResolverTab(
      actions: widget.actions,
      resolver: widget.resolver,
    ),
    StreamTab.jellyfin => ServerLibraryTab(
      server: widget.jellyfin,
      actions: widget.actions,
      favorites: widget.favorites,
    ),
    StreamTab.plex => ServerLibraryTab(
      server: widget.plex,
      actions: widget.actions,
      favorites: widget.favorites,
    ),
    StreamTab.samba => widget.samba ?? SambaTab(actions: widget.actions),
  };

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final selected = _tabs.index;
    return PageFrame(
      title: 'Stream',
      scrollable: false,
      // The tabs scroll themselves, each with the gutter at its sides; the
      // header and the tab row share it.
      padding: EdgeInsets.symmetric(horizontal: layout.gutter),
      bottom: _StreamTabBar(controller: _tabs, scrollable: layout.isCompact),
      body: IndexedStack(
        index: selected,
        sizing: StackFit.expand,
        children: [
          for (final tab in StreamTab.values)
            StreamTabScope(
              active: tab.index == selected,
              child: TickerMode(
                enabled: tab.index == selected,
                child: _body(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreamTabBar extends StatelessWidget {
  const _StreamTabBar({required this.controller, required this.scrollable});

  final TabController controller;

  /// Scrolls sideways (a phone) instead of sharing the width.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
      labelColor: Tokens.accent,
      unselectedLabelColor: Tokens.fgDim,
      labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      indicatorColor: Tokens.accent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Tokens.line,
      overlayColor: WidgetStatePropertyAll(Tokens.accentWash),
      labelPadding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
      tabs: [
        for (final t in StreamTab.values)
          Tab(height: context.layout.minTap, text: t.label),
      ],
    );
  }
}
