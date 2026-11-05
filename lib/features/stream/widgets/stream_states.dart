import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/empty_state.dart';

/// The widest a sign-in card gets: the form width, under the narrowest
/// medium window, so it reads as one column at every size.
const double streamCardWidth = Breakpoints.form;

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
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  color: Tokens.accent,
                  backgroundColor: Tokens.surface3,
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

/// A centred message for an empty or failed state, the app's
/// [EmptyState]: a glyph in a circle, a title, an optional explanation,
/// an optional action (Retry, Sign in again) and, for a failure, its
/// technical [details] on request.
class StreamMessage extends StatelessWidget {
  const StreamMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.error = false,
    this.details,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A failure: the glyph in red, and a live region.
  final bool error;

  /// What the failure was, in the system's words.
  final String? details;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: error,
      child: EmptyState(
        icon: icon,
        title: title,
        message: message,
        tone: error ? EmptyTone.error : EmptyTone.neutral,
        details: details,
        actions: [
          if (actionLabel != null && onAction != null)
            StreamButton(label: actionLabel!, onPressed: onAction),
        ],
      ),
    );
  }
}

/// The Stream page's primary button: the accent pill, at least one tap
/// target tall, a spinner in place of the label while [busy]. [expand]
/// stretches it to the full width (a form's submit on a phone).
class StreamButton extends StatelessWidget {
  const StreamButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final h = controlHeightOf(context);
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        // Busy keeps the accent so the spinner reads as progress, not as
        // a disabled button.
        disabledBackgroundColor: busy ? Tokens.accent : Tokens.surface4,
        disabledForegroundColor: busy ? Tokens.onAccent : Tokens.fgFaint,
        minimumSize: Size(expand ? double.infinity : 96, h),
      ),
      child: busy
          ? Semantics(
              label: '$label, in progress',
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  strokeCap: StrokeCap.round,
                  color: Tokens.onAccent,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: Tokens.s8),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}
