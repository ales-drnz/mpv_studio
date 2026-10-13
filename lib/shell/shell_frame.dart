import 'package:flutter/material.dart';

import '../ui/layout/layout.dart';
import 'desktop_shell.dart';
import 'mini_player.dart';
import 'mobile_shell.dart';
import 'rail_shell.dart';
import 'sections.dart';

/// Builds the mini-player in the shape the shell asks for.
typedef MiniPlayerBuilder =
    Widget Function(BuildContext context, MiniPlayerVariant variant);

/// Picks the navigation chrome for the window ([StudioLayout.navigation]):
/// [MobileShell] with a bottom tab bar on compact windows, [RailShell] on
/// medium and low ones, [DesktopShell] with the sidebar from expanded up.
/// [miniPlayer], when given, is built in the variant that fits: a compact
/// bar above the tab bar, a vertical stack in the rail of a low window,
/// and a full bar elsewhere.
class ShellFrame extends StatelessWidget {
  const ShellFrame({
    super.key,
    required this.section,
    required this.onSelect,
    required this.body,
    this.miniPlayer,
  });

  final Section section;
  final ValueChanged<Section> onSelect;
  final Widget body;
  final MiniPlayerBuilder? miniPlayer;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final mini = miniPlayer;
    Widget? build(MiniPlayerVariant v) =>
        mini == null ? null : mini(context, v);
    switch (layout.navigation) {
      case ShellNavigation.bottomBar:
        return MobileShell(
          section: section,
          onSelect: onSelect,
          body: body,
          miniPlayer: build(MiniPlayerVariant.compact),
        );
      case ShellNavigation.rail:
        return RailShell(
          section: section,
          onSelect: onSelect,
          body: body,
          miniPlayer: layout.isShort ? null : build(MiniPlayerVariant.bar),
          railMiniPlayer: layout.isShort ? build(MiniPlayerVariant.rail) : null,
        );
      case ShellNavigation.sidebar:
        return DesktopShell(
          section: section,
          onSelect: onSelect,
          body: body,
          miniPlayer: build(MiniPlayerVariant.bar),
        );
    }
  }
}
