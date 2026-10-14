import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';

/// The widest a sign-in card or a state message gets: a comfortable form
/// width, well under the narrowest medium window (`Breakpoints.medium`), so
/// it reads as one column at every size.
const double streamCardWidth = 440;

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

/// A centred message for an empty or failed state: a glyph in a tonal
/// circle, a title, an optional explanation and an optional action (Retry,
/// Sign in again). A failure sets the explanation in red on a red tint.
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

  /// A failure: the glyph and the explanation in red.
  final bool error;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Center(
      child: SingleChildScrollView(
        // Centred, so as far from the top as from the page end.
        padding: EdgeInsets.symmetric(
          horizontal: Tokens.s16,
          vertical: PageEnd.of(context),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: streamCardWidth),
          child: Semantics(
            liveRegion: error,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: ShapeDecoration(
                    color: error
                        ? Tokens.red.withValues(alpha: 0.14)
                        : Tokens.surface3,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: error ? Tokens.red : Tokens.fgDim,
                  ),
                ),
                const SizedBox(height: Tokens.s16),
                Text(
                  title,
                  style: Tokens.heading.copyWith(fontSize: 20, height: 28 / 20),
                  textAlign: TextAlign.center,
                ),
                if (message != null) ...[
                  const SizedBox(height: Tokens.s8),
                  if (error)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Tokens.s12),
                      decoration: ShapeDecoration(
                        color: Tokens.red.withValues(alpha: 0.14),
                        shape: Tokens.shape(Tokens.rMd),
                      ),
                      child: Text(
                        message,
                        style: Tokens.body.copyWith(color: Tokens.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Text(
                      message,
                      style: Tokens.body.copyWith(color: Tokens.fgDim),
                      textAlign: TextAlign.center,
                    ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: Tokens.s24),
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
