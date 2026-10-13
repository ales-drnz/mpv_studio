import 'package:flutter/material.dart';

import '../tokens.dart';
import 'controls/app_text_field.dart';
import 'round_icon_button.dart';

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
    return AppTextField(
      controller: _controller,
      label: 'URL',
      hint: widget.hint,
      monospace: true,
      keyboardType: TextInputType.url,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => _submit(widget.onPlay),
      leading: Icon(Icons.link_rounded, size: 18, color: Tokens.fgDim),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onQueue != null)
            RoundIconButton(
              icon: Icons.playlist_add_rounded,
              size: 20,
              color: Tokens.fgDim,
              tooltip: 'Add to queue',
              onTap: () => _submit(widget.onQueue),
            ),
          RoundIconButton(
            icon: Icons.play_arrow_rounded,
            size: 22,
            color: Tokens.accent,
            tooltip: 'Play',
            onTap: () => _submit(widget.onPlay),
          ),
          ...widget.trailing,
        ],
      ),
    );
  }
}
