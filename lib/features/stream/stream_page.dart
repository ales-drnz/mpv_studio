import 'package:flutter/material.dart';

import '../../studio/player_scope.dart';
import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/controls.dart';
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
import '../../ui/widgets/scroll_fade.dart';

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

  /// The tab called [name] (`lab`, `plex`...), or null for anything else.
  static StreamTab? byName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
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
  const StreamPage({super.key, this.initialTab, this.tabRequest});

  /// The tab to show, from the route (`/stream?tab=jellyfin`); Lab when
  /// null.
  final StreamTab? initialTab;

  /// The navigation that asked for [initialTab] (see [StreamView.tabRequest]).
  final Object? tabRequest;

  @override
  Widget build(BuildContext context) {
    final issues = PlayerScope.issuesOf(context);
    final settings = PlayerScope.settingsOf(context);
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
      hasGlobalUserAgent: () => settings.userAgent.isNotEmpty,
      initialTab: initialTab ?? StreamTab.lab,
      tabRequest: initialTab == null ? null : tabRequest,
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
    this.hasGlobalUserAgent = _noGlobalUserAgent,
    this.initialTab = StreamTab.lab,
    this.tabRequest,
    this.samba,
  });

  final StreamActions actions;
  final MediaServer jellyfin;
  final MediaServer plex;
  final FavoritesController favorites;
  final SignedUrlResolver resolver;

  /// Whether Settings, Network sets a user agent for every stream (the Lab
  /// options say so in their hint).
  final bool Function() hasGlobalUserAgent;

  static bool _noGlobalUserAgent() => false;
  final StreamTab initialTab;

  /// The navigation that asked for [initialTab]. The page stays alive, so
  /// a new request (a different object, even for the same tab) moves it
  /// to [initialTab]; a rebuild with the same request, or none, leaves the
  /// tab the user picked alone.
  final Object? tabRequest;

  /// The Samba tab; the real one when null (tests pass one on a fake
  /// share).
  final Widget? samba;

  /// The key of the stack of tabs, whose index is the tab on screen.
  static const tabsKey = ValueKey('stream-tabs');

  @override
  State<StreamView> createState() => _StreamViewState();
}

class _StreamViewState extends State<StreamView> {
  late StreamTab _tab = widget.initialTab;

  @override
  void didUpdateWidget(StreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The page stays alive, so a later route asking for a tab (the
    // welcome screen's "Connect a server") moves to it here.
    final request = widget.tabRequest;
    if (request != null && !identical(request, oldWidget.tabRequest)) {
      _tab = widget.initialTab;
    }
  }

  /// The tabs opened so far. A tab is built on its first visit and kept
  /// alive after, so opening the page on Lab does not reconnect to Samba
  /// or page through both server libraries.
  final _visited = <StreamTab>{};

  Widget _body(StreamTab tab) => switch (tab) {
    StreamTab.lab => LabTab(
      actions: widget.actions,
      hasGlobalUserAgent: widget.hasGlobalUserAgent,
    ),
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
    final selected = _tab;
    _visited.add(selected);
    return PageFrame(
      title: 'Stream',
      scrollable: false,
      // The tabs scroll themselves, each with the gutter at its sides and
      // under its last item; the header and the tab row share it.
      padding: layout.pagePadding.copyWith(top: 0),
      bottom: StreamTabRow(
        selected: selected,
        onSelect: (t) => setState(() => _tab = t),
      ),
      body: IndexedStack(
        key: StreamView.tabsKey,
        index: selected.index,
        sizing: StackFit.expand,
        children: [
          for (final tab in StreamTab.values)
            StreamTabScope(
              active: tab == selected,
              child: TickerMode(
                enabled: tab == selected,
                child: _visited.contains(tab)
                    ? _body(tab)
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

/// The Stream page's tabs: a row of pills, the selected one in the
/// accent. It scrolls sideways when the window is too narrow for all of
/// them, and brings the selected pill into view.
class StreamTabRow extends StatefulWidget {
  const StreamTabRow({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final StreamTab selected;
  final ValueChanged<StreamTab> onSelect;

  @override
  State<StreamTabRow> createState() => _StreamTabRowState();
}

class _StreamTabRowState extends State<StreamTabRow> {
  final _keys = {for (final t in StreamTab.values) t: GlobalKey()};

  @override
  void initState() {
    super.initState();
    _reveal(animate: false);
  }

  @override
  void didUpdateWidget(StreamTabRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal();
  }

  /// Centres the selected pill in the row (as far as the row scrolls)
  /// after this frame.
  void _reveal({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pill = _keys[widget.selected]!.currentContext;
      if (!mounted || pill == null) return;
      Scrollable.ensureVisible(
        pill,
        alignment: 0.5,
        duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.s4, bottom: Tokens.s8),
      // On a phone the pills run past the edges: the fade says so.
      child: ScrollFade(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in StreamTab.values) ...[
                if (t.index > 0) const SizedBox(width: Tokens.s8),
                _TabPill(
                  key: _keys[t],
                  label: t.label,
                  selected: t == widget.selected,
                  onTap: () => widget.onSelect(t),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.pill,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: controlHeightOf(context),
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: selected ? Tokens.accent : Tokens.surface,
              shape: Tokens.pill,
            ),
            child: Text(
              label,
              maxLines: 1,
              style: Tokens.body.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? Tokens.onAccent : Tokens.fgDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
