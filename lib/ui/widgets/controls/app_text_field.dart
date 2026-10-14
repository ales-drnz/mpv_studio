import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../tokens.dart';
import 'control_metrics.dart';

/// The app's one text field: a field pill ([Tokens.surface3]) one control
/// height tall ([controlHeightOf]), the text vertically centred, a body
/// size hint in [Tokens.fgFaint], an accent ring while focused and a red
/// one with the error under the pill when [validator] fails. A field of
/// several lines ([maxLines] other than 1) keeps round corners instead of
/// the pill. A field of several lines with [onSubmitted] holds one long
/// line wrapped over those lines: Enter submits it, and a line break typed
/// or pasted is dropped.
///
/// [leading] sits before the text (a search glyph, a prompt), [action]
/// after it (a clear or apply button). [label] names the field for screen
/// readers; with [showLabel] it also shows above the pill, hidden from
/// screen readers so it is announced once. Pass [autocorrect] and
/// [enableSuggestions] false for URLs, hosts, header names, commands and
/// anything else that is not prose.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.hint,
    this.label,
    this.showLabel = false,
    this.monospace = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onTapOutside,
    this.leading,
    this.action,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.validator,
    this.autofillHints,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String? hint;

  /// The field's name for screen readers, and above the pill with
  /// [showLabel].
  final String? label;

  /// Whether [label] also shows above the pill.
  final bool showLabel;

  /// Monospace text, for URLs, paths, commands and option values.
  final bool monospace;

  final ValueChanged<String>? onChanged;

  /// Called with the text when the user presses Enter (or the keyboard's
  /// action key).
  final ValueChanged<String>? onSubmitted;

  final GestureTapCallback? onTap;
  final TapRegionCallback? onTapOutside;

  /// A widget before the text, such as a search glyph.
  final Widget? leading;

  /// A widget after the text, such as a clear or apply button.
  final Widget? action;

  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;

  /// Checks the text when the enclosing [Form] validates; the message
  /// shows under the pill and rings it red.
  final FormFieldValidator<String>? validator;

  final Iterable<String>? autofillHints;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;

  static final _noLineBreaks = FilteringTextInputFormatter.deny(
    RegExp(r'[\n\r]'),
  );

  /// The text style of a field: body text, monospace when [monospace].
  static TextStyle textStyle({bool monospace = false, bool enabled = true}) =>
      Tokens.body.copyWith(
        fontFamily: monospace ? Tokens.mono : null,
        color: enabled ? Tokens.fg : Tokens.fgFaint,
      );

  /// The hint style of every field.
  static TextStyle get hintStyle => Tokens.body.copyWith(color: Tokens.fgFaint);

  @override
  Widget build(BuildContext context) {
    final h = controlHeightOf(context);
    final multiline = maxLines != 1;
    // Several lines shown, one line of text: Enter submits.
    final wrapped = multiline && onSubmitted != null;
    final radius = BorderRadius.circular(multiline ? Tokens.rMd : h / 2);
    OutlineInputBorder ring([Color? color]) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: color == null
          ? BorderSide.none
          : BorderSide(color: color, width: 2),
    );
    // The text line is 20 high; the rest of the control height is padding.
    final v = multiline ? Tokens.s12 : (h - 20) / 2;
    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      onTapOutside: onTapOutside,
      textInputAction:
          textInputAction ?? (wrapped ? TextInputAction.done : null),
      keyboardType: keyboardType ?? (wrapped ? TextInputType.text : null),
      inputFormatters: wrapped ? [_noLineBreaks] : null,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      validator: validator,
      autofillHints: autofillHints,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      style: textStyle(monospace: monospace, enabled: enabled),
      cursorColor: Tokens.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: hintStyle,
        hintMaxLines: 1,
        isDense: true,
        // The compact pointer density would take 8 off the control height.
        visualDensity: VisualDensity.standard,
        filled: true,
        fillColor: Tokens.surface3,
        hoverColor: Colors.transparent,
        errorStyle: Tokens.label.copyWith(color: Tokens.red),
        errorMaxLines: 3,
        prefixIcon: leading == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: Tokens.s16,
                  end: Tokens.s8,
                ),
                child: leading,
              ),
        prefixIconConstraints: const BoxConstraints(),
        suffixIcon: action == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(end: Tokens.s4),
                child: action,
              ),
        suffixIconConstraints: BoxConstraints(minHeight: h),
        contentPadding: EdgeInsetsDirectional.only(
          start: leading == null ? Tokens.s16 : 0,
          end: action == null ? Tokens.s16 : Tokens.s4,
          top: v,
          bottom: v,
        ),
        border: ring(),
        enabledBorder: ring(),
        disabledBorder: ring(),
        focusedBorder: ring(Tokens.accent),
        errorBorder: ring(Tokens.red),
        focusedErrorBorder: ring(Tokens.red),
      ),
    );
    final named = Semantics(label: label, child: field);
    if (!showLabel || label == null) return named;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(
              left: Tokens.s16,
              right: Tokens.s16,
              bottom: Tokens.s8,
            ),
            child: Text(
              label!,
              style: Tokens.label.copyWith(
                color: Tokens.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        named,
      ],
    );
  }
}
