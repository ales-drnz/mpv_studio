import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/layout/layout.dart';
import '../ui/tokens.dart';
import '../ui/widgets/scroll_fade.dart';
import 'nav_parts.dart';
import 'sections.dart';
import 'snack_clearance.dart';

/// The bottom bar chrome (compact windows): the section body with a bottom
/// tab bar that stays **pinned** to the screen edge. The soft keyboard
/// overlays the bar instead of pushing it up: only the body content lifts
/// above the keyboard, so a focused text field (such as the Console input)
/// stays visible. The root [Scaffold] sets
/// `resizeToAvoidBottomInset: false`, so this widget owns the keyboard inset.
///
/// The bar has a tab per [Section.tabs] and a More tab that opens a sheet
/// with the [Section.more] sections. [miniPlayer], when given, floats right
/// above the bar and moves with it: the body runs on under it, so the page
/// shows around and behind its card, and the shell hands its height to the
/// pages as [FloatingChrome], so they end their content above it.
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
  final GlobalKey _miniKey = GlobalKey();
  // Measured heights of the tab bar (includes the home-indicator inset)
  // and of the mini-player floating above it.
  double _tabBarHeight = 0;
  double _miniHeight = 0;

  void _measure() {
    if (!mounted) return;
    final bar = _tabBarKey.currentContext?.size?.height ?? _tabBarHeight;
    final mini = widget.miniPlayer == null
        ? 0.0
        : _miniKey.currentContext?.size?.height ?? _miniHeight;
    if (bar != _tabBarHeight || mini != _miniHeight) {
      setState(() {
        _tabBarHeight = bar;
        _miniHeight = mini;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The heights are stable after layout; re-measure post-frame (guarded
    // so it only commits on a real change, such as an orientation or inset
    // change, or the mini-player coming or going).
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    // Reserve the keyboard (when up) or the tab bar (when down) at the
    // bottom, whichever is taller, so the body is never hidden behind
    // either. The mini-player is not reserved: the body runs on under it,
    // and the pages end their content above whatever part of it the
    // keyboard leaves showing.
    final bottomReserve = math.max(keyboard, _tabBarHeight);
    final mini = widget.miniPlayer == null ? 0.0 : _miniHeight;
    final floating = math.max(0.0, _tabBarHeight + mini - bottomReserve);

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
                  child: FloatingChrome(
                    height: floating,
                    child: Material(
                      type: MaterialType.transparency,
                      child: widget.body,
                    ),
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
            // Toasts float above the bar and the mini-player.
            child: SnackObstacle(
              edge: SnackEdge.bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Only its card paints: the page shows around it,
                  // fading into the page background towards the tab bar
                  // so rows passing behind the margins stay quiet.
                  if (widget.miniPlayer != null)
                    KeyedSubtree(
                      key: _miniKey,
                      child: Stack(
                        children: [
                          const Positioned.fill(child: BackgroundFade()),
                          widget.miniPlayer!,
                        ],
                      ),
                    ),
                  KeyedSubtree(
                    key: _tabBarKey,
                    child: _TabBar(
                      section: widget.section,
                      onSelect: widget.onSelect,
                    ),
                  ),
                ],
              ),
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
