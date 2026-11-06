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
    this.compact = false,
    this.padding,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Buttons, the first one the way forward.
  final List<Widget> actions;
  final EmptyTone tone;

  /// The technical cause, shown on request.
  final String? details;

  /// The small form, for a state inside a panel or a card (a log with no
  /// lines, a chart with nothing to draw): a smaller badge and a heading
  /// instead of a title.
  final bool compact;

  /// The space around it; [Tokens.s24] (16 when [compact]) by default.
  final EdgeInsetsGeometry? padding;

  /// The badge's diameter and its icon's size.
  static const double badge = 72;
  static const double glyph = 32;

  /// The same in the [compact] form.
  static const double badgeCompact = 48;
  static const double glyphCompact = 24;

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
    final compact = widget.compact;
    final badge = compact ? EmptyState.badgeCompact : EmptyState.badge;
    final padding =
        widget.padding ?? EdgeInsets.all(compact ? Tokens.s16 : Tokens.s24);
    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: EmptyState.maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: badge,
              height: badge,
              decoration: ShapeDecoration(
                color: error
                    ? Tokens.red.withValues(alpha: Tokens.semanticWash)
                    : Tokens.surface3,
                shape: const CircleBorder(),
              ),
              child: Icon(
                widget.icon,
                size: compact ? EmptyState.glyphCompact : EmptyState.glyph,
                color: error ? Tokens.red : Tokens.fgDim,
              ),
            ),
          ),
          SizedBox(height: compact ? Tokens.s12 : Tokens.s16),
          Semantics(
            header: true,
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: compact ? Tokens.heading : Tokens.titleSm,
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
            SizedBox(height: compact ? Tokens.s16 : Tokens.s24),
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
    );
    // Scrolls where its height is bounded (a page, a panel); inside a
    // list that already scrolls it simply takes its own height.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? Center(
              child: SingleChildScrollView(padding: padding, child: body),
            )
          : Padding(
              padding: padding,
              child: Center(child: body),
            ),
    );
  }
}
