import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import 'stream_states.dart';

/// The input decoration of every Stream text field: a filled inset with a
/// leading glyph, the label floating above, and the accent or red outline
/// when focused or invalid. At least one tap target tall.
InputDecoration streamFieldDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  IconData? icon,
  Widget? suffix,
}) {
  final touch = context.layout.isTouch;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Tokens.rSm),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: !touch,
    filled: true,
    fillColor: Tokens.surface2,
    labelStyle: Tokens.label,
    floatingLabelStyle: Tokens.label.copyWith(color: Tokens.accent),
    hintStyle: Tokens.caption,
    errorStyle: Tokens.caption.copyWith(color: Tokens.red),
    prefixIcon: icon == null ? null : Icon(icon, size: 18),
    prefixIconColor: Tokens.fgFaint,
    suffixIcon: suffix,
    contentPadding: EdgeInsets.symmetric(
      horizontal: Tokens.s12,
      vertical: touch ? Tokens.s12 : Tokens.s8,
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
    TextStyle(fontFamily: Tokens.mono, fontSize: 13, color: Tokens.fg);

/// A labelled text field of a sign-in form. Enter moves to the next field,
/// and submits on the last one ([onSubmitted]).
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
    return TextFormField(
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
      decoration: streamFieldDecoration(
        context,
        label: label,
        hint: hint,
        icon: icon,
      ),
    );
  }
}

/// A required-field validator with the message "[what] is required.".
FormFieldValidator<String> requiredField(String what) =>
    (value) =>
        (value == null || value.trim().isEmpty) ? '$what is required.' : null;

/// The sign-in card of a server tab: a heading, the fields, the error of
/// the last attempt and the submit button, centred and width capped. It
/// scrolls, so the focused field stays above the soft keyboard. The fields
/// sit in a [Form] under [formKey], so [onSubmit] can validate them first.
class SignInCard extends StatelessWidget {
  const SignInCard({
    super.key,
    required this.formKey,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.onSubmit,
    this.busy = false,
    this.error,
    this.submitLabel = 'Connect',
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String subtitle;
  final List<Widget> fields;
  final VoidCallback onSubmit;
  final bool busy;
  final String? error;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.symmetric(
          vertical: context.layout.isShort ? Tokens.s8 : Tokens.s24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: formKey,
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Tokens.heading,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: Tokens.s4),
                  Text(
                    subtitle,
                    style: Tokens.label,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Tokens.s20),
                  for (final f in fields) ...[
                    f,
                    const SizedBox(height: Tokens.s12),
                  ],
                  if (error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: Tokens.red,
                          ),
                          const SizedBox(width: Tokens.s8),
                          Expanded(
                            child: Text(
                              error!,
                              style: Tokens.label.copyWith(color: Tokens.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Tokens.s12),
                  ],
                  StreamButton(
                    label: submitLabel,
                    busy: busy,
                    onPressed: onSubmit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
