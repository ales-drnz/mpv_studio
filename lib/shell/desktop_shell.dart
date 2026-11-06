import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import 'nav_parts.dart';
import 'shell_tools.dart';
import 'sections.dart';
import 'snack_clearance.dart';
import 'ui_memory.dart';

/// The sidebar chrome (expanded windows and up): a tonal sidebar on the
/// left, the section body in a rounded [StagePanel] beside it, and the
/// [miniPlayer], when given, along the bottom under both. There is no
/// drag handle: the sidebar has two widths, full (labels, grouped under
/// "Listen" and "Tools") and collapsed (icons in pill indicators), toggled
/// by the round button at its foot, beside the theme and shortcut tools. The safe area is applied here; the
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

  /// The sidebar width when open and when collapsed.
  static const double openWidth = 224;
  static const double collapsedWidth = 88;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  /// As the user left it.
  late bool _collapsed =
      UiMemory.recall<bool>(context, 'sidebarCollapsed') ?? false;

  /// Whether the items are laid out narrow. Opening, they stay narrow
  /// until the sidebar has its width, so they never overflow on the way.
  late bool _narrow = _collapsed;

  void _toggle() {
    setState(() {
      _collapsed = !_collapsed;
      if (_collapsed) _narrow = true;
    });
    UiMemory.keep(context, 'sidebarCollapsed', _collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final mini = widget.miniPlayer;
    // The sidebar covers the left inset, so the stage must not see it;
    // the panel clips the stage, so a full-bleed painter never bleeds over
    // the sidebar.
    final stage = withoutLeftInset(
      SafeArea(
        bottom: mini == null,
        child: StagePanel(child: widget.body),
      ),
    );
    // The chrome is the tonal container; the stage panel and the cards
    // in it sit one and two steps away from it. The mini-player sits
    // under the stage, beside the sidebar, as it does beside the rail.
    return ColoredBox(
      color: Tokens.surface2,
      child: liftAboveKeyboard(
        context,
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toasts float over the stage, beside the sidebar.
            SnackObstacle(
              edge: SnackEdge.left,
              child: _Sidebar(
                section: widget.section,
                onSelect: widget.onSelect,
                collapsed: _collapsed,
                narrow: _narrow,
                onWidthSettled: () {
                  if (!_collapsed && _narrow) setState(() => _narrow = false);
                },
                onToggle: _toggle,
              ),
            ),
            Expanded(
              child: mini == null
                  ? stage
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: stage),
                        // Toasts float above the mini-player.
                        SnackObstacle(
                          edge: SnackEdge.bottom,
                          child: withoutLeftInset(
                            SafeArea(top: false, child: mini),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final Section section;
  final ValueChanged<Section> onSelect;
  final bool collapsed;

  /// Lays the items out for the collapsed width; see
  /// `_DesktopShellState._narrow`.
  final bool narrow;
  final VoidCallback onWidthSettled;
  final VoidCallback onToggle;

  const _Sidebar({
    required this.section,
    required this.onSelect,
    required this.collapsed,
    required this.narrow,
    required this.onWidthSettled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final layout = narrow ? NavItemLayout.iconOnly : NavItemLayout.inline;
    Widget item(Section s) => Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s4),
      child: SectionDestination(
        section: s,
        active: s == section,
        onTap: () => onSelect(s),
        layout: layout,
        short: false,
      ),
    );
    final toggle = ShellToolButton(
      icon: collapsed
          ? Icons.keyboard_double_arrow_right_rounded
          : Icons.keyboard_double_arrow_left_rounded,
      label: collapsed ? 'Expand the sidebar' : 'Collapse the sidebar',
      onTap: onToggle,
      expanded: false,
    );
    final header = narrow
        ? const Center(child: StudioMark(size: 40))
        : Row(
            children: [
              const StudioMark(size: 40),
              const SizedBox(width: Tokens.s12),
              Expanded(
                child: Text(
                  'MPV Studio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // The sidebar is fixed in width: the name grows up to
                  // 1.3 times, so it stays whole.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.3),
                  style: Tokens.heading.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          );
    return AnimatedContainer(
      duration: Tokens.motion(context, Tokens.motionLong),
      curve: Curves.easeOutCubic,
      onEnd: onWidthSettled,
      // Grows by the left safe-area inset, as the rail does, so the items
      // keep their full width beside a notch.
      width:
          (collapsed ? DesktopShell.collapsedWidth : DesktopShell.openWidth) +
          MediaQuery.paddingOf(context).left,
      child: SafeArea(
        right: false,
        child: Padding(
          // Symmetric: 16 on every side of the sidebar column.
          padding: const EdgeInsets.all(Tokens.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: narrow ? 0 : Tokens.s4,
                  bottom: Tokens.s8,
                ),
                child: header,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (narrow)
                        const SizedBox(height: Tokens.s8)
                      else
                        const NavGroupLabel('Listen'),
                      for (final s in Section.tabs) item(s),
                      if (narrow)
                        const NavGroupGap()
                      else
                        const NavGroupLabel('Tools'),
                      for (final s in Section.more) item(s),
                    ],
                  ),
                ),
              ),
              _ToolRow(collapsed: narrow, toggle: toggle),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sidebar toggle, the theme switch and the shortcut list as round
/// tonal buttons at the foot of the sidebar: a row when open, a column
/// when collapsed.
class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.collapsed, required this.toggle});

  final bool collapsed;
  final Widget toggle;

  @override
  Widget build(BuildContext context) {
    final tools = [toggle, ...shellTools(context, expanded: false)];
    return collapsed
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in tools)
                Padding(
                  padding: const EdgeInsets.only(top: Tokens.s8),
                  child: t,
                ),
            ],
          )
        : Row(
            children: [
              for (final t in tools) ...[t, const SizedBox(width: Tokens.s8)],
            ],
          );
  }
}
