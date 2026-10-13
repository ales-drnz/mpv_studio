/// One argument of a console line and where it sits in the line.
class ConsoleToken {
  const ConsoleToken(this.value, this.start, this.end, {this.open = false});

  /// The argument with quotes removed and escapes applied.
  final String value;

  /// The `[start, end)` range of the raw text, quotes included.
  final int start;
  final int end;

  /// Whether a quote opened in it is still unterminated.
  final bool open;

  @override
  String toString() => 'ConsoleToken($value, $start, $end)';
}

/// Splits a console line into arguments following mpv's input command
/// syntax:
///
/// * whitespace separates arguments, and `#` at the start of one begins a
///   comment that runs to the end of the line;
/// * an argument that starts with `"` is quoted up to the next unescaped
///   `"`, with C style escapes inside (`\"`, `\\`, `\n`, `\t`, `\r`, `\b`,
///   `\f`, `\e`, `\'`, `\/`, `\xHH`, `\uHHHH`); an unknown escape is an
///   error;
/// * one that starts with `'` is taken literally up to the next `'`;
/// * a custom quote starts with a backtick and any character X and ends
///   at X and a backtick (`` `!a "b"!` `` is `a "b"`), also literal;
/// * quotes elsewhere in an argument, and backslashes outside quotes, are
///   ordinary characters, so Windows paths type as they are.
///
/// An unterminated quote or a bad escape throws a [FormatException] unless
/// [lenient], which completion uses while the line is being typed.
List<ConsoleToken> scanConsoleLine(String line, {bool lenient = false}) {
  final tokens = <ConsoleToken>[];
  final n = line.length;
  bool isSpace(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';
  var i = 0;

  Never fail(String message, int at) =>
      throw FormatException(message, line, at);

  while (i < n) {
    while (i < n && isSpace(line[i])) {
      i++;
    }
    if (i >= n || line[i] == '#') break;
    final start = i;
    final c = line[i];
    final buf = StringBuffer();
    var open = false;
    if (c == '"') {
      i++;
      var closed = false;
      while (i < n) {
        final d = line[i];
        if (d == '"') {
          closed = true;
          i++;
          break;
        }
        if (d == r'\' && i + 1 < n) {
          final (text, used) = _escape(line, i + 1);
          if (text == null) {
            if (!lenient) fail('Unknown escape \\${line[i + 1]}', i);
            buf.write(line[i + 1]);
            i += 2;
            continue;
          }
          buf.write(text);
          i += 1 + used;
          continue;
        }
        buf.write(d);
        i++;
      }
      if (!closed) {
        if (!lenient) fail('Unterminated double quote', start);
        open = true;
      }
    } else if (c == "'" || (c == '`' && i + 1 < n)) {
      final close = c == "'" ? "'" : '${line[i + 1]}`';
      final from = c == "'" ? i + 1 : i + 2;
      final end = line.indexOf(close, from);
      if (end < 0) {
        if (!lenient) fail('Unterminated quote', start);
        buf.write(line.substring(from));
        i = n;
        open = true;
      } else {
        buf.write(line.substring(from, end));
        i = end + close.length;
      }
    } else {
      while (i < n && !isSpace(line[i])) {
        buf.write(line[i]);
        i++;
      }
    }
    tokens.add(ConsoleToken(buf.toString(), start, i, open: open));
  }
  return tokens;
}

/// The arguments of [line]; see [scanConsoleLine].
List<String> tokenizeConsoleLine(String line) => [
  for (final t in scanConsoleLine(line)) t.value,
];

/// The text of the escape whose letter is at [at] in [line], and how many
/// characters it used; null text for an unknown or malformed escape.
(String?, int) _escape(String line, int at) {
  final c = line[at];
  String? hex(int length) {
    if (at + 1 + length > line.length) return null;
    final code = int.tryParse(
      line.substring(at + 1, at + 1 + length),
      radix: 16,
    );
    return code == null ? null : String.fromCharCode(code);
  }

  return switch (c) {
    '"' || r'\' || "'" || '/' => (c, 1),
    'n' => ('\n', 1),
    't' => ('\t', 1),
    'r' => ('\r', 1),
    'b' => ('\b', 1),
    'f' => ('\f', 1),
    'e' => ('\x1b', 1),
    'x' => (hex(2), 3),
    'u' => (hex(4), 5),
    _ => (null, 1),
  };
}

/// Quotes [value] for a console line when it needs it, so that
/// [tokenizeConsoleLine] reads it back as one argument.
String quoteConsoleArg(String value) {
  if (value.isNotEmpty &&
      !RegExp(r'\s').hasMatch(value) &&
      !RegExp('^["\'`#]').hasMatch(value)) {
    return value;
  }
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');
  return '"$escaped"';
}
