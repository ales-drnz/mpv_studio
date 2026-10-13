import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import 'stream_states.dart';

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
    return AppTextField(
      controller: controller,
      label: label,
      showLabel: true,
      hint: hint,
      monospace: true,
      leading: icon == null ? null : Icon(icon, size: 20, color: Tokens.fgDim),
      obscureText: obscure,
      validator: validator,
      autofocus: autofocus,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      // Hosts, URLs, user names and passwords are not prose; only names
      // keep the keyboard's suggestions.
      autocorrect: false,
      enableSuggestions: !obscure && keyboardType != TextInputType.url,
      textInputAction: last ? TextInputAction.go : TextInputAction.next,
      onSubmitted: last ? (_) => onSubmitted?.call() : null,
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
