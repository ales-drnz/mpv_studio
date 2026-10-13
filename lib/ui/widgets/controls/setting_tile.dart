import 'package:flutter/material.dart';

import '../../layout/layout_scope.dart';
import '../../tokens.dart';

/// The uniform settings row: a title, an optional description, and then the
/// interaction. Compact controls (switch, value readout, button) sit at the
/// trailing edge of the header; wide controls (slider, selector, dropdown)
/// sit on their own line beneath it. Every settings control is built on
/// this so the whole panel reads with one rhythm.
///
/// The row is at least one tap target tall (`context.layout.minTap`).
class SettingTile extends StatelessWidget {
  final String title;
  final String? description;

  /// Compact control aligned to the trailing edge of the header row.
  final Widget? trailing;

  /// Wide control rendered full-width under the header.
  final Widget? below;

  final bool enabled;

  /// Makes the whole row tappable (used by switch rows).
  final VoidCallback? onTap;

  /// What the row announces when it is tappable, merged with its title
  /// (a switch's on or off state, for one).
  final bool? toggled;

  const SettingTile({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.below,
    this.enabled = true,
    this.onTap,
    this.toggled,
  });

  @override
  Widget build(BuildContext context) {
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Tokens.body.copyWith(
                  color: enabled ? Tokens.fg : Tokens.fgFaint,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  // Dim rather than faint: it stays legible on the light
                  // palette.
                  style: Tokens.caption.copyWith(color: Tokens.fgDim),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: Tokens.s12), trailing!],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (below != null)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.s12),
            child: below,
          ),
      ],
    );

    final padded = ConstrainedBox(
      constraints: BoxConstraints(minHeight: context.layout.minTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.s12),
        child: Align(alignment: Alignment.centerLeft, child: content),
      ),
    );

    if (onTap == null) return padded;
    return Semantics(
      button: toggled == null,
      toggled: toggled,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: Tokens.shape(Tokens.rSm),
        child: padded,
      ),
    );
  }
}
