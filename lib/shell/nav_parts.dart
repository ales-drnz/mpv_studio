import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/layout/layout.dart';
import '../ui/tokens.dart';
import 'section_badge.dart';
import 'sections.dart';
import 'shell_tools.dart';

/// How a [NavDestination] lays out its icon and label.
enum NavItemLayout {
  /// Icon in a pill indicator with the label under it (bottom bar, rail).
  stacked,

  /// A full-width pill row with the icon and the label side by side
  /// (sidebar, More sheet).
  inline,

  /// The pill indicator alone, the label as tooltip (low rail, collapsed
  /// sidebar).
  iconOnly,
}

/// One navigation destination in every shell: the pill indicator of
/// Material 3, filled with the accent container when [active], the icon
/// switching to its filled form. The tap target is the whole item, never
/// less than `context.layout.minTap`.
class NavDestination extends StatelessWidget {
  const NavDestination({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeIcon,
    this.badge,
    this.tooltip,
    this.layout = NavItemLayout.stacked,
    this.indicatorWidth = 56,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// The section whose badge (the Console error count) rides on the icon.
  final Section? badge;

  /// Shown on hover; defaults to [label] when the label is not visible.
  final String? tooltip;
  final NavItemLayout layout;

  /// The pill indicator width of the stacked and icon-only layouts.
  final double indicatorWidth;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final fg = active ? Tokens.onAccent : Tokens.fgDim;
    Widget glyph = Icon(
      active ? activeIcon ?? icon : icon,
      size: 24,
      color: fg,
    );
    if (badge != null) glyph = SectionBadge(section: badge!, child: glyph);
    final labelStyle = Tokens.label.copyWith(
      fontSize: layout == NavItemLayout.inline ? 14 : 12,
      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      color: active
          ? (layout == NavItemLayout.inline ? fg : Tokens.fg)
          : Tokens.fgDim,
    );
    final minTap = context.layout.minTap;

    final Widget item;
    switch (layout) {
      case NavItemLayout.inline:
        item = AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOutCubic,
          height: math.max(48, minTap),
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
          decoration: ShapeDecoration(
            color: active ? Tokens.accent : Colors.transparent,
            shape: Tokens.pill,
          ),
          child: Row(
            children: [
              glyph,
              const SizedBox(width: Tokens.s12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ],
          ),
        );
      case NavItemLayout.stacked:
      case NavItemLayout.iconOnly:
        final pill = AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOutCubic,
          width: active ? indicatorWidth : indicatorWidth - 8,
          height: layout == NavItemLayout.iconOnly ? 40 : 32,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: active ? Tokens.accent : Colors.transparent,
            shape: Tokens.pill,
          ),
          child: glyph,
        );
        item = layout == NavItemLayout.iconOnly
            ? SizedBox(
                height: math.max(48, minTap),
                child: Center(child: pill),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: Tokens.s4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    pill,
                    const SizedBox(height: Tokens.s4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ],
                ),
              );
    }

    final tip = tooltip ?? (layout == NavItemLayout.iconOnly ? label : null);
    Widget tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: Tokens.pill,
        hoverColor: Tokens.accentWash,
        child: item,
      ),
    );
    if (tip != null) {
      tappable = Tooltip(
        message: tip,
        excludeFromSemantics: true,
        child: tappable,
      );
    }
    return Semantics(
      selected: active,
      button: true,
      label: layout == NavItemLayout.iconOnly ? label : null,
      child: tappable,
    );
  }
}

/// A [NavDestination] for a [Section].
class SectionDestination extends StatelessWidget {
  const SectionDestination({
    super.key,
    required this.section,
    required this.active,
    required this.onTap,
    this.layout = NavItemLayout.stacked,
    this.short = true,
    this.indicatorWidth = 56,
  });

  final Section section;
  final bool active;
  final VoidCallback onTap;
  final NavItemLayout layout;

  /// Uses the short label (bottom bar, rail) rather than the title.
  final bool short;
  final double indicatorWidth;

  @override
  Widget build(BuildContext context) => NavDestination(
    icon: section.icon,
    activeIcon: section.activeIcon,
    label: short ? section.shortLabel : section.title,
    tooltip: layout == NavItemLayout.inline ? null : section.title,
    active: active,
    onTap: onTap,
    badge: section,
    layout: layout,
    indicatorWidth: indicatorWidth,
  );
}

/// The labelled head of a group of destinations in the sidebar ("Listen",
/// "Tools"): it says why the groups stand apart.
class NavGroupLabel extends StatelessWidget {
  const NavGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Tokens.s16,
      Tokens.s16,
      Tokens.s16,
      Tokens.s8,
    ),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Tokens.label.copyWith(
          fontWeight: FontWeight.w600,
          color: Tokens.fgFaint,
        ),
      ),
    ),
  );
}

/// The quiet separator between the destination groups where no label
/// fits (the rail): a short round pill, centred.
class NavGroupGap extends StatelessWidget {
  const NavGroupGap({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
    child: Center(
      child: Container(
        width: 24,
        height: 4,
        decoration: ShapeDecoration(color: Tokens.surface4, shape: Tokens.pill),
      ),
    ),
  );
}

/// The app mark, the circular logo drawn in its own colours whatever the
/// theme: the graphite disc, the ring grey ring and the white rounded
/// play triangle ([Palette.logoGraphite], [Palette.logoRing],
/// [Palette.logoWhite]).
class StudioMark extends StatelessWidget {
  const StudioMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = Palette.logoGraphite);
    canvas.drawCircle(
      c,
      r * 0.6,
      Paint()
        ..color = Palette.logoRing
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1,
    );
    final s = size.width;
    final tri = Path()
      ..moveTo(s * 0.32, s * 0.24)
      ..lineTo(s * 0.80, s * 0.50)
      ..lineTo(s * 0.32, s * 0.76)
      ..close();
    // Filled, then stroked with round joins: the logo's rounded corners.
    final ink = Paint()
      ..color = Palette.logoWhite
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.08;
    canvas.drawPath(tri, ink..style = PaintingStyle.fill);
    canvas.drawPath(tri, ink..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}

/// The rounded panel the section body sits in on the rail and sidebar
/// shells: the page background, inset from the chrome by [Tokens.s8] and
/// rounded at [Tokens.rLg], so the chrome and the stage read as two tonal
/// layers without a hairline.
class StagePanel extends StatelessWidget {
  const StagePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, Tokens.s8, Tokens.s8, Tokens.s8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.rLg),
      child: ColoredBox(
        color: Tokens.bg,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
}

/// The More destination of the bottom bar and the low rail: it opens the
/// sections without a tab ([Section.more]) in a sheet. The Console lives
/// there, so its error count rides on it; on a More section it carries
/// that section's icon, so the bar still says where you are.
class MoreDestination extends StatelessWidget {
  const MoreDestination({
    super.key,
    required this.section,
    required this.onSelect,
    this.layout = NavItemLayout.stacked,
    this.indicatorWidth = 56,
  });

  final Section section;
  final ValueChanged<Section> onSelect;
  final NavItemLayout layout;
  final double indicatorWidth;

  Future<void> _open(BuildContext context) async {
    final picked = await showStudioSheet<Section>(
      context,
      builder: (context) => _MoreSheet(current: section),
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) => NavDestination(
    badge: Section.console,
    icon: section.tab ? Icons.more_horiz_rounded : section.icon,
    activeIcon: section.activeIcon,
    label: 'More',
    tooltip: 'More sections',
    active: !section.tab,
    onTap: () => _open(context),
    layout: layout,
    indicatorWidth: indicatorWidth,
  );
}

/// The More sheet: the sections without a tab of their own, as pill rows
/// under a group label, then the shell tools.
class _MoreSheet extends StatelessWidget {
  final Section current;
  const _MoreSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final tools = shellTools(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NavGroupLabel('Tools'),
        for (final s in Section.more)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s4),
            child: SectionDestination(
              section: s,
              active: s == current,
              onTap: () => Navigator.of(context).pop(s),
              layout: NavItemLayout.inline,
              short: false,
            ),
          ),
        if (tools.isNotEmpty) ...[const NavGroupGap(), ...tools],
      ],
    );
  }
}
