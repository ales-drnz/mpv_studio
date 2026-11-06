import 'package:flutter/material.dart';

import '../tokens.dart';

/// What an [InlineNotice] tells.
enum NoticeTone {
  /// Something failed: red.
  error,

  /// Something needs attention: amber.
  warning,
}

/// The one notice set into a page or a form: the tone's colour as a wash,
/// its [icon] in the tone, the [text] in the body colour (the tone's own
/// colour on its wash would fall under 4.5:1) and an optional [action]
/// at the end, which wraps under the text when the row is narrow. It is
/// a live region, so a screen reader reads it when it appears.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.tone,
    required this.icon,
    required this.text,
    this.action,
  });

  final NoticeTone tone;
  final IconData icon;
  final String text;

  /// A button that resolves it.
  final Widget? action;

  Color get _color => switch (tone) {
    NoticeTone.error => Tokens.red,
    NoticeTone.warning => Tokens.amber,
  };

  @override
  Widget build(BuildContext context) {
    final message = Row(
      mainAxisSize: action == null ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: Tokens.iconMd, color: _color),
        const SizedBox(width: Tokens.s12),
        Flexible(child: Text(text, style: Tokens.body)),
      ],
    );
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: _color.withValues(alpha: Tokens.semanticWash),
        shape: Tokens.shape(Tokens.rMd),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Tokens.s16,
            Tokens.s12,
            action == null ? Tokens.s16 : Tokens.s12,
            Tokens.s12,
          ),
          child: action == null
              ? message
              : Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Tokens.s12,
                  runSpacing: Tokens.s8,
                  children: [message, action!],
                ),
        ),
      ),
    );
  }
}
