import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/console/console_tokenizer.dart';

void main() {
  List<String> t(String line) => tokenizeConsoleLine(line);

  test('whitespace separates arguments', () {
    expect(t('  seek   30\tabsolute '), ['seek', '30', 'absolute']);
    expect(t(''), isEmpty);
  });

  test('double quotes keep spaces and take escapes', () {
    // mpv: print-text "a b" has one argument.
    expect(t('print-text "a b"'), ['print-text', 'a b']);
    expect(t(r'print-text "say \"hi\" \\ \n"'), [
      'print-text',
      'say "hi" \\ \n',
    ]);
    expect(t('a "" b'), ['a', '', 'b']);
  });

  test('single quotes are literal', () {
    expect(t(r"print-text 'a \n b'"), ['print-text', r'a \n b']);
  });

  test('a backslash outside quotes stays', () {
    expect(t(r'loadfile C:\Music\a.flac'), ['loadfile', r'C:\Music\a.flac']);
  });

  test('quotes count only at the start of an argument', () {
    // mpv reads a"b c" as two arguments.
    expect(t('a"b c"'), ['a"b', 'c"']);
  });

  test('custom quotes, comments and escapes', () {
    expect(t('print-text `!a "b" \\n!`'), ['print-text', 'a "b" \\n']);
    expect(t('seek 10 # forward'), ['seek', '10']);
    expect(t('"#x" #'), ['#x']);
    expect(t(r'"\x41\u00e8"'), ['Aè']);
    expect(() => t(r'"\q"'), throwsFormatException);
    expect(scanConsoleLine(r'"\q"', lenient: true).single.value, 'q');
  });

  test('an unterminated quote is an error unless lenient', () {
    expect(() => t('print-text "a b'), throwsFormatException);
    expect(() => t("print-text 'a"), throwsFormatException);
    final tokens = scanConsoleLine('print-text "a b', lenient: true);
    expect(tokens.last.value, 'a b');
    expect(tokens.last.open, isTrue);
    expect(tokens.last.start, 11);
    expect(tokens.last.end, 15);
  });

  test('quoteConsoleArg round trips', () {
    for (final v in [
      'plain',
      'a b',
      'say "hi"',
      r'back\slash x',
      '',
      "it's",
      '"quoted"',
      '#hash',
    ]) {
      expect(t('cmd ${quoteConsoleArg(v)}'), ['cmd', v]);
    }
    expect(quoteConsoleArg('plain'), 'plain');
  });
}
