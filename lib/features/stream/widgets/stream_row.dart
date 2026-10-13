import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/round_icon_button.dart';
import '../stream_actions.dart';

/// One row of every Stream list (reference streams, server tracks, Samba
/// entries): a tonal card with a leading glyph in a circle, a title over an
/// optional subtitle, and trailing buttons. The row that started the
/// current track takes the secondary selection fill and an equalizer glyph.
///
/// With [menu] the row has a context menu: right click on a pointer, long
/// press (a bottom sheet) on touch.
class StreamRow extends StatelessWidget {
  const StreamRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
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
  /// equalizer glyph.
  final IconData? icon;

  /// A leading picture ([leadSize] square) in place of [icon], such as a
  /// cover; the current row still shows the equalizer glyph.
  final Widget? leading;

  /// Whether this row started the current track.
  final bool current;

  final VoidCallback? onTap;
  final List<Widget> trailing;

  /// The context menu entries, built when the menu opens.
  final List<StudioMenuItem<RowAction>> Function()? menu;
  final ValueChanged<RowAction>? onMenu;

  /// Sets the subtitle in the monospace face (URLs, paths).
  final bool monoSubtitle;

  /// The diameter of the leading glyph circle.
  static const double leadSize = 40;

  /// Whether [context] sits inside the current row (its buttons and text
  /// take the colours that read on the selection fill).
  static bool onCurrent(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CurrentRow>() != null;

  @override
  Widget build(BuildContext context) {
    final glyph = current ? Icons.graphic_eq_rounded : icon;
    final shape = Tokens.shape(Tokens.rMd);
    final content = Row(
      children: [
        if (!current && leading != null) ...[
          SizedBox.square(dimension: leadSize, child: leading),
          const SizedBox(width: Tokens.s12),
        ] else if (glyph != null) ...[
          _Lead(glyph: glyph, current: current),
          const SizedBox(width: Tokens.s12),
        ] else
          const SizedBox(width: Tokens.s8),
        Expanded(child: _texts()),
        ...trailing,
      ],
    );
    Widget row = Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s4),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          // Ink so the hover wash shows over the card fill.
          child: Ink(
            decoration: ShapeDecoration(
              color: current ? Tokens.accentContainer : Tokens.surface,
              shape: shape,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: leadSize + 2 * Tokens.s8,
              ),
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s8),
                child: current ? _CurrentRow(child: content) : content,
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

  Widget _texts() {
    final ink = current ? Tokens.onAccentContainer : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Tokens.body.copyWith(
            color: ink ?? Tokens.fg,
            fontWeight: current ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: Tokens.s4),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tokens.label.copyWith(
              fontFamily: monoSubtitle ? Tokens.mono : null,
              fontWeight: FontWeight.w400,
              color: ink ?? Tokens.fgDim,
            ),
          ),
        ],
      ],
    );
  }
}

/// Marks the subtree of the current row.
class _CurrentRow extends InheritedWidget {
  const _CurrentRow({required super.child});

  @override
  bool updateShouldNotify(_CurrentRow oldWidget) => false;
}

/// The leading glyph of a row in a tonal circle; on the current row a
/// graphite disc on the ring grey fill, the logo's own pairing.
class _Lead extends StatelessWidget {
  const _Lead({required this.glyph, required this.current});

  final IconData glyph;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: StreamRow.leadSize,
        height: StreamRow.leadSize,
        decoration: ShapeDecoration(
          color: current ? Tokens.onAccentContainer : Tokens.surface3,
          shape: const CircleBorder(),
        ),
        child: Icon(
          glyph,
          size: 20,
          color: current ? Tokens.accentContainer : Tokens.fgDim,
        ),
      ),
    );
  }
}

/// A trailing icon button of a [StreamRow] (and of the bars above the
/// lists): a bare icon in a circle, always tooltipped, at least one tap
/// target big. Inside the current row it takes the selection's content
/// colour.
class RowButton extends StatelessWidget {
  const RowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// A toggle's state (a favourite): the secondary selection fill when
  /// on; null for a plain action.
  final bool? selected;

  @override
  Widget build(BuildContext context) => RoundIconButton(
    icon: icon,
    size: 20,
    tooltip: tooltip,
    selected: selected,
    onContainer: StreamRow.onCurrent(context),
    onTap: onPressed,
  );
}
