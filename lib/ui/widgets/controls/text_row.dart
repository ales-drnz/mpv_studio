import 'package:flutter/material.dart';

import 'app_text_field.dart';
import 'setting_tile.dart';

/// Title (+ description) with a full-width single-line text field beneath,
/// in the same flat pill language as the other controls. Seeds its
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
      label: widget.label,
      monospace: widget.monospace,
      // Monospace rows hold URLs, paths and option values, not prose.
      autocorrect: !widget.monospace,
      enableSuggestions: !widget.monospace,
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
