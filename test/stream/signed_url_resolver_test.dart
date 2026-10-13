import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/stream/signed_url_resolver.dart';

const _target = 'http://localhost:8000/02_swell.mp3';
final _entry = SignedUrlResolver.wrap(_target);

SourceResolveRequest _req(String uri, {bool retry = false}) =>
    SourceResolveRequest(media: Media(_entry), uri: uri, isRetry: retry);

void main() {
  var now = DateTime(2026, 10, 13, 12);
  late SignedUrlResolver resolver;

  setUp(() {
    now = DateTime(2026, 10, 13, 12);
    resolver = SignedUrlResolver(clock: () => now);
  });

  test('unwraps only well formed signed entries', () {
    expect(SignedUrlResolver.unwrap(_entry), _target);
    expect(SignedUrlResolver.unwrap(_target), isNull);
    expect(SignedUrlResolver.unwrap('studio-signed://not a url'), isNull);
  });

  test('a signature holds until it expires and breaks if edited', () {
    final url = resolver.sign(_target, now.add(const Duration(minutes: 1)));
    expect(resolver.isValid(url), isTrue);
    expect(
      resolver.isValid(url.replaceFirst('02_swell', '03_chords')),
      isFalse,
    );
    now = now.add(const Duration(minutes: 2));
    expect(resolver.isValid(url), isFalse);
  });

  test('simulated expiry: expired first, fresh on the retry, then kept', () {
    expect(resolver.simulateExpiry, isTrue);
    final expired = resolver.resolve(_req(_entry)) as String;
    expect(resolver.isValid(expired), isFalse);
    expect(
      Uri.parse(expired).pathSegments.first,
      SignedUrlResolver.expiredPath,
    );

    final fresh = resolver.resolve(_req(expired, retry: true)) as String;
    expect(resolver.isValid(fresh), isTrue);
    expect(fresh, startsWith('$_target?exp='));

    // mpv runs the pre-open pass again with the fresh link in place.
    expect(resolver.resolve(_req(fresh)), isNull);

    expect(resolver.log.map((e) => e.outcome), [
      ResolveOutcome.kept,
      ResolveOutcome.signed,
      ResolveOutcome.expired,
    ]);
    expect(resolver.log[1].isRetry, isTrue);
    expect(resolver.log[1].returned, fresh);
    expect(resolver.log.last.uri, _entry);
  });

  test('without simulated expiry the first link is fresh', () {
    resolver.simulateExpiry = false;
    final url = resolver.resolve(_req(_entry)) as String;
    expect(resolver.isValid(url), isTrue);
  });

  test('leaves other entries alone and notifies on every call', () {
    var notified = 0;
    resolver.addListener(() => notified++);
    final other = SourceResolveRequest(
      media: const Media(_target),
      uri: _target,
      isRetry: false,
    );
    expect(resolver.resolve(other), isNull);
    expect(notified, 0);
    resolver.resolve(_req(_entry));
    expect(notified, 1);
    resolver.clearLog();
    expect(resolver.log, isEmpty);
    expect(notified, 2);
  });
}
