import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';

/// A centred spinner with an optional [label], for a tab or list that is
/// loading.
class StreamLoading extends StatelessWidget {
  const StreamLoading({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.s16),
        child: Semantics(
          liveRegion: true,
          label: label ?? 'Loading',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Tokens.accent,
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: Tokens.s12),
                ExcludeSemantics(
                  child: Text(
                    label!,
                    style: Tokens.label,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A centred message for an empty or failed state: a glyph, a title, an
/// optional explanation and an optional action (Retry, Sign in again).
class StreamMessage extends StatelessWidget {
  const StreamMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Draws the glyph in red.
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Tokens.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Semantics(
            liveRegion: error,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: error ? Tokens.red : Tokens.fgFaint,
                ),
                const SizedBox(height: Tokens.s12),
                Text(title, style: Tokens.heading, textAlign: TextAlign.center),
                if (message != null) ...[
                  const SizedBox(height: Tokens.s6),
                  Text(
                    message!,
                    style: Tokens.label,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: Tokens.s16),
                  StreamButton(label: actionLabel!, onPressed: onAction),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Stream page's filled button: accent fill, at least one tap target
/// tall, a spinner in place of the label while [busy].
class StreamButton extends StatelessWidget {
  const StreamButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.onAccent,
        disabledBackgroundColor: Tokens.surface3,
        disabledForegroundColor: Tokens.fgDim,
        minimumSize: Size(96, context.layout.minTap + 4),
        shape: Tokens.squircle(Tokens.rSm) as OutlinedBorder,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
      child: busy
          ? Semantics(
              label: '$label, in progress',
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Tokens.fgDim,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: Tokens.s8),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}
