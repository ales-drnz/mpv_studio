import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../rack_controller.dart';

/// The line under the page title: how many stages, how many on, and how
/// to work the rack with the input at hand.
String chainSummary(RackController rack, StudioLayout layout) {
  final n = rack.chain.length;
  if (n == 0) return 'No stages: the audio plays as decoded.';
  final on = rack.chain.effects.where((e) => e.enabled).length;
  final count = '$n ${n == 1 ? 'stage' : 'stages'}, $on on.';
  return layout.isTouch
      ? '$count Long-press a stage for actions.'
      : '$count Drag to reorder, right-click for actions.';
}

/// A header action of the rack: a pill with an icon and a label, or the
/// icon alone when [compact]. [active] fills it amber (the bypass).
class RackHeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  const RackHeaderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Tokens.onAccent : Tokens.fg;
    final tap = context.layout.minTap;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: active ? true : null,
        label: label,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(left: Tokens.s8),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              customBorder: Tokens.squircle(Tokens.rSm),
              child: Ink(
                height: tap,
                width: compact ? tap : null,
                padding: compact
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: Tokens.s12),
                decoration: ShapeDecoration(
                  color: active ? Tokens.amber : Tokens.surface2,
                  shape: Tokens.squircle(Tokens.rSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: fg),
                    if (!compact) ...[
                      const SizedBox(width: Tokens.s6),
                      Text(label, style: Tokens.label.copyWith(color: fg)),
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

/// The last refused chain or failure next to it, until dismissed.
class RackErrorBanner extends StatelessWidget {
  final RackController rack;
  const RackErrorBanner({super.key, required this.rack});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('rack-error'),
        margin: const EdgeInsets.only(bottom: Tokens.s8),
        padding: const EdgeInsets.fromLTRB(
          Tokens.s12,
          Tokens.s4,
          Tokens.s4,
          Tokens.s4,
        ),
        decoration: ShapeDecoration(
          color: Tokens.red.withValues(alpha: 0.14),
          shape: Tokens.squircle(Tokens.rSm),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: Tokens.red),
            const SizedBox(width: Tokens.s8),
            Expanded(child: Text(rack.error!, style: Tokens.label)),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: rack.clearError,
              icon: Icon(Icons.close_rounded, size: 16, color: Tokens.fgDim),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ends of the chain, joined to the stages by the signal line.
class RackNode extends StatelessWidget {
  final String label;
  final String detail;
  const RackNode({super.key, required this.label, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s4),
      child: Row(
        children: [
          const SizedBox(width: Tokens.s16),
          Container(
            width: 8,
            height: 8,
            decoration: ShapeDecoration(
              color: Tokens.accentDim,
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: Tokens.s12),
          Text(
            label,
            style: Tokens.caption.copyWith(
              letterSpacing: 1.2,
              color: Tokens.fgDim,
            ),
          ),
          const SizedBox(width: Tokens.s8),
          Flexible(
            child: Text(
              detail,
              style: Tokens.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The chain with no stage yet.
class EmptyRack extends StatelessWidget {
  final VoidCallback onAdd;
  const EmptyRack({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Tokens.s4),
      padding: const EdgeInsets.all(Tokens.s20),
      decoration: ShapeDecoration(
        shape: Tokens.squircle(
          Tokens.rMd,
          side: BorderSide(color: Tokens.line2),
        ),
      ),
      child: Column(
        children: [
          Text(
            'The audio plays as decoded.',
            style: Tokens.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Tokens.s4),
          Text(
            'Add a stage, or pick a quick editor above.',
            style: Tokens.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Tokens.s12),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add stage'),
            style: TextButton.styleFrom(
              foregroundColor: Tokens.accent,
              textStyle: Tokens.label,
            ),
          ),
        ],
      ),
    );
  }
}

/// A flat surface card for the stage detail and the loudness panel.
class RackCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const RackCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Tokens.s16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.s12),
      padding: padding,
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      child: child,
    );
  }
}
