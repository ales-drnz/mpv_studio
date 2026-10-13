import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import '../ui/widgets/resize_handle.dart';
import 'section_badge.dart';
import 'sections.dart';

/// Desktop chrome: a resizable text sidebar on the left and the section
/// body filling the stage. Flat throughout — hierarchy via surface
/// colour, not shadow.
class DesktopShell extends StatefulWidget {
  final Section section;
  final ValueChanged<Section> onSelect;
  final Widget body;

  const DesktopShell({
    super.key,
    required this.section,
    required this.onSelect,
    required this.body,
  });

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  double _sidebarWidth = 200;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final onSelect = widget.onSelect;
    final body = widget.body;
    // Panels touch flush; the resize line is overlaid exactly on the
    // seam so there are no gap pixels between sidebar and stage.
    return Stack(
      children: [
        Row(
          children: [
            _Sidebar(
                section: section, onSelect: onSelect, width: _sidebarWidth),
            Expanded(
              // Clip the stage to its own bounds: a full-bleed meter's
              // CustomPaint paints unclipped by default, so without this a
              // painter drawing past its left edge (e.g. during a resize
              // frame) would bleed over the sidebar.
              child: ClipRect(
                child: Material(type: MaterialType.transparency, child: body),
              ),
            ),
          ],
        ),
        Positioned(
          left: _sidebarWidth - 4.5,
          top: 0,
          bottom: 0,
          width: 9,
          child: ResizeHandle(
            axis: Axis.vertical,
            onDelta: (dx) => setState(
              () => _sidebarWidth = (_sidebarWidth + dx).clamp(168.0, 340.0),
            ),
          ),
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  final Section section;
  final ValueChanged<Section> onSelect;
  final double width;

  const _Sidebar({
    required this.section,
    required this.onSelect,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Tokens.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.s12,
          Tokens.s20,
          Tokens.s12,
          Tokens.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                Tokens.s12,
                0,
                Tokens.s12,
                Tokens.s20,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'MPV ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Tokens.fg,
                      ),
                    ),
                    TextSpan(
                      text: 'Studio',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Tokens.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final s in Section.values)
              _NavItem(
                section: s,
                active: s == section,
                onTap: () => onSelect(s),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Section section;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.section,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: Tokens.squircle(Tokens.rSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: ShapeDecoration(
              color: active ? Tokens.accent : Colors.transparent,
              shape: Tokens.squircle(Tokens.rSm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.s12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  SectionBadge(
                    section: section,
                    child: Icon(
                      section.icon,
                      size: 18,
                      color: active ? Tokens.onAccent : Tokens.fgDim,
                    ),
                  ),
                  const SizedBox(width: Tokens.s12),
                  Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? Tokens.onAccent : Tokens.fgDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
