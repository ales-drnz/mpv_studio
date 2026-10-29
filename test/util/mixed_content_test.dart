import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/util/mixed_content.dart';

void main() {
  final https = Uri.parse('https://ales-drnz.github.io/mpv_studio/');

  bool blocked(String url, {bool web = true, Uri? page}) =>
      isBlockedMixedContent(Uri.parse(url), web: web, page: page ?? https);

  test('an http server is blocked from an https page', () {
    expect(blocked('http://192.168.1.11:8096'), isTrue);
    expect(blocked('http://jellyfin.example.com'), isTrue);
  });

  test('https, and the machine itself, are not', () {
    expect(blocked('https://192.168.1.11:8920'), isFalse);
    expect(blocked('http://localhost:8096'), isFalse);
    expect(blocked('http://127.0.0.1:8096'), isFalse);
    expect(blocked('http://[::1]:8096'), isFalse);
  });

  test('nothing is blocked from an http page or outside the browser', () {
    expect(
      blocked('http://192.168.1.11:8096', page: Uri.parse('http://x/')),
      isFalse,
    );
    expect(blocked('http://192.168.1.11:8096', web: false), isFalse);
  });
}
