import 'package:flutter/material.dart';

import '../tokens.dart';
import 'controls/control_metrics.dart';
import 'focus_ring.dart';

/// The app's one chip, for filters and shortcuts: a pill in the card tone
/// with an optional [icon], on the secondary selection fill
/// ([Tokens.accentContainer]) when [selected]. The solid accent stays for
/// the primary action of a view.
class StudioChip extends StatelessWidget {
  const StudioChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool selected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Tokens.onAccentContainer : Tokens.fg;
    final chip = Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: tooltip ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: FocusRing(
        child: Material(
          color: selected ? Tokens.accentContainer : Tokens.surface,
          shape: Tokens.pill,
          child: InkWell(
            onTap: onTap,
            customBorder: Tokens.pill,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: controlHeightOf(context)),
              child: Padding(
                padding: EdgeInsets.only(
                  left: icon == null ? Tokens.s16 : Tokens.s12,
                  right: Tokens.s16,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon case final icon?) ...[
                      Icon(icon, size: Tokens.iconSm, color: ink),
                      const SizedBox(width: Tokens.s8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Tokens.label.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}
