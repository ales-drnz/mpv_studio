import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import 'nav_parts.dart';
import 'sections.dart';

/// The bottom bar chrome (compact windows): the section body with a bottom
/// tab bar that stays **pinned** to the screen edge. The soft keyboard
/// overlays the bar instead of pushing it up: only the body content lifts
/// above the keyboard, so a focused text field (such as the Console input)
/// stays visible. The root [Scaffold] sets
/// `resizeToAvoidBottomInset: false`, so this widget owns the keyboard inset.
///
/// The bar has a tab per [Section.tabs] and a More tab that opens a sheet
/// with the [Section.more] sections. [miniPlayer], when given, sits right
/// above the bar and moves with it.
class MobileShell extends StatefulWidget {
  final Section section;
  final ValueChanged<Section> onSelect;
  final Widget body;
  final Widget? miniPlayer;

  const MobileShell({
    super.key,
    required this.section,
    required this.onSelect,
    required this.body,
    this.miniPlayer,
  });

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  final GlobalKey _tabBarKey = GlobalKey();
  // Measured height of the tab bar and the mini-player above it (includes
  // the home-indicator inset). The body reserves this much at the bottom
  // when the keyboard is down; the keyboard inset takes over when it's up,
  // so the content clears whichever is taller.
  double _tabBarHeight = 0;

  void _measureTabBar() {
    final h = _tabBarKey.currentContext?.size?.height;
    if (h != null && h != _tabBarHeight && mounted) {
      setState(() => _tabBarHeight = h);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The bar height is stable after layout; re-measure post-frame (guarded
    // so it only commits on a real change, such as an orientation or inset
    // change).
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTabBar());

    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    // Reserve the keyboard (when up) or the tab bar (when down) at the bottom,
    // whichever is taller, so the body content is never hidden behind either.
    final bottomReserve = math.max(keyboard, _tabBarHeight);

    // The top and sides are inset normally, but NOT the bottom: the tab bar itself
    // fills the bottom inset (home indicator) with its own surface so it reads
    // as continuous to the screen edge.
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Body fills the whole area, reserving the bottom for the keyboard
          // or the tab bar so a bottom-anchored input lifts above the
          // keyboard while the bar below stays put.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomReserve),
              // Read below the SafeArea, so the consumed top and side
              // insets stay consumed; the bottom inset belongs to the tab
              // bar and the keyboard to this shell, so the body sees neither.
              child: Builder(
                builder: (inner) => MediaQuery(
                  data: MediaQuery.of(inner)
                      .removePadding(removeBottom: true)
                      .removeViewInsets(removeBottom: true),
                  child: Material(
                    type: MaterialType.transparency,
                    child: widget.body,
                  ),
                ),
              ),
            ),
          ),
          // Tab bar pinned to the screen bottom: the keyboard overlays it
          // instead of pushing it up.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              key: _tabBarKey,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.miniPlayer != null) widget.miniPlayer!,
                _TabBar(section: widget.section, onSelect: widget.onSelect),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final Section section;
  final ValueChanged<Section> onSelect;
  const _TabBar({required this.section, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // A tonal bar, no hairline: its fill runs on into the home-indicator
    // inset so it reads as continuous to the screen edge.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      color: Tokens.surface2,
      padding: EdgeInsets.only(top: Tokens.s8, bottom: Tokens.s8 + bottomInset),
      child: Row(
        children: [
          for (final s in Section.tabs)
            Expanded(
              child: SectionDestination(
                section: s,
                active: s == section,
                onTap: () => onSelect(s),
                indicatorWidth: 64,
              ),
            ),
          Expanded(
            child: MoreDestination(
              section: section,
              onSelect: onSelect,
              indicatorWidth: 64,
            ),
          ),
        ],
      ),
    );
  }
}
