import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import 'section_badge.dart';
import 'sections.dart';

/// Mobile chrome: the section body with a bottom tab bar that stays **pinned**
/// to the screen edge. The soft keyboard overlays the bar instead of pushing it
/// up — only the body content lifts above the keyboard, so a focused text field
/// (e.g. the Console input) stays visible. The root [Scaffold] sets
/// `resizeToAvoidBottomInset: false`, so this widget owns the keyboard inset.
class MobileShell extends StatefulWidget {
  final Section section;
  final ValueChanged<Section> onSelect;
  final Widget body;

  const MobileShell({
    super.key,
    required this.section,
    required this.onSelect,
    required this.body,
  });

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  final GlobalKey _tabBarKey = GlobalKey();
  // Measured tab-bar height (includes the home-indicator inset). The body
  // reserves this much at the bottom when the keyboard is down; the keyboard
  // inset takes over when it's up — so the content clears whichever is taller.
  double _tabBarHeight = 0;

  void _measureTabBar() {
    final h = _tabBarKey.currentContext?.size?.height;
    if (h != null && h != _tabBarHeight && mounted) {
      setState(() => _tabBarHeight = h);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The bar height is stable after layout; re-measure post-frame (guarded so
    // it only commits on a real change — e.g. an orientation / inset change).
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTabBar());

    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    // Reserve the keyboard (when up) or the tab bar (when down) at the bottom,
    // whichever is taller, so the body content is never hidden behind either.
    final bottomReserve = math.max(keyboard, _tabBarHeight);

    // Top/sides are inset normally, but NOT the bottom: the tab bar itself
    // fills the bottom inset (home indicator) with its own surface so it reads
    // as continuous to the screen edge.
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Body fills the whole area, reserving the bottom for the keyboard /
          // tab bar so a bottom-anchored input lifts above the keyboard while
          // the bar below stays put.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomReserve),
              child: Material(
                type: MaterialType.transparency,
                child: widget.body,
              ),
            ),
          ),
          // Tab bar pinned to the screen bottom — the keyboard overlays it
          // instead of pushing it up.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _TabBar(
              key: _tabBarKey,
              section: widget.section,
              onSelect: widget.onSelect,
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
  const _TabBar({super.key, required this.section, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // Pad the content above the home indicator while the surface colour fills
    // the inset, so the bar runs continuously to the screen edge.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Tokens.surface,
        border: Border(top: BorderSide(color: Tokens.line)),
      ),
      padding: EdgeInsets.only(
        top: Tokens.s8,
        bottom: Tokens.s8 + bottomInset,
      ),
      child: Row(
        children: [
          for (final s in Section.values)
            Expanded(
              child: _Tab(
                section: s,
                active: s == section,
                onTap: () => onSelect(s),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final Section section;
  final bool active;
  final VoidCallback onTap;
  const _Tab(
      {required this.section, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Mirror the desktop sidebar's _NavItem: a solid-accent squircle pill for
    // the active tab with onAccent contents, inactive tabs in fgDim.
    final color = active ? Tokens.onAccent : Tokens.fgDim;
    // The inter-pill gap is a Padding OUTSIDE the InkWell so the ink/hover
    // area (clipped to the same squircle) lines up exactly with the visible
    // pill — a margin inside the InkWell would make the highlight overshoot.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s4),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.squircle(Tokens.rSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
            decoration: ShapeDecoration(
              color: active ? Tokens.accent : Colors.transparent,
              shape: Tokens.squircle(Tokens.rSm),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SectionBadge(
                  section: section,
                  child: Icon(section.icon, size: 22, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  section.shortLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
