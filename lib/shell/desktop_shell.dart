import 'package:flutter/material.dart';

import '../ui/layout/layout.dart';
import '../ui/tokens.dart';
import '../ui/widgets/resize_handle.dart';
import 'section_badge.dart';
import 'shell_tools.dart';
import 'sections.dart';

/// The sidebar chrome (expanded windows and up): a resizable text sidebar
/// on the left and the section body filling the stage. Flat throughout,
/// hierarchy via surface colour, not shadow. [miniPlayer], when given,
/// runs along the bottom under both. The safe area is applied here; the
/// soft keyboard lifts the whole shell.
class DesktopShell extends StatefulWidget {
  final Section section;
  final ValueChanged<Section> onSelect;
  final Widget body;
  final Widget? miniPlayer;

  const DesktopShell({
    super.key,
    required this.section,
    required this.onSelect,
    required this.body,
    this.miniPlayer,
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
    final panels = Stack(
      children: [
        Row(
          children: [
            _Sidebar(
              section: section,
              onSelect: onSelect,
              width: _sidebarWidth,
              safeBottom: widget.miniPlayer == null,
            ),
            Expanded(
              // Clip the stage to its own bounds: a full-bleed meter's
              // CustomPaint paints unclipped by default, so without this a
              // painter drawing past its left edge (e.g. during a resize
              // frame) would bleed over the sidebar.
              child: withoutLeftInset(
                SafeArea(
                  bottom: widget.miniPlayer == null,
                  child: ClipRect(
                    child: Material(
                      type: MaterialType.transparency,
                      child: body,
                    ),
                  ),
                ),
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
    final mini = widget.miniPlayer;
    return liftAboveKeyboard(
      context,
      mini == null
          ? panels
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: panels),
                ColoredBox(
                  color: Tokens.surface,
                  child: SafeArea(top: false, child: mini),
                ),
              ],
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final Section section;
  final ValueChanged<Section> onSelect;
  final double width;
  final bool safeBottom;

  const _Sidebar({
    required this.section,
    required this.onSelect,
    required this.width,
    required this.safeBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Tokens.surface,
      child: SafeArea(
        right: false,
        bottom: safeBottom,
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
              Padding(
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final s in Section.values) ...[
                        // A gap sets the tools (Engine, Settings, Console)
                        // apart from the listening sections.
                        if (s == Section.more.first)
                          const SizedBox(height: Tokens.s16),
                        _NavItem(
                          section: s,
                          active: s == section,
                          onTap: () => onSelect(s),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ...shellTools(context),
            ],
          ),
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
      child: Semantics(
        selected: active,
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: Tokens.shape(Tokens.rSm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              constraints: BoxConstraints(minHeight: context.layout.minTap),
              alignment: Alignment.centerLeft,
              decoration: ShapeDecoration(
                color: active ? Tokens.accent : Colors.transparent,
                shape: Tokens.shape(Tokens.rSm),
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
                    Flexible(
                      child: Text(
                        section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: active ? Tokens.onAccent : Tokens.fgDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
