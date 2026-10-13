import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import 'nav_parts.dart';
import 'shell_tools.dart';
import 'sections.dart';

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
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final mini = widget.miniPlayer;
    final panels = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Sidebar(
          section: widget.section,
          onSelect: widget.onSelect,
          collapsed: _collapsed,
          onToggle: () => setState(() => _collapsed = !_collapsed),
          safeBottom: mini == null,
        ),
        // The sidebar covers the left inset, so the stage must not see
        // it; the panel clips the stage, so a full-bleed painter never
        // bleeds over the sidebar.
        Expanded(
          child: withoutLeftInset(
            SafeArea(
              bottom: mini == null,
              child: StagePanel(child: widget.body),
            ),
          ),
        ),
      ],
    );
    // The chrome is the tonal container; the stage panel and the cards
    // in it sit one and two steps away from it.
    return ColoredBox(
      color: Tokens.surface2,
      child: liftAboveKeyboard(
        context,
        mini == null
            ? panels
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: panels),
                  SafeArea(top: false, child: mini),
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
  final VoidCallback onToggle;
  final bool safeBottom;

  const _Sidebar({
    required this.section,
    required this.onSelect,
    required this.collapsed,
    required this.onToggle,
    required this.safeBottom,
  });

  @override
  Widget build(BuildContext context) {
    final layout = collapsed ? NavItemLayout.iconOnly : NavItemLayout.inline;
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
    final header = collapsed
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
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      // Grows by the left safe-area inset, as the rail does, so the items
      // keep their full width beside a notch.
      width:
          (collapsed ? DesktopShell.collapsedWidth : DesktopShell.openWidth) +
          MediaQuery.paddingOf(context).left,
      child: SafeArea(
        right: false,
        bottom: safeBottom,
        child: Padding(
          // Symmetric: 16 on every side of the sidebar column.
          padding: const EdgeInsets.all(Tokens.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: collapsed ? 0 : Tokens.s4,
                  bottom: Tokens.s8,
                ),
                child: header,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (collapsed)
                        const SizedBox(height: Tokens.s8)
                      else
                        const NavGroupLabel('Listen'),
                      for (final s in Section.tabs) item(s),
                      if (collapsed)
                        const NavGroupGap()
                      else
                        const NavGroupLabel('Tools'),
                      for (final s in Section.more) item(s),
                    ],
                  ),
                ),
              ),
              _ToolRow(collapsed: collapsed, toggle: toggle),
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
