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

/// Splits a console line into arguments the way mpv's input parser does:
///
/// * whitespace separates arguments;
/// * `"..."` quotes an argument, with C style escapes inside (`\"`, `\\`,
///   `\n`, `\t`, `\r`, `\'`, `\$`);
/// * `'...'` quotes an argument literally, without escapes;
/// * a backslash outside quotes is an ordinary character, so Windows paths
///   type as they are.
///
/// Quoted and unquoted parts next to each other join into one argument
/// (`a"b c"` is `ab c`). An unterminated quote throws a [FormatException]
/// unless [lenient], which completion uses while the line is being typed.
List<ConsoleToken> scanConsoleLine(String line, {bool lenient = false}) {
  final tokens = <ConsoleToken>[];
  var i = 0;
  final n = line.length;
  bool isSpace(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';

  while (i < n) {
    while (i < n && isSpace(line[i])) {
      i++;
    }
    if (i >= n) break;
    final start = i;
    final buf = StringBuffer();
    var open = false;
    while (i < n && !isSpace(line[i])) {
      final c = line[i];
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
            buf.write(_escape(line[i + 1]));
            i += 2;
            continue;
          }
          buf.write(d);
          i++;
        }
        if (!closed) {
          if (!lenient) {
            throw FormatException('Unterminated double quote', line, start);
          }
          open = true;
        }
      } else if (c == "'") {
        final close = line.indexOf("'", i + 1);
        if (close < 0) {
          if (!lenient) {
            throw FormatException('Unterminated single quote', line, start);
          }
          buf.write(line.substring(i + 1));
          i = n;
          open = true;
        } else {
          buf.write(line.substring(i + 1, close));
          i = close + 1;
        }
      } else {
        buf.write(c);
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

String _escape(String c) => switch (c) {
  'n' => '\n',
  't' => '\t',
  'r' => '\r',
  _ => c,
};

/// Quotes [value] for a console line when it needs it, so that
/// [tokenizeConsoleLine] reads it back as one argument.
String quoteConsoleArg(String value) {
  if (value.isNotEmpty && !RegExp('[\\s"\']').hasMatch(value)) return value;
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');
  return '"$escaped"';
}
