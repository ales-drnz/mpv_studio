import 'package:flutter/material.dart';

import '../ui/layout/layout.dart';
import '../ui/tokens.dart';
import '../ui/widgets/scroll_fade.dart';
import 'nav_parts.dart';
import 'sections.dart';
import 'shell_tools.dart';
import 'snack_clearance.dart';

/// The rail chrome (medium windows, and any low window such as a phone in
/// landscape): a slim icon rail with every section on the left and the
/// section body filling the rest.
///
/// The rail lists icons in pill indicators with short labels, in two
/// groups set apart by a short round divider; on a low window it shows
/// bare pills with tooltips and folds the tools into a More sheet, as the
/// phone bar does. It scrolls when it runs out of height. The body
/// sits in a rounded [StagePanel] on the tonal chrome. A [miniPlayer]
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
    final width = 88.0 + MediaQuery.paddingOf(context).left;
    final mini = miniPlayer;
    final railMini = railMiniPlayer;
    final itemLayout = labels ? NavItemLayout.stacked : NavItemLayout.iconOnly;

    Widget item(Section s) => Padding(
      padding: EdgeInsets.only(bottom: labels ? Tokens.s4 : 0),
      child: SectionDestination(
        section: s,
        active: s == section,
        onTap: () => onSelect(s),
        layout: itemLayout,
      ),
    );

    final tools = shellTools(context, expanded: false);
    final rail = SizedBox(
      width: width,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Expanded(
              // A low window fits its targets with no padding to spare
              // (a phone in landscape: four tabs, More and the rail
              // mini-player in 336); the fade says when it still scrolls.
              child: ScrollFade(
                axis: Axis.vertical,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: Tokens.s8,
                    vertical: labels ? Tokens.s16 : 0,
                  ),
                  child: Column(
                    children: [
                      if (labels) ...[
                        const StudioMark(size: 40),
                        const SizedBox(height: Tokens.s16),
                      ],
                      for (final s in Section.tabs) item(s),
                      // A low window has no height for seven targets and
                      // the mini-player: the tools fold into More, as on
                      // the phone bar.
                      if (labels) ...[
                        const NavGroupGap(),
                        for (final s in Section.more) item(s),
                      ] else
                        MoreDestination(
                          section: section,
                          onSelect: onSelect,
                          layout: NavItemLayout.iconOnly,
                        ),
                      if (tools.isNotEmpty) const SizedBox(height: Tokens.s8),
                      for (final t in tools)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Tokens.s8),
                          child: t,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (railMini != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Tokens.s8,
                  0,
                  Tokens.s8,
                  labels ? Tokens.s8 : 0,
                ),
                child: railMini,
              ),
          ],
        ),
      ),
    );

    final stage = SafeArea(
      bottom: mini == null,
      child: StagePanel(child: body),
    );

    // The chrome is the tonal container; the stage panel and the cards
    // in it sit one and two steps away from it.
    return ColoredBox(
      color: Tokens.surface2,
      child: liftAboveKeyboard(
        context,
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // With the mini-player at its foot, toasts float beside the
            // rail, over the stage.
            if (railMini != null)
              SnackObstacle(edge: SnackEdge.left, child: rail)
            else
              rail,
            // The rail covers the left inset, so the stage must not see it.
            Expanded(
              child: withoutLeftInset(
                mini == null
                    ? stage
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: stage),
                          // Toasts float above the mini-player.
                          SnackObstacle(
                            edge: SnackEdge.bottom,
                            child: SafeArea(top: false, child: mini),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
