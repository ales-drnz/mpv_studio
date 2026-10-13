import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';

/// What a Console line is.
enum ConsoleLineKind {
  /// An engine or library log entry.
  log,

  /// A command the user ran.
  input,

  /// A command's answer.
  output,

  /// How a command was routed to the Player API.
  routed,

  /// A command that failed.
  error,
}

/// One line of the Console.
@immutable
class ConsoleLine {
  const ConsoleLine(
    this.kind,
    this.text, {
    this.level = LogLevel.info,
    this.prefix = '',
  });

  ConsoleLine.log(MpvLogEntry e)
    : kind = ConsoleLineKind.log,
      text = e.text,
      level = e.level,
      prefix = e.prefix;

  final ConsoleLineKind kind;
  final LogLevel level;
  final String prefix;
  final String text;

  /// The line as plain text, for copying.
  String get plain => kind == ConsoleLineKind.log && prefix.isNotEmpty
      ? '[$prefix] $text'
      : text;

  /// Whether [query] (lower case) appears in the text or the prefix.
  bool matches(String query) =>
      query.isEmpty ||
      text.toLowerCase().contains(query) ||
      prefix.toLowerCase().contains(query);
}

/// Severity rank, lower is more severe.
int logSeverity(LogLevel l) => switch (l) {
  LogLevel.fatal => 0,
  LogLevel.error => 1,
  LogLevel.warn => 2,
  LogLevel.info => 4,
  LogLevel.v => 5,
  LogLevel.debug => 6,
  LogLevel.trace => 7,
  LogLevel.off => 8,
};

/// The readable name of a log level.
String logLevelLabel(LogLevel l) => switch (l) {
  LogLevel.fatal => 'Fatal',
  LogLevel.error => 'Errors',
  LogLevel.warn => 'Warnings',
  LogLevel.info => 'Info',
  LogLevel.v => 'Verbose',
  LogLevel.debug => 'Debug',
  LogLevel.trace => 'Trace',
  LogLevel.off => 'Off',
};

/// The scrolling log: one selectable area over plain text rows, so a
/// mouse drag selects text (and Ctrl+C copies it) across rows.
class ConsoleLogView extends StatelessWidget {
  const ConsoleLogView({
    super.key,
    required this.lines,
    required this.controller,
    required this.emptyText,
  });

  final List<ConsoleLine> lines;
  final ScrollController controller;
  final String emptyText;

  static TextStyle get _mono => Tokens.numeric.copyWith(
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: Tokens.fg,
  );

  static Color _color(ConsoleLine l) => switch (l.kind) {
    ConsoleLineKind.input => Tokens.accent,
    ConsoleLineKind.error => Tokens.red,
    ConsoleLineKind.output => Tokens.fg,
    ConsoleLineKind.routed => Tokens.green,
    ConsoleLineKind.log => switch (l.level) {
      LogLevel.fatal || LogLevel.error => Tokens.red,
      LogLevel.warn => Tokens.amber,
      LogLevel.info => Tokens.fgDim,
      _ => Tokens.fgFaint,
    },
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.shape(Tokens.rLg),
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: Tokens.shape(Tokens.rLg)),
        child: _lines(context),
      ),
    );
  }

  Widget _lines(BuildContext context) {
    if (lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.s24),
          child: Text(
            emptyText,
            style: Tokens.body.copyWith(color: Tokens.fgDim),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // One SelectionArea for the whole log, over plain Text rows: a
    // SelectableText per row registers each line as a text field in the
    // semantics tree, which under a log flood fights the list's layout
    // ("RenderViewport exceeded its maximum number of layout cycles").
    return SelectionArea(
      // Without the mouse among the drag devices, a mouse drag selects
      // text instead of scrolling; the wheel and trackpad still scroll.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        child: ListView.builder(
          controller: controller,
          padding: const EdgeInsets.all(Tokens.s16),
          itemCount: lines.length,
          itemBuilder: (context, i) => _row(lines[i]),
        ),
      ),
    );
  }

  Widget _row(ConsoleLine l) {
    final mono = _mono;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text.rich(
        TextSpan(
          style: mono,
          children: [
            if (l.kind == ConsoleLineKind.log) ...[
              TextSpan(
                text: '${l.level.mpvValue.padRight(5)} ',
                style: mono.copyWith(
                  color: _color(l),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (l.prefix.isNotEmpty)
                TextSpan(
                  text: '${l.prefix}: ',
                  style: mono.copyWith(color: Tokens.fgFaint),
                ),
              TextSpan(text: l.text),
            ] else
              TextSpan(
                text: l.text,
                style: mono.copyWith(color: _color(l)),
              ),
          ],
        ),
      ),
    );
  }
}
