import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import 'stream_states.dart';

/// The input decoration of every Stream text field: a field pill
/// ([Tokens.surface3]) with an optional leading glyph, an accent ring when
/// focused and a red one when invalid, the error under the pill. One
/// control height tall ([controlHeightOf]).
InputDecoration streamFieldDecoration(
  BuildContext context, {
  String? hint,
  IconData? icon,
  Widget? suffix,
}) {
  final h = controlHeightOf(context);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(h / 2),
    borderSide: color == Colors.transparent
        ? BorderSide.none
        : BorderSide(color: color, width: 2),
  );
  // The text line is 20 high; the rest of the control height is padding.
  final v = (h - 20) / 2;
  return InputDecoration(
    hintText: hint,
    isDense: true,
    // The compact pointer density would take 8 off the control height.
    visualDensity: VisualDensity.standard,
    filled: true,
    fillColor: Tokens.surface3,
    hoverColor: Colors.transparent,
    hintStyle: Tokens.body.copyWith(color: Tokens.fgFaint),
    hintMaxLines: 1,
    errorStyle: Tokens.label.copyWith(color: Tokens.red),
    errorMaxLines: 3,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    prefixIconColor: Tokens.fgDim,
    prefixIconConstraints: const BoxConstraints(
      minWidth: Tokens.s48,
      minHeight: Tokens.s24,
    ),
    suffixIcon: suffix,
    contentPadding: EdgeInsetsDirectional.only(
      start: icon == null ? Tokens.s16 : 0,
      end: Tokens.s16,
      top: v,
      bottom: v,
    ),
    border: border(Colors.transparent),
    enabledBorder: border(Colors.transparent),
    focusedBorder: border(Tokens.accent),
    errorBorder: border(Tokens.red),
    focusedErrorBorder: border(Tokens.red),
  );
}

/// The text style of Stream text fields: monospace, since they hold hosts,
/// URLs and names.
TextStyle get streamFieldStyle =>
    Tokens.body.copyWith(fontFamily: Tokens.mono, fontSize: 13);

/// The label above a Stream field, inset like the field's text.
class StreamFieldLabel extends StatelessWidget {
  const StreamFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.only(
        left: Tokens.s16,
        right: Tokens.s16,
        bottom: Tokens.s8,
      ),
      child: Text(
        text,
        style: Tokens.label.copyWith(
          color: Tokens.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// A labelled text field of a sign-in form: the label above a field pill.
/// Enter moves to the next field, and submits on the last one
/// ([onSubmitted]).
class StreamTextField extends StatelessWidget {
  const StreamTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.validator,
    this.onSubmitted,
    this.keyboardType,
    this.autofillHints,
    this.last = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final FormFieldValidator<String>? validator;

  /// Called on Enter in the [last] field.
  final VoidCallback? onSubmitted;

  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  /// Whether this is the form's last field: Enter submits instead of moving
  /// on.
  final bool last;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamFieldLabel(label),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            validator: validator,
            autofocus: autofocus,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            autocorrect: false,
            enableSuggestions: !obscure && keyboardType != TextInputType.url,
            textInputAction: last ? TextInputAction.go : TextInputAction.next,
            onFieldSubmitted: last ? (_) => onSubmitted?.call() : null,
            style: streamFieldStyle,
            cursorColor: Tokens.accent,
            decoration: streamFieldDecoration(context, hint: hint, icon: icon),
          ),
        ),
      ],
    );
  }
}

/// A required-field validator with the message "[what] is required.".
FormFieldValidator<String> requiredField(String what) =>
    (value) =>
        (value == null || value.trim().isEmpty) ? '$what is required.' : null;

/// The sign-in card of a server tab: a tonal card with the server's glyph
/// in a circle beside the title and subtitle, the fields, the error of the
/// last attempt and the submit button (full width on a phone), centred and
/// width capped. It scrolls, so the focused field stays above the soft
/// keyboard. The fields sit in a [Form] under [formKey], so [onSubmit] can
/// validate them first.
class SignInCard extends StatelessWidget {
  const SignInCard({
    super.key,
    required this.formKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.onSubmit,
    this.busy = false,
    this.error,
    this.submitLabel = 'Connect',
  });

  final GlobalKey<FormState> formKey;

  /// The server's glyph.
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> fields;
  final VoidCallback onSubmit;
  final bool busy;
  final String? error;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final error = this.error;
    final submit = StreamButton(
      label: submitLabel,
      busy: busy,
      onPressed: onSubmit,
      expand: layout.isCompact,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.symmetric(
          vertical: layout.isShort ? Tokens.s8 : Tokens.s16,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: streamCardWidth),
          child: Container(
            padding: EdgeInsets.all(layout.isCompact ? Tokens.s16 : Tokens.s24),
            decoration: ShapeDecoration(
              color: Tokens.surface,
              shape: Tokens.shape(Tokens.rLg),
            ),
            child: Form(
              key: formKey,
              child: FocusTraversalGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: Tokens.s48,
                            height: Tokens.s48,
                            decoration: ShapeDecoration(
                              color: Tokens.surface3,
                              shape: const CircleBorder(),
                            ),
                            child: Icon(icon, size: 24, color: Tokens.fg),
                          ),
                        ),
                        const SizedBox(width: Tokens.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(title, style: Tokens.heading),
                              ),
                              const SizedBox(height: Tokens.s4),
                              Text(
                                subtitle,
                                style: Tokens.label.copyWith(
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Tokens.s24),
                    for (final f in fields) ...[
                      f,
                      const SizedBox(height: Tokens.s16),
                    ],
                    if (error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(Tokens.s12),
                          decoration: ShapeDecoration(
                            color: Tokens.red.withValues(alpha: 0.14),
                            shape: Tokens.shape(Tokens.rMd),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 20,
                                color: Tokens.red,
                              ),
                              const SizedBox(width: Tokens.s8),
                              Expanded(
                                child: Text(
                                  error,
                                  style: Tokens.body.copyWith(
                                    color: Tokens.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Tokens.s16),
                    ],
                    const SizedBox(height: Tokens.s8),
                    if (layout.isCompact)
                      submit
                    else
                      Align(alignment: Alignment.centerRight, child: submit),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
