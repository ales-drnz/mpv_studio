import 'package:flutter/material.dart';

import '../tokens.dart';

/// The tone of an [EmptyState].
enum EmptyTone {
  /// Nothing here yet: a neutral badge.
  neutral,

  /// Something failed: a red badge and the [EmptyState.details] to expand.
  error,
}

/// The one empty and error state of the app: a round badge with an icon,
/// a [title], a line or two of [message] and the [actions] that move on,
/// centred in the space it gets. An error can carry the technical
/// [details] (an exception, a server's answer) behind a "Details" toggle,
/// so the message itself stays in the user's words.
class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
    this.tone = EmptyTone.neutral,
    this.details,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Buttons, the first one the way forward.
  final List<Widget> actions;
  final EmptyTone tone;

  /// The technical cause, shown on request.
  final String? details;

  /// The badge's diameter and its icon's size.
  static const double badge = 72;
  static const double glyph = 32;

  /// The widest the text runs.
  static const double maxWidth = 440;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> {
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final error = widget.tone == EmptyTone.error;
    final details = widget.details;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Tokens.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: EmptyState.maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: EmptyState.badge,
                  height: EmptyState.badge,
                  decoration: ShapeDecoration(
                    color: error
                        ? Tokens.red.withValues(alpha: 0.14)
                        : Tokens.surface3,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    widget.icon,
                    size: EmptyState.glyph,
                    color: error ? Tokens.red : Tokens.fgDim,
                  ),
                ),
              ),
              const SizedBox(height: Tokens.s16),
              Semantics(
                header: true,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: Tokens.titleSm,
                ),
              ),
              if (widget.message case final message?) ...[
                const SizedBox(height: Tokens.s8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Tokens.body.copyWith(color: Tokens.fgDim),
                ),
              ],
              if (widget.actions.isNotEmpty) ...[
                const SizedBox(height: Tokens.s24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Tokens.s8,
                  runSpacing: Tokens.s8,
                  children: widget.actions,
                ),
              ],
              if (details != null) ...[
                const SizedBox(height: Tokens.s16),
                TextButton.icon(
                  onPressed: () => setState(() => _details = !_details),
                  icon: Icon(
                    _details
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  label: const Text('Details'),
                ),
                if (_details)
                  SelectableText(
                    details,
                    textAlign: TextAlign.center,
                    style: Tokens.numeric,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
