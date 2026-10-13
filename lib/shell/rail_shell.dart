import 'package:flutter/material.dart';

import '../ui/layout/layout.dart';
import '../ui/tokens.dart';
import 'section_badge.dart';
import 'sections.dart';
import 'shell_tools.dart';

/// The rail chrome (medium windows, and any low window such as a phone in
/// landscape): a slim icon rail with every section on the left and the
/// section body filling the rest.
///
/// The rail lists icons with short labels, or bare icons with tooltips on
/// a low window, and scrolls when it runs out of height. A [miniPlayer]
/// runs along the bottom of the body; a [railMiniPlayer] sits at the foot
/// of the rail instead (low windows, where a bar would eat the height).
class RailShell extends StatelessWidget {
  const RailShell({
    super.key,
    required this.section,
    required this.onSelect,
    required this.body,
    this.miniPlayer,
    this.railMiniPlayer,
  });

  final Section section;
  final ValueChanged<Section> onSelect;
  final Widget body;
  final Widget? miniPlayer;
  final Widget? railMiniPlayer;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final labels = !layout.isShort;
    // The rail grows by the left safe-area inset (a landscape notch), so
    // its items keep their full width.
    final width = (labels ? 80.0 : 68.0) + MediaQuery.paddingOf(context).left;
    final mini = miniPlayer;
    final railMini = railMiniPlayer;

    final rail = Container(
      width: width,
      decoration: BoxDecoration(
        color: Tokens.surface,
        border: Border(right: BorderSide(color: Tokens.line)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.s6,
                  vertical: Tokens.s8,
                ),
                child: Column(
                  children: [
                    for (final s in Section.values) ...[
                      if (s == Section.more.first)
                        Divider(
                          height: Tokens.s12,
                          indent: Tokens.s12,
                          endIndent: Tokens.s12,
                          color: Tokens.line,
                        ),
                      _RailItem(
                        section: s,
                        active: s == section,
                        label: labels,
                        onTap: () => onSelect(s),
                      ),
                    ],
                    const SizedBox(height: Tokens.s8),
                    ...shellTools(context, expanded: false),
                  ],
                ),
              ),
            ),
            if (railMini != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: Tokens.s4),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Tokens.line)),
                ),
                child: railMini,
              ),
          ],
        ),
      ),
    );

    final stage = SafeArea(
      left: false,
      bottom: mini == null,
      child: ClipRect(
        child: Material(type: MaterialType.transparency, child: body),
      ),
    );

    return liftAboveKeyboard(
      context,
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          rail,
          Expanded(
            child: mini == null
                ? stage
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: stage),
                      ColoredBox(
                        color: Tokens.surface,
                        child: SafeArea(top: false, left: false, child: mini),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.section,
    required this.active,
    required this.label,
    required this.onTap,
  });

  final Section section;
  final bool active;
  final bool label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Tokens.onAccent : Tokens.fgDim;
    final tap = context.layout.minTap;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s4),
      child: Semantics(
        selected: active,
        button: true,
        child: Tooltip(
          message: section.title,
          excludeFromSemantics: label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              customBorder: Tokens.squircle(Tokens.rSm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                constraints: BoxConstraints(minHeight: tap),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(vertical: label ? Tokens.s6 : 0),
                decoration: ShapeDecoration(
                  color: active ? Tokens.accent : Colors.transparent,
                  shape: Tokens.squircle(Tokens.rSm),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SectionBadge(
                      section: section,
                      child: Icon(section.icon, size: 22, color: color),
                    ),
                    if (label) ...[
                      const SizedBox(height: 3),
                      Text(
                        section.shortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
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
