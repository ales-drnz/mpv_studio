import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/layout_scope.dart';
import '../tokens.dart';

/// A "play any URL" bar: a monospace URL field with a play button, and an
/// add to queue button when [onQueue] is given. Submitting (Enter or the
/// play button) hands the trimmed URL to [onPlay]; an empty field does
/// nothing. The field keeps its text so the same URL can be replayed.
/// [trailing] adds buttons after the built-in ones (an options toggle).
class CustomUrlBar extends StatefulWidget {
  const CustomUrlBar({
    super.key,
    required this.onPlay,
    this.onQueue,
    this.controller,
    this.hint = 'Paste a URL',
    this.trailing = const [],
  });

  /// Called with the trimmed URL when the user plays a non-empty value.
  final ValueChanged<String> onPlay;

  /// Called with the trimmed URL to add it to the queue; null hides the
  /// button.
  final ValueChanged<String>? onQueue;

  /// The field's text; the bar owns one when null.
  final TextEditingController? controller;

  /// Placeholder shown when the field is empty.
  final String hint;

  final List<Widget> trailing;

  @override
  State<CustomUrlBar> createState() => _CustomUrlBarState();
}

class _CustomUrlBarState extends State<CustomUrlBar> {
  TextEditingController? _own;
  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _submit(ValueChanged<String>? action) {
    final url = _controller.text.trim();
    if (url.isEmpty || action == null) return;
    action(url);
  }

  @override
  Widget build(BuildContext context) {
    final tap = context.layout.minTap;
    final buttons = BoxConstraints.tightFor(width: tap, height: tap);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: math.max(Tokens.controlH, tap)),
      child: DecoratedBox(
        decoration: ShapeDecoration(color: Tokens.surface3, shape: Tokens.pill),
        child: Padding(
          padding: const EdgeInsets.only(left: Tokens.s16),
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: Tokens.fgFaint),
              const SizedBox(width: Tokens.s8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(widget.onPlay),
                  textInputAction: TextInputAction.go,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: TextStyle(
                    fontFamily: Tokens.mono,
                    fontSize: 13,
                    color: Tokens.fg,
                  ),
                  cursorColor: Tokens.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hint,
                    hintStyle: Tokens.caption,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (widget.onQueue != null)
                IconButton(
                  onPressed: () => _submit(widget.onQueue),
                  icon: const Icon(Icons.playlist_add_rounded, size: 20),
                  color: Tokens.fgDim,
                  constraints: buttons,
                  padding: EdgeInsets.zero,
                  tooltip: 'Add to queue',
                ),
              IconButton(
                onPressed: () => _submit(widget.onPlay),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                color: Tokens.accent,
                constraints: buttons,
                padding: EdgeInsets.zero,
                tooltip: 'Play',
              ),
              ...widget.trailing,
            ],
          ),
        ),
      ),
    );
  }
}
