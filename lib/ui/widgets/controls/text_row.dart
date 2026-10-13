import 'package:flutter/material.dart';

import '../../tokens.dart';
import 'control_metrics.dart';
import 'setting_tile.dart';

/// Title (+ description) with a full-width single-line text field beneath,
/// in the same flat rounded language as the other controls. Seeds its
/// editing buffer from [value]; reports edits through [onChanged] and the
/// Enter key through [onSubmitted] (give either or both). The controller is reseeded only when
/// [value] changes from outside (e.g. a reset) and the field isn't
/// focused, so live typing is never clobbered.
class TextRow extends StatefulWidget {
  final String label;
  final String? description;
  final String value;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  /// Called with the text when the user presses Enter.
  final ValueChanged<String>? onSubmitted;

  /// Monospace text, for URLs, paths and option values.
  final bool monospace;

  /// A trailing widget inside the field (a "Choose" or "Apply" button).
  final Widget? action;

  const TextRow({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.description,
    this.hint,
    this.enabled = true,
    this.onSubmitted,
    this.monospace = true,
    this.action,
  });

  @override
  State<TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<TextRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(TextRow old) {
    super.didUpdateWidget(old);
    // Resync from an external change (reset, engine sync) only while the
    // field is unfocused, so it never overwrites what the user is typing.
    if (widget.value != _controller.text && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = AppTextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      hint: widget.hint,
      semanticLabel: widget.label,
      monospace: widget.monospace,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      action: widget.action,
    );
    return SettingTile(
      title: widget.label,
      description: widget.description,
      enabled: widget.enabled,
      below: field,
    );
  }
}

/// The app's flat single-line text field: a rounded box at the control
/// height ([controlHeightOf]), surface2 fill, text vertically centred, an
/// optional trailing [action]. Shared by [TextRow] and the search fields.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String? hint;
  final String? semanticLabel;
  final bool monospace;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? leading;
  final Widget? action;
  final TextInputAction? textInputAction;

  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.hint,
    this.semanticLabel,
    this.monospace = false,
    this.onChanged,
    this.onSubmitted,
    this.leading,
    this.action,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final style = Tokens.body.copyWith(
      fontFamily: monospace ? Tokens.mono : null,
      color: enabled ? Tokens.fg : Tokens.fgFaint,
    );
    return Container(
      constraints: BoxConstraints(minHeight: controlHeightOf(context)),
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.shape(Tokens.rSm),
      ),
      padding: EdgeInsets.only(
        left: leading == null ? Tokens.s12 : Tokens.s8,
        right: action == null ? Tokens.s12 : Tokens.s4,
      ),
      // A Row centres the field vertically; a TextField forced to the full
      // height would top-anchor its text instead.
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Tokens.s8)],
          Expanded(
            child: Semantics(
              label: semanticLabel,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: textInputAction,
                style: style,
                cursorColor: Tokens.accent,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: Tokens.s8,
                  ),
                  hintText: hint,
                  hintStyle: Tokens.caption,
                  hintMaxLines: 1,
                ),
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
