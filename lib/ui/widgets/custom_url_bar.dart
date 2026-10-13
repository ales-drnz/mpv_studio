import 'package:flutter/material.dart';

import '../tokens.dart';

/// A shared "play any URL" bar used at the top of the Stream page's reference
/// tabs (Lab, Chapters). A monospace URL field with a play button;
/// submitting (enter or the button) hands the trimmed URL to [onPlay]. The
/// field keeps its text so the same URL can be replayed.
class CustomUrlBar extends StatefulWidget {
  /// Placeholder shown when the field is empty.
  final String hint;

  /// Called with the trimmed URL when the user submits a non-empty value.
  final ValueChanged<String> onPlay;

  const CustomUrlBar({
    super.key,
    required this.onPlay,
    this.hint = 'Paste a URL',
  });

  @override
  State<CustomUrlBar> createState() => _CustomUrlBarState();
}

class _CustomUrlBarState extends State<CustomUrlBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    widget.onPlay(url);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Tokens.controlH,
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.squircle(Tokens.rSm),
      ),
      padding: const EdgeInsets.only(left: Tokens.s12, right: Tokens.s4),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 16, color: Tokens.fgFaint),
          const SizedBox(width: Tokens.s8),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _play(),
              textInputAction: TextInputAction.go,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(
                fontFamily: Tokens.mono,
                fontSize: 12.5,
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
          IconButton(
            onPressed: _play,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            color: Tokens.accent,
            splashRadius: 18,
            tooltip: 'Play',
          ),
        ],
      ),
    );
  }
}
