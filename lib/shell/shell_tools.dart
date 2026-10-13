import 'package:flutter/material.dart';

import '../ui/layout/layout.dart';
import '../ui/theme_host.dart';
import '../ui/tokens.dart';
import 'playback_shortcuts.dart';

/// A quiet utility entry of the shell navigation: a pill row with a
/// [label] in the More sheet ([expanded]), or a tonal circle with the
/// label as tooltip at the foot of the sidebar and the rail.
class ShellToolButton extends StatelessWidget {
  const ShellToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.expanded = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tap = context.layout.minTap < 40 ? 40.0 : context.layout.minTap;
    final glyph = Icon(icon, size: 20, color: Tokens.fgDim);
    // Icon only: a tonal circle. Expanded: a full-width pill row.
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: Material(
          color: expanded ? Colors.transparent : Tokens.surface3,
          shape: expanded ? Tokens.pill : const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: expanded ? Tokens.pill : const CircleBorder(),
            child: expanded
                ? ConstrainedBox(
                    constraints: BoxConstraints(minHeight: tap),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.s16,
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
                              style: Tokens.label.copyWith(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox.square(
                    dimension: tap,
                    child: Center(child: glyph),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The shell's utility entries on pointer devices: a quick theme switch
/// (when a [StudioThemeHost] is above; its home is Settings, Listening,
/// Appearance) and the keyboard shortcut list. Touch layouts have none.
List<Widget> shellTools(BuildContext context, {bool expanded = true}) {
  if (!context.layout.isPointer) return const [];
  final theme = ThemeController.maybeOf(context);
  return [
    if (theme != null)
      ShellToolButton(
        icon: theme.icon,
        label: 'Theme: ${theme.label}',
        onTap: theme.cycle,
        expanded: expanded,
      ),
    ShellToolButton(
      icon: Icons.keyboard_outlined,
      label: 'Keyboard shortcuts',
      onTap: () => showShortcutHelp(context),
      expanded: expanded,
    ),
  ];
}

/// Pads [child] up by the soft keyboard and hides that inset from the
/// pages below, so nothing is covered and nothing pads twice.
Widget liftAboveKeyboard(BuildContext context, Widget child) {
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  return Padding(
    padding: EdgeInsets.only(bottom: keyboard),
    child: MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: child,
    ),
  );
}

/// Hides the left safe-area inset from [child]: content to the right of
/// the rail or the sidebar, which already cover that inset themselves.
Widget withoutLeftInset(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).removePadding(removeLeft: true),
    child: child,
  ),
);
