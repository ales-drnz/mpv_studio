import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../stream_actions.dart';

/// One row of every Stream list (reference streams, server tracks, Samba
/// entries): a rounded card with a leading glyph, a title over an optional
/// subtitle, and trailing buttons. The row that started the current track
/// gets the accent wash and a speaker glyph.
///
/// With [menu] the row has a context menu: right click on a pointer, long
/// press (a bottom sheet) on touch.
class StreamRow extends StatelessWidget {
  const StreamRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.current = false,
    this.onTap,
    this.trailing = const [],
    this.menu,
    this.onMenu,
    this.monoSubtitle = false,
  });

  final String title;
  final String? subtitle;

  /// The leading glyph; null for none. The current row always shows the
  /// speaker glyph.
  final IconData? icon;

  /// Whether this row started the current track.
  final bool current;

  final VoidCallback? onTap;
  final List<Widget> trailing;

  /// The context menu entries, built when the menu opens.
  final List<StudioMenuItem<RowAction>> Function()? menu;
  final ValueChanged<RowAction>? onMenu;

  /// Sets the subtitle in the monospace face (URLs, paths).
  final bool monoSubtitle;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final glyph = current ? Icons.volume_up_rounded : icon;
    final shape = Tokens.shape(Tokens.rSm);
    Widget row = Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s6),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          // Ink so the hover highlight shows over the card surface.
          child: Ink(
            decoration: ShapeDecoration(
              color: current ? Tokens.accentWash : Tokens.surface,
              shape: shape,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: layout.minTap + 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.s12,
                  Tokens.s6,
                  Tokens.s4,
                  Tokens.s6,
                ),
                child: Row(
                  children: [
                    if (glyph != null) ...[
                      Icon(
                        glyph,
                        size: 18,
                        color: current || icon == Icons.folder_rounded
                            ? Tokens.accent
                            : Tokens.fgFaint,
                      ),
                      const SizedBox(width: Tokens.s12),
                    ],
                    Expanded(child: _texts()),
                    ...trailing,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    row = Semantics(
      selected: current,
      hint: current ? 'Now playing' : null,
      child: row,
    );
    final menu = this.menu, onMenu = this.onMenu;
    if (menu == null || onMenu == null) return row;
    return StudioMenuRegion<RowAction>(
      title: title,
      items: menu,
      onSelected: onMenu,
      child: row,
    );
  }

  Widget _texts() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Tokens.body.copyWith(
          color: current ? Tokens.accent : Tokens.fg,
          fontWeight: current ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      if (subtitle != null && subtitle!.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: monoSubtitle
              ? Tokens.caption.copyWith(fontFamily: Tokens.mono)
              : Tokens.caption.copyWith(color: Tokens.fgDim),
        ),
      ],
    ],
  );
}

/// A trailing icon button of a [StreamRow] (and of the bars above the
/// lists): always tooltipped, at least one tap target big.
class RowButton extends StatelessWidget {
  const RowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = false,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Draws the glyph in the accent (the primary action of a row).
  final bool accent;

  /// Draws the glyph in the accent as a toggled-on state (a favourite).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tap = context.layout.minTap;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      isSelected: selected,
      icon: Icon(icon, size: 20),
      color: accent || selected ? Tokens.accent : Tokens.fgDim,
      disabledColor: Tokens.fgFaint,
      constraints: BoxConstraints.tightFor(width: tap, height: tap),
      padding: EdgeInsets.zero,
    );
  }
}
